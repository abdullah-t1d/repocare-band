/*
  repoCare Band (Aware) - Combined Prototype Firmware  v3.0
  Board   : Seeed Studio XIAO nRF52840 Sense
  Sensors : ProtoCentral Pulse 3+ (MAX30102)  @ 0x57  - HR, SpO2, HRV/PRV, PPG
            ProtoCentral AS6221 skin temp     @ 0x48
  Wiring  : shared I2C via Qwiic hub. 3V3, GND, SDA = D4, SCL = D5
  Site    : FINGERTIP (default) or BACK OF THE WRIST. Send 'f' / 'w' to switch.
            Each profile keeps its own validated settings and algorithm.

  Serial protocol @115200 (UNCHANGED):
    S,<ir>,<red>,<ppg>
    B,<ibi_ms>
    M,<bpm>,<spo2>,<rmssd>,<contact>,<quality>,<skinTempC>,<led>,<saturated>,
      <beats>,<pi>,<motion>,<auto>,<led_mA>
    #<status>
  Sentinels: bpm/spo2/rmssd = -1, skin temp = -99, pi = -1
  Commands : 'a' auto LED, '1'..'4' fixed LED, 'r' reset,
             'f' finger profile, 'w' wrist profile  (new, backward compatible)

  v3.0: two profiles in one firmware.
    FINGER = v2.2 unchanged (HR tiers, SpO2, HRV).
    WRIST  = wrist algorithm validated on the back of the wrist: ADC 16384, bright
             auto LED (IR 140k-210k), 15 s rhythm search on IR/RED/MIX, a rate must
             repeat 3 s before it is shown, no SpO2, HRV only when beats and rhythm agree.
    '#MODE finger|wrist' is printed at boot and on every switch; '#CH IR|RED|MIX' (wrist).

  What changed in v2.1 (summary, details in the notes at the end of the file):
    - Heart rate now has three confidence tiers (A: two methods agree,
      B: consistent beats, C: strong rhythm only). HR is shown from tier B/C,
      SpO2 and HRV only from tier A (stricter, as requested).
    - Beat consistency uses a robust median-based spread instead of a plain
      coefficient of variation, so normal breathing-related HRV no longer
      blocks the heart rate.
    - Auto-brightness changes are rarer and no longer wipe the 8 s rhythm
      buffer (each change used to hide HR for ~9 s).
    - Contact thresholds scale with LED current, LED returns to the start
      level when the finger is removed, and contact is debounced.
    - v2.2: HRV (RMSSD) from a 60 s artefact-corrected window, updated every 10 s,
      only after 45 s of usable signal. SpO2 shown after 3 good seconds in a row.
    - Faster rhythm search (no FIFO pressure), runtime MAX30102 health check,
      I2C bus recovery at boot. AS6221 code unchanged and independent.

  Research prototype, not a medical device. SpO2 is an uncalibrated estimate.
  PPG-derived HRV (PRV) is not equivalent to ECG HRV. Skin temperature is not
  core body temperature.
*/

#include <Adafruit_TinyUSB.h>
#include <Wire.h>
#include "MAX30105.h"
#include "protocentral_as6221.h"

MAX30105 sensor;
ProtocentralAS6221 skinTempSensor(AS6221_DEFAULT_ADDRESS);

bool maxReady = false;
bool skinTempReady = false;

// =====================================================
// MAX30102 configuration (unchanged: proven on the fingertip)
// =====================================================
const uint16_t SAMPLE_RATE   = 400;   // internal rate
const uint8_t  SAMPLE_AVG    = 4;     // -> ~100 samples/s
const uint16_t MS_PER_SAMPLE = 10;
const uint32_t SATURATED     = 250000;  // ADC full scale is 262143

// ---- Contact (IR counts at the START LED level, ADC range 4096) ----------
// Typical IR at ~6 mA:  no contact / ambient reflection ~1k-30k (25k seen with the hub),
//                        weak contact ~30k-60k, good fingertip ~80k-180k,
//                        saturation >250k.
// Thresholds are scaled with the current LED amplitude (see contactScale()),
// because a brighter LED also raises the no-contact reflection.
// (finger values; wrist values are in the WRIST profile below)
const uint8_t  CONTACT_DEBOUNCE = 30;  // samples (~300 ms) before contact changes

// ---- Auto brightness --------------------------------------------------------
// ---- Two measurement profiles. Switch with 'f' (finger) or 'w' (wrist). ----
struct Profile {
  const char *name;
  uint16_t adcRange;      // MAX30102 ADC full-scale setting
  uint8_t  ledStart;      // starting LED amplitude (0.2 mA per step)
  uint32_t contactOn;     // IR above -> skin present   (at ledStart, scaled with LED)
  uint32_t contactOff;    // IR below -> skin removed   (hysteresis)
  uint32_t agcLow;        // auto brightness keeps the IR level inside [agcLow, agcHigh]
  uint32_t agcHigh;
};
// Finger: values validated on the fingertip (v2.1/v2.2).
const Profile FINGER = {"finger", 4096,  0x1F, 50000, 30000,  60000, 200000};
// Wrist (BACK of the wrist): values validated in the wrist tests.
// The wrist pulse is 10-50x weaker, so the LED runs much brighter with a 4x wider ADC range.
const Profile WRIST  = {"wrist",  16384, 0x7F, 12000,  8000, 140000, 210000};
const Profile *P = &FINGER;
bool wristMode = false;
const uint16_t AGC_MIN_INTERVAL_MS = 3000;  // was 1000: one change per 3 s at most

