extends Node3D
## Low-poly, flat-shaded F-16 built from the README dimensions (inches ->
## metres via AircraftParams/Frames). Control surfaces, gear and afterburner
## are driven from the same F16Model values the physics uses.

const TAN40 := 0.8390996
const WING_Z := 0.15          # wing plane, metres below the CG (body z)
const LEF_CHORD := 0.415      # README LEF area 36.71 ft² over the span
const FLAP_CHORD := 0.68      # README flaperon area 31.32 ft² over 0.8-3.1 m
const FLAP_SPAN_END := 3.1

@onready var _ac: Aircraft = get_parent()

var _mat := {}
var _lef := []     # [left, right] pivots
var _flap := []
var _stab := []
var _rudder: Node3D
var _speed_brakes := []
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _ab_light: OmniLight3D
var _gear := []    # per wheel: {pivot, strut, wheel, spin, wheel_ref}
var _wing_root_le := 0.0
var _semi := 0.0
var _beacon: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	set_process(false)
	if _ac.model == null:
		await _ac.ready
	var si := _ac.model.si
	var p := _ac.params
	_semi = 0.5 * si.b
	# Planform: LE sweep 40°, straight trailing edge, wingtip chord at README wingtip X.
	var area := si.s
	var root_chord := 2.0 * area / (si.b * (1.0 + p.wing_taper))
	var tip_chord := root_chord * p.wing_taper
	var tip_mid := (p.wingtip_in.x - p.cg_x_in) * 0.0254
	var tip_le := tip_mid + 0.5 * tip_chord
	_wing_root_le = tip_le + _semi * TAN40
	_make_materials()
	_build_static(root_chord)
	_build_wing_surfaces()
	_build_tail(si, p)
	_build_engine()
	_build_gear(si)
	_build_lights()
	set_process(true)


func _b(x: float, y: float, z: float) -> Vector3:
	return Frames.from_body(Vector3(x, y, z))


func _x_le(y: float) -> float:
	return _wing_root_le - absf(y) * TAN40


# ---------------------------------------------------------------- mesh helpers
class Builder:
	extends RefCounted
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Triangle facing away from ref (Godot front faces are clockwise).
	func tri(a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		if n.dot((a + b + c) / 3.0 - ref) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		n = n.normalized()
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ref: Vector3) -> void:
		tri(a, b, c, ref)
		tri(a, c, d, ref)

	## Convex planar polygon extruded along normal n to the given thickness.
	func slab(pts: Array, n: Vector3, thickness: float, origin := Vector3.ZERO) -> void:
		var top := []
		var bot := []
		var centre := Vector3.ZERO
		for v in pts:
			top.append(v + n * thickness * 0.5 - origin)
			bot.append(v - n * thickness * 0.5 - origin)
			centre += v - origin
		centre /= pts.size()
		for i in range(1, pts.size() - 1):
			tri(top[0], top[i], top[i + 1], centre)
			tri(bot[0], bot[i], bot[i + 1], centre)
		for i in pts.size():
			var j := (i + 1) % pts.size()
			quad(top[i], top[j], bot[j], bot[i], centre)

	func mesh(material: Material) -> ArrayMesh:
		var m := st.commit()
		m.surface_set_material(0, material)
		return m


