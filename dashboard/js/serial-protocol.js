// @ts-check
// Parser for the band's USB serial lines (docs/SERIAL_PROTOCOL.md).
// Pure functions, no I/O: one text line in, one typed message (or null) out.
// Firmware sentinels (-1, -99) become null here, so nothing downstream ever
// sees them. No signal processing happens here; the firmware does that.

/**
 * @typedef {{ type: 'S', ir: number, red: number, ppg: number }} SampleMsg
 * @typedef {{ type: 'B', ibiMs: number }} BeatMsg
 * @typedef {Object} MetricsMsg
 * @property {'M'} type
 * @property {number | null} bpm
 * @property {number | null} spo2
 * @property {number | null} rmssd
 * @property {boolean} contact
 * @property {number} quality            0–100
 * @property {number | null} tempC       AS6221 skin temperature in the combined firmware
 * @property {number} led                0 = auto, 1–4 = fixed level
 * @property {boolean} saturated
 * @property {number} beats              clean beats stored by the firmware
 * @property {number | null} pi          perfusion index, %
 * @property {boolean | null} motion     null when the firmware version does not send it
 * @property {boolean | null} autoLed
 * @property {number | null} ledMa
 * @typedef {{ type: 'status', text: string, error: boolean }} StatusMsg
 * @typedef {SampleMsg | BeatMsg | MetricsMsg | StatusMsg} SerialMsg
 */

/** @param {string | undefined} s */
const toNum = s => {
  if (s === undefined || s.trim() === '') return NaN;
  return Number(s);
};
/** Firmware "not available" values (-1, -99, NaN) → null. @param {number} v @param {number} min */
const valid = (v, min) => (Number.isFinite(v) && v >= min ? v : null);

/**
 * @param {string} line one line without the trailing newline
 * @returns {SerialMsg | null} null for empty, unknown or malformed lines
 */
function parseSerialLine(line) {
  line = line.trim();
  if (!line) return null;
  if (line[0] === '#') return { type: 'status', text: line.slice(1).trim(), error: line.startsWith('#ERR') };

  const p = line.split(',');
  switch (p[0]) {
    case 'S': {
      const ir = toNum(p[1]), red = toNum(p[2]), ppg = toNum(p[3]);
      return p.length >= 4 && Number.isFinite(ir) && Number.isFinite(red) && Number.isFinite(ppg) ? { type: 'S', ir, red, ppg } : null;
    }
    case 'B': {
      const ibi = toNum(p[1]);
      return Number.isFinite(ibi) && ibi > 0 && ibi < 5000 ? { type: 'B', ibiMs: ibi } : null;
    }
    case 'M': {
      // first 10 fields exist in every firmware version; pi, motion, auto, led_mA were added later
      if (p.length < 10) return null;
      const quality = toNum(p[5]), led = toNum(p[7]), beats = toNum(p[9]);
      if (!Number.isFinite(quality) || !Number.isFinite(led) || !Number.isFinite(beats)) return null;
      return {
        type: 'M',
        bpm: valid(toNum(p[1]), 1),
        spo2: valid(toNum(p[2]), 1),
        rmssd: valid(toNum(p[3]), 0.1),
        contact: p[4] === '1',
        quality: Math.min(100, Math.max(0, quality)),
        tempC: valid(toNum(p[6]), -90),
        led,
        saturated: p[8] === '1',
        beats,
        pi: p.length > 10 ? valid(toNum(p[10]), 0) : null,
        motion: p.length > 11 ? p[11] === '1' : null,
        autoLed: p.length > 12 ? p[12] === '1' : null,
        ledMa: p.length > 13 ? valid(toNum(p[13]), 0) : null,
      };
    }
    default:
      return null;
  }
}

/**
 * Firmware quality (0–100) → model category. Same 45 / 75 thresholds as the
 * live monitor. No contact means there is no signal to grade.
 * @param {number} quality @param {boolean} contact
 * @returns {SignalQuality | null}
 */
function qualityCategory(quality, contact) {
  if (!contact) return null;
  return quality >= 90 ? 'excellent' : quality >= 75 ? 'good' : quality >= 45 ? 'fair' : 'poor';
}

/**
 * Builds the raw record for normalizeReading() from one M line plus the latest
 * S sample. Only fields the firmware really sends are set; steps, activity,
 * stress, recovery and resting HR are left out and therefore become null.
 *
 * @param {MetricsMsg} m
 * @param {SampleMsg | null} lastSample
 * @param {boolean} beatSinceLast a B line arrived since the previous M line
 * @param {number} timestamp
 * @returns {Record<string, unknown>}
 */
function metricsToRaw(m, lastSample, beatSinceLast, timestamp) {
  return {
    timestamp,
    heartRate: m.bpm,
    spo2: m.spo2,
    hrv: m.rmssd,
    skinTemperature: m.tempC,
    signalQuality: qualityCategory(m.quality, m.contact),
    sensorContact: m.contact ? 'good' : 'none',
    rawIR: lastSample ? lastSample.ir : null,
    rawRed: lastSample ? lastSample.red : null,
    beatDetected: beatSinceLast,
  };
}
