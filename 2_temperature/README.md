# 2. Skin temperature: ProtoCentral AS6221

> ⏳ **Planned.** No firmware yet. Coding starts when the Qwiic hub arrives, so both sensors can share the I2C bus.

## About the sensor

- **ams OSRAM AS6221** digital temperature sensor on a ProtoCentral board with a probe on a cable and a Qwiic (JST-SH 4-pin) connector.
- High accuracy for body-range temperatures (see the AS6221 datasheet; about ±0.1 °C around 20–42 °C).
- I2C. The address depends on the board's address pin: **run an I2C scan to confirm it** (the MAX30102 is at `0x57`, so there is no clash).

## Important: skin temperature is not body temperature

Wrist skin is normally about **32–35 °C**, lower than core body temperature (~37 °C) and strongly affected by room temperature.
The useful signal is the **change compared with your own baseline**, especially at night (the same idea WHOOP and Oura use).
The firmware and the app must **never** present it as a fever or body-temperature reading.

## Planned firmware

| Folder | Site | Plan |
|---|---|---|
| [`repocare_temp_wrist`](repocare_temp_wrist/) | Back of wrist | Continuous reading every few seconds, nightly baseline |
| [`repocare_temp_finger`](repocare_temp_finger/) | Fingertip | Quick reading together with the on-demand heart-rate measurement |

## Wiring

The AS6221 cable ends in a JST-SH plug, and the Pulse 3+ board has a single Qwiic port, so both cannot plug into the XIAO directly.

- **Prototype:** XIAO ← Qwiic-to-Dupont cable ← **Qwiic 5-port hub** → MAX30102 and AS6221
- **Final band:** cut the plugs and solder both sensors' 4 wires to the same 3V3 / GND / D4 / D5 points

Before cutting any cable, **test the sensor first** and **confirm which wire is SDA and which is SCL** with a multimeter. The cable colours may not follow the usual Qwiic colours.
