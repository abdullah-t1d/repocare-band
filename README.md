# repoCare Band

Open-source firmware and tools for a screenless health band built on the **Seeed Studio XIAO nRF52840 Sense**, the **ProtoCentral Pulse 3+ (MAX30102)** optical heart-rate sensor and the **ProtoCentral AS6221** skin-temperature sensor.

Everything here was tested on real hardware. If you own the same sensors, this repository should save you days of debugging: tested settings, working firmware, real recordings and the mistakes we made along the way.

> ⚠️ **Research prototype, not a medical device.** SpO2 is an uncalibrated estimate. Do not use these readings for diagnosis or treatment.

---

## Project status

| Module | Sensor | Fingertip | Wrist | Status |
|---|---|---|---|---|
| [Heart rate, HRV, SpO2](1_heart_rate/) | ProtoCentral Pulse 3+ (MAX30102) | ✅ Validated | ✅ Validated at rest (back of wrist) | **Done** |
| [Skin temperature](2_temperature/) | ProtoCentral AS6221 | ⏳ Planned | ⏳ Planned | Read by the combined firmware; validation pending |
| [Motion and sleep](3_motion/) | LSM6DS3TR-C IMU (built into XIAO Sense) | — | ⏳ Planned | After temperature |
| [Combined firmware v2.2](firmware/repocare_combined/) | MAX30102 + AS6221 on one Qwiic hub | 🧪 Validation stage | — | **Prototype**: HR, SpO2, HRV/PRV (60 s window), skin temperature |
| [Live dashboard](dashboard/) | — | ✅ | ✅ | **Done** |

---

## Hardware

| Part | Exact product | Role |
|---|---|---|
| Microcontroller | **Seeed Studio XIAO nRF52840 Sense** | Runs the firmware, BLE, built-in IMU, battery charger |
| PPG sensor | **ProtoCentral Pulse 3+** (Maxim/ADI **MAX30102**, red + IR LEDs) | Heart rate, HRV, SpO2 |
| Temperature sensor | **ProtoCentral AS6221** skin temperature sensor (ams OSRAM **AS6221**) | Skin temperature |
| Cable | **Adafruit #4397** STEMMA QT / Qwiic to female Dupont | Connects the sensor to the XIAO pins |
| Hub (for 2+ sensors) | Qwiic / STEMMA QT 5-port hub | Shares one I2C bus between sensors |

### Wiring (MAX30102 via Qwiic cable)

| Qwiic wire | XIAO pin | Signal |
|---|---|---|
| Red | **3V3** | Power (never 5V) |
| Black | **GND** | Ground |
| Blue | **D4** | SDA |
| Yellow | **D5** | SCL |

The silkscreen numbers on the **underside** of the XIAO are the most reliable way to check the pins.
Swapping blue and yellow is the most common mistake and gives `No devices found` (see [Troubleshooting](docs/TROUBLESHOOTING.md)).

---

## Software setup

| Item | Version we used |
|---|---|
| Arduino IDE | 2.3.10 |
| Board package | **Seeed nRF52 Boards** 1.1.13 (board: *Seeed XIAO nRF52840 Sense*) |
| Library | **SparkFun MAX3010x Pulse and Proximity Sensor Library** 1.1.2 |

With this board package every sketch that uses `Serial` must start with:

```cpp
#include <Adafruit_TinyUSB.h>
```

Otherwise the build fails with `undefined reference to Serial`.

**Arduino rule:** a sketch must live in a folder with the same name (`repocare_finger/repocare_finger.ino`). Keep the folders as they are.

---

## Quick start

1. Wire the sensor as shown above (USB unplugged).
2. Open `1_heart_rate/repocare_finger/repocare_finger.ino` in Arduino IDE and upload it.
3. Close the Serial Monitor (only one program can use the port).
4. Open `dashboard/repocare_dashboard.html` in **Chrome or Edge** on a computer and click **اتصال بالسوار** (Connect).
5. Rest your fingertip on the sensor with light pressure. A heart rate appears within 10 to 15 seconds.

---

## Repository layout

```
repocare_band/
├─ 1_heart_rate/          MAX30102 firmware (finger + wrist), test recordings, results
├─ 2_temperature/         AS6221 firmware (planned)
├─ 3_motion/              IMU readings: steps, activity, sleep, wear (planned)
├─ app/                   Flutter web app: devices, live dashboard, guided measurement (Web Serial or demo recordings)
├─ dashboard/             Legacy HTML pages: live monitor (Web Serial, CSV export) + health overview prototype
├─ docs/                  Serial protocol, troubleshooting, lessons learned
└─ firmware/              Combined firmware v2.2 (MAX30102 + AS6221), fingertip validation stage
```

---

## Key results

| Test | Duration | Result | Independent check |
|---|---|---|---|
| Fingertip, at rest | 80 s | 65–72 BPM, quality 100 most of the time | Spectral analysis: 68.8 BPM |
| Back of wrist, at rest | 221 s | 61–71 BPM, reading available ~60% of the time | Spectral analysis: 62–69 BPM |
| Inner wrist, at rest | 134 s | No reliable pulse (firmware correctly showed nothing) | No heart rhythm in the signal |

Full details: [1_heart_rate/README.md](1_heart_rate/README.md).
Comparison against a reference device (smartwatch / pulse oximeter) is **pending**.

---

## Documentation

- [Serial protocol](docs/SERIAL_PROTOCOL.md): the text lines the firmware sends and the commands it accepts
- [Troubleshooting](docs/TROUBLESHOOTING.md): every problem we hit and how we fixed it

---

## نظرة عامة بالعربي

سوار صحي بدون شاشة، يقيس **النبض** و**HRV** و**SpO2** من الإصبع، و**النبض المستمر** من ظهر المعصم وقت الراحة. وقريبًا **حرارة الجلد** و**الحركة والنوم**. كل الأكواد مجرّبة على الأجهزة الحقيقية، ومعها تسجيلات فعلية ونتائج تحليلها.

---

## License

MIT, see [LICENSE](LICENSE). Change it if your team prefers another license.
