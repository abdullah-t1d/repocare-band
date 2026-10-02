# Test recordings

Raw recordings exported from the dashboard (100 samples per second). The column meanings are listed in [../README.md](../README.md#csv-columns).

| File | Firmware | Site | Notes |
|---|---|---|---|
| `finger_rest_80s.csv` | `repocare_finger` | Fingertip | Seated, hand on table, light pressure |
| `wrist_back_rest_221s.csv` | `repocare_wrist` | Back of wrist | Seated, still. Two short periods of movement. Recorded just before the "same rate for 3 s" rule was added |
| `wrist_inner_no_pulse_134s.csv` | `repocare_wrist` | Inner wrist | Kept as a **negative example**: no usable pulse |

Use them to test your own algorithm offline: the raw `ir` and `red` columns are untouched.
