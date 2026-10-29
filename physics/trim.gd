class_name Trim
extends RefCounted
## Steady, wings-level, unaccelerated flight: solve alpha, stabilator and
## throttle so that the body accelerations and pitching moment vanish.
## Newton iteration with a finite-difference Jacobian.


static func level(model: F16Model, vt: float, altitude: float, gamma_deg := 0.0) -> Dictionary:
	var x := Vector3(4.0, -2.0, 0.4)   # alpha deg, dh deg, throttle
	var ok := false
	var res := Vector3.ZERO
	for it in 60:
		res = _residual(model, x, vt, altitude, gamma_deg)
		if res.length() < 1e-7:
			ok = true
			break
		var jac := Basis()
		var steps := Vector3(0.01, 0.01, 0.001)
		for i in 3:
			var dx := Vector3.ZERO
			dx[i] = steps[i]
			var col := (_residual(model, x + dx, vt, altitude, gamma_deg) - res) / steps[i]
			jac[i] = col
		if absf(jac.determinant()) < 1e-12:
			break
		var delta := jac.inverse() * res
		# Damped step keeps the iteration inside the table range.
		var scale := minf(1.0, 3.0 / maxf(absf(delta.x), 1e-9))
		x -= delta * scale
		x.x = clampf(x.x, -10.0, 45.0)
		x.y = clampf(x.y, -model.params.dh_limit_deg, model.params.dh_limit_deg)
		x.z = clampf(x.z, 0.0, 1.0)
	var rho := Atmosphere.density(altitude)
	var mach := vt / Atmosphere.speed_of_sound(altitude)
	return {
		"ok": ok, "alpha": x.x, "dh": x.y, "throttle": x.z, "vt": vt, "altitude": altitude,
		"gamma": gamma_deg, "residual": res.length(), "mach": mach,
		"qbar": 0.5 * rho * vt * vt,
	}


## Scaled residual (ax/g, az/g, Cm) for unknowns (alpha, dh, throttle).
static func _residual(model: F16Model, x: Vector3, vt: float, altitude: float, gamma_deg: float) -> Vector3:
	var si := model.si
	var alpha_deg := x.x
	var rho := Atmosphere.density(altitude)
	var ps := Atmosphere.pressure(altitude)
	var mach := vt / Atmosphere.speed_of_sound(altitude)
	var qbar := 0.5 * rho * vt * vt
	var lef := clampf(1.38 * alpha_deg - 9.05 * qbar / ps + 1.45, 0.0, model.params.lef_max_deg)
	model.aero.compute(alpha_deg, 0.0, vt, 0.0, 0.0, 0.0, x.y, 0.0, 0.0, lef, 0.0)
	var thrust := model.engine.thrust_at(F16Engine.throttle_to_power(x.z), mach, altitude)
	var theta := deg_to_rad(alpha_deg + gamma_deg)
	var g := Atmosphere.G0
	var ax := (qbar * si.s * model.aero.cx + thrust) / si.mass - g * sin(theta)
	var az := qbar * si.s * model.aero.cz / si.mass + g * cos(theta)
	return Vector3(ax / g, az / g, model.aero.cm)


## Body pose and velocity for a trim result, heading north (-Z) at the given position.
static func initial_state(trim: Dictionary, position: Vector3) -> Dictionary:
	var theta := deg_to_rad(trim.alpha + trim.gamma)
	var basis := Basis(Vector3.RIGHT, theta)
	var gamma := deg_to_rad(trim.gamma)
	var vel := Vector3(0.0, sin(gamma), -cos(gamma)) * float(trim.vt)
	return {"transform": Transform3D(basis, position), "velocity": vel}
