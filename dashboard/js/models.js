// @ts-check
// Data model shared by every data source (mock today; USB / BLE / Firebase later).
// Nothing in this file holds readings: it only describes their shape and how to
// turn raw values into display text. Sensor algorithms belong in the firmware
// (or the app layer), never here or in the UI.

/**
 * @typedef {'resting' | 'walking' | 'active' | 'unknown'} ActivityState
 * @typedef {'still' | 'low' | 'moderate' | 'high'} MotionIntensity
 * @typedef {'low' | 'moderate' | 'high'} StressLevel
 * @typedef {'poor' | 'fair' | 'good' | 'excellent'} SignalQuality
 * @typedef {'good' | 'weak' | 'none'} SensorContact
 */

/**
 * One reading from the band. Every field except `timestamp` may be `null`:
 * "not available right now" (no contact, algorithm not ready, sensor missing).
 * Never replace null with a made-up value; the UI shows "--" instead.
 *
 * @typedef {Object} WearableReading
 * @property {number} timestamp                       Unix time, ms
 * --- primary
 * @property {number | null} heartRate                BPM
 * @property {number | null} spo2                     %, wearable estimate
 * @property {number | null} skinTemperature          °C, skin surface (not core body temperature)
 * @property {StressLevel | null} stressLevel         derived, non-diagnostic
 * --- activity
 * @property {number | null} steps                    steps today (firmware step detection)
 * @property {ActivityState | null} activity
 * @property {MotionIntensity | null} motionIntensity
 * --- advanced / experimental
 * @property {number | null} hrv                      ms, RMSSD of PPG pulse intervals (PRV)
 * @property {number | null} recoveryScore            0–100, experimental
 * @property {number | null} restingHeartRate         BPM, from long resting periods
 * --- signal / engineering
 * @property {SignalQuality | null} signalQuality
 * @property {number | null} rawIR                    MAX30102 IR counts
 * @property {number | null} rawRed                   MAX30102 Red counts
 * @property {boolean | null} beatDetected            a beat was accepted since the last reading
 * @property {SensorContact | null} sensorContact
 */

/**
 * @typedef {Object} DeviceState
 * @property {string} deviceName
 * @property {boolean} connected
 * @property {number | null} lastSync                 Unix time, ms of the last valid reading; null = none yet
 * @property {string | null} error                    connection problem to show the user, if any
 */

/**
 * Prototype-testing values that are not health metrics (from the firmware's M,
 * B and # lines). Shown only in the Engineering / Sensor Debug section.
 * @typedef {Object} EngineeringInfo
 * @property {number | null} qualityPct              firmware signal quality, 0–100
 * @property {number | null} perfusionIndex          %
 * @property {boolean | null} saturated              PPG signal clipped
 * @property {number | null} beatsStored             clean beats the firmware currently holds
 * @property {number | null} lastIbiMs               interval of the last accepted beat
 * @property {'auto' | number | null} ledLevel
 * @property {number | null} ledCurrentMa
 * @property {boolean | null} motionFlag             firmware motion flag (always 0 while the IMU is off)
 * @property {boolean} skinSensorReady               "#OK AS6221 ready" seen this session
 * @property {string[]} statusLog                    latest firmware status lines, newest first
 */

/**
 * Recent filtered PPG samples for the debug waveform (the firmware's `S` lines).
 * @typedef {Object} PpgWindow
 * @property {number[]} samples                       oldest first
 * @property {number} sampleRate                      samples per second
 * @property {number[]} beats                         indexes into `samples` where a beat was detected
 */

/**
 * What a data source hands to the UI. `history` is sorted oldest first.
 *
 * @typedef {Object} DashboardSnapshot
 * @property {DeviceState} device
 * @property {WearableReading | null} latest
 * @property {WearableReading[]} history
 * @property {PpgWindow | null} ppg                   null when no live stream (e.g. Firebase history only)
 * @property {EngineeringInfo | null} engineering     null when the source has no debug data
 */

/**
 * Every data source implements this. The UI calls `subscribe`, and `connect` /
 * `disconnect` when the source has them (a source the user must connect by hand).
 *
 * @typedef {Object} WearableDataSource
 * @property {'mock' | 'serial' | 'ble' | 'firebase'} kind
 * @property {ReadonlyArray<Exclude<keyof WearableReading, 'timestamp'>>} provides
 *   fields this source can deliver at all. Others show "not available yet";
 *   a provided field that is null shows "not available" (momentarily).
 * @property {(onSnapshot: (s: DashboardSnapshot) => void) => () => void} subscribe  returns an unsubscribe function
 * @property {boolean} [supported]                    false when the browser cannot use this source
 * @property {() => Promise<void>} [connect]
 * @property {() => Promise<void>} [disconnect]
 */

