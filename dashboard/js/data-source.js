// @ts-check
// The hardware integration boundary: the only place the overview page gets data from.
//
//   MAX30102 + AS6221 + XIAO IMU → XIAO firmware → USB Web Serial → parseSerialLine()
//   → this file → normalizeReading() → WearableReading → overview.js
//
// Default: the real band over USB (createSerialDataSource).
// `?mock=1` (or `?mock=disconnected`, `?mock=nodata`) loads sample data instead;
// js/mock-data.js is only fetched in that case.
// A BLE or Firebase source would be another function returning a WearableDataSource.

const DEVICE_NAME = 'repoCare Band';
const PPG_RATE = 100;            // samples per second, as the firmware sends them
const PPG_WINDOW_S = 6;

// ---------- Real band over USB (Web Serial) ----------

/** Fields the current firmware actually sends. Everything else shows "not available yet". */
/** @type {WearableDataSource['provides']} */
const SERIAL_PROVIDES = ['heartRate', 'spo2', 'skinTemperature', 'hrv', 'signalQuality', 'rawIR', 'rawRed', 'beatDetected', 'sensorContact'];

const SERIAL_BAUD = 115200;
const HISTORY_MAX = 3600;        // one point per M line (~1/s): the last hour
const STALE_MS = 5000;           // no M line for this long → readings are cleared
const STATUS_LOG_MAX = 12;
const EMIT_MS = 50;              // waveform updates at most 20×/s
const BEAT_DELAY_SAMPLES = 15;   // firmware reports a beat ~150 ms after its upstroke

const MSG_UNSUPPORTED = 'هذا المتصفح لا يدعم الاتصال عبر USB. افتح الصفحة في Chrome أو Edge على الكمبيوتر.';
const MSG_BUSY = 'تعذّر فتح المنفذ. أغلق Serial Monitor في Arduino IDE (أو صفحة المراقبة الحية إن كانت مفتوحة) وحاول مرة أخرى.';
const MSG_LOST = 'انقطع الاتصال بالسوار. تأكد من كيبل USB واضغط «اتصال بسوار repoCare» مرة أخرى.';
const MSG_SILENT = 'المنفذ مفتوح لكن لا تصل قراءات من السوار. تأكد أن الفيرموير مرفوع ويعمل.';

/**
 * Minimal Web Serial types (not part of TypeScript's DOM library).
 * @typedef {{ open(o: { baudRate: number }): Promise<void>, close(): Promise<void>, readable: ReadableStream<Uint8Array> | null }} SerialPortLike
 * @typedef {{ requestPort(): Promise<SerialPortLike>, addEventListener(type: 'disconnect', cb: (e: Event) => void): void }} SerialLike
 */
const serialApi = () => /** @type {SerialLike | undefined} */ (/** @type {any} */ (navigator).serial);

