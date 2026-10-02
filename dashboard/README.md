# Dashboard

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