const ACTIVITY_LABELS = Object.freeze({ resting: 'راحة', walking: 'مشي', active: 'نشاط', unknown: 'غير معروف' });
const MOTION_LABELS = Object.freeze({ still: 'ساكن', low: 'خفيفة', moderate: 'متوسطة', high: 'عالية' });
const STRESS_LABELS = Object.freeze({ low: 'منخفض', moderate: 'متوسط', high: 'مرتفع' });
const QUALITY_LABELS = Object.freeze({ poor: 'ضعيفة', fair: 'مقبولة', good: 'جيدة', excellent: 'ممتازة' });
const CONTACT_LABELS = Object.freeze({ good: 'يوجد تلامس', weak: 'تلامس ضعيف', none: 'لا يوجد تلامس' });

/** @type {ReadonlyArray<ActivityState>} */
const ACTIVITY_STATES = Object.freeze(['resting', 'walking', 'active', 'unknown']);
/** @type {ReadonlyArray<MotionIntensity>} */
const MOTION_LEVELS = Object.freeze(['still', 'low', 'moderate', 'high']);
/** @type {ReadonlyArray<StressLevel>} */
const STRESS_LEVELS = Object.freeze(['low', 'moderate', 'high']);
/** @type {ReadonlyArray<SignalQuality>} */
const QUALITY_LEVELS = Object.freeze(['poor', 'fair', 'good', 'excellent']);
/** @type {ReadonlyArray<SensorContact>} */
const CONTACT_STATES = Object.freeze(['good', 'weak', 'none']);

/**
 * Turns loosely typed input (a parsed USB/BLE packet, a Firebase document) into a
 * WearableReading. Missing, wrongly typed or out-of-range values become null, so
 * a bad field shows "--" instead of a wrong number.
 *
 * @param {Record<string, unknown>} raw
 * @returns {WearableReading}
 */
function normalizeReading(raw) {
  /** @param {unknown} v @param {number} lo @param {number} hi */
  const num = (v, lo, hi) => (typeof v === 'number' && Number.isFinite(v) && v >= lo && v <= hi ? v : null);
  /** @template {string} T @param {unknown} v @param {ReadonlyArray<T>} allowed @returns {T | null} */
  const oneOf = (v, allowed) => (allowed.includes(/** @type {T} */ (v)) ? /** @type {T} */ (v) : null);
  return {
    timestamp: num(raw.timestamp, 0, Number.MAX_SAFE_INTEGER) ?? Date.now(),
    heartRate: num(raw.heartRate, 25, 250),
    spo2: num(raw.spo2, 50, 100),
    skinTemperature: num(raw.skinTemperature, 15, 45),
    stressLevel: oneOf(raw.stressLevel, STRESS_LEVELS),
    steps: num(raw.steps, 0, 200000),
    activity: oneOf(raw.activity, ACTIVITY_STATES),
    motionIntensity: oneOf(raw.motionIntensity, MOTION_LEVELS),
    hrv: num(raw.hrv, 1, 300),
    recoveryScore: num(raw.recoveryScore, 0, 100),
    restingHeartRate: num(raw.restingHeartRate, 25, 150),
    signalQuality: oneOf(raw.signalQuality, QUALITY_LEVELS),
    rawIR: num(raw.rawIR, 0, 1 << 18),            // MAX30102 ADC is 18-bit
    rawRed: num(raw.rawRed, 0, 1 << 18),
    beatDetected: typeof raw.beatDetected === 'boolean' ? raw.beatDetected : null,
    sensorContact: oneOf(raw.sensorContact, CONTACT_STATES),
  };
}

/** @param {number | null} score */
function recoveryBand(score) {
  if (score === null) return null;
  return score >= 67 ? 'جيد' : score >= 34 ? 'متوسط' : 'منخفض';
}

/**
 * "Just now", "5 min ago"… in Arabic. Western digits, matching the live monitor.
 * @param {number | null} ms
 * @param {number} [now]
 */
function formatSince(ms, now = Date.now()) {
  if (ms === null) return 'لم تتم مزامنة بعد';
  const s = Math.max(0, Math.round((now - ms) / 1000));
  if (s < 60) return 'الآن';
  const m = Math.round(s / 60);
  if (m < 60) return 'قبل ' + arCount(m, 'دقيقة', 'دقيقتين', 'دقائق');
  const h = Math.round(m / 60);
  if (h < 24) return 'قبل ' + arCount(h, 'ساعة', 'ساعتين', 'ساعات');
  return new Date(ms).toLocaleDateString('ar-SA-u-nu-latn');
}

/** Arabic count agreement: 1 / 2 (dual) / 3–10 (plural) / 11+ (singular). */
function arCount(/** @type {number} */ n, /** @type {string} */ one, /** @type {string} */ two, /** @type {string} */ few) {
  if (n === 1) return one;
  if (n === 2) return two;
  return `${n} ${n <= 10 ? few : one}`;
}

/** @param {number} ms @param {boolean} [seconds] */
function formatClock(ms, seconds = false) {
  return new Date(ms).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', ...(seconds ? { second: '2-digit' } : {}) });
}
