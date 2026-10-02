# 3. Motion, activity and sleep: built-in IMU (LSM6DS3TR-C)

> ⏳ **Planned**, after skin temperature.

The **XIAO nRF52840 Sense** already contains a 6-axis IMU (**LSM6DS3TR-C**: accelerometer + gyroscope). It is wired inside the board, so it uses no extra pins and needs no extra hardware.

## Readings we will build (only the essentials)

| Reading | Why it matters |
|---|---|
| **Steps** | Basic daily activity |
| **Activity level**: still / light / active | Tells the heart-rate firmware when a reading can be trusted |
| **Sleep**: sleep time, wake time, duration | The most useful feature after heart rate |
| **Wear detection**: is the band on the wrist? | Avoids storing empty data (combined with PPG contact and skin temperature) |

**Deliberately left out:** calories, fall detection and sleep stages (light/deep/REM). They are rough estimates even in commercial devices and add complexity without real value for this project.

## Known issue

In our first test, enabling the IMU with the **Seeed Arduino LSM6DS3** library (2.0.7) together with the **Seeed nRF52 Boards** package (1.1.13) froze the board at start-up. The heart-rate firmware therefore ships with `#define USE_IMU 0`.
The IMU will be tested alone in a small sketch first, before it is merged.