// ---- Timing -----------------------------------------------------------------
const uint16_t SETTLE_MS     = 1500;   // after finger placed
const uint16_t SETTLE_AGC_MS = 500;    // after an LED change (was 1500 + buffer wipe)
const uint16_t MIN_IBI = 300, MAX_IBI = 2000;   // 30..200 BPM
const uint16_t LOST_MS = 4000;         // no beat for this long -> beat history cleared
const uint16_t HR_HOLD_MS = 10000;     // keep last good HR through short disturbances

// ---- Confidence rules (tune these with real data) ----------------------------
const float TIER_B_MAX_SPREAD = 0.10f; // robust spread of the last beats (MAD/median)
const float TIER_C_MIN_AC     = 0.45f; // rhythm strength needed when beats are unclear...
const float TIER_C_ALONE_AC   = 0.65f; // ...and when it does not continue the last good HR
const float AGREE_TOL         = 0.10f; // beats vs rhythm must agree within 10 %
const int   HRV_MIN_QUALITY   = 70;    // SpO2 only from tier A at/above this
// ---- HRV / PRV (RMSSD) over a 60 s window, artefact-corrected ----
const uint32_t HRV_WINDOW_MS   = 60000; // analysis window (ultra-short HRV needs >= 30-60 s)
const uint32_t HRV_MIN_SPAN_MS = 45000; // beats must cover at least this much of the window
const uint8_t  HRV_MIN_PAIRS   = 30;    // clean successive-difference pairs required
const float    HRV_MAX_DIFF    = 0.20f; // drop pairs whose difference is > 20 % of the median
const uint32_t HRV_UPDATE_MS   = 10000; // recompute every 10 s (not every second)
const uint32_t HRV_SHOW_MS     = 15000; // keep the last value on screen this long
const uint16_t HRV_STABLE_SEC  = 45;    // seconds of usable signal (quality >= 45) in a row
const uint8_t  SPO2_STABLE_SEC = 3;     // SpO2 shown after 3 good seconds in a row
const uint8_t SPO2_MIN_SAMPLES = 4;
const float SPO2_MIN_PI       = 0.20f; // % ; very weak pulses give meaningless R

const byte LED_FIXED[4] = {0x1F, 0x3F, 0x7F, 0xFF};   // ~6, 12, 25, 50 mA
bool autoLed = true;
uint8_t ledPA = 0x1F;
uint8_t fixedIndex = 0;

// =====================================================
// Filters (unchanged): 2nd-order Butterworth, fs = 100 Hz
// =====================================================
struct Biquad {
  float b0, b1, b2, a1, a2, z1, z2;
  float run(float x) { float y = b0 * x + z1; z1 = b1 * x - a1 * y + z2; z2 = b2 * x - a2 * y; return y; }
  void reset(float x0 = 0) {
    float dcGain = (b0 + b1 + b2) / (1 + a1 + a2);
    float y0 = dcGain * x0;
    z1 = y0 - b0 * x0; z2 = b2 * x0 - a2 * y0;
  }
};
Biquad hpIR  {0.97803048f, -1.95606096f, 0.97803048f, -1.95557824f, 0.95654368f, 0, 0};  // 0.5 Hz HP
Biquad lpIR  {0.01335920f,  0.02671840f, 0.01335920f, -1.64745998f, 0.70089678f, 0, 0};  // 4 Hz LP
Biquad hpRed {0.97803048f, -1.95606096f, 0.97803048f, -1.95557824f, 0.95654368f, 0, 0};
Biquad lpRed {0.01335920f,  0.02671840f, 0.01335920f, -1.64745998f, 0.70089678f, 0, 0};

// =====================================================
// State
// =====================================================
uint32_t lastMaxInitTry = 0, lastTempInitTry = 0, lastHealthCheck = 0;
uint32_t sampleCount = 0;
bool contact = false;
uint8_t contactCount = 0;              // debounce counter
uint32_t settleUntil = 0;
uint32_t lastIr = 0, lastRed = 0;
bool satRecent = false;

float dcIR = 0, dcRed = 0;
float ppg = 0, ppgRed = 0;
float envHi = 0, envLo = 0;

// Beat detector: steepest upstroke inside a +/-150 ms window (unchanged)
const uint8_t HALF_WIN = 15, WIN = 2 * HALF_WIN + 1;
float win[WIN]; uint8_t winHead = 0, winFill = 0;
float hist4[4] = {0, 0, 0, 0}; uint8_t h4 = 0;
float slopeEnv = 0;
uint32_t lastBeatMs = 0; uint8_t rejectRun = 0;
bool gapPending = false;               // next stored interval follows a rejected beat

// Beat intervals
const uint8_t N_IBI = 12;
uint16_t ibiBuf[N_IBI]; bool ibiGap[N_IBI];
uint8_t ibiCount = 0, ibiHead = 0;

