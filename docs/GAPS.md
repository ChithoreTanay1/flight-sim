# Gaps, disagreements and assumptions

Every number the sim uses either comes from the sources (see
`PARAMS_SUMMARY.md`) or is listed here. Placeholders are also marked
`PLACEHOLDER` in `aircraft/AircraftParams.gd`.

## 1. PDF vs MATLAB disagreements (PDF wins)

| # | Item | TP-1538 | MATLAB model | Used |
|---|---|---|---|---|
| D1 | Cmq(α) | p.72: −6.00 … −4.04 for α ≥ 25° | h5 has different values for α ≥ 25° (−6.63, −7.97, …, **+6.82** at 70°) | PDF |
| D2 | Cnr(α) | p.87 | h5 differs for α ≥ 15° (e.g. −0.0762 vs −0.840 at 45°) | PDF |
| D3 | Cnp(α) | p.88 | h5 differs for α ≥ 10° | PDF |
| D4 | Clp(α) | p.97: smooth −0.23 … −0.10 above 30° | h5: −0.901 at 35°, **+0.594** at 45° | PDF |
| D5 | Cl, Cn, Cy and their LEF / δa / δr tables | exactly 0 at β = 0 for the base tables | h5 adds a per-row bias equal to the base table's β = 0 value | PDF (bias removed; verified on 11 printed rows, exact match) |
| D6 | Aileron normalisation | δa/20 (Appendix B, p.44–45) | `ail/21.5` in `F16AeroFM.m` | PDF |
| D7 | Pitch-rate Cz term | ΔCzq,lef(α) | `F16AeroFM.m` uses ΔCz,lef (a bug) | PDF |
| D8 | Flight CG | 0.35 c̄ nominal (p.14) | `xcg = 0.30` | PDF |
| D9 | Mass | 20 500 lb → 9 298.6 kg | 636.94 slug → 9 295.4 kg | PDF |
| D10 | Speed-brake tables ΔCx,sb, ΔCz,sb, ΔCm,sb | p.57, 64, 71 | absent | PDF (hand transcribed) |
| D11 | Deep-stall ΔCm,ds(α, δh) | p.73 | ignored (`delta_Cm_ds = 0`) | PDF (hand transcribed) |
| D12 | Thrust | Table VI + Fig. 66 engine dynamics | thrust is a direct input (lbf) | PDF |

Hand-transcribed tables are asserted in `tools/export_aero.py`. The other
large tables were spot-checked row by row against the scans; the
longitudinal tables (Cx, Cz, Cm) and the LEF/1D derivative tables not listed
above match the h5 exactly.

Also in TP-1538 but not used: ΔCn,δa(α) (p.87; tiny, ≤ 0.00016, and it does
not appear in the Appendix B coefficient equations).

## 2. Values digitized from figures (approximate, about ±2 % of full scale)

| Item | Figure | Breakpoints used |
|---|---|---|
| Pitch command gradient (N → g) | 62e | (−80,−4.0) (−32.4,−0.8) (−8.8,0) (7.1,0) (33.3,0.42) (180,10.7) |
| Negative-g limit vs q̄ (kPa) | 62b | (1.5,−1.0) (8.8,−4.0), flat outside |
| Pitch-rate gain vs q̄ (kPa) | 62c | (4.4,1.0) (14.1,0.4), flat outside |
| Pitch-loop gain vs q̄ (kPa) | 62d | (11.3,1.0) (42.4,0.45), flat outside |
| Roll command gradient (N → °/s) | 64b | (±5.6,0) (±27,±18.7) (±49.6,±79.3) (±75,±308) |
| Rudder command gradient (N → °) | 65b | (−528,+30) (−75,0) (70,0) (488,−30) |
| ARI q̄/ps schedule | 65a | 0 at 0.187, 1 at 1.129 |
| Throttle military detent | 66b | 77 % throttle travel = 50 % power |
| 1/τ engine vs ΔP | 66c | 1.0 to ΔP 25, 0.1 from ΔP 50 |

## 3. Interpretation of block diagrams

- **Pitch PI (Fig. 62a).** The anti-windup network next to the 5/s integrator
  is drawn ambiguously. It is implemented as an integrator clamped to ±25°
  that stops integrating while clamped.
- **Roll command shaping (Fig. 64a).** The two half-wave 6s/(s+20)
  branches are implemented symmetrically (the stray dashes beside the upper
  transfer function are read as fraction-bar artefacts). They act as
  negative feedback around the 10/(s+10) command filter and slow the onset
  of large roll-rate commands.
- **Roll trim (Fig. 64a)** feeds 1.67 × (±40) into the error node; the sim exposes no roll trim, so it is 0.
- **Weight-on-wheels logic** is not described in TP-1538, which covers
  airborne flight only. The pitch integrator is held at zero while on the
  ground below 50 m/s, so it cannot wind up during taxi.
- **Differential tail δd** is driven and animated, but TP-1538's roll data
  (the "δa = 20°" tables) already represent the combined roll control, so δd
  has no separate aero term.
- **FCS off** (test toggle): stick, pedal and roll inputs map straight to
  surface deflections (full stick = full deflection). LEF scheduling stays on.

## 4. Missing data → placeholders (PLACEHOLDER in AircraftParams.gd)