func _make_materials() -> void:
	_mat.body = _std(Color("9aa4ae"), 0.65, 0.15)
	_mat.dark = _std(Color("737c87"), 0.7, 0.15)
	_mat.radome = _std(Color("5f6670"), 0.6, 0.1)
	_mat.metal = _std(Color("3b3f45"), 0.4, 0.7)
	_mat.tyre = _std(Color("1c1d20"), 0.9, 0.0)
	_mat.strut = _std(Color("d8dadc"), 0.4, 0.6)
	var canopy := _std(Color("3a2a12"), 0.08, 0.6)
	canopy.emission_enabled = true
	canopy.emission = Color("ffb35c")
	canopy.emission_energy_multiplier = 0.15
	_mat.canopy = canopy
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_mat.albedo_color = Color(1.0, 0.55, 0.25, 0.85)
	_flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _std(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _add_mesh(parent: Node, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	return n


# ------------------------------------------------------------------ airframe
func _build_static(root_chord: float) -> void:
	var b := Builder.new()
	# Fuselage loft: [x fwd, half-width, half-height, centre z(down)] in metres.
	var stations := [
		[8.22, 0.03, 0.03, 0.33], [7.6, 0.24, 0.26, 0.26], [6.6, 0.40, 0.42, 0.18],
		[5.2, 0.52, 0.55, 0.12], [3.9, 0.60, 0.72, 0.30], [2.4, 0.78, 0.80, 0.26],
		[0.4, 0.86, 0.80, 0.22], [-2.2, 0.82, 0.76, 0.16], [-4.0, 0.68, 0.66, 0.06],
		[-5.11, 0.56, 0.56, 0.02],
	]
	var sides := 10
	var rings := []
	for s in stations:
		var ring := []
		for k in sides:
			var th := TAU * k / sides
			ring.append(_b(s[0], s[1] * sin(th), s[3] - s[2] * cos(th)))
		rings.append(ring)
	for i in stations.size() - 1:
		var ref := _b(0.5 * (stations[i][0] + stations[i + 1][0]), 0.0, 0.5 * (stations[i][3] + stations[i + 1][3]))
		for k in sides:
			var k2 := (k + 1) % sides
			b.quad(rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k], ref)
	var tail_ref := _b(-4.5, 0.0, 0.02)
	var tail_c := _b(-5.11, 0.0, 0.02)
	for k in sides:
		b.tri(rings[-1][k], rings[-1][(k + 1) % sides], tail_c, tail_ref)
	# Intake (README air intake X 350.7, Z -41): a box under the forward fuselage.
	var ix := 3.8
	b.slab([_b(ix, -0.48, 1.04), _b(ix, 0.48, 1.04), _b(ix - 2.6, 0.48, 0.95), _b(ix - 2.6, -0.48, 0.95)],
			_b(0, 0, 1), 0.38)
	# Strakes (leading-edge extensions) blending into the wing root.
	for sgn: float in [-1.0, 1.0]:
		b.slab([_b(5.3, 0.30 * sgn, WING_Z), _b(_wing_root_le, 0.95 * sgn, WING_Z), _b(_wing_root_le - 0.6, 0.6 * sgn, WING_Z)],
				_b(0, 0, 1), 0.06)
	# Fixed wing panels between the LEF and the flaperon / trailing edge.
	var te := _wing_root_le - root_chord
	for sgn: float in [-1.0, 1.0]:
		var y0 := 0.8 * sgn
		var y1 := FLAP_SPAN_END * sgn
		var y2 := _semi * sgn
		var flap_le := te + FLAP_CHORD
		b.slab([_b(_x_le(y0) - LEF_CHORD, y0, WING_Z), _b(_x_le(y1) - LEF_CHORD, y1, WING_Z),
				_b(flap_le, y1, WING_Z), _b(flap_le, y0, WING_Z)], _b(0, 0, 1), 0.14)
		b.slab([_b(_x_le(y1) - LEF_CHORD, y1, WING_Z), _b(_x_le(y2) - LEF_CHORD, y2, WING_Z),
				_b(te, y2, WING_Z), _b(te, y1, WING_Z)], _b(0, 0, 1), 0.10)
		# Wingtip launcher rail out to the README wingtip (Y 197 in).
		var yt := 5.004 * sgn
		b.slab([_b(0.2, _semi * sgn, WING_Z), _b(0.2, yt, WING_Z), _b(-2.6, yt, WING_Z), _b(-2.6, _semi * sgn, WING_Z)],
				_b(0, 0, 1), 0.12)
	_add_mesh(self, b.mesh(_mat.body))
	# Radome
	var r := Builder.new()
	var cone := []
	for k in sides:
		var th := TAU * k / sides
		cone.append(_b(7.6, 0.24 * sin(th), 0.26 - 0.26 * cos(th)))
	var tip := _b(8.22, 0.0, 0.33)
	for k in sides:
		r.tri(cone[k], cone[(k + 1) % sides], tip, _b(7.0, 0, 0.26))
	_add_mesh(self, r.mesh(_mat.radome))
	# Canopy bubble around the README pilot eyepoint.
	var eye := _ac.model.si.pilot_eye
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 1.0
	canopy.radial_segments = 12
	canopy.rings = 6
	canopy.material = _mat.canopy
	var cmi := _add_mesh(self, canopy, eye + Vector3(0, -0.28, 0.35))
	cmi.scale = Vector3(1.05, 0.95, 3.3)


func _build_wing_surfaces() -> void:
	var te := _wing_root_le - 2.0 * _ac.model.si.s / (_ac.model.si.b * (1.0 + _ac.params.wing_taper))
	for sgn: float in [-1.0, 1.0]:
		var y0 := 0.8 * sgn
		var y2 := _semi * sgn
		# LEF, hinged at its aft edge.
		var h0 := _b(_x_le(y0) - LEF_CHORD, y0, WING_Z)
		var h1 := _b(_x_le(y2) - LEF_CHORD, y2, WING_Z)
		var lb := Builder.new()
		lb.slab([_b(_x_le(y0), y0, WING_Z), _b(_x_le(y2), y2, WING_Z), h1, h0], _b(0, 0, 1), 0.08, h0)
		var lp := _pivot(h0)
		_add_mesh(lp, lb.mesh(_mat.body))
		lp.set_meta("axis", ((h1 - h0) * sgn).normalized())
		_lef.append(lp)
		# Flaperon, hinged at its leading edge.
		var y1 := FLAP_SPAN_END * sgn
		var f0 := _b(te + FLAP_CHORD, y0, WING_Z)
		var fb := Builder.new()
		fb.slab([f0, _b(te + FLAP_CHORD, y1, WING_Z), _b(te, y1, WING_Z), _b(te, y0, WING_Z)], _b(0, 0, 1), 0.07, f0)
		var fp := _pivot(f0)
		_add_mesh(fp, fb.mesh(_mat.dark))
		_flap.append(fp)


func _build_tail(si: AircraftParams.SI, p: AircraftParams) -> void:
	const FT2 := 0.09290304
	# Horizontal stabilators: README area, semi-span, taper, 40° sweep, -10° dihedral.
	var ht_area := 0.5 * p.htail_area_ft2 * FT2
	var ht_span := p.htail_semispan_ft * 0.3048
	var ht_root := 2.0 * ht_area / (ht_span * (1.0 + p.htail_taper))
	var ht_tip := ht_root * p.htail_taper
	var dih := deg_to_rad(p.htail_dihedral_deg)
	var ht_root_le := -3.3
	var pivot_x := ht_root_le - 0.42 * ht_root
	for sgn: float in [-1.0, 1.0]:
		var y0 := 0.72 * sgn
		var tip_y := y0 + ht_span * cos(dih) * sgn
		var tip_z := 0.12 - ht_span * sin(dih)
		var ht_tip_le := ht_root_le - ht_span * tan(deg_to_rad(p.htail_sweep_le_deg))
		var piv := _b(pivot_x, y0, 0.12)
		var hb := Builder.new()
		var n := _b(0, -sin(dih) * sgn, cos(dih))
		hb.slab([_b(ht_root_le, y0, 0.12), _b(ht_tip_le, tip_y, tip_z), _b(ht_tip_le - ht_tip, tip_y, tip_z),
				_b(ht_root_le - ht_root, y0, 0.12)], n, 0.09, piv)
		var sp := _pivot(piv)
		_add_mesh(sp, hb.mesh(_mat.dark))
		sp.set_meta("axis", (_b(0, tip_y, tip_z) - _b(0, y0, 0.12)).normalized() * sgn)
		_stab.append(sp)
	# Vertical tail: README area, taper, 47.5° sweep, top at README fin top.
	var top := Frames.to_body(Frames.from_readme_inches(p.fin_top_in.x, 0, p.fin_top_in.z, p.cg_x_in))
	var vt_area := p.vtail_area_ft2 * FT2
	var root_z := -0.72
	var span := root_z - top.z
	var vt_root := 2.0 * vt_area / (span * (1.0 + p.vtail_taper))
	var vt_tip := vt_root * p.vtail_taper
	var sweep := tan(deg_to_rad(p.vtail_sweep_le_deg))
	var tip_te := top.x - 0.45
	var tip_le := tip_te + vt_tip
	var root_le := tip_le + span * sweep
	var root_te := root_le - vt_root
	var rudder_chord := p.rudder_area_ft2 * FT2 / (0.8 * span)
	var vb := Builder.new()
	var rz0 := root_z - 0.1 * span
	var rz1 := root_z - 0.9 * span
	var te_at := func(z: float) -> float: return lerpf(root_te, tip_te, (root_z - z) / span)
	vb.slab([_b(root_le, 0, root_z), _b(tip_le, 0, top.z), _b(tip_te, 0, top.z), _b(te_at.call(rz1) + rudder_chord, 0, rz1),
			_b(te_at.call(rz0) + rudder_chord, 0, rz0), _b(root_te, 0, root_z)], _b(0, 1, 0), 0.1)
	# Ventral fins (README X 111.1, Y ±24, Z -51.3)
	var vf := Frames.to_body(Frames.from_readme_inches(p.ventral_fin_in.x, p.ventral_fin_in.y, p.ventral_fin_in.z, p.cg_x_in))
	for sgn: float in [-1.0, 1.0]:
		vb.slab([_b(vf.x + 0.5, vf.y * sgn, 0.6), _b(vf.x - 0.6, vf.y * sgn, 0.6), _b(vf.x - 0.75, vf.y * sgn * 1.2, vf.z + 0.15),
				_b(vf.x - 0.1, vf.y * sgn * 1.2, vf.z + 0.15)], _b(0, 1, 0), 0.05)
	_add_mesh(self, vb.mesh(_mat.body))
	var h0 := _b(te_at.call(rz0) + rudder_chord, 0, rz0)
	var h1 := _b(te_at.call(rz1) + rudder_chord, 0, rz1)
	var rb := Builder.new()
	rb.slab([h0, h1, _b(te_at.call(rz1), 0, rz1), _b(te_at.call(rz0), 0, rz0)], _b(0, 1, 0), 0.07, h0)
	_rudder = _pivot(h0)
	_add_mesh(_rudder, rb.mesh(_mat.dark))
	_rudder.set_meta("axis", (h1 - h0).normalized())
	# Speed brakes: clamshell panels either side of the nozzle (README 14.26 ft²).
	for sgn: float in [-1.0, 1.0]:
		var piv := _b(-4.2, 0.62 * sgn, 0.0)
		var sb := Builder.new()
		sb.slab([_b(-4.2, 0.62 * sgn, -0.3), _b(-4.2, 0.62 * sgn, 0.3), _b(-5.0, 0.6 * sgn, 0.3), _b(-5.0, 0.6 * sgn, -0.3)],
				_b(0, 1, 0), 0.04, piv)
		var sp := _pivot(piv)
		_add_mesh(sp, sb.mesh(_mat.dark))
		sp.set_meta("sign", sgn)
		_speed_brakes.append(sp)


func _build_engine() -> void:
	# Nozzle from the README reference point (front of the nozzle) aft.
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.55
	nozzle.bottom_radius = 0.45
	nozzle.height = 0.9
	nozzle.radial_segments = 12
	nozzle.rings = 1
	nozzle.material = _mat.metal
	var nmi := _add_mesh(self, nozzle, _b(-5.55, 0, 0.02))
	nmi.rotation = Vector3(PI / 2, 0, 0)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.38
	flame.bottom_radius = 0.02
	flame.height = 1.0
	flame.radial_segments = 10
	flame.rings = 1
	flame.material = _flame_mat
	_flame = MeshInstance3D.new()
	_flame.mesh = flame
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.rotation = Vector3(PI / 2, 0, 0)
	_flame.position = _b(-6.0, 0, 0.02)
	add_child(_flame)
	_ab_light = OmniLight3D.new()
	_ab_light.light_color = Color(1.0, 0.55, 0.25)
	_ab_light.omni_range = 18.0
	_ab_light.position = _b(-7.0, 0, 0.02)
	_ab_light.shadow_enabled = false
	add_child(_ab_light)


func _build_gear(si: AircraftParams.SI) -> void:
	for w in _ac.model.gear.wheels:
		var piv := _pivot(w.top_point() + Vector3.UP * 0.35)
		var strut := CylinderMesh.new()
		strut.top_radius = 0.06
		strut.bottom_radius = 0.06
		strut.height = 1.0
		strut.radial_segments = 6
		strut.rings = 1
		strut.material = _mat.strut
		var smi := _add_mesh(piv, strut)
		var wheel := CylinderMesh.new()
		wheel.top_radius = w.radius
		wheel.bottom_radius = w.radius
		wheel.height = 0.22 if w.braked else 0.15
		wheel.radial_segments = 12
		wheel.rings = 1
		wheel.material = _mat.tyre
		var steer := Node3D.new()
		piv.add_child(steer)
		var spin := Node3D.new()
		steer.add_child(spin)
		var wmi := _add_mesh(spin, wheel)
		wmi.rotation = Vector3(0, 0, PI / 2)
		_gear.append({"wheel": w, "pivot": piv, "strut": smi, "steer": steer, "spin": spin})


func _build_lights() -> void:
	var colors := [Color(1, 0.1, 0.05), Color(0.1, 1, 0.2)]
	for i in 2:
		var s := SphereMesh.new()
		s.radius = 0.07
		s.height = 0.14
		s.radial_segments = 6
		s.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = colors[i]
		m.emission_enabled = true
		m.emission = colors[i]
		m.emission_energy_multiplier = 4.0
		s.material = m
		_add_mesh(self, s, _b(-0.9, 5.05 * (-1 if i == 0 else 1), WING_Z))
	var bs := SphereMesh.new()
	bs.radius = 0.08
	bs.height = 0.16
	bs.radial_segments = 6
	bs.rings = 3
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1, 0.9, 0.8)
	bm.emission_enabled = true
	bm.emission = Color(1, 0.95, 0.85)
	bm.emission_energy_multiplier = 0.0
	bs.material = bm
	var top := Frames.from_readme_inches(_ac.params.fin_top_in.x, 0, _ac.params.fin_top_in.z, _ac.params.cg_x_in)
	_beacon = _add_mesh(self, bs, top + Vector3(0, 0.05, 0))


