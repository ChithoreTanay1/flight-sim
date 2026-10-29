extends Control
## Head-up display drawn in a single _draw pass: speed and altitude boxes,
## heading tape, pitch ladder, vertical speed, G, AoA, throttle, configuration,
## warnings and a help overlay.

const COL := Color(0.45, 1.0, 0.55)
const WARN := Color(1.0, 0.3, 0.2)
const SHADOW := Color(0, 0, 0, 0.55)
const KT := 1.943844
const FT := 3.280840

@export var aircraft: Aircraft
@export var input: PilotInput

var _font: Font
var _help := true
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func setup(p_aircraft: Aircraft, p_input: PilotInput) -> void:
	aircraft = p_aircraft
	input = p_input
	input.help_toggled.connect(func(): _help = not _help)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _text(pos: Vector2, s: String, size := 18, col := COL, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font, pos + Vector2(1.5, 1.5), s, align, width, size, SHADOW)
	draw_string(_font, pos, s, align, width, size, col)


func _line(a: Vector2, b: Vector2, col := COL, w := 2.0) -> void:
	draw_line(a + Vector2(1.5, 1.5), b + Vector2(1.5, 1.5), SHADOW, w)
	draw_line(a, b, col, w)


func _box(r: Rect2, col := COL) -> void:
	draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size), SHADOW, false, 2.0)
	draw_rect(r, col, false, 2.0)


