# Dashboard

Two pages, linked to each other from the header:

| Page | What it is |
|---|---|
| `repocare_dashboard.html` | **Live monitor**: raw sensor view over USB (below) |
| `repocare_overview.html` | **Health overview**: the user-facing summary, fed by the real band over USB |

`repocare_dashboard.html` is a single-file web page that reads the band over USB using the **Web Serial API**. No installation and no server are needed.

## Use

1. Upload one of the firmware sketches.
2. Close the Arduino Serial Monitor (the port can only be open in one program).
3. Open the file in **Chrome or Edge** on a computer (Safari and Firefox do not support Web Serial).
4. Click **اتصال بالسوار** (Connect) and choose the XIAO port.

## Features

- Live pulse wave on an ECG-style grid, with a tick at every detected beat
- Heart rate, SpO2 (estimate), HRV (RMSSD), signal quality, sensor chip temperature
- BPM trend for the last 2 minutes
- LED brightness: auto or fixed levels 1–4
- **CSV recording** of raw and processed data (see the column list in [../1_heart_rate/README.md](../1_heart_rate/README.md#csv-columns))

The interface text is in Arabic.
The "sensor chip temperature" is the MAX30102's internal die temperature, **not** body temperature.

## Health overview (`repocare_overview.html`)

We are in the **hardware validation phase**, so the overview deliberately shows every *candidate* metric, not just the final ones. Metrics that prove unreliable in testing will be dropped later.

| Section | Metrics |
|---|---|
| Main health readings | Heart rate, SpO2 (estimate), skin temperature, stress level (derived) |
| Activity | Steps today, activity state, motion intensity |
| Advanced / experimental | HRV/PRV (RMSSD), recovery score, resting heart rate |
| Trends (this session, up to 1 h) | Heart rate, SpO2, skin temperature, HRV/PRV, steps with the activity state underneath |
| Engineering / Sensor Debug (collapsible) | Live PPG waveform with beat markers, raw IR / Red, signal quality, sensor contact, beat detection, motion, and the validation status of every metric |

### Using it with the band

1. Upload the firmware and close the Arduino Serial Monitor (and the live monitor page, if it is connected): only one program can open the port.
2. Open `repocare_overview.html` in **Chrome or Edge** on a computer and click **اتصال بسوار repoCare**. Pick the XIAO port (115200 baud).
3. Readings appear as the firmware sends them. Until then, and after disconnecting, every value shows "--".

What is real today (from the firmware's `S` / `B` / `M` lines): heart rate, SpO2, skin temperature, HRV/PRV, signal quality, sensor contact, beat detection, raw IR / Red, the PPG waveform, perfusion index, saturation and LED data.
Not sent by the firmware yet, so shown as "غير متاح بعد": steps, activity, motion intensity, stress, recovery, resting heart rate.

Skin temperature: in the combined prototype firmware the `M` line's temperature field is the AS6221 reading. The debug section shows whether `#OK AS6221 ready` was received. The heart-rate-only sketches in `1_heart_rate/` still send the MAX30102 chip temperature in that field.

### Sample data (development only)

Sample data is never shown unless the URL asks for it (`js/mock-data.js` is not even loaded otherwise):

- `?mock=1`: connected band with sample readings and a 12-hour history
- `?mock=disconnected`: band offline, last readings 40 minutes old
- `?mock=nodata`: connected, but every value is unavailable (checks that nulls show "--" / "غير متاح")

Wording rules: skin temperature is not core body temperature; wrist PPG HRV is PRV, not ECG HRV; SpO2 is a wearable estimate; stress and recovery are not diagnoses.

### Code layout

Plain scripts (no build step), loaded in this order so the page still opens straight from disk:

```
Web Serial → serial-protocol.js (parse lines) → data-source.js → normalizeReading() → WearableReading → overview.js
```

| File | Role |
|---|---|
| `js/models.js` | Data model: `WearableReading` (every field nullable), `DeviceState`, `PpgWindow`, `DashboardSnapshot`, `WearableDataSource`. `normalizeReading()` turns raw input into a reading, rejecting out-of-range values |
| `js/metrics.js` | Metric catalogue: label, unit, source, kind (measured / estimate / derived / experimental) and **validation status** (testing / candidate / accepted / rejected) |
| `js/serial-protocol.js` | Parses one serial line (`S`, `B`, `M`, `#`) into a typed message. Firmware sentinels (`-1`, `-99`) become `null`; malformed lines are ignored. Maps quality 0–100 to poor / fair / good / excellent |
| `js/data-source.js` | Hardware boundary. `createSerialDataSource()` owns the Web Serial port (connect, disconnect, unplug, reconnect), the PPG ring buffer and the session history, and emits snapshots. `createDataSource()` picks serial (default) or mock |
| `js/mock-data.js` | **All sample values**, the synthetic PPG waveform and the `?mock=` scenarios. Loaded only in mock mode |
| `js/overview.js` | Rendering only. Never sees raw serial lines; no sensor algorithms |

### Validation status

Change a metric's `validation` in `js/metrics.js` as test results come in. Setting it to `'rejected'` hides its card and chart from the overview automatically; it stays listed in the debug section's validation table.

### Adding another data source (BLE, Firebase)

Write a function in `js/data-source.js` that returns a `WearableDataSource`: `{ kind, provides, subscribe(onSnapshot) }`, plus `connect` / `disconnect` if the user starts it by hand. Call `onSnapshot({ device, latest, history, ppg, engineering })` whenever data changes, passing each record through `normalizeReading()`. List in `provides` only the fields the source really delivers; the others show "غير متاح بعد". Return it from `createDataSource()`.

The UI files do not change. Step counting, activity classification, stress, recovery and resting heart rate belong in the firmware or app layer, never in the dashboard.