// Long beat history for HRV (~60-90 s)
const uint8_t N_HRV = 128;
uint16_t hrvIbi[N_HRV]; uint32_t hrvT[N_HRV]; bool hrvGap[N_HRV];
uint8_t hrvCount = 0, hrvHead = 0;
float hrvValue = -1; uint32_t hrvAt = 0, lastHrvCalc = 0;
uint16_t stableSec = 0; uint8_t spo2Run = 0;

// Rhythm search buffer: 8 s of upstroke signal at 100 Hz
const uint16_t AC_N = 800;
float acBuf[AC_N]; uint16_t acHead = 0, acFill = 0;
float acBpm = -1, acStrength = 0;
// Wrist: 15 s rhythm search on three signals (IR, RED, IR+RED), the clearest one wins
const uint16_t WAC_N = 1500;
float wIR[WAC_N], wRed[WAC_N], wMix[WAC_N];
uint16_t wHead = 0, wFill = 0;
float histR[4] = {0, 0, 0, 0}, histM[4] = {0, 0, 0, 0};
uint8_t channel = 0, lastChannel = 255;     // 0 IR, 1 RED, 2 MIX
float prevAc = -1; uint8_t wStableRun = 0;  // wrist: same rate 3 s in a row before showing
float lin[WAC_N / 2];                       // analysis scratch (50 Hz)

// SpO2
float irMax, irMin, redMax, redMin;
const uint8_t N_SPO2 = 8;
float spo2Buf[N_SPO2]; uint8_t spo2Count = 0, spo2Head = 0;

// AGC
uint32_t agcSum = 0; uint16_t agcN = 0; uint32_t lastAgcMs = 0;

// Motion: IMU not enabled at this stage
const bool moving = false;

// Temperature (AS6221, unchanged)
float skinTempC = NAN;
uint32_t lastSkinTempRead = 0;

float lastGoodBpm = -1; uint32_t lastGoodMs = 0;
uint32_t lastMetrics = 0;

// =====================================================
// Helpers
// =====================================================
void resetAC() { irMax = redMax = -1e9f; irMin = redMin = 1e9f; }

void resetBeats() {
  ibiCount = ibiHead = 0; spo2Count = spo2Head = 0;
  slopeEnv = 0; lastBeatMs = 0; rejectRun = 0; gapPending = false;
  acFill = acHead = 0; acBpm = -1; acStrength = 0;
  lastGoodBpm = -1;
  hrvCount = hrvHead = 0; hrvValue = -1; hrvAt = 0; lastHrvCalc = 0;
  stableSec = 0; spo2Run = 0;
  wFill = wHead = 0; prevAc = -1; wStableRun = 0; lastChannel = 255;
  resetAC();
}

void restartFilters(uint32_t ir, uint32_t red, uint32_t t, uint16_t settle) {
  dcIR = ir; dcRed = red;
  hpIR.reset(ir); lpIR.reset(0); hpRed.reset(red); lpRed.reset(0);
  envHi = envLo = 0;
  winHead = winFill = 0;
  for (uint8_t i = 0; i < 4; i++) hist4[i] = histR[i] = histM[i] = 0;
  settleUntil = t + settle;
}

uint16_t ibiAt(uint8_t i) { return ibiBuf[(ibiHead + N_IBI - ibiCount + i) % N_IBI]; }
bool gapAt(uint8_t i)     { return ibiGap[(ibiHead + N_IBI - ibiCount + i) % N_IBI]; }

// Median and robust spread (mean absolute deviation / median) of the last n beats
void beatStats(uint8_t n, float &med, float &spread) {
  uint16_t tmp[N_IBI];
  uint8_t s = ibiCount - n;
  for (uint8_t i = 0; i < n; i++) tmp[i] = ibiAt(s + i);
  for (uint8_t i = 1; i < n; i++) {
    uint16_t v = tmp[i]; int8_t j = i - 1;
    while (j >= 0 && tmp[j] > v) { tmp[j + 1] = tmp[j]; j--; }
    tmp[j + 1] = v;
  }
  med = (n % 2) ? tmp[n / 2] : (tmp[n / 2 - 1] + tmp[n / 2]) / 2.0f;
  float dev = 0;
  for (uint8_t i = 0; i < n; i++) dev += fabs((float)tmp[i] - med);
  spread = (med > 0) ? dev / n / med : 1;
}

float medianIbiAll() { float m, s; beatStats(ibiCount, m, s); return m; }

// Contact thresholds follow the LED: twice the light -> twice the no-contact reflection
float contactScale() { return (float)ledPA / (float)P->ledStart; }

void setLed(uint8_t pa) {
  ledPA = pa;
  sensor.setPulseAmplitudeRed(pa);
  sensor.setPulseAmplitudeIR(pa);
}

// =====================================================
// SpO2 estimate (formula unchanged, inputs checked harder)
// =====================================================
void computeSpO2() {
  if (moving || irMax <= irMin || redMax <= redMin || dcIR < 1 || dcRed < 1) return;
  if (lastIr > SATURATED || lastRed > SATURATED) return;
  float acI = irMax - irMin, acR = redMax - redMin;
  if (100.0f * acI / dcIR < SPO2_MIN_PI) return;          // pulse too weak for a ratio
  float R = (acR / dcRed) / (acI / dcIR);
  if (R < 0.3f || R > 1.5f) return;
  float s = 110.0f - 25.0f * R;                           // experimental, uncalibrated
  if (s > 100) s = 100;
  if (s < 70) return;
  spo2Buf[spo2Head] = s; spo2Head = (spo2Head + 1) % N_SPO2;
  if (spo2Count < N_SPO2) spo2Count++;
}

