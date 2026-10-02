/*
  repoCare Band - FINGER firmware  (repocare_finger.ino)
  Purpose : stable, trustworthy readings from the FINGERTIP only.
  Board   : Seeed XIAO nRF52840 Sense
  Sensor  : ProtoCentral Pulse 3+ (MAX30102)
  Wiring  : Red -> 3V3 | Black -> GND | Blue (SDA) -> D4 | Yellow (SCL) -> D5

  How it works
   - Fingertip settings that already gave clean waves in our tests
     (ADC range 4096, start at ~6 mA, finger threshold 50,000)
   - Auto brightness keeps IR between 80,000 and 180,000 (never saturated)
   - Band-pass filter 0.5 - 4 Hz
   - Two independent heart-rate methods (beat detection + autocorrelation);
     a number is shown only when both agree
   - HRV and SpO2 only when the signal quality is high

  Serial @115200 (same protocol as repocare_dashboard.html):
    S,<ir>,<red>,<ppg>
    B,<ibi_ms>
    M,<bpm>,<spo2>,<rmssd>,<contact>,<quality>,<tempC>,<led>,<saturated>,<beats>,<pi>,<motion>,<auto>,<led_mA>
    #<text>
  Commands: 'a' = auto brightness,  '1'..'4' = fixed brightness,  'r' = reset

  Research prototype, not a medical device. SpO2 is an uncalibrated estimate.
*/
#include <Adafruit_TinyUSB.h>
#include <Wire.h>
#include "MAX30105.h"    // SparkFun MAX3010x library

MAX30105 sensor;

// ---------------- Settings ----------------
const uint16_t SAMPLE_RATE = 400;      // internal rate, averaged by 4 -> 100 samples/s
const uint8_t  SAMPLE_AVG  = 4;
const uint16_t MS_PER_SAMPLE = 10;
const uint32_t FULL_SCALE = 262143;    // 18-bit
const uint32_t CONTACT_ON  = 50000;    // IR above -> finger on the sensor
const uint32_t CONTACT_OFF = 30000;    // IR below -> finger removed
const uint32_t SATURATED   = 250000;
const uint32_t AGC_LOW  = 80000;       // auto brightness keeps IR in this window
const uint32_t AGC_HIGH = 180000;      // ...well below saturation (262143)
const uint16_t SETTLE_MS = 1500;
const uint16_t MIN_IBI = 300, MAX_IBI = 2000, LOST_MS = 4000;

const byte LED_FIXED[4] = {0x1F, 0x3F, 0x7F, 0xFF};   // ~6, 12, 25, 50 mA
bool autoLed = true;
uint8_t ledPA = 0x1F;                  // start at ~6 mA (best on the finger in our tests)
uint8_t fixedIndex = 0;

// ---------------- Biquad filter ----------------
struct Biquad {
  float b0, b1, b2, a1, a2, z1, z2;
  float run(float x) { float y = b0 * x + z1; z1 = b1 * x - a1 * y + z2; z2 = b2 * x - a2 * y; return y; }
  void reset(float x0 = 0) {             // start in steady state for input x0 (avoids a start-up jump)
    float dcGain = (b0 + b1 + b2) / (1 + a1 + a2);
    float y0 = dcGain * x0;
    z1 = y0 - b0 * x0; z2 = b2 * x0 - a2 * y0;
  }
};
// Butterworth, fs = 100 Hz
Biquad hpIR  {0.97803048f, -1.95606096f, 0.97803048f, -1.95557824f, 0.95654368f, 0, 0};   // 0.5 Hz high-pass
Biquad lpIR  {0.01335920f,  0.02671840f, 0.01335920f, -1.64745998f, 0.70089678f, 0, 0};   // 4 Hz low-pass
Biquad hpRed {0.97803048f, -1.95606096f, 0.97803048f, -1.95557824f, 0.95654368f, 0, 0};
Biquad lpRed {0.01335920f,  0.02671840f, 0.01335920f, -1.64745998f, 0.70089678f, 0, 0};