func _draw() -> void:
	if aircraft == null or aircraft.model == null:
		return
	var m := aircraft.model
	var xf := aircraft.get_global_transform_interpolated()
	var vel := aircraft.linear_velocity
	var eul := Frames.euler_from_basis(xf.basis.orthonormalized())
	var phi := eul.x
	var theta := eul.y
	var psi := eul.z
	var sz := size
	var c := sz * 0.5
	var px_per_deg := sz.y / 70.0

	# Pitch ladder and horizon, rolled about the screen centre.
	draw_set_transform(c, -phi, Vector2.ONE)
	var pitch_deg := rad_to_deg(theta)
	for k in range(-18, 19):
		var deg := k * 5
		var y := (pitch_deg - deg) * px_per_deg
		if absf(y) > sz.y * 0.32:
			continue
		var half := 220.0 if deg == 0 else 70.0
		if deg == 0:
			_line(Vector2(-half, y), Vector2(-40, y))
			_line(Vector2(40, y), Vector2(half, y))
		elif deg > 0:
			_line(Vector2(-half, y), Vector2(-30, y))
			_line(Vector2(30, y), Vector2(half, y))
			_text(Vector2(half + 6, y + 6), str(deg), 14)
		else:
			for s: float in [-1.0, 1.0]:
				for i in 3:
					var x0 := s * (30.0 + i * 14.0)
					_line(Vector2(x0, y), Vector2(x0 + s * 9.0, y))
			_text(Vector2(half + 6, y + 6), str(deg), 14)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Waterline
	_line(c + Vector2(-30, 0), c + Vector2(-10, 0))
	_line(c + Vector2(-10, 0), c + Vector2(0, 8))
	_line(c + Vector2(0, 8), c + Vector2(10, 0))
	_line(c + Vector2(10, 0), c + Vector2(30, 0))
	# Flight path marker: velocity vector relative to the nose.
	if vel.length() > 5.0:
		var vb := Frames.to_body(xf.basis.orthonormalized().transposed() * vel)
		var fpm_deg := Vector2(rad_to_deg(atan2(vb.y, vb.x)), rad_to_deg(atan2(vb.z, vb.x)))
		var fpm := c + fpm_deg.clamp(Vector2(-25, -25), Vector2(25, 25)) * px_per_deg
		draw_arc(fpm, 7.0, 0, TAU, 16, COL, 2.0)
		_line(fpm + Vector2(-18, 0), fpm + Vector2(-7, 0))
		_line(fpm + Vector2(7, 0), fpm + Vector2(18, 0))
		_line(fpm + Vector2(0, -7), fpm + Vector2(0, -15))

	# Airspeed (equivalent airspeed ~ indicated) and Mach.
	var eas := m.vt * sqrt(m.rho / Atmosphere.RHO0) * KT
	var left := Vector2(c.x - 330, c.y)
	_box(Rect2(left + Vector2(-50, -18), Vector2(100, 34)))
	_text(left + Vector2(-50, 8), "%d" % roundi(eas), 24, COL, HORIZONTAL_ALIGNMENT_CENTER, 100)
	_text(left + Vector2(-50, -26), "KIAS", 13, COL, HORIZONTAL_ALIGNMENT_CENTER, 100)
	_text(left + Vector2(-50, 40), "M %.2f" % m.mach, 15, COL, HORIZONTAL_ALIGNMENT_CENTER, 100)
	_text(left + Vector2(-50, 60), "G %.1f" % m.an_g, 16, WARN if m.an_g > 8.0 or m.an_g < -2.5 else COL, HORIZONTAL_ALIGNMENT_CENTER, 100)
	_text(left + Vector2(-50, 80), "max %.1f" % m.peak_g, 13, COL, HORIZONTAL_ALIGNMENT_CENTER, 100)
	_text(left + Vector2(-50, 102), "α %.1f°" % m.alpha, 16, WARN if m.alpha > 20.0 else COL, HORIZONTAL_ALIGNMENT_CENTER, 100)

	# Altitude and vertical speed.
	var right := Vector2(c.x + 330, c.y)
	_box(Rect2(right + Vector2(-55, -18), Vector2(110, 34)))
	_text(right + Vector2(-55, 8), "%d" % roundi(xf.origin.y * FT), 24, COL, HORIZONTAL_ALIGNMENT_CENTER, 110)
	_text(right + Vector2(-55, -26), "ALT FT", 13, COL, HORIZONTAL_ALIGNMENT_CENTER, 110)
	var vs := vel.y * FT * 60.0
	_text(right + Vector2(-55, 40), "VS %+d" % (roundi(vs / 10.0) * 10), 15, COL, HORIZONTAL_ALIGNMENT_CENTER, 110)
	var vs_y := clampf(-vs / 6000.0, -1.0, 1.0) * 90.0
	_line(right + Vector2(70, 0), right + Vector2(70, vs_y), COL, 4.0)
	_line(right + Vector2(64, 0), right + Vector2(76, 0))

	# Heading tape.
	var hdg := fposmod(rad_to_deg(psi), 360.0)
	var top := Vector2(c.x, 46)
	for k in range(-6, 7):
		var h := floorf(hdg / 10.0) * 10.0 + k * 10.0
		var x := (h - hdg) * 6.0
		if absf(x) > 180.0:
			continue
		_line(top + Vector2(x, 0), top + Vector2(x, 8))
		var lbl := int(fposmod(h, 360.0)) / 10
		_text(top + Vector2(x - 20, 28), "%02d" % lbl, 14, COL, HORIZONTAL_ALIGNMENT_CENTER, 40)
	_box(Rect2(top + Vector2(-28, -36), Vector2(56, 26)))
	_text(top + Vector2(-28, -16), "%03d" % (roundi(hdg) % 360), 18, COL, HORIZONTAL_ALIGNMENT_CENTER, 56)

	# Throttle and configuration (bottom left).
	var bl := Vector2(30, sz.y - 40)
	var thr_h := 140.0
	_box(Rect2(bl + Vector2(0, -thr_h), Vector2(18, thr_h)))
	draw_rect(Rect2(bl + Vector2(2, -thr_h * m.throttle), Vector2(14, thr_h * m.throttle)),
			Color(1.0, 0.6, 0.2) if m.throttle > F16Engine.MIL_DETENT + 0.001 else COL)
	var det_y := -thr_h * F16Engine.MIL_DETENT
	_line(bl + Vector2(-4, det_y), bl + Vector2(22, det_y), WARN)
	var ab := m.engine.power > 50.0
	_text(bl + Vector2(28, -thr_h + 14), "THR %d%%" % roundi(m.throttle * 100.0), 15)
	_text(bl + Vector2(28, -thr_h + 34), "RPM %d%%" % roundi(m.engine.power * 2.0 if not ab else 100.0), 15)
	if ab:
		_text(bl + Vector2(28, -thr_h + 54), "AB", 15, Color(1.0, 0.6, 0.2))
	var gear_txt := "GEAR DOWN" if m.gear_pos > 0.99 else ("GEAR UP" if m.gear_pos < 0.01 else "GEAR TRANSIT")
	var lines := [
		[gear_txt, WARN if m.gear_pos > 0.01 and m.gear_pos < 0.99 else COL],
		["FLAPS %s %d°" % ["AUTO" if m.flaps_auto else "UP", roundi(m.tef)], COL],
		["LEF %d°" % roundi(m.dlef), COL],
		["SPD BRK", COL] if m.dsb > 1.0 else ["", COL],
		["PARK BRK" if m.parking_brake else ("BRAKES" if m.brake > 0.1 else ""), COL],
		["FCS %s" % ("ON" if m.fcs.enabled else "OFF (DIRECT)"), COL if m.fcs.enabled else WARN],
		["TRIM %+.2f g" % m.fcs.pitch_trim_g if m.fcs.enabled else "TRIM %+.1f°" % m.fcs.pitch_trim_deg, COL],
	]
	for i in lines.size():
		_text(bl + Vector2(130, -thr_h + 14 + i * 20), lines[i][0], 15, lines[i][1])

	# Warnings
	var blink := fmod(_t, 0.6) < 0.35
	var airborne := not m.gear.weight_on_wheels
	if airborne and m.alpha > 22.0 and blink:
		_text(Vector2(0, c.y + 110), "STALL", 34, WARN, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	if m.overstress:
		_text(Vector2(0, c.y + 150), "OVER-G", 26, WARN, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	if airborne and m.gear_pos < 0.99 and xf.origin.y < 150.0 and vel.y < -1.0 and m.vt < 110.0 and blink:
		_text(Vector2(0, c.y + 190), "GEAR", 26, WARN, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	if m.crashed:
		_text(Vector2(0, c.y - 120), m.crash_reason, 40, WARN, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
		_text(Vector2(0, c.y - 84), "R  reset on runway     Y  air start", 18, COL, HORIZONTAL_ALIGNMENT_CENTER, sz.x)

	if _help:
		var hl := [
			"W / S      pitch (W nose down)", "A / D      roll", "Q / E      yaw, nose-wheel steering",
			"Shift/Ctrl throttle (stops at MIL, press again for AB)", "Space      brakes      P  parking brake",
			"B  speed brake   F  flaps   G  gear", "Up / Down  pitch trim", "V  FCS on/off    C  camera (RMB look, wheel zoom)",
			"R  reset on runway    Y  air start    H  hide help",
		]
		var hp := Vector2(sz.x - 470, sz.y - 30 - hl.size() * 19)
		draw_rect(Rect2(hp - Vector2(12, 22), Vector2(460, hl.size() * 19 + 16)), Color(0, 0, 0, 0.35))
		for i in hl.size():
			_text(hp + Vector2(0, i * 19), hl[i], 14, Color(0.9, 0.95, 0.9))
