extends SceneTree
## Headless physics tests. Run:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all passed. Numbers checked against TP-1538 where it gives one.

const DT := 1.0 / 120.0

var _failures := 0
var _results: Array[String] = []


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	_test_lookup()
	_test_frames()
	_test_atmosphere()
	_test_engine()
	_test_trim_hold()
	_test_alpha_limit()
	_test_stall()
	_test_ground_static()
	_test_takeoff()
	_test_long_run()
	print("")
	for line in _results:
		print(line)
	print("\n%d failure(s), %.1f s" % [_failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if _failures > 0 else 0)


func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	_results.append("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _model() -> F16Model:
	return F16Model.new(load("res://aircraft/params_f16.tres"))


# 1. Table lookup against known table points (TP-1538 Table III).
func _test_lookup() -> void:
	var t := F16Aero.tables()
	var cx: AeroTable = t.Cx
	_check("lookup: Cx grid point (a=-20,b=-30,dh=-25) = -.1837 (p.51)",
			_near(cx.eval3(-20, -30, -25), -0.1837, 1e-9))
	_check("lookup: Cx grid point (a=10,b=-30,dh=-25) = -.0079 (p.51)",
			_near(cx.eval3(10, -30, -25), -0.0079, 1e-9))
	var mid := 0.5 * (cx.eval3(0, 0, 0) + cx.eval3(5, 0, 0))
	_check("lookup: linear midpoint in alpha", _near(cx.eval3(2.5, 0, 0), mid, 1e-9))
	var corner := (cx.at(4, 9, 2) + cx.at(5, 9, 2) + cx.at(4, 10, 2) + cx.at(5, 10, 2)
			+ cx.at(4, 9, 3) + cx.at(5, 9, 3) + cx.at(4, 10, 3) + cx.at(5, 10, 3)) / 8.0
	_check("lookup: trilinear cell centre", _near(cx.eval3(2.5, 1.0, 5.0), corner, 1e-9))
	_check("lookup: clamps below grid", _near(cx.eval3(-40, -30, -25), cx.eval3(-20, -30, -25), 1e-12))
	_check("lookup: Cmq(25) = -6.00 (p.72)", _near(t.Cmq.eval1(25), -6.0, 1e-9))
	_check("lookup: Cl(a,0,dh) = 0 at beta=0 (p.90)", _near(t.Cl.eval3(30, 0, 0), 0.0, 1e-12))
	_check("lookup: thrust_max(M0.6, 9144 m) = 41300 N (Table VI)",
			_near(t.thrust_max.eval2(0.6, 9144), 41300.0, 1e-6))


# 4. Frame conversion round trip and handedness.
func _test_frames() -> void:
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1538
	for i in 1000:
		var v := Vector3(rng.randf_range(-100, 100), rng.randf_range(-100, 100), rng.randf_range(-100, 100))
		var w := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		ok = ok and Frames.from_body(Frames.to_body(v)).is_equal_approx(v)
		ok = ok and Frames.to_body(Frames.from_body(v)).is_equal_approx(v)
		ok = ok and Frames.to_body(v.cross(w)).is_equal_approx(Frames.to_body(v).cross(Frames.to_body(w)))
	_check("frames: round trip and cross product preserved (1000 random)", ok)
	_check("frames: Godot forward -Z -> body +X", Frames.to_body(Vector3.FORWARD).is_equal_approx(Vector3(1, 0, 0)))
	_check("frames: Godot up -> body -Z", Frames.to_body(Vector3.UP).is_equal_approx(Vector3(0, 0, -1)))
	_check("frames: Godot right -> body +Y", Frames.to_body(Vector3.RIGHT).is_equal_approx(Vector3(0, 1, 0)))
	var eul := Frames.euler_from_basis(Basis.from_euler(Vector3(deg_to_rad(10), deg_to_rad(-30), deg_to_rad(-20)), EULER_ORDER_YXZ))
	_check("frames: euler pitch/heading/roll", _near(rad_to_deg(eul.y), 10, 1e-3) and _near(rad_to_deg(eul.z), 30, 1e-3)
			and _near(rad_to_deg(eul.x), 20, 1e-3), "phi %.2f theta %.2f psi %.2f" % [rad_to_deg(eul.x), rad_to_deg(eul.y), rad_to_deg(eul.z)])
	var si := (load("res://aircraft/params_f16.tres") as AircraftParams).to_si()
	_check("frames: nose gear 3.325 m ahead, 1.854 m below CG",
			_near(-si.nose_gear.z, 3.325, 0.001) and _near(-si.nose_gear.y, 1.854, 0.001))
	_check("params: inertia SI matches TP Table I (Ixx 12875, Iyy 75674, Izz 85552, Ixz 1331)",
			_near(si.inertia.x.x, 12875, 1) and _near(si.inertia.y.y, 75674, 1)
			and _near(si.inertia.z.z, 85552, 1) and _near(-si.inertia.x.z, 1331, 1))


func _test_atmosphere() -> void:
	_check("ISA: sea level density 1.225", _near(Atmosphere.density(0), 1.225, 1e-3))
	_check("ISA: 11 km T = 216.65 K, p = 22632 Pa",
			_near(Atmosphere.temperature(11000), 216.65, 1e-6) and _near(Atmosphere.pressure(11000), 22632, 2))
	_check("ISA: sea level a = 340.29 m/s", _near(Atmosphere.speed_of_sound(0), 340.29, 0.01))


func _test_engine() -> void:
	var e := F16Engine.new()
	_check("engine: military (P=50) at M0.2 SL = 56401 N", _near(e.thrust_at(50, 0.2, 0), 56401, 1e-6))
	_check("engine: throttle detent 0.77 -> 50 %", _near(F16Engine.throttle_to_power(0.77), 50, 1e-9))
	e.settle(0.0, 0.4, 3048)
	var t := 0.0
	var t95 := -1.0
	while t < 20.0:
		e.step(0.77, 0.4, 3048, DT)
		t += DT
		if t95 < 0.0 and e.power >= 47.5:
			t95 = t
	_check("engine: idle->mil spool (Fig. 66 lag) reaches 95 % of command", t95 > 0.0, "t95 %.1f s" % t95)
	e.step(1.0, 0.4, 3048, DT)
	var t_ab := 0.0
	while e.power < 95.0 and t_ab < 10.0:
		e.step(1.0, 0.4, 3048, DT)
		t_ab += DT
	_check("engine: mil->max with 1/tau = 5 (fast AB light)", t_ab < 1.5, "%.2f s" % t_ab)


# 1. Trim and hold: TP-1538 tracking-task condition, M 0.6 at 9144 m (p.16).
func _test_trim_hold() -> void:
	var m := _model()
	var h := 9144.0
	var vt := 0.6 * Atmosphere.speed_of_sound(h)
	var trim := Trim.level(m, vt, h)
	_check("trim: M0.6 / 9144 m converges", trim.ok,
			"alpha %.2f deg, dh %.2f deg, throttle %.3f, residual %s" % [trim.alpha, trim.dh, trim.throttle, str(trim.residual)])
	var body := SimBody.new()
	body.set_trim(m, trim, Vector3(0, h, 0))
	var max_dh := 0.0
	var max_dv := 0.0
	var max_phi := 0.0
	for i in int(60.0 / DT):
		body.step(m, DT)
		max_dh = maxf(max_dh, absf(body.xform.origin.y - h))
		max_dv = maxf(max_dv, absf(m.vt - vt))
		max_phi = maxf(max_phi, absf(Frames.euler_from_basis(body.xform.basis).x))
	_check("trim: 60 s hands-off, FCS on, altitude within 15 m", max_dh < 15.0,
			"max |dh| %.2f m, max |dV| %.2f m/s, max |phi| %.3f deg" % [max_dh, max_dv, rad_to_deg(max_phi)])
	# Kick the pitch rate: the FCS must damp the unstable airframe back to trim alpha.
	var kick := SimBody.new()
	var mk := _model()
	kick.set_trim(mk, trim, Vector3(0, h, 0))
	kick.angular_velocity = kick.xform.basis * Frames.from_body(Vector3(0, deg_to_rad(5.0), 0))
	var peak := 0.0
	for i in int(6.0 / DT):
		kick.step(mk, DT)
		peak = maxf(peak, absf(mk.alpha - trim.alpha))
	_check("FCS: 5 deg/s pitch kick damped back to trim alpha within 6 s",
			absf(mk.alpha - trim.alpha) < 0.1 and absf(rad_to_deg(mk.q)) < 0.2,
			"peak |dalpha| %.2f deg, final |dalpha| %.3f deg, q %.3f deg/s" % [peak, absf(mk.alpha - trim.alpha), rad_to_deg(mk.q)])
	# Relaxed static stability: TP p.17 "static margin at low angles of attack
	# is approximately -4 percent" (low speed, CG 0.35, flaps not deflected).
	var cm := PackedFloat64Array()
	var cl := PackedFloat64Array()
	for a in [2.0, 6.0]:
		m.aero.compute(a, 0.0, 60.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
		cm.append(m.aero.cm)
		cl.append(m.aero.lift_coefficient(a))
	var sm := -(cm[1] - cm[0]) / (cl[1] - cl[0])
	_check("stability: static margin about -4 % (TP p.17)", _near(sm, -0.04, 0.01),
			"SM %.1f %% of MAC" % (sm * 100.0))


# 2a. Angle-of-attack limiter: about 25 deg in 1 g flight (TP-1538 p.40).
func _test_alpha_limit() -> void:
	var m := _model()
	var h := 9144.0
	var trim := Trim.level(m, 0.4 * Atmosphere.speed_of_sound(h), h)
	var body := SimBody.new()
	body.set_trim(m, trim, Vector3(0, h, 0))
	m.throttle = F16Engine.MIL_DETENT
	m.fcs.in_pitch = 1.0
	var alpha_sum := 0.0
	var n := 0
	var alpha_max := 0.0
	for i in int(20.0 / DT):
		body.step(m, DT)
		alpha_max = maxf(alpha_max, m.alpha)
		if body.time > 15.0:
			alpha_sum += m.alpha
			n += 1
	var alpha_ss := alpha_sum / n
	_check("FCS: full aft stick holds alpha at about 25 deg (TP p.40)", _near(alpha_ss, 25.0, 3.0),
			"steady alpha %.1f deg, peak %.1f deg" % [alpha_ss, alpha_max])


# 2b. Stall: CLmax near alpha 35 deg (TP-1538 p.17); 1 g stall speeds derived from it.
func _test_stall() -> void:
	var m := _model()
	var best_cl := -1.0
	var best_a := 0.0
	var cl25 := 0.0
	for i in 61:
		var a := float(i)
		var lef := clampf(1.38 * a + 1.45, 0.0, 25.0)
		m.aero.compute(a, 0.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lef, 0.0)
		var cl := m.aero.lift_coefficient(a)
		if cl > best_cl:
			best_cl = cl
			best_a = a
		if i == 25:
			cl25 = cl
	_check("stall: CLmax near alpha 35 deg (TP p.17)", _near(best_a, 35.0, 5.0),
			"CLmax %.3f at alpha %.0f deg" % [best_cl, best_a])
	var w := m.si.weight
	var vs := sqrt(2.0 * w / (Atmosphere.RHO0 * m.si.s * best_cl))
	var v25 := sqrt(2.0 * w / (Atmosphere.RHO0 * m.si.s * cl25))
	# TP-1538 gives no stall speed; report the 1 g speeds the data implies and
	# check that level trim exists just above the FCS alpha-limit speed.
	var above := Trim.level(m, 1.05 * v25, 0.0)
	_check("stall: level trim exists at 1.05 x V(alpha 25)", above.ok and above.alpha < 25.0,
			"Vs(CLmax) %.1f m/s (%.0f kt), V(alpha 25) %.1f m/s (%.0f kt), trim alpha %.1f" % [vs, vs * 1.9438, v25, v25 * 1.9438, above.alpha])


# 10. Parked: gear settles at the static compression and holds on the brakes at idle.
func _test_ground_static() -> void:
	var m := _model()
	m.reset_ground()
	var body := SimBody.new()
	body.xform.origin = Vector3(0, -m.si.nose_gear.y, 0)
	for i in int(10.0 / DT):
		body.step(m, DT)
	var p0 := body.xform.origin
	for i in int(30.0 / DT):
		body.step(m, DT)
	var drift := (body.xform.origin - p0).length()
	var nose := m.gear.wheels[0]
	var main := m.gear.wheels[1]
	var comp_ok := _near(nose.compression, nose.stroke * nose.static_frac, 0.03) \
			and _near(main.compression, main.stroke * main.static_frac, 0.03)
	_check("gear: static compression about 50 % of stroke", comp_ok,
			"nose %.3f of %.3f m, main %.3f of %.3f m" % [nose.compression, nose.stroke, main.compression, main.stroke])
	_check("gear: parked at idle on brakes drifts < 5 cm in 30 s", drift < 0.05, "drift %.4f m" % drift)
	var load_sum := 0.0
	for wh in m.gear.wheels:
		load_sum += wh.load
	_check("gear: wheel loads carry the weight", _near(load_sum / m.si.weight, 1.0, 0.03),
			"nose share %.3f" % (nose.load / load_sum))


# 3. Take-off roll at max power. TP-1538 gives no take-off speeds (GAPS §5),
# so the check is against the aero data: lift-off where lift ~ weight.
func _test_takeoff() -> void:
	var m := _model()
	m.reset_ground()
	var body := SimBody.new()
	body.xform.origin = Vector3(0, -m.si.nose_gear.y, 0)
	for i in int(3.0 / DT):
		body.step(m, DT)
	var start := body.xform.origin
	m.parking_brake = false
	m.throttle = 1.0
	var rotate_speed := 70.0     # m/s, PLACEHOLDER pilot technique (GAPS §5)
	var lof_v := -1.0
	var lof_d := 0.0
	var max_pitch := 0.0
	while body.time < 80.0 and lof_v < 0.0:
		m.fcs.in_pitch = 0.5 if m.vt >= rotate_speed else 0.0
		body.step(m, DT)
		max_pitch = maxf(max_pitch, rad_to_deg(Frames.euler_from_basis(body.xform.basis).y))
		if not m.gear.weight_on_wheels and m.vt > 30.0:
			lof_v = m.vt
			lof_d = (body.xform.origin - start).length()
	var alpha_lof := m.alpha
	_check("takeoff: lifts off at max power", lof_v > 0.0 and not m.crashed,
			"V_lof %.1f m/s (%.0f kt), ground roll %.0f m, alpha %.1f deg, max pitch %.1f deg" % [lof_v, lof_v * 1.9438, lof_d, alpha_lof, max_pitch])
	_check("takeoff: lift-off speed in 65-110 m/s, roll < 2000 m", lof_v > 65.0 and lof_v < 110.0 and lof_d < 2000.0)


# 5. Ten minutes of flight: no NaN, attitude basis stays orthonormal.
func _test_long_run() -> void:
	var m := _model()
	var h := 3048.0
	var trim := Trim.level(m, 150.0, h)
	var body := SimBody.new()
	body.set_trim(m, trim, Vector3(0, h, 0))
	var worst := 0.0
	var finite := true
	for i in int(600.0 / DT):
		# Roll in and pull for 8 s (exercises every axis), then a simple test
		# pilot levels the wings and holds a level flight path.
		var t := i * DT
		if t < 8.0:
			m.fcs.in_roll = 0.4 if t < 2.0 else 0.0
			m.fcs.in_pitch = 0.3 if t >= 2.0 else 0.0
		else:
			var eul := Frames.euler_from_basis(body.xform.basis)
			var gam := asin(clampf(body.velocity.y / body.velocity.length(), -1.0, 1.0))
			m.fcs.in_roll = clampf(-eul.x / deg_to_rad(40.0), -0.6, 0.6)
			m.fcs.in_pitch = clampf(-gam / deg_to_rad(20.0), -0.3, 0.3)
			m.throttle = clampf(trim.throttle + 0.05 * (150.0 - m.vt), 0.0, 1.0)
		body.step(m, DT)
		var bb := body.xform.basis
		worst = maxf(worst, (bb * bb.transposed()).x.distance_to(Vector3.RIGHT))
		finite = finite and is_finite(body.xform.origin.y) and is_finite(m.alpha)
	_check("long run: 10 min finite state", finite, "final alt %.0f m, V %.1f m/s" % [body.xform.origin.y, m.vt])
	_check("long run: basis orthonormal", worst < 1e-5, "max error %s" % str(worst))