/** @returns {WearableDataSource} */
function createSerialDataSource() {
  const supported = !!serialApi();
  /** @type {Set<(s: DashboardSnapshot) => void>} */
  const listeners = new Set();

  /** @type {SerialPortLike | null} */ let port = null;
  /** @type {ReadableStreamDefaultReader<Uint8Array> | null} */ let reader = null;
  /** @type {Promise<void> | null} */ let readLoopDone = null;
  let keepReading = false, connected = false, connecting = false, disconnectHooked = false;
  /** @type {string | null} */ let error = supported ? null : MSG_UNSUPPORTED;
  /** @type {string | null} */ let firmwareError = null;

  /** @type {WearableReading | null} */ let latest = null;
  /** @type {WearableReading[]} */ let history = [];      // replaced (not mutated) on change, so the UI can compare references
  /** @type {number | null} */ let lastSync = null;
  let lastMetricsAt = 0;
  /** @type {SampleMsg | null} */ let lastSample = null;
  let beatSinceMetrics = false;

  // bounded PPG ring buffer for the waveform
  const ring = new Float32Array(PPG_RATE * PPG_WINDOW_S);
  let head = 0, sampleNo = 0;
  /** @type {number[]} */ let beatMarks = [];               // absolute sample numbers

  /** @type {EngineeringInfo} */
  let engineering = emptyEngineering();
  /** @param {Partial<EngineeringInfo>} patch */
  const patchEngineering = patch => { engineering = { ...engineering, ...patch }; };

  let emitTimer = 0, watchdog = 0;

  function emptyEngineering() {
    return { qualityPct: null, perfusionIndex: null, saturated: null, beatsStored: null, lastIbiMs: null,
      ledLevel: null, ledCurrentMa: null, motionFlag: null, skinSensorReady: false, statusLog: [] };
  }

  /** @returns {PpgWindow | null} */
  function ppgWindow() {
    if (!connected || sampleNo === 0) return null;
    const len = Math.min(sampleNo, ring.length), first = sampleNo - len;
    const samples = new Array(len);
    for (let i = 0; i < len; i++) samples[i] = ring[(head - len + i + ring.length) % ring.length];
    const beats = beatMarks.map(b => b - first).filter(i => i >= 0 && i < len);
    return { samples, sampleRate: PPG_RATE, beats };
  }

  function emit() {
    clearTimeout(emitTimer); emitTimer = 0;
    /** @type {DashboardSnapshot} */
    const s = {
      device: { deviceName: DEVICE_NAME, connected, lastSync, error: error ?? (firmwareError && 'السوار أبلغ عن خطأ: ' + firmwareError) },
      latest, history, ppg: ppgWindow(), engineering,
    };
    listeners.forEach(cb => cb(s));
  }
  const scheduleEmit = () => { if (!emitTimer) emitTimer = window.setTimeout(emit, EMIT_MS); };

  /** @param {string} line */
  function handleLine(line) {
    const msg = parseSerialLine(line);
    if (!msg) return;                                   // malformed or unknown: ignore
    switch (msg.type) {
      case 'S':
        lastSample = msg;
        ring[head] = msg.ppg; head = (head + 1) % ring.length; sampleNo++;
        scheduleEmit();
        break;
      case 'B':
        beatSinceMetrics = true;
        beatMarks.push(sampleNo - BEAT_DELAY_SAMPLES);
        if (beatMarks.length > 40) beatMarks = beatMarks.slice(-40);
        patchEngineering({ lastIbiMs: msg.ibiMs });
        scheduleEmit();
        break;
      case 'M': {
        const now = Date.now();
        latest = normalizeReading(metricsToRaw(msg, lastSample, beatSinceMetrics, now));
        beatSinceMetrics = false;
        lastSync = lastMetricsAt = now;
        history = history.length >= HISTORY_MAX ? [...history.slice(1), latest] : [...history, latest];
        patchEngineering({
          qualityPct: msg.quality, perfusionIndex: msg.pi, saturated: msg.saturated, beatsStored: msg.beats,
          ledLevel: msg.led === 0 ? 'auto' : msg.led,
          ledCurrentMa: msg.ledMa, motionFlag: msg.motion,
        });
        if (error === MSG_SILENT) error = null;
        emit();
        break;
      }
      case 'status':
        patchEngineering({
          statusLog: [msg.text, ...engineering.statusLog].slice(0, STATUS_LOG_MAX),
          skinSensorReady: engineering.skinSensorReady || /^OK AS6221/i.test(msg.text),
        });
        if (msg.error) firmwareError = msg.text.replace(/^ERR\s*/, '');
        else if (/^OK MAX30102/i.test(msg.text)) firmwareError = null;
        emit();
        break;
    }
  }

  /** Reads until the stream ends, the user disconnects or the port dies. @param {SerialPortLike} p */
  async function readLoop(p) {
    const decoder = new TextDecoder();
    let buf = '';
    while (keepReading && p.readable) {
      const r = p.readable.getReader();
      reader = r;
      try {
        for (;;) {
          const { value, done } = await r.read();
          if (done) return;                             // cancelled by us, or the stream ended
          buf += decoder.decode(value, { stream: true });
          let i;
          while ((i = buf.indexOf('\n')) >= 0) {
            const line = buf.slice(0, i);
            buf = buf.slice(i + 1);
            try { handleLine(line); } catch { /* a bad line must never stop the reader */ }
          }
          if (buf.length > 4096) buf = '';              // no newline for this long: garbage
        }
      } catch {
        // non-fatal errors (framing, overrun) leave p.readable set and we keep reading;
        // fatal ones (cable unplugged) set it to null and the loop ends
      } finally {
        r.releaseLock();
        reader = null;
      }
    }
  }

  /** Releases the port and resets live state. History is kept, with a gap marker. @param {string | null} reason */
  async function close(reason) {
    keepReading = false;
    const p = port;
    port = null;
    try { if (reader) await reader.cancel(); } catch { /* already closed */ }
    try { if (readLoopDone) await readLoopDone; } catch { /* ignore */ }
    try { if (p) await p.close(); } catch { /* unplugged ports cannot be closed */ }
    clearInterval(watchdog);
    if (connected && history.length) history = [...history.slice(-(HISTORY_MAX - 1)), normalizeReading({ timestamp: Date.now() })];
    connected = false;
    latest = null;
    lastSample = null;
    error = reason;
    emit();
  }

  async function connect() {
    const serial = serialApi();
    if (!serial || connected || connecting) return;
    connecting = true;
    try {
      const p = await serial.requestPort();
      await p.open({ baudRate: SERIAL_BAUD });
      if (!disconnectHooked) {
        disconnectHooked = true;
        serial.addEventListener('disconnect', e => { if (port && /** @type {unknown} */ (e.target) === port) void close(MSG_LOST); });
      }
      port = p;
      connected = true; keepReading = true;
      error = null; firmwareError = null;
      latest = null; lastSample = null; beatSinceMetrics = false;
      head = 0; sampleNo = 0; beatMarks = []; ring.fill(0);
      engineering = emptyEngineering();
      lastMetricsAt = Date.now();
      watchdog = window.setInterval(() => {
        if (!connected || Date.now() - lastMetricsAt < STALE_MS) return;
        latest = null;                                  // never keep showing old values as if current
        error = MSG_SILENT;
        emit();
      }, 1000);
      readLoopDone = readLoop(p);
      readLoopDone.then(() => { if (keepReading && port === p) void close(MSG_LOST); });
      emit();
    } catch (e) {
      // DOMException: compare by name (instanceof fails across frames)
      const { name = '', message = String(e) } = /** @type {{ name?: string, message?: string }} */ (e ?? {});
      if (name !== 'NotFoundError') {                   // NotFoundError = the user closed the port picker
        error = name === 'NetworkError' || name === 'InvalidStateError' ? MSG_BUSY : `تعذّر فتح المنفذ (${message}). ${MSG_BUSY}`;
      }
      emit();
    } finally {
      connecting = false;
    }
  }

  return {
    kind: 'serial',
    provides: SERIAL_PROVIDES,
    supported,
    connect,
    disconnect: () => close(null),
    subscribe(onSnapshot) {
      listeners.add(onSnapshot);
      emit();
      return () => { listeners.delete(onSnapshot); };
    },
  };
}

