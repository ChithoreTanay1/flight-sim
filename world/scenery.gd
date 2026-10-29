extends Node3D
## Ground plane (infinite collision, one grass quad), clustered low-poly
## trees as a MultiMesh, and a distant hill ring for the horizon silhouette.

const Builder := preload("res://aircraft/aircraft_visual.gd").Builder
const GROUND_SIZE := 40000.0


func _ready() -> void:
	var body := StaticBody3D.new()
	# A thick box rather than WorldBoundaryShape3D: Jolt limits the boundary
	# plane's extent and the gear rays must always find the ground.
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 50.0, GROUND_SIZE)
	cs.shape = box
	cs.position = Vector3.DOWN * 25.0
	body.add_child(cs)
	add_child(body)
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://world/shaders/grass.gdshader")
	plane.material = gm
	var gi := MeshInstance3D.new()
	gi.mesh = plane
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gi)
	_trees()
	_hills()


func _clear_of_airfield(p: Vector2) -> bool:
	if absf(p.x - 150.0) < 420.0 and absf(p.y) < 1700.0:
		return false
	if absf(p.x) < 160.0 and p.y > 1500.0 and p.y < 2600.0:   # approach lights / undershoot
		return false
	if absf(p.x) < 250.0 and p.y < -1500.0 and p.y > -3500.0:  # climb-out
		return false
	return true


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 36
	var noise := FastNoiseLite.new()
	noise.seed = 18
	noise.frequency = 0.0015
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries := 0
	while xforms.size() < 1400 and tries < 40000:
		tries += 1
		var p := Vector2(rng.randf_range(-6000, 6000), rng.randf_range(-7000, 7000))
		if not _clear_of_airfield(p) or noise.get_noise_2dv(p) < 0.15:
			continue
		var h := rng.randf_range(7.0, 16.0)
		var w := h * rng.randf_range(0.32, 0.45)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w))
		xforms.append(Transform3D(basis, Vector3(p.x, h * 0.5, p.y)))
		colors.append(Color(0.13, 0.24, 0.1).lerp(Color(0.25, 0.32, 0.12), rng.randf()))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	cone.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 9000.0
	add_child(mmi)


func _hills() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1538
	noise.frequency = 2.2
	var b := Builder.new()
	var n := 96
	var r_in := 11000.0
	var r_out := 15500.0
	var pts_in: Array[Vector3] = []
	var pts_top: Array[Vector3] = []
	var pts_out: Array[Vector3] = []
	for i in n + 1:
		var a := TAU * i / n
		var d := Vector3(sin(a), 0, cos(a))
		var h := 120.0 + 380.0 * maxf(0.0, noise.get_noise_1d(a) + 0.35)
		var mid := lerpf(r_in, r_out, 0.45 + 0.2 * noise.get_noise_1d(a + 40.0))
		pts_in.append(d * r_in + Vector3.DOWN * 5.0)
		pts_top.append(d * mid + Vector3.UP * h)
		pts_out.append(d * r_out + Vector3.DOWN * 5.0)
	for i in n:
		var below := pts_top[i] + Vector3.DOWN * 1.0e5   # both slopes face up
		b.quad(pts_in[i], pts_in[i + 1], pts_top[i + 1], pts_top[i], below)
		b.quad(pts_top[i], pts_top[i + 1], pts_out[i + 1], pts_out[i], below)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.22, 0.2)
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh(m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
