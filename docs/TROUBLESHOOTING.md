# Troubleshooting and lessons learned

Every problem below happened to us. They are listed roughly in the order you are likely to meet them.

## Wiring and soldering

| Symptom | Cause | Fix |
|---|---|---|
| I2C scan finds the sensor sometimes, then not | Header pins pressed into the XIAO without soldering | Solder all needed pins (3V3, GND, D4, D5 at least) |
| Pin shows 0 V when driven HIGH | Pin is not soldered to its pad (the top of the pin still beeps in a continuity test) | Reheat pad and pin together; the solder must flow around the pin |
| Continuous beep between 3V3 and GND | Solder bridge between neighbouring pins | Drag a clean iron tip **out** through the gap; use flux or solder wick |
| Board freezes and prints nothing | I2C line held low: loose wire, or the sensor was reset mid-transfer | Re-seat all four wires. Unplug USB for 5 s. The wrist sketch frees the bus automatically at start-up |

Check for shorts with the multimeter in continuity mode **with USB unplugged**. A short chirp between 3V3 and GND is normal (capacitors charging); a continuous beep is a short.

## I2C / sensor

| Symptom | Cause | Fix |
|---|---|---|
| `No devices found`, Part ID error 2 | **SDA and SCL swapped** | Blue → D4, Yellow → D5. Check the numbers printed under the XIAO |
| `undefined reference to Serial` | Board package needs TinyUSB | Add `#include <Adafruit_TinyUSB.h>` at the top |

## Upload and port

| Symptom | Cause | Fix |
|---|---|---|
| `could not open port 'COM5': FileNotFoundError` | The port number changed after a reset | Pick the current port in **Tools → Port** |
| `PermissionError(13, 'Access is denied')` | The dashboard or Serial Monitor is still using the port | Disconnect the dashboard and close Serial Monitor before uploading |
| No port at all | Board stuck | Double-tap **RST** (tiny button next to USB-C) to enter bootloader mode, then upload |
| `A folder named ... already exists` | Arduino IDE wants the sketch in a folder with its own name | Open the existing sketch and paste the new code, or rename the old folder |
| `LSM6DS3.h: No such file` | IMU library missing | Install **Seeed Arduino LSM6DS3**, or set `#define USE_IMU 0` |

## Signal quality

| Symptom | Cause | Fix |
|---|---|---|
| IR stuck at 262,143 | Saturation: LED too bright for the ADC range | Use auto brightness; on the wrist use ADC range 16384 |
| Wild heart-rate numbers (e.g. 119–189) | Finger pressed too hard or moving; old code reporting noise as beats | Light pressure, hand resting on the table; trust only quality ≥ 45 |
| Wrist shows nothing | Inner wrist, loose strap, room light, finger movement | Back of the wrist, firm strap, cover the sensor, keep fingers still, wait ~17 s |
| Readings slowly drift wrong over time | The board could not keep up and lost samples (we saw 80 instead of 100 samples/s) | Fixed in the current wrist sketch (lighter rhythm search). Check that your CSV has ~100 rows per second |

## Good habits

- Change wiring only with USB unplugged.
- Never feed the sensor from 5V.
- Record a CSV for every test and write down a reference reading at the same time.
- One change at a time: wiring, then code, then placement.