// ---------- Sample data (development only) ----------

const MOCK_TICK_MS = 200;

/**
 * Sample data, with live-looking updates: the PPG waveform streams continuously,
 * the reading refreshes once a second (like the firmware's M line).
 * Needs js/mock-data.js (loaded by createDataSource only in mock mode).
 * @returns {WearableDataSource}
 */
function createMockDataSource() {
  const scenario = mockScenario();
  const start = Date.now();
  /** @type {WearableDataSource['provides']} */
  const provides = /** @type {any} */ (Object.keys(METRICS));

  return {
    kind: 'mock',
    provides,
    subscribe(onSnapshot) {
      if (scenario === 'nodata') {
        onSnapshot({ device: { deviceName: MOCK_DEVICE_NAME, connected: true, lastSync: start, error: null },
          latest: normalizeReading({ timestamp: start }), history: [], ppg: null, engineering: null });
        return () => {};
      }
      const history = buildMockHistory(scenario === 'disconnected' ? start - 40 * 60000 : start);
      if (scenario === 'disconnected') {
        onSnapshot({ device: { deviceName: MOCK_DEVICE_NAME, connected: false, lastSync: history[history.length - 1].timestamp, error: null },
          latest: history[history.length - 1], history, ppg: null, engineering: null });
        return () => {};
      }

      const stream = createMockPpgStream(/** @type {number} */ (MOCK_LATEST.heartRate), PPG_RATE);
      const size = PPG_RATE * PPG_WINDOW_S, perTick = (PPG_RATE * MOCK_TICK_MS) / 1000;
      /** @type {number[]} */ let samples = [];
      /** @type {number[]} */ let beats = [];          // absolute sample numbers
      let total = 0, tick = 0, beatSinceReading = false;
      let latest = history[history.length - 1];

      const step = () => {
        const chunk = stream.next(tick === 0 ? size : perTick);
        chunk.beats.forEach(b => beats.push(total + b));
        if (chunk.beats.length) beatSinceReading = true;
        total += chunk.samples.length;
        samples = samples.concat(chunk.samples).slice(-size);
        beats = beats.filter(b => b >= total - size);
        if (tick % (1000 / MOCK_TICK_MS) === 0) {
          latest = normalizeReading({ ...MOCK_LATEST, ...mockRawJitter(), beatDetected: beatSinceReading, timestamp: Date.now() });
          beatSinceReading = false;
        }
        tick++;
        onSnapshot({
          device: { deviceName: MOCK_DEVICE_NAME, connected: true, lastSync: latest.timestamp, error: null },
          latest,
          history,
          ppg: { samples, sampleRate: PPG_RATE, beats: beats.map(b => b - (total - samples.length)) },
          engineering: null,
        });
      };
      step();
      const timer = setInterval(step, MOCK_TICK_MS);
      return () => clearInterval(timer);
    },
  };
}

/** @param {string} src */
function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = src;
    s.onload = resolve;
    s.onerror = () => reject(new Error('could not load ' + src));
    document.head.append(s);
  });
}

/**
 * Real band by default. Sample data only when the URL explicitly asks for it.
 * @returns {Promise<WearableDataSource>}
 */
async function createDataSource() {
  if (new URLSearchParams(location.search).has('mock')) {
    await loadScript('js/mock-data.js');
    return createMockDataSource();
  }
  return createSerialDataSource();
}
