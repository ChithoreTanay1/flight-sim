class_name F16Model
extends RefCounted
## One physics tick of the F-16: air data -> FCS -> actuators -> engine ->
## aerodynamics + gear -> velocity update. Pure GDScript, no nodes, so the
## same code runs in the RigidBody3D and in headless tests.
##
## Rotational dynamics use the full body inertia tensor (including Ixz) and
## the engine gyroscopic term (TP-1538 App. B p.42). Godot's RigidBody3D can
## only hold a diagonal inertia, so the aircraft integrates velocities itself
## (custom_integrator) and Godot integrates the pose.

var params: AircraftParams
var si: AircraftParams.SI
var aero: F16Aero
var engine := F16Engine.new()
var fcs := F16FCS.new()
var gear: LandingGear

var _stab_l: TFilter.Actuator
var _stab_r: TFilter.Actuator
var _ail: TFilter.Actuator
var _rud: TFilter.Actuator
var _lef: TFilter.Actuator
var _sb: TFilter.Actuator

# Pilot controls (set by the input layer)
var throttle := 0.0          # 0..1, military detent at F16Engine.MIL_DETENT
var brake := 0.0             # 0..1 wheel brakes
var parking_brake := false
var speed_brake := false
var gear_down := true
var flaps_auto := true       # TEF follows the README schedule; false = up

# Surface positions, deg (TP-1538 signs)
var dh := 0.0
var dd := 0.0
var da := 0.0
var dr := 0.0
var dlef := 0.0
var dsb := 0.0
var tef := 0.0               # visual only (no aero data, GAPS §5)
var gear_pos := 1.0          # 0 = up, 1 = down

# Air data and state outputs
var altitude := 0.0
var vt := 0.0
var alpha := 0.0             # deg
var beta := 0.0              # deg
var mach := 0.0
var qbar := 0.0
var ps := Atmosphere.P0
var rho := Atmosphere.RHO0
var p := 0.0                 # body rates, rad/s
var q := 0.0
var r := 0.0
var an_g := 1.0
var ay_g := 0.0
var force_body := Vector3.ZERO    # aero + thrust, TP body axes, N
var moment_body := Vector3.ZERO   # aero, TP body axes, N·m

# Events
var crashed := false
var crash_reason := ""
var overstress := false
var peak_g := 1.0


func _init(p_params: AircraftParams) -> void:
	params = p_params
	si = params.to_si()
	aero = F16Aero.new(si.b, si.cbar, si.xcg_ref, si.xcg)
	gear = LandingGear.new(si, params)
	var bw := 1.0 / params.surface_lag_s
	var dh_lim := params.dh_limit_deg
	_stab_l = TFilter.Actuator.new(bw, params.stab_rate_dps, -dh_lim, dh_lim)
	_stab_r = TFilter.Actuator.new(bw, params.stab_rate_dps, -dh_lim, dh_lim)
	_ail = TFilter.Actuator.new(bw, params.aileron_rate_dps, -params.da_limit_deg, params.da_limit_deg)
	_rud = TFilter.Actuator.new(bw, params.rudder_rate_dps, -params.dr_limit_deg, params.dr_limit_deg)
	_lef = TFilter.Actuator.new(1.0 / params.lef_lag_s, params.lef_rate_dps, 0.0, params.lef_max_deg)
	_sb = TFilter.Actuator.new(1000.0, params.sb_rate_dps, 0.0, params.sb_max_deg)


