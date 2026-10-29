extends Node3D
## Runway 18/36 (3000 x 45 m) along Z, south threshold at +Z, with parallel
## taxiway, connectors, apron, edge/threshold/approach lights and a PAPI.
## Pavement and lights are generic airfield furniture, not aircraft data.

const LENGTH := 3000.0
const WIDTH := 45.0
const TAXI_X := 180.0
const TAXI_W := 23.0
const APRON := Rect2(191.5, -300.0, 160.0, 600.0)   # x, z, size x, size z

var _pavement := preload("res://world/shaders/pavement.gdshader")
var _lights_shader := preload("res://world/shaders/lights.gdshader")


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _pavement
	_slab(mat, Vector3(0, 0.06, 0), Vector2(WIDTH, LENGTH), 0, 0.0)
	_slab(mat, Vector3(TAXI_X, 0.05, 0), Vector2(TAXI_W, LENGTH), 1, 0.0)
	var conn_len := TAXI_X - TAXI_W * 0.5 - WIDTH * 0.5
	for z in [LENGTH * 0.5 - 40.0, 0.0, -LENGTH * 0.5 + 40.0]:
		_slab(mat, Vector3(WIDTH * 0.5 + conn_len * 0.5, 0.045, z), Vector2(TAXI_W, conn_len), 1, PI / 2)
	_slab(mat, Vector3(APRON.position.x + APRON.size.x * 0.5, 0.05, APRON.position.y + APRON.size.y * 0.5),
			Vector2(APRON.size.x, APRON.size.y), 2, 0.0)
	_numbers()
	_lights()


func _slab(mat: Material, pos: Vector3, size: Vector2, mode: int, yaw: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("size", size)
	mi.set_instance_shader_parameter("mode", mode)
	add_child(mi)


func _numbers() -> void:
	for end in [["36", LENGTH * 0.5 - 52.0, 0.0], ["18", -LENGTH * 0.5 + 52.0, PI]]:
		var l := Label3D.new()
		l.text = end[0]
		l.font_size = 256
		l.outline_size = 0
		l.pixel_size = 0.036
		l.modulate = Color(0.92, 0.92, 0.9)
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(0, 0.08, end[1])
		l.rotation = Vector3(-PI / 2, end[2], 0)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)


func _lights() -> void:
	var items := []   # [position, colour, papi angle]
	var half := LENGTH * 0.5
	var edge := Color(1.0, 0.85, 0.6)
	var z := -half
	while z <= half + 0.1:
		for x in [-WIDTH * 0.5 - 1.5, WIDTH * 0.5 + 1.5]:
			items.append([Vector3(x, 0.35, z), edge, 0.0])
		z += 60.0
	var x0 := -WIDTH * 0.5
	while x0 <= WIDTH * 0.5 + 0.1:
		items.append([Vector3(x0, 0.3, half + 2.0), Color(0.1, 1.0, 0.25), 0.0])
		items.append([Vector3(x0, 0.3, -half - 2.0), Color(1.0, 0.1, 0.05), 0.0])
		x0 += 4.5
	# Approach lights (south), 900 m centreline with a 300 m crossbar.
	for i in range(1, 31):
		var az := half + 30.0 * i
		for dx in [-1.5, 0.0, 1.5]:
			items.append([Vector3(dx, 0.6, az), Color(1.0, 0.95, 0.85), 0.0])
		if i == 10:
			for k in range(-5, 6):
				items.append([Vector3(3.0 * k, 0.6, az), Color(1.0, 0.95, 0.85), 0.0])
	# Taxiway edge lights (blue).
	z = -half
	while z <= half + 0.1:
		for x in [TAXI_X - TAXI_W * 0.5 - 1.0, TAXI_X + TAXI_W * 0.5 + 1.0]:
			items.append([Vector3(x, 0.3, z), Color(0.15, 0.3, 1.0), 0.0])
		z += 50.0
	# PAPI left of the runway abeam the aiming point, 3° glide path.
	var angles := [3.5, 3.1667, 2.8333, 2.5]
	for i in 4:
		items.append([Vector3(-WIDTH * 0.5 - 15.0 - 9.0 * i, 0.9, half - 422.0), Color.WHITE, angles[i]])

	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := ShaderMaterial.new()
	mat.shader = _lights_shader
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var s := 1.8 if it[2] > 0.0 else 1.0
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), it[0]))
		mm.set_instance_color(i, it[1])
		mm.set_instance_custom_data(i, Color(it[2], 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# PAPI housings
	for i in 4:
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 0.8, 0.9)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position = Vector3(-WIDTH * 0.5 - 15.0 - 9.0 * i, 0.4, half - 421.0)
		add_child(mi)