float medianSpO2() {
  float tmp[N_SPO2];
  for (uint8_t i = 0; i < spo2Count; i++) tmp[i] = spo2Buf[i];
  for (uint8_t i = 1; i < spo2Count; i++) {
    float v = tmp[i]; int8_t j = i - 1;
    while (j >= 0 && tmp[j] > v) { tmp[j + 1] = tmp[j]; j--; }
    tmp[j + 1] = v;
  }
  return (spo2Count % 2) ? tmp[spo2Count / 2] : 0.5f * (tmp[spo2Count / 2 - 1] + tmp[spo2Count / 2]);
}

// =====================================================
// Beat handling
// =====================================================
void onBeat(uint32_t beatT) {
  if (lastBeatMs == 0) { lastBeatMs = beatT; resetAC(); return; }
  uint32_t interval = beatT - lastBeatMs;
  lastBeatMs = beatT;
  if (interval > MAX_IBI || moving) { gapPending = true; resetAC(); return; }

  if (ibiCount >= 4) {
    float med = medianIbiAll();
    if (fabs((float)interval - med) > 0.30f * med) {      // outlier (missed or extra beat)
      resetAC(); gapPending = true;
      if (++rejectRun >= 3) { ibiCount = ibiHead = 0; rejectRun = 0; }   // rhythm changed: relearn
      return;
    }
  }
  rejectRun = 0;
  hrvIbi[hrvHead] = interval; hrvT[hrvHead] = beatT; hrvGap[hrvHead] = gapPending;
  hrvHead = (hrvHead + 1) % N_HRV;
  if (hrvCount < N_HRV) hrvCount++;
  ibiBuf[ibiHead] = interval; ibiGap[ibiHead] = gapPending; gapPending = false;
  ibiHead = (ibiHead + 1) % N_IBI;
  if (ibiCount < N_IBI) ibiCount++;

  Serial.print("B,"); Serial.println(interval);
  computeSpO2();
  resetAC();
}

// =====================================================
// Rhythm search (autocorrelation), shared by both profiles.
// The ring buffer is copied once into a straight 50 Hz array (pairs averaged).
// =====================================================
void autocorrOn(const float *buf, uint16_t N, uint16_t head, float minBest, float &bpmOut, float &strOut) {
  bpmOut = -1; strOut = 0;
  const uint16_t D = N / 2;
  float mean = 0;
  for (uint16_t i = 0; i < D; i++) {
    lin[i] = 0.5f * (buf[(head + 2 * i) % N] + buf[(head + 2 * i + 1) % N]);
    mean += lin[i];
  }
  mean /= D;
  float r0 = 0;
  for (uint16_t i = 0; i < D; i++) { lin[i] -= mean; r0 += lin[i] * lin[i]; }
  if (r0 <= 0) return;

  const uint16_t KMIN = 15, KMAX = 75;   // 200 .. 40 BPM at 50 Hz
  static float r[KMAX + 2];
  float best = 0;
  for (uint16_t k = KMIN - 1; k <= KMAX + 1; k++) {
    float acc = 0;
    const uint16_t n = D - k;
    for (uint16_t i = 0; i < n; i++) acc += lin[i] * lin[i + k];
    r[k] = acc / r0 * D / n;
    if (k >= KMIN && k <= KMAX && r[k] > best) best = r[k];
  }
  if (best < minBest) return;               // finger 0.20, wrist 0.15 (validated values)
  uint16_t K = 0;
  for (uint16_t k = KMIN; k <= KMAX; k++)
    if (r[k] == best && r[k] >= r[k - 1] && r[k] >= r[k + 1]) { K = k; break; }
  if (K == 0) return;
  uint16_t h0 = (uint16_t)(K * 0.45f), h1 = (uint16_t)(K * 0.55f) + 1;   // avoid half-rate error
  for (uint16_t k = max(h0, KMIN); k <= h1 && k <= KMAX; k++)
    if (r[k] >= r[k - 1] && r[k] >= r[k + 1] && r[k] >= 0.85f * best) { K = k; break; }
  float den = r[K - 1] - 2 * r[K] + r[K + 1];
  float off = (den != 0) ? 0.5f * (r[K - 1] - r[K + 1]) / den : 0;
  bpmOut = 3000.0f / (K + off);
  strOut = r[K];
}