// ---------------- State ----------------
bool sensorReady = false;
uint32_t lastInitTry = 0;
uint32_t sampleCount = 0;
bool contact = false;
uint32_t settleUntil = 0;
uint32_t lastIr = 0, lastRed = 0;
bool satRecent = false;

float dcIR = 0, dcRed = 0;
float ppg = 0, ppgRed = 0;
float envHi = 0, envLo = 0;              // pulse envelope -> perfusion index

// beat detector (steepest upstroke in a +/-150 ms window)
const uint8_t HALF_WIN = 15, WIN = 2 * HALF_WIN + 1;
float win[WIN]; uint8_t winHead = 0, winFill = 0;
float hist4[4] = {0, 0, 0, 0}; uint8_t h4 = 0;
float slopeEnv = 0;
uint32_t lastBeatMs = 0; uint8_t rejectRun = 0;

const uint8_t N_IBI = 12;
uint16_t ibiBuf[N_IBI]; uint8_t ibiCount = 0, ibiHead = 0;

// autocorrelation buffer (8 s)
const uint16_t AC_N = 800;
float acBuf[AC_N]; uint16_t acHead = 0, acFill = 0;
float acBpm = -1, acStrength = 0;

// SpO2
float irMax, irMin, redMax, redMin;
const uint8_t N_SPO2 = 8;
float spo2Buf[N_SPO2]; uint8_t spo2Count = 0, spo2Head = 0;

// AGC
uint32_t agcSum = 0; uint16_t agcN = 0; uint32_t lastAgcMs = 0;

const bool moving = false;              // finger mode: no motion sensor
float tempC = NAN;
float lastGoodBpm = -1; uint32_t lastGoodMs = 0;
uint32_t lastMetrics = 0, lastTemp = 0;

// ---------------- Helpers ----------------
void resetAC() { irMax = redMax = -1e9f; irMin = redMin = 1e9f; }

void resetBeats() {
  ibiCount = ibiHead = 0; spo2Count = spo2Head = 0;
  slopeEnv = 0; lastBeatMs = 0; rejectRun = 0;
  acFill = acHead = 0; acBpm = -1; acStrength = 0;
  resetAC();
}

void restartFilters(uint32_t ir, uint32_t red, uint32_t t) {
  dcIR = ir; dcRed = red;
  hpIR.reset(ir); lpIR.reset(0); hpRed.reset(red); lpRed.reset(0);
  envHi = envLo = 0;
  winHead = winFill = 0;
  for (uint8_t i = 0; i < 4; i++) hist4[i] = 0;
  settleUntil = t + SETTLE_MS;
}

uint16_t ibiAt(uint8_t i) { return ibiBuf[(ibiHead + N_IBI - ibiCount + i) % N_IBI]; }

float medianIbi() {
  uint16_t tmp[N_IBI];
  for (uint8_t i = 0; i < ibiCount; i++) tmp[i] = ibiAt(i);
  for (uint8_t i = 1; i < ibiCount; i++) {
    uint16_t v = tmp[i]; int8_t j = i - 1;
    while (j >= 0 && tmp[j] > v) { tmp[j + 1] = tmp[j]; j--; }
    tmp[j + 1] = v;
  }
  return (ibiCount % 2) ? tmp[ibiCount / 2] : (tmp[ibiCount / 2 - 1] + tmp[ibiCount / 2]) / 2.0f;
}

void setLed(uint8_t pa) {
  ledPA = pa;
  sensor.setPulseAmplitudeRed(pa);
  sensor.setPulseAmplitudeIR(pa);
}

void computeSpO2() {
  if (moving || irMax <= irMin || redMax <= redMin || dcIR < 1 || dcRed < 1) return;
  float R = ((redMax - redMin) / dcRed) / ((irMax - irMin) / dcIR);
  if (R < 0.3f || R > 1.5f) return;
  float s = 110.0f - 25.0f * R;          // common uncalibrated approximation
  if (s > 100) s = 100;
  if (s < 70) return;
  spo2Buf[spo2Head] = s; spo2Head = (spo2Head + 1) % N_SPO2;
  if (spo2Count < N_SPO2) spo2Count++;
}