## Advance one step. Returns [new world linear velocity, new world angular velocity].
func tick(xform: Transform3D, v_world: Vector3, w_world: Vector3, g_world: Vector3,
		probe: Callable, dt: float) -> Array:
	var b := xform.basis
	var inv := b.transposed()
	var vb := Frames.to_body(inv * v_world)
	var wb := Frames.to_body(inv * w_world)
	p = wb.x
	q = wb.y
	r = wb.z

	# Air data
	altitude = xform.origin.y
	rho = Atmosphere.density(altitude)
	ps = Atmosphere.pressure(altitude)
	vt = vb.length()
	alpha = rad_to_deg(atan2(vb.z, vb.x)) if vt > 0.1 else 0.0
	beta = rad_to_deg(asin(clampf(vb.y / vt, -1.0, 1.0))) if vt > 0.1 else 0.0
	mach = vt / Atmosphere.speed_of_sound(altitude)
	qbar = 0.5 * rho * vt * vt

	# Flight control system and actuators
	var slow_on_ground := gear.weight_on_wheels and vt < 50.0
	fcs.step(alpha, rad_to_deg(p), rad_to_deg(q), rad_to_deg(r), an_g, ay_g, qbar, ps,
			slow_on_ground, dt)
	var dd_cmd := clampf(fcs.dd_cmd, -params.dd_limit_deg, params.dd_limit_deg)
	var left := _stab_l.step(fcs.dh_cmd + dd_cmd, dt)
	var right := _stab_r.step(fcs.dh_cmd - dd_cmd, dt)
	dh = 0.5 * (left + right)
	dd = 0.5 * (left - right)
	da = _ail.step(fcs.da_cmd, dt)
	dr = _rud.step(fcs.dr_cmd, dt)
	dlef = _lef.step(fcs.lef_cmd, dt)
	dsb = _sb.step(params.sb_max_deg if speed_brake else 0.0, dt)
	_update_gear_and_flaps(dt)

	# Engine and aerodynamics (body axes)
	var thrust := engine.step(throttle, mach, altitude, dt)
	aero.compute(alpha, beta, vt, p, q, r, dh, da, dr, dlef, dsb)
	var qs := qbar * si.s
	force_body = Vector3(qs * aero.cx + thrust, qs * aero.cy, qs * aero.cz)
	moment_body = Vector3(qs * si.b * aero.cl, qs * si.cbar * aero.cm, qs * si.b * aero.cn)

	# Landing gear (world axes)
	var nws := deg_to_rad(lerpf(params.nws_limit_low_deg, params.nws_limit_high_deg,
			clampf(vt / params.nws_fade_speed_mps, 0.0, 1.0)))
	var brake_cmd := 1.0 if parking_brake else brake
	gear.compute(xform, v_world, w_world, probe, brake_cmd, fcs.in_yaw * nws, gear_pos, dt)

	# Totals
	var f_world := b * Frames.from_body(force_body) + gear.force
	var m_body := moment_body + Frames.to_body(inv * gear.torque)
	var sf := Frames.to_body(inv * f_world) / si.mass
	an_g = -sf.z / Atmosphere.G0
	ay_g = sf.y / Atmosphere.G0
	_check_limits()

	# Velocity update: translation in world axes, rotation in body axes.
	var v_new := v_world + (f_world / si.mass + g_world) * dt
	var h := Vector3(si.engine_h, 0.0, 0.0)   # fixed engine momentum, TP-1538 p.46
	var wdot := si.inertia_inv * (m_body - wb.cross(si.inertia * wb + h))
	var wb_new := wb + wdot * dt
	return [v_new, b * Frames.from_body(wb_new)]


func _update_gear_and_flaps(dt: float) -> void:
	var target := 1.0 if gear_down else 0.0
	if not gear_down and gear.weight_on_wheels:
		target = 1.0   # no retraction on the ground
	gear_pos = move_toward(gear_pos, target, dt / params.gear_transit_s)
	var tef_target := params.tef_down_deg if (flaps_auto and gear_pos > 0.5) else params.tef_up_deg
	tef = move_toward(tef, tef_target, 10.0 * dt)


func _check_limits() -> void:
	if gear.weight_on_wheels:
		if gear.touchdown_sink_rate > si.hard_landing_sink:
			crash("HARD LANDING  %.1f m/s sink" % gear.touchdown_sink_rate)
		return
	peak_g = maxf(peak_g, an_g)
	if an_g > params.overstress_pos_g or an_g < params.overstress_neg_g:
		overstress = true


func crash(reason: String) -> void:
	if not crashed:
		crashed = true
		crash_reason = reason


## Surface and engine state for steady trimmed flight (see Trim.level()).
func apply_trim(trim: Dictionary) -> void:
	var a: float = trim.alpha
	var d: float = trim.dh
	_stab_l.pos = d
	_stab_r.pos = d
	_ail.pos = 0.0
	_rud.pos = 0.0
	dh = d
	throttle = trim.throttle
	var h: float = trim.altitude
	var v: float = trim.vt
	var qb := 0.5 * Atmosphere.density(h) * v * v
	var press := Atmosphere.pressure(h)
	engine.settle(throttle, v / Atmosphere.speed_of_sound(h), h)
	var an_trim := cos(deg_to_rad(a + float(trim.gamma)))
	fcs.initialize_trim(a, d, qb, press, an_trim)
	_lef.pos = fcs.lef_cmd
	dlef = fcs.lef_cmd
	an_g = an_trim
	ay_g = 0.0
	gear_down = false
	gear_pos = 0.0
	parking_brake = false
	crashed = false
	overstress = false


## Parked on the ground, engine at idle.
func reset_ground() -> void:
	for act in [_stab_l, _stab_r, _ail, _rud, _lef, _sb]:
		act.pos = 0.0
	fcs.reset()
	engine.settle(0.0, 0.0, 0.0)
	throttle = 0.0
	brake = 0.0
	parking_brake = true
	speed_brake = false
	gear_down = true
	gear_pos = 1.0
	an_g = 1.0
	ay_g = 0.0
	crashed = false
	crash_reason = ""
	overstress = false
	peak_g = 1.0
	for w in gear.wheels:
		w.compression = 0.0
		w.in_contact = false
		w.s_lon = 0.0
		w.s_lat = 0.0
