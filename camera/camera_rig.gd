extends Camera3D
## Chase, cockpit and orbit cameras following the aircraft's interpolated
## transform (physics runs at 120 Hz, rendering at any rate).
## Mouse drag (right button) looks around in cockpit and orbit; wheel zooms orbit.

enum Mode { CHASE, COCKPIT, ORBIT }

@export var aircraft: Aircraft
@export var input: PilotInput

var mode := Mode.CHASE
var _chase_pos := Vector3.ZERO
var _chase_up := Vector3.UP
var _yaw := 0.0
var _pitch := -0.15
var _dist := 25.0
var _look := Vector2.ZERO
var _first := true


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = 0.1
	far = 40000.0
	fov = 70.0


func setup(p_aircraft: Aircraft, p_input: PilotInput) -> void:
	aircraft = p_aircraft
	input = p_input
	input.camera_cycled.connect(_cycle)
	aircraft.reset_done.connect(func(): _first = true)


func _cycle() -> void:
	mode = ((mode + 1) % 3) as Mode
	_look = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var d: Vector2 = event.relative * 0.005
		if mode == Mode.ORBIT:
			_yaw -= d.x
			_pitch = clampf(_pitch - d.y, -1.45, 1.45)
		elif mode == Mode.COCKPIT:
			_look.x = clampf(_look.x - d.x, -2.6, 2.6)
			_look.y = clampf(_look.y - d.y, -1.0, 1.3)
	elif event is InputEventMouseButton and event.pressed and mode == Mode.ORBIT:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(10.0, _dist * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(300.0, _dist * 1.1)


func _process(delta: float) -> void:
	if aircraft == null or aircraft.model == null:
		return
	var xf := aircraft.get_global_transform_interpolated()
	var b := xf.basis.orthonormalized()
	match mode:
		Mode.CHASE:
			# Trail behind the flight path, lagging slightly in roll for a sense of motion.
			var fwd := -b.z
			var target := xf.origin - fwd * 22.0 + b.y * 5.0
			var k := 1.0 - exp(-8.0 * delta)
			if _first:
				_chase_pos = target
				_chase_up = b.y
				_first = false
			_chase_pos = _chase_pos.lerp(target, k)
			_chase_up = _chase_up.lerp(b.y, 1.0 - exp(-3.0 * delta)).normalized()
			global_transform = Transform3D(Basis.looking_at(xf.origin + fwd * 30.0 - _chase_pos, _chase_up), _chase_pos)
			fov = lerpf(fov, 70.0 + clampf((aircraft.model.vt - 100.0) * 0.04, 0.0, 12.0), k)
		Mode.COCKPIT:
			var eye := xf * aircraft.model.si.pilot_eye
			var look := Basis(Vector3.UP, _look.x) * Basis(Vector3.RIGHT, _look.y)
			global_transform = Transform3D(b * look, eye)
			fov = 75.0
		Mode.ORBIT:
			var dir := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Vector3.BACK
			var pos := xf.origin + dir * _dist
			pos.y = maxf(pos.y, 0.5)
			global_transform = Transform3D(Basis.looking_at(xf.origin - pos, Vector3.UP), pos)
			fov = 60.0