| Item | Placeholder | Why it is needed |
|---|---|---|
| Gear static compression | 50 % of stroke | sets oleo spring rate k = static load / (0.5·stroke) |
| Gear damping ratio | 0.6 of critical (per strut, on static load) | oleo damping |
| Tyre rolling resistance μ | 0.02 | taxi drag |
| Wheel-brake μ | 0.5 (main gear only) | braking |
| Tyre lateral μ | 0.8 | side force limit |
| Tyre "bristle" stiffness / damping | 2.0e5 N/m, 0.7 ratio | numerical static friction (solver parameter) |
| Nose-wheel steering limit | 32° at taxi speed, fading to 6° at 40 m/s | ground steering |
| Speed-brake rate | 30 °/s | actuator |
| Gear transit time | 6 s | retract/extend (visual + wheels disabled when up) |
| Hard-landing sink rate | 3.05 m/s (10 ft/s) | crash detection |
| Overstress limits | +9.0 g / −4.5 g | warning; FCS command limits are +8 g / about −4 g (Fig. 62) |
| Thrust line | through CG along body X | no offset given |
| Fuel burn | none (mass and CG constant) | no fuel-flow data |

## 5. Missing data → effect not modelled

- **Trailing-edge flaps.** The README gives settings (20° take-off/landing)
  but there are no TEF aero data anywhere. The flaps are visual and shown on the HUD only.
- **Gear aerodynamics** (drag, pitching moment): no data.
- **Ground effect**: no data (the spec says to model it only if the docs give data).
- **Mach / compressibility**: the aero data are low-speed. TP-1538 says the model is valid only below about M 0.6.
- **Thrust below M 0.2**: Table VI starts at M 0.2, so static thrust uses the M 0.2 row.
- **Wind / turbulence**: no data; not modelled.
- **LEF on the ground**: the README says −2° with weight on wheels, but the
  TP-1538 schedule is limited to 0…25° and the aero data stop at 0°. The TP-1538 schedule is used everywhere.
- **Stall speed / take-off speed / cruise speed**: none of the sources
  gives one. The tests use the conditions TP-1538 does document instead (see §6).
- **LEF data above α = 45°**: the LEF increment tables (`*_lef`) stop at
  α = 45° (TP-1538 alpha2 axis); the lookup clamps them at 45° above that.
- **Fuel, weight change, engine failure, icing, damage**: not modelled.

## 5a. Implementation choices that deviate from a plain RigidBody3D

- **custom_integrator.** Godot's RigidBody3D inertia is diagonal only, but
  TP-1538 Table I gives Ixz = 982 slug·ft². `Aircraft` sets
  `custom_integrator = true`; `F16Model.tick()` updates linear and angular
  velocity itself (full tensor plus the engine angular momentum term,
  ω̇ = I⁻¹(M − ω × (Iω + h))), with Godot's `state.total_gravity` applied
  exactly once. Godot integrates the pose and resolves collisions. The
  diagonal `inertia` given to Godot is used only for contact response.
- **Ground.** A 40 × 40 km box, not `WorldBoundaryShape3D`: under Jolt the
  aircraft fell through the boundary plane in the main scene.
- **Crash detection.** Any contact between the airframe collision boxes and
  the world is a crash; the wheels are raycasts and never collide.
- **Test pilot.** The take-off test rotates with half aft stick at 70 m/s.
  That is technique, not aircraft data (PLACEHOLDER).
- **Pilot-input tuning** (keyboard ramp 3/s and 5/s, throttle 0.45/s, trim rates
  0.4 g/s and 3°/s, the 0.12 deadzone): input feel, not aircraft data.

## 6. Verification against the documents

See `tests/` and the results section below (updated by running the tests).

### Results

Run on Godot 4.7.2 (Jolt), 2026-10-29.
`godot --headless --path . --script res://tests/run_tests.gd`: **36/36 pass**.
`godot --headless --path . --fixed-fps 120 --script res://tests/scene_test.gd`: **4/4 pass**.

| Check | Reference | Result |
|---|---|---|
| Table lookup at grid points, interpolation, clamping | TP Table III (pp. 51, 72, 90), Table VI | exact (≤1e-9) |
| Frames round trip, cross product, gear position, inertia SI | Table I, README | pass |
| ISA SL density, 11 km T/p, SL a | ISA | pass |
| Engine military thrust M0.2 SL, idle→mil spool, AB light | Table VI, Fig. 66 | 56 401 N; t95 = 4.1 s; 0.46 s |
| Trim M 0.6 / 9144 m | TP p.16 tracking task | α 5.28°, δh −0.27°, throttle 0.301 |
| 60 s hands-off with FCS on (sim core and RigidBody) | | max \|Δh\| 0.00 m |
| 5 °/s pitch kick damped by the FCS | | peak Δα 0.48°, back to trim in 6 s |
| Static margin at low α (unaugmented) | TP p.17 "about −4 %" | −4.1 % c̄ |
| Full aft stick α limit in 1 g flight | TP p.40 "about 25°" | steady 25.4°, peak 27.3° |
| CLmax α | TP p.17 "about 35°" | CLmax 1.894 at 36° |
| Implied 1 g stall speeds (SL, 91 188 N) | derived (no doc value) | Vs(CLmax) 53.1 m/s (103 kt); V(α 25°) 58.6 m/s (114 kt) |
| Gear static compression and load split | placeholder spring sizing | 0.138 of 0.254 m nose, 0.131 of 0.267 m main; nose share 19.9 % |
| Parked at idle on brakes, 30 s | | drift 0.0000 m |
| Max-AB take-off on flat ground | no doc value | lift-off 85.2 m/s (166 kt), 381 m roll, α 8.5° |
| 10 min flight with manoeuvres: finite state, basis orthonormal | | error 2.5e-7 (core), < 1e-6 (RigidBody) |

The stall-speed check in the spec ("within 5 %") has no documented value
to compare against. The test reports the speeds the TP-1538 data imply
instead, and checks that level trim exists at 1.05 × V(α 25°).
