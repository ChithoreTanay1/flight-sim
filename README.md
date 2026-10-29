# flight-sim

F-16 flight simulator in Godot 4.7 (Jolt, Forward+). Flight physics come only
from NASA TP-1538 (aero tables, flight control system, engine), the
F16-Model-Matlab data and `README.txt` (geometry, gear). The scene is a
stylized low-poly airfield at sunset.

Open the folder in Godot 4.7 and press Play. You start parked on runway 36
with the parking brake on.

## Controls

| Key | Gamepad | Action |
|---|---|---|
| W / S | left stick Y | pitch (W = nose down) |
| A / D | left stick X | roll |
| Q / E | LB / RB | yaw, nose-wheel steering |
| Shift / Ctrl | RT / LT | throttle (stops at MIL; press Shift again for afterburner) |
| Space | A | wheel brakes |
| P | | parking brake |
| B | X | speed brake |
| F | d-pad left | flaps auto / up |
| G | d-pad right | gear |
| Up / Down | d-pad up / down | pitch trim |
| V | | flight control system on / off (direct mode) |
| C | Y | camera: chase / cockpit / orbit (hold right mouse button to look, wheel to zoom) |
| R | Back | reset on runway |
| Y | | air start (1500 m, 180 m/s) |
| H | Start | help overlay |

To take off: P to release the brake, then Shift past MIL into afterburner.
Pull S gently at about 140 kt and raise the gear with G after lift-off.

## Tests

```
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --fixed-fps 120 --script res://tests/scene_test.gd
```

Every assumption, placeholder and disagreement between sources is listed in
`docs/GAPS.md`, along with the latest test results. Parameters are
summarized in `docs/PARAMS_SUMMARY.md`.
