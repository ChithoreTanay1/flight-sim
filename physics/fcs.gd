class_name F16FCS
extends RefCounted
## TP-1538 "control system A" (App. A p.40-41, Figs. 62-65 p.216-224).
## Signals use the report's units: degrees, deg/s, g, N (pilot force).
## Surface signs follow TP-1538: +dh nose down, +da left roll, +dr left yaw.
## Schedule breakpoints are digitized from the figures (docs/GAPS.md §2).

# Pilot force range used to map normalized inputs (-1..1) onto the
# command-gradient figures (full figure extents).
const F_LONG_AFT := 180.0     # N, Fig. 62e right edge
const F_LONG_FWD := 80.0      # N, Fig. 62e left edge
const F_LAT_MAX := 75.0       # N, Fig. 64b
const F_PED_MAX := 530.0      # N, Fig. 65b

static var PITCH_GRADIENT := PackedVector2Array([Vector2(-80, -4.0), Vector2(-32.4, -0.8),
		Vector2(-8.8, 0.0), Vector2(7.1, 0.0), Vector2(33.3, 0.42), Vector2(180, 10.7)])
static var NEG_G_LIMIT := PackedVector2Array([Vector2(1.5, -1.0), Vector2(8.8, -4.0)])        # q̄ kPa
static var PITCH_RATE_GAIN := PackedVector2Array([Vector2(4.4, 1.0), Vector2(14.1, 0.4)])     # q̄ kPa
static var PITCH_LOOP_GAIN := PackedVector2Array([Vector2(11.3, 1.0), Vector2(42.4, 0.45)])   # q̄ kPa
static var ROLL_GRADIENT := PackedVector2Array([Vector2(-75, -308), Vector2(-49.6, -79.3),
		Vector2(-27, -18.7), Vector2(-5.6, 0), Vector2(5.6, 0), Vector2(27, 18.7),
		Vector2(49.6, 79.3), Vector2(75, 308)])
static var RUDDER_GRADIENT := PackedVector2Array([Vector2(-528, 30), Vector2(-75, 0),
		Vector2(70, 0), Vector2(488, -30)])
static var ARI_QBAR_PS := PackedVector2Array([Vector2(0.187, 0.0), Vector2(1.129, 1.0)])
static var ARI_TRIANGLE := PackedVector2Array([Vector2(-10, 0.0), Vector2(0, 1.0), Vector2(10, 0.0)])

var enabled := true

# Pilot inputs, normalized -1..1: pitch + = aft stick, roll + = right, yaw + = right pedal.
var in_pitch := 0.0
var in_roll := 0.0
var in_yaw := 0.0
var pitch_trim_g := 0.0       # FCS on: incremental g trim (±2.4, Fig. 62a)
var pitch_trim_deg := 0.0     # FCS off: stabilator trim offset

# Commands out (deg)
var dh_cmd := 0.0
var dd_cmd := 0.0
var da_cmd := 0.0
var dr_cmd := 0.0
var lef_cmd := 0.0
var alpha_f := 0.0            # filtered alpha, also used for HUD

# Pitch
var _f_long := TFilter.lag(60.0)
var _g_prefilter := TFilter.lag(8.3)
var _alpha_lag := TFilter.lag(10.0)
var _q_washout := TFilter.washout(1.0)
var _an_lag := TFilter.lag(50.0)
var _lead := TFilter.lead(3.0, 12.0, 12.0)
var _pitch_int := 0.0
# Roll
var _f_lat := TFilter.lag(60.0)
var _p_cmd_lag := TFilter.lag(10.0)
var _p_lag := TFilter.lag(50.0)
var _p_shape := TFilter.new(6400.0, 64.0, 4.0, 6400.0, 80.0, 1.0)
var _rise_pos := TFilter.washout(20.0, 6.0)
var _rise_neg := TFilter.washout(20.0, 6.0)
var _fb_pos := 0.0
var _fb_neg := 0.0
# Yaw
var _f_ped := TFilter.lag(60.0)
var _r_lag := TFilter.lag(50.0)
var _yaw_lead := TFilter.lead(3.0, 15.0, 15.0)
var _yaw_washout := TFilter.washout(1.0, 1.5)
# LEF
var _lef_lead := TFilter.lead(2.0, 7.25, 7.25)