void updateAutocorr() {
  acBpm = -1; acStrength = 0;
  if (!wristMode) {                                   // finger: 8 s window, IR only
    if (acFill < AC_N) return;
    autocorrOn(acBuf, AC_N, acHead, 0.20f, acBpm, acStrength);
    return;
  }
  if (wFill < WAC_N) return;                          // wrist: 15 s window, 3 signals
  float b[3], st[3];
  autocorrOn(wIR,  WAC_N, wHead, 0.15f, b[0], st[0]);
  autocorrOn(wRed, WAC_N, wHead, 0.15f, b[1], st[1]);
  autocorrOn(wMix, WAC_N, wHead, 0.15f, b[2], st[2]);
  uint8_t best = 0;
  for (uint8_t c = 1; c < 3; c++) if (st[c] > st[best] + 0.05f) best = c;   // margin = no flicker
  channel = best; acBpm = b[best]; acStrength = st[best];
  if (channel != lastChannel) {
    lastChannel = channel;
    Serial.println(channel == 0 ? "#CH IR" : channel == 1 ? "#CH RED" : "#CH MIX");
  }
}

// =====================================================
// Auto brightness: rarer changes, rhythm buffer kept
// =====================================================
void runAgc(uint32_t t) {
  if (!autoLed || !contact || agcN == 0) return;
  bool due = (t - lastAgcMs >= AGC_MIN_INTERVAL_MS);
  if (!due && !satRecent) return;                 // saturation is handled immediately
  uint32_t mean = agcSum / agcN;
  agcSum = 0; agcN = 0; lastAgcMs = t;

  uint8_t pa = ledPA;
  if (satRecent || mean > P->agcHigh) pa = max(8, (int)(ledPA * 0.75f));
  else if (mean < P->agcLow)          pa = min(255, (int)(ledPA * 1.3f) + 1);
  satRecent = false;

  if (pa != ledPA) {
    setLed(pa);
    restartFilters(lastIr, lastRed, t, SETTLE_AGC_MS);   // beat history and rhythm buffer are kept
    Serial.print("#AGC LED "); Serial.print(ledPA * 0.2f, 1); Serial.println(" mA");
  }
}

// =====================================================
// One MAX30102 sample
// =====================================================
void processSample(uint32_t ir, uint32_t red) {
  sampleCount++;
  uint32_t t = sampleCount * MS_PER_SAMPLE;
  lastIr = ir; lastRed = red;
  if (ir > SATURATED || red > SATURATED) satRecent = true;

  // ---- Contact with LED-scaled hysteresis and debounce ----
  float sc = contactScale();
  if (!contact) {
    if (ir > P->contactOn * sc) { if (++contactCount >= CONTACT_DEBOUNCE) {
        contact = true; contactCount = 0;
        resetBeats(); restartFilters(ir, red, t, SETTLE_MS); lastAgcMs = t; agcSum = 0; agcN = 0;
        Serial.println("#CONTACT on");
    } } else contactCount = 0;
  } else {
    if (ir < P->contactOff * sc) { if (++contactCount >= CONTACT_DEBOUNCE) {
        contact = false; contactCount = 0;
        resetBeats();
        if (autoLed && ledPA != P->ledStart) setLed(P->ledStart);   // otherwise reflection may fake contact
        Serial.println("#CONTACT off");
    } } else contactCount = 0;
  }

  dcIR  += 0.02f * ((float)ir  - dcIR);
  dcRed += 0.02f * ((float)red - dcRed);
  ppg    = lpIR.run(hpIR.run(-(float)ir));     // inverted: each beat becomes an upward peak
  ppgRed = lpRed.run(hpRed.run(-(float)red));

  Serial.print("S,"); Serial.print(ir); Serial.print(',');
  Serial.print(red); Serial.print(',');
  Serial.println(contact ? ppg : 0.0f, 1);

  if (!contact) return;
  agcSum += ir; agcN++;
  runAgc(t);
  if (t < settleUntil) return;

  float span = envHi - envLo;                 // pulse envelope -> perfusion index
  if (ppg > envHi) envHi = ppg; else envHi -= 0.01f * span;
  if (ppg < envLo) envLo = ppg; else envLo += 0.01f * span;

  if (ppg > irMax) irMax = ppg;
  if (ppg < irMin) irMin = ppg;
  if (ppgRed > redMax) redMax = ppgRed;
  if (ppgRed < redMin) redMin = ppgRed;

  float slope = ppg - hist4[h4];              // rise over 40 ms
  hist4[h4] = ppg;
  if (!wristMode) {
    acBuf[acHead] = slope; acHead = (acHead + 1) % AC_N;
    if (acFill < AC_N) acFill++;
  } else {                                    // normalised so IR and RED can be mixed
    float nIR = ppg / dcIR * 100000.0f, nRed = ppgRed / dcRed * 100000.0f, mix = nIR + nRed;
    wIR[wHead] = slope;
    wRed[wHead] = nRed - histR[h4]; histR[h4] = nRed;
    wMix[wHead] = mix - histM[h4];  histM[h4] = mix;
    wHead = (wHead + 1) % WAC_N;
    if (wFill < WAC_N) wFill++;
  }
  h4 = (h4 + 1) % 4;

  slopeEnv *= 0.999f;
  win[winHead] = slope; winHead = (winHead + 1) % WIN;
  if (winFill < WIN) { winFill++; return; }

  float centre = win[(winHead + HALF_WIN) % WIN];
  for (uint8_t i = 0; i < WIN; i++) if (win[i] > centre) return;
  if (centre <= 0 || centre < 0.5f * slopeEnv) return;

  uint32_t beatT = t - HALF_WIN * MS_PER_SAMPLE;
  float refractory = MIN_IBI;                 // skip the dicrotic wave
  if (acBpm > 0)          refractory = max((float)MIN_IBI, 0.55f * 60000.0f / acBpm);
  else if (ibiCount >= 4) refractory = max((float)MIN_IBI, 0.6f * medianIbiAll());
  if (lastBeatMs && (beatT - lastBeatMs) < refractory) return;
  slopeEnv = (slopeEnv == 0) ? centre : 0.7f * slopeEnv + 0.3f * centre;
  onBeat(beatT);
}

