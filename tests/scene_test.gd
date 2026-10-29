extends SceneTree
## Runs the real Aircraft RigidBody3D (Jolt, _integrate_forces) headless.
##   godot --headless --path . --fixed-fps 120 --script res://tests/scene_test.gd

var _failures := 0
var _ac: Aircraft
var _frame := 0
var _phase := 0
var _log: Array[String] = []
var _h0 := 0.0
var _max_dh := 0.0
var _worst_ortho := 0.0
var _p_parked := Vector3.ZERO
var _lof_v := -1.0


func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 2, 40000)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	ground.add_child(shape)
	root3d.add_child(ground)
	_ac = load("res://aircraft/aircraft.tscn").instantiate()
	_ac.spawn_point = Vector3(0, 0, 15000)
	root3d.add_child(_ac)
	physics_frame.connect(_on_physics)


func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	_log.append("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func _on_physics() -> void:
	_frame += 1
	var m := _ac.model
	match _phase:
		0:  # parked 20 s
			if _frame == 600:
				_p_parked = _ac.global_position
			if _frame == 2400:
				var drift := (_ac.global_position - _p_parked).length()
				_check("scene: parked on brakes, no crash, drift < 5 cm", not m.crashed and drift < 0.05,
						"drift %.4f m, CG height %.3f m, wow %s" % [drift, _ac.global_position.y, str(m.gear.weight_on_wheels)])
				m.parking_brake = false
				m.throttle = 1.0
				_phase = 1
				_frame = 0
		1:  # take-off run
			m.fcs.in_pitch = 0.5 if m.vt > 70.0 else 0.0
			if _lof_v < 0.0 and not m.gear.weight_on_wheels and m.vt > 30.0:
				_lof_v = m.vt
			if _lof_v > 0.0 and _ac.global_position.y > 60.0 or _frame > 120 * 60 or m.crashed:
				_check("scene: take-off with the RigidBody", _lof_v > 0.0 and not m.crashed,
						"V_lof %.1f m/s, crashed '%s'" % [_lof_v, m.crash_reason])
				_ac.air_start(3000.0, 180.0)
				_phase = 2
				_frame = 0
		2:  # air start then 10 min hands-off
			if _frame == 3:
				_h0 = _ac.global_position.y
			elif _frame > 3:
				_max_dh = maxf(_max_dh, absf(_ac.global_position.y - _h0)) if _frame < 3 + 120 * 60 else _max_dh
				var b := _ac.global_transform.basis
				_worst_ortho = maxf(_worst_ortho, (b * b.transposed()).x.distance_to(Vector3.RIGHT))
			if _frame >= 120 * 600:
				_check("scene: air start, 60 s hands-off within 15 m", _max_dh < 15.0, "max |dh| %.2f m" % _max_dh)
				_check("scene: 10 min, basis orthonormal and no crash", _worst_ortho < 1e-4 and not m.crashed,
						"max error %s, alt %.0f m, V %.1f" % [str(_worst_ortho), _ac.global_position.y, m.vt])
				for line in _log:
					print(line)
				print("%d failure(s)" % _failures)
				quit(1 if _failures > 0 else 0)
