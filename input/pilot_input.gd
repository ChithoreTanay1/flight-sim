class_name PilotInput
extends Node
## Registers the control scheme in the InputMap at runtime and feeds smoothed
## pilot commands into the aircraft model every physics tick.
##
## Keyboard (WASD): W/S pitch (W = nose down), A/D roll, Q/E yaw + nose-wheel
## steering, Shift/Ctrl throttle (stops at the MIL detent; press again for
## afterburner), Space brakes, P parking brake, B speed brake, F flaps, G gear,
## Up/Down arrows pitch trim, V FCS on/off, C camera, R runway reset, Y air
## start, H help. Gamepad: left stick pitch/roll, bumpers yaw, triggers throttle.

signal camera_cycled
signal help_toggled

const RISE := 3.0       # keyboard axis ramp toward full deflection, 1/s
const FALL := 5.0       # ramp back toward centre, 1/s
const THROTTLE_RATE := 0.45
const DEADZONE := 0.12

@export var aircraft: Aircraft

var pitch := 0.0
var roll := 0.0
var yaw := 0.0
var _detent_hold := false


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


static func _axis(a: JoyAxis, dir: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = dir
	return e


static func register_actions() -> void:
	var map := {
		"pitch_down": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"pitch_up": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"roll_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"roll_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"yaw_left": [_key(KEY_Q), _btn(JOY_BUTTON_LEFT_SHOULDER)],
		"yaw_right": [_key(KEY_E), _btn(JOY_BUTTON_RIGHT_SHOULDER)],
		"throttle_up": [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"throttle_down": [_key(KEY_CTRL), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"brakes": [_key(KEY_SPACE), _btn(JOY_BUTTON_A)],
		"parking_brake": [_key(KEY_P)],
		"speed_brake": [_key(KEY_B), _btn(JOY_BUTTON_X)],
		"flaps": [_key(KEY_F), _btn(JOY_BUTTON_DPAD_LEFT)],
		"gear": [_key(KEY_G), _btn(JOY_BUTTON_DPAD_RIGHT)],
		"trim_nose_down": [_key(KEY_UP), _btn(JOY_BUTTON_DPAD_UP)],
		"trim_nose_up": [_key(KEY_DOWN), _btn(JOY_BUTTON_DPAD_DOWN)],
		"camera": [_key(KEY_C), _btn(JOY_BUTTON_Y)],
		"reset": [_key(KEY_R), _btn(JOY_BUTTON_BACK)],
		"air_start": [_key(KEY_Y)],
		"fcs_toggle": [_key(KEY_V)],
		"help": [_key(KEY_H), _btn(JOY_BUTTON_START)],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for ev in map[action]:
			InputMap.action_add_event(action, ev)


func _ready() -> void:
	register_actions()
	process_physics_priority = -10   # before the aircraft integrates


## Keyboard gives 0/1, gamepad gives analog strength. Analog input is used
## directly (light smoothing); digital input ramps at RISE/FALL.
func _smooth(current: float, neg: String, pos: String, dt: float) -> float:
	var target := Input.get_action_strength(pos) - Input.get_action_strength(neg)
	var analog := absf(target) > 0.001 and absf(target) < 0.999
	if analog:
		return lerpf(current, target, 1.0 - exp(-20.0 * dt))
	var rate := RISE if absf(target) > absf(current) and signf(target) != -signf(current) else FALL
	return move_toward(current, target, rate * dt)


func _physics_process(dt: float) -> void:
	if aircraft == null or aircraft.model == null:
		return
	var m := aircraft.model
	pitch = _smooth(pitch, "pitch_down", "pitch_up", dt)
	roll = _smooth(roll, "roll_left", "roll_right", dt)
	yaw = _smooth(yaw, "yaw_left", "yaw_right", dt)
	m.fcs.in_pitch = pitch
	m.fcs.in_roll = roll
	m.fcs.in_yaw = yaw

	# Throttle stops at the MIL detent; a fresh press from the detent lights the burner.
	var mil := F16Engine.MIL_DETENT
	if Input.is_action_just_pressed("throttle_up"):
		_detent_hold = m.throttle < mil - 0.001
	var dthr := (Input.get_action_strength("throttle_up") - Input.get_action_strength("throttle_down")) * THROTTLE_RATE * dt
	var t := clampf(m.throttle + dthr, 0.0, 1.0)
	if m.throttle <= mil and t > mil and _detent_hold:
		t = mil
	m.throttle = t

	m.brake = Input.get_action_strength("brakes")
	var trim := Input.get_action_strength("trim_nose_up") - Input.get_action_strength("trim_nose_down")
	if m.fcs.enabled:
		m.fcs.pitch_trim_g = clampf(m.fcs.pitch_trim_g + trim * 0.4 * dt, -2.4, 2.4)
	else:
		m.fcs.pitch_trim_deg = clampf(m.fcs.pitch_trim_deg - trim * 3.0 * dt, -25.0, 25.0)


func _unhandled_input(event: InputEvent) -> void:
	if aircraft == null or aircraft.model == null or event.is_echo():
		return
	var m := aircraft.model
	if event.is_action_pressed("gear"):
		m.gear_down = not m.gear_down
	elif event.is_action_pressed("flaps"):
		m.flaps_auto = not m.flaps_auto
	elif event.is_action_pressed("speed_brake"):
		m.speed_brake = not m.speed_brake
	elif event.is_action_pressed("parking_brake"):
		m.parking_brake = not m.parking_brake
	elif event.is_action_pressed("fcs_toggle"):
		m.fcs.enabled = not m.fcs.enabled
		m.fcs.pitch_trim_deg = m.dh
	elif event.is_action_pressed("reset"):
		_clear()
		aircraft.reset_to_runway()
	elif event.is_action_pressed("air_start"):
		_clear()
		aircraft.air_start()
	elif event.is_action_pressed("camera"):
		camera_cycled.emit()
	elif event.is_action_pressed("help"):
		help_toggled.emit()


func _clear() -> void:
	pitch = 0.0
	roll = 0.0
	yaw = 0.0
	_detent_hold = false