// RMSSD from the beats of the last 60 s. Successive differences across a rejected
// beat or larger than 20 % of the median interval are treated as artefacts and skipped.
float computeHRV(uint32_t now) {
  if (hrvCount < HRV_MIN_PAIRS + 1) return -1;
  uint16_t tmp[N_HRV]; uint8_t n = 0;
  uint8_t first = 255;
  for (uint8_t i = 0; i < hrvCount; i++) {
    uint8_t k = (hrvHead + N_HRV - hrvCount + i) % N_HRV;
    if (now - hrvT[k] <= HRV_WINDOW_MS) { if (first == 255) first = i; tmp[n++] = hrvIbi[k]; }
  }
  if (n < HRV_MIN_PAIRS + 1) return -1;
  uint8_t kFirst = (hrvHead + N_HRV - hrvCount + first) % N_HRV;
  uint8_t kLast  = (hrvHead + N_HRV - 1) % N_HRV;
  if (hrvT[kLast] - hrvT[kFirst] < HRV_MIN_SPAN_MS) return -1;
  for (uint8_t i = 1; i < n; i++) {                       // median of the window
    uint16_t v = tmp[i]; int16_t j = i - 1;
    while (j >= 0 && tmp[j] > v) { tmp[j + 1] = tmp[j]; j--; }
    tmp[j + 1] = v;
  }
  float med = (n % 2) ? tmp[n / 2] : 0.5f * (tmp[n / 2 - 1] + tmp[n / 2]);
  float sq = 0; uint8_t pairs = 0;
  for (uint8_t i = first + 1; i < hrvCount; i++) {
    uint8_t k = (hrvHead + N_HRV - hrvCount + i) % N_HRV;
    uint8_t kp = (k + N_HRV - 1) % N_HRV;
    if (hrvGap[k]) continue;
    float d = (float)hrvIbi[k] - hrvIbi[kp];
    if (fabs(d) > HRV_MAX_DIFF * med) continue;
    sq += d * d; pairs++;
  }
  return (pairs >= HRV_MIN_PAIRS) ? sqrt(sq / pairs) : -1;
}