void onBeat(uint32_t beatT) {
  if (lastBeatMs == 0) { lastBeatMs = beatT; resetAC(); return; }
  uint32_t interval = beatT - lastBeatMs;
  lastBeatMs = beatT;
  if (interval > MAX_IBI || moving) { resetAC(); return; }   // gap or motion -> do not trust
  if (ibiCount >= 4) {
    float med = medianIbi();
    if (fabs((float)interval - med) > 0.30f * med) {
      resetAC();
      if (++rejectRun >= 3) { ibiCount = ibiHead = 0; rejectRun = 0; }
      return;
    }
  }
  rejectRun = 0;
  ibiBuf[ibiHead] = interval; ibiHead = (ibiHead + 1) % N_IBI;
  if (ibiCount < N_IBI) ibiCount++;
  Serial.print("B,"); Serial.println(interval);
  computeSpO2();
  resetAC();
}

// Heart rate from autocorrelation of the last 8 s (independent check)
void updateAutocorr() {
  acBpm = -1; acStrength = 0;
  if (acFill < AC_N) return;
  float mean = 0;
  for (uint16_t i = 0; i < AC_N; i++) mean += acBuf[i];
  mean /= AC_N;
  float r0 = 0;
  for (uint16_t i = 0; i < AC_N; i++) { float d = acBuf[i] - mean; r0 += d * d; }
  if (r0 <= 0) return;

  const uint16_t KMIN = 30, KMAX = 150;   // 200 .. 40 BPM
  static float r[KMAX + 2];
  float best = 0;
  for (uint16_t k = KMIN - 1; k <= KMAX + 1; k++) {
    float s = 0;
    for (uint16_t i = 0; i + k < AC_N; i++) {
      float a = acBuf[(acHead + i) % AC_N] - mean, b = acBuf[(acHead + i + k) % AC_N] - mean;
      s += a * b;
    }
    r[k] = s / r0 * AC_N / (AC_N - k);
    if (k >= KMIN && k <= KMAX && r[k] > best) best = r[k];
  }
  if (best < 0.2f) return;
  // Global maximum = most likely beat period
  uint16_t K = 0;
  for (uint16_t k = KMIN; k <= KMAX; k++)
    if (r[k] == best && r[k] >= r[k - 1] && r[k] >= r[k + 1]) { K = k; break; }
  if (K == 0) return;
  // If a peak at half that lag is almost as strong, the real rate is double (avoid half-rate errors)
  uint16_t h0 = (uint16_t)(K * 0.45f), h1 = (uint16_t)(K * 0.55f) + 1;
  for (uint16_t k = max(h0, KMIN); k <= h1 && k <= KMAX; k++)
    if (r[k] >= r[k - 1] && r[k] >= r[k + 1] && r[k] >= 0.85f * best) { K = k; break; }
  float den = r[K - 1] - 2 * r[K] + r[K + 1];
  float off = (den != 0) ? 0.5f * (r[K - 1] - r[K + 1]) / den : 0;   // sub-sample refinement
  acBpm = 6000.0f / (K + off);
  acStrength = r[K];
}

void runAgc(uint32_t t) {
  if (!autoLed || !contact) return;
  if (t - lastAgcMs < 1000 || agcN == 0) return;
  uint32_t mean = agcSum / agcN;
  agcSum = 0; agcN = 0; lastAgcMs = t;
  uint8_t pa = ledPA;
  if (satRecent || mean > AGC_HIGH) pa = max(8, (int)(ledPA * 0.75f));
  else if (mean < AGC_LOW)          pa = min(255, (int)(ledPA * 1.3f) + 1);
  satRecent = false;
  if (pa != ledPA) {
    setLed(pa);
    restartFilters(lastIr, lastRed, t);   // baseline jumps; keep the beat history
    acFill = acHead = 0;
  }
}

