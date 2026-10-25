# Serial protocol (USB, 115200 baud)

Both heart-rate sketches and the combined firmware ([`firmware/repocare_combined`](../firmware/repocare_combined/repocare_combined.ino), v2.2) send the same plain-text lines, so any tool can read them (the dashboard, the app, a Python script, the Arduino Serial Monitor).

"v2.2" below marks behaviour of the combined firmware; the names in brackets are its constants.

## Lines sent by the band

| Prefix | Rate | Format | Meaning |
|---|---|---|---|
| `S` | 100 per second | `S,<ir>,<red>,<ppg>` | Raw IR and RED values + filtered pulse wave (`0` when there is no skin contact) |
| `B` | Each heartbeat | `B,<ibi_ms>` | Accepted beat and the time since the previous beat |
| `M` | Once per second | see below | Computed results. v2.2: keeps flowing even when the MAX30102 is missing, so the skin temperature stays live |
| `#` | Occasionally | `#<text>` | Status and errors |

### `M` line

```
M,<bpm>,<spo2>,<rmssd>,<contact>,<quality>,<tempC>,<led>,<saturated>,<beats>,<pi>,<motion>,<auto>,<led_mA>
```

| Field | Meaning | Not available |
|---|---|---|
| `bpm` | Heart rate. v2.2: when a reading drops below quality 40, the last good value is kept for up to 10 s (`HR_HOLD_MS`) and arrives with the current low quality. Losing contact clears it at once | `-1` |
| `spo2` | SpO2 estimate, % (finger only, uncalibrated). v2.2: shown after 3 seconds in a row of tier-A signal (`SPO2_STABLE_SEC`) and at least 4 beat-to-beat estimates; pulses with a perfusion index below 0.2 % and estimates below 70 % are discarded | `-1` |
| `rmssd` | HRV / PRV (RMSSD), ms. v2.2: computed from a 60 s window (`HRV_WINDOW_MS`), refreshed every 10 s (`HRV_UPDATE_MS`), only after 45 s in a row with quality ≥ 45 and a heart rate (`HRV_STABLE_SEC`). Artefact correction: pairs across a rejected beat or differing by more than 20 % of the median interval are skipped; at least 30 clean pairs spanning ≥ 45 s are needed. A value stays for 15 s (`HRV_SHOW_MS`). First value typically after ~50–60 s of steady signal | `-1` |
| `contact` | `1` = skin detected. v2.2: thresholds scale with the LED current, ~300 ms debounce | — |
| `quality` | 0–100. v2.2 bands: tier A (beats and rhythm agree) 75–100; tier B (consistent beats) 45–74, down to 40 if a strong rhythm disagrees; tier C (strong rhythm only) 40–65; contact but nothing trustworthy 10; saturated ≤ 20; no contact 0 | — |
| `tempC` | Heart-rate sketches in `1_heart_rate/`: MAX30102 **chip** temperature, 1 decimal. Combined firmware: AS6221 **skin** temperature, 2 decimals. Neither is core body temperature | `-99` |
| `led` | Fixed level 1–4, or `0` in auto mode | — |
| `saturated` | `1` = signal clipped (IR above 250000) | — |
| `beats` | Clean beats currently stored (max 12) | — |
| `pi` | Perfusion index, % | `-1` |
| `motion` | `1` = moving (always `0` while the IMU is off) | — |
| `auto` | `1` = auto brightness | — |
| `led_mA` | LED current | — |

### `#` messages

| Message | Sent by | Meaning |
|---|---|---|
| `#BOOT` / `#BOOT repoCare Band` | Wrist sketch / combined | Board started |
| `#I2C started` | Combined | I2C bus recovered and started |
| `#OK MAX30102 ready` | All | Sensor found and configured |
| `#ERR MAX30102 not found ...` | All | Wiring problem; retried every 2 s |
| `#OK AS6221 ready` | Combined | Skin-temperature sensor found |
| `#ERR AS6221 not found at 0x48` | Combined | Skin-temperature sensor missing; retried every 2 s. Heart rate is not affected |
| `#MODE finger` / `#MODE wrist` | All | Which sketch is running (the combined firmware is a fingertip sketch) |
| `#READY` | Combined | Start-up finished |
| `#CH IR` / `#CH RED` / `#CH MIX` | Wrist sketch | Signal currently used for the rhythm search |
| `#CONTACT on` / `#CONTACT off` | Combined | Skin contact found / lost |
| `#AGC LED x.x mA` | Combined | Automatic brightness changed the LED current (at most every 3 s, at once on saturation) |
| `#ERR MAX30102 lost - retrying` | Combined | Health check (every 5 s) found no sensor; the firmware keeps trying to reconnect and sends `#OK MAX30102 ready` when it is back |
| `#LED fixed level N` / `#LED auto` / `#Reset` | All | Reply to the commands below |

Start-up order of the combined firmware: `#BOOT repoCare Band`, `#I2C started`, the `#OK`/`#ERR` line of each sensor, `#MODE finger`, `#READY`. These lines are sent once, so a tool that connects later may never see them.

## Commands accepted by the band

Send a single character:

| Char | Effect |
|---|---|
| `a` | Auto brightness |
| `1` – `4` | Fixed brightness (~6 / 12 / 25 / 50 mA) |
| `r` | Reset the analysis |