// =====================================================
// Metrics, once per second
// =====================================================
void sendMetrics() {
  uint32_t t = sampleCount * MS_PER_SAMPLE;
  if (contact && lastBeatMs && (t - lastBeatMs) > LOST_MS) { ibiCount = ibiHead = 0; lastBeatMs = 0; }
  updateAutocorr();

  // Beat statistics from the last (up to) 8 accepted intervals
  float beatBpm = -1, spread = 1;
  if (ibiCount >= 4) {
    float med; beatStats(min(ibiCount, (uint8_t)8), med, spread);
    beatBpm = 60000.0f / med;
  }

  float bpm = -1, rmssd = -1, spo2 = -1;
  int quality = 0;
  char tier = '-';

  if (contact) {
    if (wristMode) {
      // ---- Wrist: the 15 s rhythm search leads, beat detection only confirms ----
      bool agreeW = beatBpm > 0 && acBpm > 0 && fabs(beatBpm - acBpm) < AGREE_TOL * acBpm;
      if (acBpm > 0) quality = (int)(constrain((acStrength - 0.25f) / 0.45f, 0.0f, 1.0f) * 100);
      if (agreeW) quality = min(100, quality + 15);
      if (acBpm > 0 && quality >= 40 && prevAc > 0 && fabs(acBpm - prevAc) < 0.08f * prevAc) wStableRun++;
      else wStableRun = 0;
      prevAc = (quality >= 40) ? acBpm : -1;
      if (wStableRun >= 2) { bpm = acBpm; tier = agreeW ? 'A' : 'C'; }   // same rate 3 s in a row
      if (quality == 0) quality = 10;
    } else {
      bool beatsOk = beatBpm > 0 && spread < TIER_B_MAX_SPREAD;
      bool agree   = beatBpm > 0 && acBpm > 0 && acStrength >= 0.3f &&
                     fabs(beatBpm - acBpm) < AGREE_TOL * acBpm && spread < 0.15f;

      if (agree) {                                   // ---- Tier A: both methods agree
        float qPeriod = constrain((acStrength - 0.2f) / 0.5f, 0.0f, 1.0f) * 100;
        float qBeats  = constrain(1.0f - spread / TIER_B_MAX_SPREAD, 0.0f, 1.0f) * 100;
        quality = constrain((int)(0.5f * (qPeriod + qBeats) + 25), 75, 100);
        bpm = beatBpm; tier = 'A';
      } else if (beatsOk) {                          // ---- Tier B: consistent beats
        quality = 45 + (int)(29 * (1.0f - spread / TIER_B_MAX_SPREAD));       // 45..74
        if (acBpm > 0 && acStrength >= TIER_C_MIN_AC &&
            fabs(beatBpm - acBpm) > 0.2f * acBpm) quality = max(40, quality - 10);  // strong rhythm disagrees
        bpm = beatBpm; tier = 'B';
      } else if (acBpm > 0 && acStrength >= TIER_C_MIN_AC &&
                 ((lastGoodBpm > 0 && fabs(acBpm - lastGoodBpm) < 0.15f * lastGoodBpm) ||
                  acStrength >= TIER_C_ALONE_AC)) {      // ---- Tier C: rhythm only
        // Noise can also look periodic, so a rhythm alone is trusted only if it continues
        // the last good HR, or if it is very strong.
        quality = 40 + (int)(25 * constrain((acStrength - TIER_C_MIN_AC) / 0.35f, 0.0f, 1.0f));  // 40..65
        bpm = acBpm; tier = 'C';
      } else {
        quality = 10;                                // contact, but nothing trustworthy yet
      }

    }
    if (moving) quality = min(quality, 20);
    if (lastIr > SATURATED) { quality = min(quality, 20); bpm = -1; }

    if (bpm > 0 && quality >= 40) { lastGoodBpm = bpm; lastGoodMs = millis(); }
    else if (lastGoodBpm > 0 && millis() - lastGoodMs < HR_HOLD_MS) bpm = lastGoodBpm;   // short disturbance
    else bpm = -1;

    // ---- Stability counters ----
    if (quality >= 45 && bpm > 0) { if (stableSec < 60000) stableSec++; } else stableSec = 0;
    if (tier == 'A' && quality >= HRV_MIN_QUALITY) { if (spo2Run < 255) spo2Run++; } else spo2Run = 0;

    // ---- HRV / PRV (RMSSD): 60 s window, recomputed every 10 s ----
    if (t - lastHrvCalc >= HRV_UPDATE_MS) {
      lastHrvCalc = t;
      bool okW = !wristMode || (tier == 'A' && quality >= HRV_MIN_QUALITY);   // wrist: stricter
      float v = (stableSec >= HRV_STABLE_SEC && !moving && okW) ? computeHRV(t) : -1;
      if (v > 0) { hrvValue = v; hrvAt = t; }
    }
    if (hrvValue > 0 && t - hrvAt < HRV_SHOW_MS) rmssd = hrvValue;

    // ---- SpO2: tier A only, after a few good seconds in a row ----
    if (!wristMode && spo2Run >= SPO2_STABLE_SEC && spo2Count >= SPO2_MIN_SAMPLES)   // never on the wrist
      spo2 = medianSpO2();
  } else {
    lastGoodBpm = -1; stableSec = 0; spo2Run = 0;
  }

  float pi = (contact && dcIR > 0 && t >= settleUntil) ? 100.0f * (envHi - envLo) / dcIR : -1;
  uint8_t ledLevel = 0;
  for (uint8_t i = 0; i < 4; i++) if (ledPA == LED_FIXED[i]) ledLevel = i + 1;

  Serial.print("M,");
  Serial.print(bpm, 1);   Serial.print(',');
  Serial.print(spo2, 1);  Serial.print(',');
  Serial.print(rmssd, 1); Serial.print(',');
  Serial.print(contact ? 1 : 0); Serial.print(',');
  Serial.print(quality);  Serial.print(',');
  if (skinTempReady && !isnan(skinTempC)) Serial.print(skinTempC, 2); else Serial.print(-99);
  Serial.print(',');
  Serial.print(autoLed ? 0 : ledLevel); Serial.print(',');
  Serial.print(lastIr > SATURATED ? 1 : 0); Serial.print(',');
  Serial.print(ibiCount); Serial.print(',');
  Serial.print(pi, 2); Serial.print(',');
  Serial.print(moving ? 1 : 0); Serial.print(',');
  Serial.print(autoLed ? 1 : 0); Serial.print(',');
  Serial.println(ledPA * 0.2f, 1);
}

// =====================================================
// MAX30102 init + runtime health check
// =====================================================
bool initMAX30102() {
  if (!sensor.begin(Wire, I2C_SPEED_STANDARD)) {     // also checks Part ID 0x15
    Serial.println("#ERR MAX30102 not found at 0x57");
    return false;
  }
  ledPA = autoLed ? P->ledStart : LED_FIXED[fixedIndex];
  sensor.setup(ledPA, SAMPLE_AVG, 2, SAMPLE_RATE, 411, P->adcRange);
  sensor.enableDIETEMPRDY();
  contact = false; contactCount = 0;
  resetBeats();
  Serial.println("#OK MAX30102 ready");
  return true;
}

void checkMaxHealth() {
  if (millis() - lastHealthCheck < 5000) return;
  lastHealthCheck = millis();
  if (sensor.readPartID() != 0x15) {                 // cable pulled or sensor reset
    maxReady = false;
    contact = false;
    lastIr = lastRed = 0;
    resetBeats();
    Serial.println("#ERR MAX30102 lost - retrying");
  }
}

// =====================================================
// AS6221 (unchanged)
// =====================================================
bool initAS6221() {
  if (!skinTempSensor.begin()) {
    Serial.println("#ERR AS6221 not found at 0x48");
    return false;
  }
  Serial.println("#OK AS6221 ready");
  return true;
}

