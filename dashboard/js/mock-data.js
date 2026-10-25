// @ts-check
// ALL sample values live in this file and nowhere else.
// When the real band is connected this file is no longer loaded: see data-source.js.

const MOCK_DEVICE_NAME = 'repoCare Band';

/** The "current" reading shown on the cards. `null` = not available yet. */
const MOCK_LATEST = Object.freeze({
  heartRate: 78,
  spo2: 98,
  skinTemperature: 33.6,
  stressLevel: 'low',
  steps: 3248,
  activity: 'resting',
  motionIntensity: 'still',
  hrv: 54,
  recoveryScore: 82,
  restingHeartRate: null,          // not calculated yet: needs long resting periods
  signalQuality: 'good',
  rawIR: 112450,
  rawRed: 98320,
  beatDetected: false,
  sensorContact: 'good',
});

const MOCK_HISTORY_HOURS = 12;
const MOCK_HISTORY_STEP_MIN = 15;

/**
 * Preview scenarios, picked with `?mock=` in the URL:
 *   (none)        connected, sample data
 *   disconnected  band offline, last values 40 min old
 *   nodata        connected but every value unavailable (tests null handling)
 * @returns {'normal' | 'disconnected' | 'nodata'}
 */
function mockScenario() {
  const s = new URLSearchParams(location.search).get('mock');
  return s === 'disconnected' || s === 'nodata' ? s : 'normal';
}

/**
 * A plausible 12-hour history ending at `now` whose last point equals MOCK_LATEST:
 * mostly at rest with a walk in the middle. During the most intense minutes the
 * PPG is marked poor and SpO2/HRV are unavailable, as happens on a real wrist.
 * Deterministic (fixed seed), so the page looks the same every load.
 *
 * @param {number} now
 * @returns {WearableReading[]}
 */
function buildMockHistory(now) {
  let seed = 7;
  const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) - 0.5;
  const n = (MOCK_HISTORY_HOURS * 60) / MOCK_HISTORY_STEP_MIN;
  /** @type {Record<string, unknown>[]} */
  const rows = [];
  for (let i = 0; i <= n; i++) {
    const walk = Math.exp(-(((i - n * 0.55) / 3) ** 2));
    const motionArtefact = walk > 0.9;
    rows.push({
      timestamp: now - (n - i) * MOCK_HISTORY_STEP_MIN * 60000,
      heartRate: Math.round(74 + walk * 34 + rand() * 6),
      spo2: motionArtefact ? null : Math.round(97.6 + rand() * 1.6 - walk),
      skinTemperature: +(33.25 + Math.cos(i / 9) * 0.3 - walk * 0.5 + rand() * 0.15).toFixed(1),
      stressLevel: walk > 0.6 ? 'moderate' : 'low',
      stepsDelta: walk > 0.6 ? 400 + Math.round(rand() * 60) : walk > 0.25 ? 250 + Math.round(rand() * 60) : Math.round(12 + rand() * 20),
      activity: walk > 0.6 ? 'active' : walk > 0.25 ? 'walking' : 'resting',
      motionIntensity: walk > 0.6 ? 'high' : walk > 0.25 ? 'moderate' : walk > 0.1 ? 'low' : 'still',
      hrv: motionArtefact ? null : Math.round(58 - walk * 22 + rand() * 8),
      recoveryScore: MOCK_LATEST.recoveryScore,
      restingHeartRate: null,
      signalQuality: motionArtefact ? 'poor' : walk > 0.25 ? 'fair' : 'good',
      sensorContact: 'good',
    });
  }
  // cumulative "steps today", ending exactly at MOCK_LATEST.steps
  const total = rows.slice(1).reduce((s, r) => s + /** @type {number} */ (r.stepsDelta), 0);
  let steps = Math.max(0, MOCK_LATEST.steps - total);
  rows.forEach((r, i) => { if (i) steps += /** @type {number} */ (r.stepsDelta); r.steps = steps; });

  const out = rows.map(normalizeReading);
  out[out.length - 1] = normalizeReading({ ...MOCK_LATEST, timestamp: now });
  return out;
}

/**
 * Synthetic filtered PPG (systolic peak + dicrotic wave + noise) for the debug
 * waveform. `next(count)` returns the next `count` samples and the indexes,
 * within them, where a beat falls.
 *
 * @param {number} bpm
 * @param {number} sampleRate
 */
function createMockPpgStream(bpm, sampleRate) {
  let phase = 0, n = 0, seed = 11;
  const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) - 0.5;
  return {
    next(/** @type {number} */ count) {
      /** @type {number[]} */ const samples = [];
      /** @type {number[]} */ const beats = [];
      for (let i = 0; i < count; i++, n++) {
        const prev = phase;
        phase = (phase + bpm / 60 / sampleRate) % 1;
        if (prev < 0.15 && phase >= 0.15) beats.push(i);
        samples.push(40 * Math.exp(-(((phase - 0.15) / 0.07) ** 2)) + 14 * Math.exp(-(((phase - 0.45) / 0.09) ** 2))
          + 3 * Math.sin(n / 160) + rand() * 2.5);
      }
      return { samples, beats };
    },
  };
}

/** Small jitter for the raw IR/Red counters so the debug panel visibly updates. */
function mockRawJitter() {
  return { rawIR: MOCK_LATEST.rawIR + Math.round((Math.random() - 0.5) * 900), rawRed: MOCK_LATEST.rawRed + Math.round((Math.random() - 0.5) * 700) };
}
