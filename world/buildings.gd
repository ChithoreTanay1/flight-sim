extends Node3D
## Six low-poly airfield buildings east of the apron with glowing windows.
## Each is a StaticBody3D on layer 1, so flying into one is a crash.

const Builder := preload("res://aircraft/aircraft_visual.gd").Builder

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://world/shaders/building.gdshader")
	# Control tower
	_box(Vector3(400, 0, -380), Vector3(7, 20, 7), Color(0.78, 0.74, 0.68), 0.0)
	_box(Vector3(400, 20, -380), Vector3(11, 4.5, 11), Color(0.25, 0.27, 0.3), 1.0, true)
	_box(Vector3(400, 24.5, -380), Vector3(12, 0.8, 12), Color(0.35, 0.33, 0.32), 0.0)
	# Hangars with gable roofs
	_hangar(Vector3(440, 0, -170), Vector3(42, 14, 38), Color(0.62, 0.64, 0.6))
	_hangar(Vector3(440, 0, 110), Vector3(42, 14, 38), Color(0.55, 0.6, 0.66))
	# Operations building, fire station
	_box(Vector3(410, 0, 330), Vector3(16, 10, 34), Color(0.82, 0.76, 0.66), 1.0)
	_box(Vector3(290, 0, -440), Vector3(14, 7, 20), Color(0.72, 0.36, 0.3), 1.0)
	# Fuel farm
	for i in 2:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 6.0
		cyl.bottom_radius = 6.0
		cyl.height = 8.0
		cyl.radial_segments = 12
		cyl.rings = 1
		var p := Vector3(480 + 16 * i, 4, 440)
		_add(cyl, p, Color(0.85, 0.85, 0.82), 0.0, Vector3(12, 8, 12))


func _box(base: Vector3, size: Vector3, col: Color, win: float, glass := false) -> void:
	var m := BoxMesh.new()
	m.size = size
	var mi := _add(m, base + Vector3(0, size.y * 0.5, 0), col, win, size)
	if glass:
		mi.set_instance_shader_parameter("windows", 1.0)


func _add(mesh: Mesh, pos: Vector3, col: Color, win: float, shape_size: Vector3) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.set_instance_shader_parameter("wall", col)
	mi.set_instance_shader_parameter("windows", win)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = shape_size
	cs.shape = box
	body.add_child(cs)
	return mi


func _hangar(base: Vector3, size: Vector3, col: Color) -> void:
	_box(base, size, col, 0.35)
	# Gable roof as a triangular prism along Z.
	var b := Builder.new()
	var hx := size.x * 0.5 + 0.6
	var hz := size.z * 0.5 + 0.6
	var ridge := 5.0
	var ref := Vector3(0, 1.0, 0)
	var l0 := Vector3(-hx, 0, -hz)
	var r0 := Vector3(hx, 0, -hz)
	var t0 := Vector3(0, ridge, -hz)
	var l1 := Vector3(-hx, 0, hz)
	var r1 := Vector3(hx, 0, hz)
	var t1 := Vector3(0, ridge, hz)
	b.quad(l0, t0, t1, l1, ref)
	b.quad(t0, r0, r1, t1, ref)
	b.tri(l0, r0, t0, ref)
	b.tri(l1, r1, t1, ref)
	b.quad(l0, r0, r1, l1, ref)
	var mi := MeshInstance3D.new()
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = col.darkened(0.35)
	roof_mat.roughness = 0.6
	roof_mat.metallic = 0.3
	mi.mesh = b.mesh(roof_mat)
	mi.position = base + Vector3(0, size.y, 0)
	add_child(mi)
	# Lit hangar door facing the apron (west).
	var door := BoxMesh.new()
	door.size = Vector3(0.2, size.y * 0.7, size.z * 0.7)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.2, 0.18, 0.15)
	dm.emission_enabled = true
	dm.emission = Color(1.0, 0.78, 0.5)
	dm.emission_energy_multiplier = 0.6
	door.material = dm
	var di := MeshInstance3D.new()
	di.mesh = door
	di.position = base + Vector3(-size.x * 0.5 - 0.1, size.y * 0.35, 0)
	add_child(di)