void updateSkinTemperature() {
  if (!skinTempReady) {
    if (millis() - lastTempInitTry > 2000) { lastTempInitTry = millis(); skinTempReady = initAS6221(); }
    return;
  }
  if (millis() - lastSkinTempRead < 1000) return;
  lastSkinTempRead = millis();
  float t = skinTempSensor.readTemperatureC();
  if (t > -20 && t < 80) skinTempC = t;   // sanity limits only
  else skinTempC = NAN;
}

// Switch measurement profile: reconfigures the sensor and restarts the analysis
void setMode(bool wrist) {
  wristMode = wrist;
  P = wrist ? &WRIST : &FINGER;
  autoLed = true;
  ledPA = P->ledStart;
  if (maxReady) {
    sensor.setup(ledPA, SAMPLE_AVG, 2, SAMPLE_RATE, 411, P->adcRange);
    sensor.enableDIETEMPRDY();
  }
  contact = false; contactCount = 0; resetBeats();
  Serial.print("#MODE "); Serial.println(P->name);
}

// =====================================================
// Commands
// =====================================================
void handleCommands() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c >= '1' && c <= '4') {
      autoLed = false; fixedIndex = c - '1';
      if (maxReady) setLed(LED_FIXED[fixedIndex]);
      contact = false; contactCount = 0; resetBeats();
      Serial.print("#LED fixed level "); Serial.println(c);
    } else if (c == 'a') {
      autoLed = true;
      if (maxReady) setLed(P->ledStart);
      contact = false; contactCount = 0; resetBeats();
      Serial.println("#LED auto");
    } else if (c == 'f') {
      setMode(false);
    } else if (c == 'w') {
      setMode(true);
    } else if (c == 'r') {
      contact = false; contactCount = 0; resetBeats();
      Serial.println("#Reset");
    }
  }
}

// Free the I2C bus if a sensor was left holding SDA low (reset during a transfer).
void i2cBusRecover() {
  pinMode(PIN_WIRE_SDA, INPUT_PULLUP);
  pinMode(PIN_WIRE_SCL, OUTPUT);
  for (uint8_t i = 0; i < 9 && digitalRead(PIN_WIRE_SDA) == LOW; i++) {
    digitalWrite(PIN_WIRE_SCL, LOW);  delayMicroseconds(5);
    digitalWrite(PIN_WIRE_SCL, HIGH); delayMicroseconds(5);
  }
  pinMode(PIN_WIRE_SDA, OUTPUT);
  digitalWrite(PIN_WIRE_SDA, LOW);  delayMicroseconds(5);
  digitalWrite(PIN_WIRE_SCL, HIGH); delayMicroseconds(5);
  digitalWrite(PIN_WIRE_SDA, HIGH); delayMicroseconds(5);
  pinMode(PIN_WIRE_SDA, INPUT);
  pinMode(PIN_WIRE_SCL, INPUT);
}

// =====================================================
// Setup / loop
// =====================================================
void setup() {
  Serial.begin(115200);
  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 3000) delay(10);
  Serial.println("#BOOT repoCare Band");

  i2cBusRecover();
  Wire.begin();
  Wire.setClock(100000);
  Serial.println("#I2C started");

  resetBeats();
  maxReady = initMAX30102();      lastMaxInitTry = millis();
  skinTempReady = initAS6221();   lastTempInitTry = millis();

  Serial.print("#MODE "); Serial.println(P->name);
  Serial.println("#READY");
}

void loop() {
  handleCommands();
  updateSkinTemperature();          // independent of MAX30102

  if (!maxReady) {
    if (millis() - lastMaxInitTry > 2000) { lastMaxInitTry = millis(); maxReady = initMAX30102(); }
  } else {
    sensor.check();
    while (sensor.available()) {
      uint32_t red = sensor.getFIFORed();
      uint32_t ir  = sensor.getFIFOIR();
      sensor.nextSample();
      processSample(ir, red);
    }
    checkMaxHealth();
  }

  // M line keeps flowing even when MAX30102 is missing, so temperature stays live
  if (millis() - lastMetrics >= 1000) { lastMetrics = millis(); sendMetrics(); }
}

/*
  =====================================================================
  TUNING NOTES
  =====================================================================
  Quality bands (dashboard: <45 poor, 45-74 fair, >=75 good):
    Tier A (beats + rhythm agree)  -> 75..100, enables SpO2 and HRV
    Tier B (consistent beats only) -> 45..74 (40.. if a strong rhythm disagrees)
    Tier C (strong rhythm only)    -> 40..65
    no trustworthy estimate        -> 10 ; saturated -> <=20
  WRIST profile: first HR after ~17-25 s (15 s window + 3 s repeat rule),
                then updates every second; no SpO2; HRV rarely (needs agreement).
  FINGER first values: Tier B after ~4 accepted beats (~5-6 s after contact),
                Tier A after the 8 s rhythm buffer fills (~9-10 s),
                SpO2 ~3 s after tier A, HRV after ~50-60 s of steady signal.
  To make HR stricter: lower TIER_B_MAX_SPREAD or raise TIER_C_MIN_AC.
  To make HR more available: raise TIER_B_MAX_SPREAD towards 0.12.
*/