void processSample(uint32_t ir, uint32_t red) {
  sampleCount++;
  uint32_t t = sampleCount * MS_PER_SAMPLE;
  lastIr = ir; lastRed = red;
  if (ir > SATURATED || red > SATURATED) satRecent = true;

  if (!contact && ir > CONTACT_ON) { contact = true; resetBeats(); restartFilters(ir, red, t); lastAgcMs = t; }
  else if (contact && ir < CONTACT_OFF) { contact = false; resetBeats(); }

  dcIR  += 0.02f * ((float)ir  - dcIR);
  dcRed += 0.02f * ((float)red - dcRed);
  ppg    = lpIR.run(hpIR.run(-(float)ir));       // inverted: heartbeat -> upward
  ppgRed = lpRed.run(hpRed.run(-(float)red));

  Serial.print("S,"); Serial.print(ir); Serial.print(',');
  Serial.print(red); Serial.print(',');
  Serial.println(contact ? ppg : 0.0f, 1);

  if (!contact) return;
  agcSum += ir; agcN++;
  runAgc(t);
  if (t < settleUntil) return;

  float span = envHi - envLo;                    // envelope follows the pulse, decays ~1%/sample
  if (ppg > envHi) envHi = ppg; else envHi -= 0.01f * span;
  if (ppg < envLo) envLo = ppg; else envLo += 0.01f * span;

  if (ppg > irMax) irMax = ppg;
  if (ppg < irMin) irMin = ppg;
  if (ppgRed > redMax) redMax = ppgRed;
  if (ppgRed < redMin) redMin = ppgRed;

  float slope = ppg - hist4[h4];                 // rise over 40 ms
  hist4[h4] = ppg; h4 = (h4 + 1) % 4;
  acBuf[acHead] = slope; acHead = (acHead + 1) % AC_N;   // autocorrelation runs on the upstroke signal
  if (acFill < AC_N) acFill++;
  slopeEnv *= 0.999f;
  win[winHead] = slope; winHead = (winHead + 1) % WIN;
  if (winFill < WIN) { winFill++; return; }

  float centre = win[(winHead + HALF_WIN) % WIN];
  for (uint8_t i = 0; i < WIN; i++) if (win[i] > centre) return;
  if (centre <= 0 || centre < 0.5f * slopeEnv) return;

  uint32_t beatT = t - HALF_WIN * MS_PER_SAMPLE;
  float refractory = MIN_IBI;                     // ignore the dicrotic wave after each beat
  if (acBpm > 0)          refractory = max((float)MIN_IBI, 0.55f * 60000.0f / acBpm);
  else if (ibiCount >= 4) refractory = max((float)MIN_IBI, 0.6f * medianIbi());
  if (lastBeatMs && (beatT - lastBeatMs) < refractory) return;
  slopeEnv = (slopeEnv == 0) ? centre : 0.7f * slopeEnv + 0.3f * centre;
  onBeat(beatT);
}

