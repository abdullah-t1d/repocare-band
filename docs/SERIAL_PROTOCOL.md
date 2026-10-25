# Serial protocol (USB, 115200 baud)

Both heart-rate sketches and the combined firmware ([`firmware/repocare_combined`](../firmware/repocare_combined/repocare_combined.ino), v3.0) send the same plain-text lines, so any tool can read them (the dashboard, the app, a Python script, the Arduino Serial Monitor).

The names in brackets below are constants of the combined firmware.

## Profiles (combined firmware v3.0)

The combined firmware has two measurement profiles in one sketch. It starts in **finger**; send `f` or `w` to switch (see [Commands](#commands-accepted-by-the-band)).

| | Finger (default) | Wrist (back of the wrist) |
|---|---|---|
| Algorithm | Same as v2.2: beat detection and an 8 s rhythm search, confidence tiers A/B/C | 15 s rhythm search on IR, RED and IR+RED (the clearest wins, reported with `#CH`); beat detection only confirms |
| First heart rate | ~5–10 s after contact | ~17–25 s after contact (15 s window, then the same rate must repeat for 3 s) |
| SpO2 | Yes (estimate) | Never |
| HRV / PRV | After 45 s of steady signal | Only when beats and rhythm agree (tier A, quality ≥ 70), so rarely |
| Sensor setup | ADC range 4096, LED starts at ~6.2 mA | ADC range 16384, LED starts at ~25.4 mA, auto brightness keeps IR at 140k–210k |

Switching profile reconfigures the sensor, turns auto brightness on and restarts the analysis: readings start again from scratch.

## Lines sent by the band

| Prefix | Rate | Format | Meaning |
|---|---|---|---|
| `S` | 100 per second | `S,<ir>,<red>,<ppg>` | Raw IR and RED values + filtered pulse wave (`0` when there is no skin contact) |
| `B` | Each heartbeat | `B,<ibi_ms>` | Accepted beat and the time since the previous beat |
| `M` | Once per second | see below | Computed results. Combined firmware: keeps flowing even when the MAX30102 is missing, so the skin temperature stays live |
| `#` | Occasionally | `#<text>` | Status and errors |

### `M` line

```
M,<bpm>,<spo2>,<rmssd>,<contact>,<quality>,<tempC>,<led>,<saturated>,<beats>,<pi>,<motion>,<auto>,<led_mA>
```

| Field | Meaning | Not available |
|---|---|---|
| `bpm` | Heart rate. Combined firmware: when a reading drops below quality 40, the last good value is kept for up to 10 s (`HR_HOLD_MS`) and arrives with the current low quality. Losing contact clears it at once. Wrist profile: shown only after the same rate repeats for 3 s | `-1` |
| `spo2` | SpO2 estimate, % (uncalibrated). Finger profile only: shown after 3 seconds in a row of tier-A signal (`SPO2_STABLE_SEC`) and at least 4 beat-to-beat estimates; pulses with a perfusion index below 0.2 % and estimates below 70 % are discarded. Never in the wrist profile | `-1` |
| `rmssd` | HRV / PRV (RMSSD), ms. Computed from a 60 s window (`HRV_WINDOW_MS`), refreshed every 10 s (`HRV_UPDATE_MS`), only after 45 s in a row with quality ≥ 45 and a heart rate (`HRV_STABLE_SEC`). Artefact correction: pairs across a rejected beat or differing by more than 20 % of the median interval are skipped; at least 30 clean pairs spanning ≥ 45 s are needed. A value stays for 15 s (`HRV_SHOW_MS`). Finger: first value typically after ~50–60 s of steady signal. Wrist: additionally needs tier A with quality ≥ 70 | `-1` |
| `contact` | `1` = skin detected. Thresholds depend on the profile and scale with the LED current, ~300 ms debounce | — |
| `quality` | 0–100. Finger bands: tier A (beats and rhythm agree) 75–100; tier B (consistent beats) 45–74, down to 40 if a strong rhythm disagrees; tier C (strong rhythm only) 40–65; contact but nothing trustworthy 10. Wrist: strength of the 15 s rhythm mapped to 0–100, +15 when the beats agree, 10 while there is no rhythm. Both: saturated ≤ 20, no contact 0 | — |
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
| `#MODE finger` / `#MODE wrist` | All | Active profile. The single-site sketches print it once at start-up. The combined firmware prints it at start-up **and after every `f` / `w` command**, even when the profile did not change |
| `#READY` | Combined | Start-up finished |
| `#CH IR` / `#CH RED` / `#CH MIX` | Wrist sketch, combined in the wrist profile | Signal currently used for the rhythm search; sent when it changes |
| `#CONTACT on` / `#CONTACT off` | Combined | Skin contact found / lost |
| `#AGC LED x.x mA` | Combined | Automatic brightness changed the LED current (at most every 3 s, at once on saturation) |
| `#ERR MAX30102 lost - retrying` | Combined | Health check (every 5 s) found no sensor; the firmware keeps trying to reconnect and sends `#OK MAX30102 ready` when it is back |
| `#LED fixed level N` / `#LED auto` / `#Reset` | All | Reply to the commands below |

Start-up order of the combined firmware: `#BOOT repoCare Band`, `#I2C started`, the `#OK`/`#ERR` line of each sensor, `#MODE finger`, `#READY`. These lines are sent once, so a tool that connects later may never see them; sending `f` or `w` is the way to learn (and set) the profile.

## Commands accepted by the band

Send a single character:

| Char | Effect |
|---|---|
| `a` | Auto brightness (combined firmware: back to the profile's start level) |
| `1` – `4` | Fixed brightness (~6 / 12 / 25 / 50 mA) |
| `r` | Reset the analysis |
| `f` | Combined firmware v3.0: finger profile. Reconfigures the sensor, auto brightness on, analysis restarted, replies `#MODE finger` |
| `w` | Combined firmware v3.0: wrist profile. Same, replies `#MODE wrist` |

Older firmware ignores `f` and `w` and does not reply.
