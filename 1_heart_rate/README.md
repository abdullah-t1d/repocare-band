# 1. Heart rate, HRV and SpO2: ProtoCentral Pulse 3+ (MAX30102)

Two separate firmware files, one per body site. Each is tuned for that site only.

| Firmware | Body site | Reports | Use it for |
|---|---|---|---|
| [`repocare_finger`](repocare_finger/repocare_finger.ino) | Fingertip | Heart rate, HRV (RMSSD), SpO2 estimate | Accurate on-demand measurement (~30 s) |
| [`repocare_wrist`](repocare_wrist/repocare_wrist.ino) | **Back** of the wrist | Heart rate (HRV only when the signal is very clean) | Continuous heart rate at rest and during sleep |

---

## About the sensor

The **MAX30102** shines red (660 nm) and infrared (880 nm) light into the skin and measures how much comes back. Each heartbeat pushes blood into the tissue and slightly changes the reflected light. That small change is the **PPG** (photoplethysmography) signal.

- I2C address: **0x57**, Part ID register `0xFF` = **0x15**
- 18-bit ADC, programmable LED current (0–51 mA), up to 3200 samples/s
- ProtoCentral designs the **Pulse 3+** board for the **fingertip**. It has no green LED (the colour smartwatches use on the wrist), so the wrist signal is much weaker.

---

## Settings that worked (and why)

| Setting | Finger | Wrist | Why |
|---|---|---|---|
| Sample rate | 400/s, averaged by 4 → **100/s** | same | Smooth signal, enough for HRV |
| Pulse width | 411 µs (18-bit) | same | Highest resolution |
| ADC range | **4096** | **16384** | The wrist needs high LED current; a small range saturates |
| LED current | Starts at ~6 mA, auto | Starts at ~25 mA, auto | Auto brightness keeps the signal strong but never clipped |
| Auto brightness target (IR) | 80,000 – 180,000 | 140,000 – 210,000 | Saturation is 262,143 |
| Contact threshold (IR) | on > 50,000, off < 30,000 | on > 12,000, off < 8,000 | Different ADC ranges |

---

## How the algorithm works

1. **Band-pass filter 0.5–4 Hz** (2nd-order Butterworth) keeps only heart-rate frequencies (30–240 BPM). It removes breathing drift and fast noise.
2. **Beat detection:** each beat is found at its **steepest upstroke** inside a ±150 ms window. The upstroke is used instead of the peak because the second "dicrotic" wave after each beat can look like a peak and double the count.
3. **Rhythm detection (autocorrelation):** the signal is compared with delayed copies of itself to find the repeating period. This works even when single beats are hard to see.
4. **Agreement rule:** a number is shown only when the methods agree. The firmware prefers showing nothing to showing a wrong number.

**Finger:** beat detection and an 8-second rhythm check must agree.
**Wrist:** a **15-second** rhythm search on three signals (IR, RED and IR+RED combined). The clearest one is used, and the same rate must repeat for 3 seconds before it is shown.

**HRV (RMSSD)** is computed only from clean, consistent beats.
**SpO2** (finger only) uses the ratio-of-ratios formula `SpO2 ≈ 110 − 25·R`. It is **not calibrated** against a medical oximeter.

---

## Test results

All recordings are in [`test_data/`](test_data/). "Independent check" means we re-analysed the raw signal offline (frequency spectrum) without using the firmware's numbers.

| Recording | Site | LED current | Firmware result | Independent check |
|---|---|---|---|---|
| `finger_rest_80s.csv` | Fingertip | 6.2 mA | **65–72 BPM**, quality 100 most of the time, 91 beats | 68.8 BPM |
| `wrist_back_rest_221s.csv` | Back of wrist | 38 mA | **61–71 BPM**, reading available ~60% of the time | 62–69 BPM |
| `wrist_inner_no_pulse_134s.csv` | Inner wrist | 33–43 mA | No number shown (correct) | No heart rhythm found |

**Pending:** side-by-side comparison with a reference device (smartwatch or medical pulse oximeter).

### What we learned about the wrist

- The **back** of the wrist worked; the **inner** wrist did not. On the inner wrist the tendons move with every small finger movement, and that movement hides the tiny pulse.
- The wrist pulse is very small (perfusion index ~0.05% vs ~0.7–1.3% on the finger). It is still **regular**, and the long 15-second rhythm search can find it.
- Movement interrupts the reading. The firmware stops showing a number instead of guessing.
- A sensor with a **green LED** (for example **MAXM86161**) would be the next step for continuous wrist readings during movement.

---

## How to test it yourself

1. Upload the firmware for your site and open the [dashboard](../dashboard/).
2. **Finger:** rest your hand on the table, sensor face up, fingertip on top with **light** pressure. Wait 10–15 s.
3. **Wrist:** strap the sensor firmly to the **back** of the wrist, about one finger-width above the wrist bone towards the elbow. Cover it from room light and keep still. The first number appears after ~17 s.
4. Press **بدء التسجيل** (Record) to save a CSV. Note the reading of a reference device at the same time.

### CSV columns

| Column | Meaning |
|---|---|
| `time_ms` | Computer time in milliseconds |
| `ir`, `red` | Raw 18-bit sensor values |
| `ppg` | Filtered pulse wave |
| `beat` | `1` when a heartbeat was detected |
| `bpm`, `spo2` | Reported values (`-1` = not available) |
| `quality` | 0–100 signal quality |
| `led` | `auto` or fixed level 1–4 |
| `contact` | `1` = sensor touching skin |
| `pi` | Perfusion index (pulse strength, %) |
| `motion` | `1` = movement detected (IMU off in v1) |
| `led_mA` | LED current |
