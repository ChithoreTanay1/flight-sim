class_name LandingGear
extends RefCounted
## Three-wheel landing gear: spring-damper struts along the body vertical,
## tyre friction with a bristle (spring) model so static friction holds the
## aircraft still, nose-wheel steering and main-wheel brakes.
## Ground is queried through a probe Callable(from: Vector3, to: Vector3) ->
## Dictionary {position, normal} (empty when nothing is hit), so this class
## has no scene dependencies.

const RAY_MARGIN := 0.5      # m of ray above the fully compressed position
const BOTTOM_STIFFNESS := 20.0  # x spring rate once the stroke is used up

class Wheel:
	extends RefCounted
	var name := ""
	var static_point := Vector3.ZERO   # Godot local, static contact point
	var stroke := 0.25
	var static_frac := 0.5
	var k := 1.0e5
	var c := 1.0e4
	var radius := 0.25
	var steerable := false
	var braked := false
	# State
	var compression := 0.0
	var compression_rate := 0.0
	var in_contact := false
	var load := 0.0
	var s_lon := 0.0
	var s_lat := 0.0
	var wheel_speed := 0.0             # rolling speed, m/s (visual)

	## Fully compressed wheel bottom in local coordinates.
	func top_point() -> Vector3:
		return static_point + Vector3.UP * stroke * (1.0 - static_frac)


var wheels: Array[Wheel] = []
var force := Vector3.ZERO          # world, N (sum)
var torque := Vector3.ZERO         # world, N·m about CG (sum)
var weight_on_wheels := false
var touchdown_sink_rate := 0.0     # largest sink rate at first contact this step, m/s

var _mu_roll := 0.02
var _mu_brake := 0.5
var _mu_lat := 0.8
var _kt := 2.0e5
var _zt := 0.7


func _init(si: AircraftParams.SI, params: AircraftParams) -> void:
	_mu_roll = params.mu_rolling
	_mu_brake = params.mu_brake
	_mu_lat = params.mu_lateral
	_kt = params.tyre_stiffness_npm
	_zt = params.tyre_damping_ratio
	var nose := Wheel.new()
	nose.name = "nose"
	nose.static_point = si.nose_gear
	nose.stroke = si.nose_stroke
	nose.k = si.nose_k
	nose.c = si.nose_c
	nose.radius = si.nose_wheel_r
	nose.steerable = true
	wheels.append(nose)
	for side in [si.main_gear_l, si.main_gear_r]:
		var w := Wheel.new()
		w.name = "main_l" if side == si.main_gear_l else "main_r"
		w.static_point = side
		w.stroke = si.main_stroke
		w.k = si.main_k
		w.c = si.main_c
		w.radius = si.main_wheel_r
		w.braked = true
		wheels.append(w)
	for w in wheels:
		w.static_frac = params.static_compression_frac


## xform: body transform (origin = CG); v_cg, w_world: world velocities.
## extended: 0..1 gear position (wheels only work when fully down).
func compute(xform: Transform3D, v_cg: Vector3, w_world: Vector3, probe: Callable,
		brake: float, steer: float, extended: float, dt: float) -> void:
	force = Vector3.ZERO
	torque = Vector3.ZERO
	weight_on_wheels = false
	touchdown_sink_rate = 0.0
	var up := xform.basis.y.normalized()
	for w in wheels:
		var was_in_contact := w.in_contact
		w.in_contact = false
		w.load = 0.0
		if extended < 1.0:
			w.compression = 0.0
			w.compression_rate = 0.0
			w.s_lon = 0.0
			w.s_lat = 0.0
			continue
		var top := xform * w.top_point()
		var ray_len := RAY_MARGIN + w.stroke
		var from := top + up * RAY_MARGIN
		var hit: Dictionary = probe.call(from, from - up * ray_len)
		if hit.is_empty():
			w.compression = 0.0
			w.compression_rate = 0.0
			w.s_lon = 0.0
			w.s_lat = 0.0
			continue
		var contact: Vector3 = hit.position
		var n: Vector3 = hit.normal
		var c := ray_len - from.distance_to(contact)
		var c_rate := (c - w.compression) / dt if was_in_contact else 0.0
		var r := contact - xform.origin
		var v_c := v_cg + w_world.cross(r)
		if not was_in_contact:
			touchdown_sink_rate = maxf(touchdown_sink_rate, -v_c.dot(n))
			c_rate = maxf(0.0, -v_c.dot(n))
		w.compression = c
		w.compression_rate = c_rate
		var spring := w.k * minf(c, w.stroke) + w.k * BOTTOM_STIFFNESS * maxf(0.0, c - w.stroke)
		var normal_force := maxf(0.0, spring + w.c * c_rate)
		if normal_force <= 0.0:
			continue
		w.in_contact = true
		w.load = normal_force
		weight_on_wheels = true

		# Wheel heading in the ground plane.
		var fwd := -xform.basis.z
		if w.steerable:
			fwd = fwd.rotated(up, -steer)
		var roll_dir := (fwd - n * fwd.dot(n)).normalized()
		var lat_dir := n.cross(roll_dir)
		var v_lon := v_c.dot(roll_dir)
		var v_lat := v_c.dot(lat_dir)
		w.wheel_speed = v_lon
		var m_eff := normal_force / Atmosphere.G0
		var ct := 2.0 * _zt * sqrt(_kt * m_eff)

		var f_lon: float
		if w.braked and brake > 0.0:
			f_lon = _bristle(w, true, v_lon, _mu_brake * brake * normal_force, ct, dt)
		else:
			w.s_lon = 0.0
			f_lon = -_mu_roll * normal_force * clampf(v_lon / 0.5, -1.0, 1.0)
		var f_lat := _bristle(w, false, v_lat, _mu_lat * normal_force, ct, dt)

		var f := n * normal_force + roll_dir * f_lon + lat_dir * f_lat
		force += f
		torque += r.cross(f)


func _bristle(w: Wheel, lon: bool, v: float, limit: float, ct: float, dt: float) -> float:
	var s := (w.s_lon if lon else w.s_lat) + v * dt
	var f := -_kt * s - ct * v
	if absf(f) > limit:
		f = signf(f) * limit
		s = -(f + ct * v) / _kt
	if lon:
		w.s_lon = s
	else:
		w.s_lat = s
	return f


## Ground probe for a flat plane y = 0 (used by headless tests).
static func flat_ground_probe(from: Vector3, to: Vector3) -> Dictionary:
	if from.y <= 0.0:
		return {"position": from, "normal": Vector3.UP}
	if to.y > 0.0:
		return {}
	var t := from.y / (from.y - to.y)
	return {"position": from.lerp(to, t), "normal": Vector3.UP}