void sendMetrics() {
  uint32_t t = sampleCount * MS_PER_SAMPLE;
  if (contact && lastBeatMs && (t - lastBeatMs) > LOST_MS) { ibiCount = ibiHead = 0; lastBeatMs = 0; }
  updateAutocorr();

  float peakBpm = -1, cv = 1, rmssd = -1, spo2 = -1;
  if (ibiCount >= 3) {
    uint8_t n = min(ibiCount, (uint8_t)8);
    float sum = 0;
    for (uint8_t i = ibiCount - n; i < ibiCount; i++) sum += ibiAt(i);
    float mean = sum / n;
    peakBpm = 60000.0f / mean;
    float var = 0;
    for (uint8_t i = ibiCount - n; i < ibiCount; i++) { float d = ibiAt(i) - mean; var += d * d; }
    cv = sqrt(var / n) / mean;
  }

  // Combine the two methods
  float bpm = -1; int quality = 0;
  if (contact) {
    float qPeriod = constrain((acStrength - 0.2f) / 0.6f, 0.0f, 1.0f) * 100;
    float qBeats  = (peakBpm > 0) ? constrain(100 - cv * 400, 0.0f, 100.0f) : 0;
    bool agree = peakBpm > 0 && acBpm > 0 && fabs(peakBpm - acBpm) < 0.10f * acBpm;
    if (agree)                         { bpm = peakBpm; quality = constrain((int)(0.5f * (qPeriod + qBeats) + 15), 0, 100); }
    else if (acBpm > 0 && acStrength > 0.5f) { bpm = acBpm;  quality = (int)(0.6f * qPeriod); }
    else if (peakBpm > 0 && cv < 0.08f)      { bpm = peakBpm; quality = (int)(0.5f * qBeats); }
    else quality = 10;
    if (moving) quality = min(quality, 20);
    if (lastIr > SATURATED) quality = min(quality, 20);

    if (bpm > 0 && quality >= 40) { lastGoodBpm = bpm; lastGoodMs = millis(); }
    else if (lastGoodBpm > 0 && millis() - lastGoodMs < 8000) bpm = lastGoodBpm;   // hold briefly
    else bpm = -1;

    if (quality >= 60 && !moving && ibiCount >= 6) {
      float sq = 0;
      for (uint8_t i = 1; i < ibiCount; i++) { float d = (float)ibiAt(i) - ibiAt(i - 1); sq += d * d; }
      rmssd = sqrt(sq / (ibiCount - 1));
    }
    if (spo2Count >= 3 && quality >= 60) {
      float s = 0; for (uint8_t i = 0; i < spo2Count; i++) s += spo2Buf[i];
      spo2 = s / spo2Count;
    }
  } else {
    lastGoodBpm = -1;
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
  if (isnan(tempC)) Serial.print(-99); else Serial.print(tempC, 1);
  Serial.print(',');
  Serial.print(autoLed ? 0 : ledLevel); Serial.print(',');
  Serial.print(lastIr > SATURATED ? 1 : 0); Serial.print(',');
  Serial.print(ibiCount); Serial.print(',');
  Serial.print(pi, 2); Serial.print(',');
  Serial.print(moving ? 1 : 0); Serial.print(',');
  Serial.print(autoLed ? 1 : 0); Serial.print(',');
  Serial.println(ledPA * 0.2f, 1);
}

bool initSensor() {
  if (!sensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("#ERR MAX30102 not found - check wiring: Blue SDA=D4, Yellow SCL=D5");
    return false;
  }
  sensor.setup(ledPA, SAMPLE_AVG, 2, SAMPLE_RATE, 411, 4096);   // ADC range 4096: proven on the finger
  sensor.enableDIETEMPRDY();
  Serial.println("#OK MAX30102 ready");
  return true;
}

void handleCommands() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c >= '1' && c <= '4') {
      autoLed = false; fixedIndex = c - '1'; setLed(LED_FIXED[fixedIndex]);
      contact = false; resetBeats();
      Serial.print("#LED fixed level "); Serial.println(c);
    } else if (c == 'a') {
      autoLed = true; contact = false; resetBeats();
      Serial.println("#LED auto");
    } else if (c == 'r') {
      contact = false; resetBeats();
      Serial.println("#Reset");
    }
  }
}

void setup() {
  Serial.begin(115200);
  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 3000) delay(10);
  Wire.begin();
  Wire.setClock(100000);
  resetBeats();
  sensorReady = initSensor();
  lastInitTry = millis();
  Serial.println("#MODE finger");
}

void loop() {
  if (!sensorReady) {
    if (millis() - lastInitTry > 2000) { lastInitTry = millis(); sensorReady = initSensor(); }
    return;
  }
  handleCommands();

  sensor.check();
  while (sensor.available()) {
    uint32_t red = sensor.getFIFORed();
    uint32_t ir  = sensor.getFIFOIR();
    sensor.nextSample();
    processSample(ir, red);
  }

  if (millis() - lastMetrics >= 1000) { lastMetrics = millis(); sendMetrics(); }
  if (millis() - lastTemp >= 5000) { lastTemp = millis(); tempC = sensor.readTemperature(); }
}