# ------------------------------------------------------------------ animation
func _process(delta: float) -> void:
	var m := _ac.model
	_t += delta
	# LEF: leading edge down = negative rotation about the outboard hinge axis.
	for i in 2:
		var lp: Node3D = _lef[i]
		lp.basis = Basis(lp.get_meta("axis"), -deg_to_rad(m.dlef) * (1 if i == 1 else -1))
	# Flaperons: TEF droop plus aileron (+da = left roll: left TE up, right TE down).
	_flap[0].basis = Basis(Vector3.RIGHT, deg_to_rad(m.tef - m.da))
	_flap[1].basis = Basis(Vector3.RIGHT, deg_to_rad(m.tef + m.da))
	# Stabilators (TE down positive), differential +dd = left roll.
	_stab[0].basis = Basis(Vector3.RIGHT, deg_to_rad(m.dh - m.dd))
	_stab[1].basis = Basis(Vector3.RIGHT, deg_to_rad(m.dh + m.dd))
	# Rudder: +dr = left yaw, trailing edge to the left.
	_rudder.basis = Basis(_rudder.get_meta("axis"), -deg_to_rad(m.dr))
	for sb in _speed_brakes:
		sb.basis = Basis(Vector3.UP, deg_to_rad(m.dsb) * 0.75 * float(sb.get_meta("sign")))
	# Afterburner: flame length with power above military.
	var ab := clampf((m.engine.power - 50.0) / 50.0, 0.0, 1.0)
	var mil := clampf(m.engine.power / 50.0, 0.0, 1.0)
	var flicker := 1.0 + 0.08 * sin(_t * 53.0) + 0.05 * sin(_t * 31.0)
	_flame.visible = mil > 0.05
	_flame.scale = Vector3(1.0, (0.4 + 3.6 * ab) * flicker * maxf(mil, 0.2), 1.0)
	_flame.position = _b(-6.0 - 0.5 * _flame.scale.y, 0, 0.02)
	_flame_mat.albedo_color = Color(1.0, lerpf(0.45, 0.75, ab), lerpf(0.2, 0.55, ab), 0.25 + 0.6 * maxf(ab, mil * 0.3))
	_ab_light.light_energy = 3.0 * ab * flicker
	_ab_light.visible = ab > 0.01
	# Beacon blink
	(_beacon.mesh.material as StandardMaterial3D).emission_energy_multiplier = 6.0 if fmod(_t, 1.2) < 0.12 else 0.0
	# Gear: retraction, oleo compression, steering and wheel spin.
	var nws := deg_to_rad(lerpf(_ac.params.nws_limit_low_deg, _ac.params.nws_limit_high_deg,
			clampf(m.vt / _ac.params.nws_fade_speed_mps, 0.0, 1.0)))
	for g in _gear:
		var w: LandingGear.Wheel = g.wheel
		var piv: Node3D = g.pivot
		piv.visible = m.gear_pos > 0.02
		piv.basis = Basis(Vector3.RIGHT, -(1.0 - m.gear_pos) * deg_to_rad(95.0))
		var bottom := w.static_point + Vector3.UP * (w.compression - w.stroke * w.static_frac)
		var centre := bottom + Vector3.UP * w.radius - piv.position
		var strut: MeshInstance3D = g.strut
		strut.position = centre * 0.5
		strut.scale = Vector3(1.0, maxf(centre.length(), 0.05), 1.0)
		var steer: Node3D = g.steer
		steer.position = centre
		if w.steerable:
			steer.basis = Basis(Vector3.UP, -m.fcs.in_yaw * nws) if m.gear.weight_on_wheels else Basis()
		var spin: Node3D = g.spin
		spin.rotate_x(-w.wheel_speed / w.radius * delta if w.in_contact else 0.0)