## alpha_deg: angle of attack; p, q, r in deg/s; an_g, ay_g: normal and lateral
## acceleration in g; qbar, ps in Pa; on_ground_slow: weight on wheels below
## 50 m/s (the pitch integrator is held, see GAPS §3).
func step(alpha_deg: float, p: float, q: float, r: float, an_g: float, ay_g: float,
		qbar: float, ps: float, on_ground_slow: bool, dt: float) -> void:
	var qbar_kpa := qbar / 1000.0
	alpha_f = _alpha_lag.step(clampf(alpha_deg, -5.0, 30.0), dt)

	# Leading-edge flap schedule (App. A p.40), active in both FCS modes.
	lef_cmd = clampf(1.38 * _lef_lead.step(alpha_deg, dt) - 9.05 * qbar / maxf(ps, 1.0) + 1.45, 0.0, 25.0)

	if not enabled:
		_direct()
		return

	# ---- Pitch (Fig. 62a)
	var f_long := _f_long.step(in_pitch * (F_LONG_AFT if in_pitch > 0.0 else F_LONG_FWD), dt)
	var g_cmd := AeroTable.piecewise(PITCH_GRADIENT, f_long) + clampf(pitch_trim_g, -2.4, 2.4)
	g_cmd = clampf(g_cmd, AeroTable.piecewise(NEG_G_LIMIT, qbar_kpa), 8.0)
	var g_f := _g_prefilter.step(g_cmd, dt)
	var q_wo := _q_washout.step(q, dt)
	var q_alpha := 0.7 * AeroTable.piecewise(PITCH_RATE_GAIN, qbar_kpa) * q_wo
	var alpha_lim_hi := maxf(0.0, alpha_f + q_alpha - 20.4)
	var alpha_lim_lo := 0.322 * maxf(0.0, alpha_f + q_alpha - 15.0)
	var accel_fb := _an_lag.step(an_g - 1.0, dt)
	var lead := _lead.step(alpha_lim_lo + 0.334 * q_wo + accel_fb, dt)
	var err := 1.5 * AeroTable.piecewise(PITCH_LOOP_GAIN, qbar_kpa) * (-g_f + alpha_lim_hi + lead)
	if on_ground_slow:
		_pitch_int = 0.0
	else:
		_pitch_int = clampf(_pitch_int + 5.0 * err * dt, -25.0, 25.0)
	dh_cmd = err + _pitch_int + 0.5 * alpha_f

	# ---- Roll (Fig. 64a)
	var f_lat := _f_lat.step(in_roll * F_LAT_MAX, dt)
	var p_cmd := AeroTable.piecewise(ROLL_GRADIENT, f_lat)
	var p_cmd_f := _p_cmd_lag.step(p_cmd - _fb_pos - _fb_neg, dt)
	_fb_pos = maxf(0.0, _rise_pos.step(maxf(0.0, p_cmd_f), dt))
	_fb_neg = minf(0.0, _rise_neg.step(minf(0.0, p_cmd_f), dt))
	var p_f := _p_shape.step(_p_lag.step(p, dt), dt)
	var r_f := _r_lag.step(r, dt)
	var roll_err := (p_f - p_cmd_f) if alpha_f < 29.0 else 8.34 * r_f
	da_cmd = clampf(0.12 * roll_err, -21.5, 21.5)
	dd_cmd = 0.25 * da_cmd

	# ---- Yaw (Fig. 65a)
	var f_ped := _f_ped.step(in_yaw * F_PED_MAX, dt)
	var pilot_rud := AeroTable.piecewise(RUDDER_GRADIENT, f_ped)
	pilot_rud *= clampf((30.0 - alpha_f) / 10.0, 0.0, 1.0)
	var r_stab := r_f - p / 57.3 * alpha_f
	var damper := _yaw_washout.step(_yaw_lead.step(r_stab, dt), dt)
	var ari_gain := 0.075 * alpha_f - AeroTable.piecewise(ARI_TRIANGLE, alpha_f) \
			* AeroTable.piecewise(ARI_QBAR_PS, qbar / maxf(ps, 1.0))
	var sas := 0.5 * (damper + 19.32 * ay_g) + ari_gain * da_cmd
	if alpha_f >= 29.0:
		sas = 0.75 * r_f
	dr_cmd = clampf(pilot_rud + sas, -30.0, 30.0)


func _direct() -> void:
	dh_cmd = clampf(-25.0 * in_pitch + pitch_trim_deg, -25.0, 25.0)
	da_cmd = -21.5 * in_roll
	dd_cmd = 0.25 * da_cmd
	dr_cmd = -30.0 * in_yaw


## Initialize every filter for steady flight at the given alpha (deg) and
## trimmed stabilator, so that a trimmed start has no transient.
## an_trim is the steady body normal load factor (cos(pitch) in level flight);
## the pitch loop feeds back (an - 1), so the g-trim is set to an_trim - 1,
## the way a pilot would trim the jet hands-off.
func initialize_trim(alpha_deg: float, dh_trim: float, qbar: float, ps: float, an_trim := 1.0) -> void:
	for f in [_f_long, _q_washout, _f_lat, _p_cmd_lag, _p_lag, _p_shape,
			_rise_pos, _rise_neg, _f_ped, _r_lag, _yaw_lead, _yaw_washout]:
		f.reset(0.0)
	_fb_pos = 0.0
	_fb_neg = 0.0
	pitch_trim_g = an_trim - 1.0
	_g_prefilter.reset(pitch_trim_g)
	_an_lag.reset(an_trim - 1.0)
	_alpha_lag.reset(clampf(alpha_deg, -5.0, 30.0))
	_lef_lead.reset(alpha_deg)
	alpha_f = _alpha_lag.value
	var lo := 0.322 * maxf(0.0, alpha_f - 15.0)
	_lead.reset(lo + an_trim - 1.0)
	var qbar_kpa := qbar / 1000.0
	var err := 1.5 * AeroTable.piecewise(PITCH_LOOP_GAIN, qbar_kpa) \
			* (-pitch_trim_g + maxf(0.0, alpha_f - 20.4) + lo + an_trim - 1.0)
	_pitch_int = dh_trim - err - 0.5 * alpha_f
	dh_cmd = dh_trim
	pitch_trim_deg = dh_trim
	lef_cmd = clampf(1.38 * alpha_deg - 9.05 * qbar / maxf(ps, 1.0) + 1.45, 0.0, 25.0)


func reset() -> void:
	initialize_trim(0.0, 0.0, 0.0, 101325.0)
	_pitch_int = 0.0
	pitch_trim_deg = 0.0
