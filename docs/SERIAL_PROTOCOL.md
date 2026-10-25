# Serial protocol (USB, 115200 baud)

Both heart-rate sketches and the combined firmware (`repocare_combined.ino`, v2.2) send the same plain-text lines, so any tool can read them (the dashboard, the app, a Python script, the Arduino Serial Monitor).

## Lines sent by the band

| Prefix | Rate | Format | Meaning |
|---|---|---|---|
| `S` | 100 per second | `S,<ir>,<red>,<ppg>` | Raw IR and RED values + filtered pulse wave (`0` when there is no skin contact) |
| `B` | Each heartbeat | `B,<ibi_ms>` | Accepted beat and the time since the previous beat |
| `M` | Once per second | see below | Computed results |
| `#` | Occasionally | `#<text>` | Status and errors |

### `M` line

```
M,<bpm>,<spo2>,<rmssd>,<contact>,<quality>,<tempC>,<led>,<saturated>,<beats>,<pi>,<motion>,<auto>,<led_mA>
```

| Field | Meaning | Not available |
|---|---|---|
| `bpm` | Heart rate. v2.2: when the signal drops, the last good value is kept for up to 10 s and arrives with the current low quality (`quality` < 40) | `-1` |
| `spo2` | SpO2 estimate, % (finger only). v2.2: appears after 3 good seconds | `-1` |
| `rmssd` | HRV (RMSSD), ms. v2.2: computed over a 60 s artefact-corrected window and refreshed every 10 s, so the first value appears after ~45–60 s of steady signal | `-1` |
| `contact` | `1` = skin detected | — |
| `quality` | 0–100 | — |
| `tempC` | Heart-rate sketches in this repo: MAX30102 **chip** temperature. Combined prototype firmware (with AS6221): **skin** temperature. Neither is core body temperature | `-99` |
| `led` | Fixed level 1–4, or `0` in auto mode | — |
| `saturated` | `1` = signal clipped | — |
| `beats` | Clean beats currently stored (max 12) | — |
| `pi` | Perfusion index, % | `-1` |
| `motion` | `1` = moving (always `0` while the IMU is off) | — |
| `auto` | `1` = auto brightness | — |
| `led_mA` | LED current | — |

### `#` messages

| Message | Meaning |
|---|---|
| `#BOOT` | Board started (wrist sketch) |
| `#OK MAX30102 ready` | Sensor found and configured |
| `#ERR MAX30102 not found ...` | Wiring problem; retried every 2 s |
| `#MODE finger` / `#MODE wrist` | Which sketch is running |
| `#CH IR` / `#CH RED` / `#CH MIX` | Wrist only: signal currently used for the rhythm search |
| `#CONTACT on` / `#CONTACT off` | v2.2: skin contact found / lost |
| `#AGC LED x.x mA` | v2.2: automatic brightness changed the LED current |
| `#ERR MAX30102 lost - retrying` | v2.2: the sensor stopped answering; the firmware keeps trying to reconnect |

## Commands accepted by the band

Send a single character:

| Char | Effect |
|---|---|
| `a` | Auto brightness |
| `1` – `4` | Fixed brightness (~6 / 12 / 25 / 50 mA) |
| `r` | Reset the analysis |
