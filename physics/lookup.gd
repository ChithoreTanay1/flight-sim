class_name AeroTable
extends RefCounted
## Tabulated function of 1 to 3 variables with multilinear interpolation.
## Inputs outside the grid are clamped to its edge.
## Data is stored with the first axis varying fastest (same as data/*.csv).

var name := ""
var axes: Array[PackedFloat64Array] = []
var data := PackedFloat64Array()


static func from_csv(path: String) -> AeroTable:
	var t := AeroTable.new()
	t.name = path.get_file().get_basename()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("AeroTable: cannot open %s" % path)
		return t
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(",")
		if parts[0] == "axis":
			var a := PackedFloat64Array()
			for i in range(2, parts.size()):
				a.append(parts[i].to_float())
			t.axes.append(a)
		elif parts[0] == "row":
			for i in range(1, parts.size()):
				t.data.append(parts[i].to_float())
	var expected := 1
	for a in t.axes:
		expected *= a.size()
	if expected != t.data.size():
		push_error("AeroTable %s: %d values, expected %d" % [t.name, t.data.size(), expected])
	return t


static func from_arrays(table_name: String, table_axes: Array[PackedFloat64Array], values: PackedFloat64Array) -> AeroTable:
	var t := AeroTable.new()
	t.name = table_name
	t.axes = table_axes
	t.data = values
	return t


## Index of the cell containing x (clamped), returned with the fraction in that cell.
static func _cell(axis: PackedFloat64Array, x: float) -> Vector2:
	var n := axis.size()
	if x <= axis[0]:
		return Vector2(0, 0.0)
	if x >= axis[n - 1]:
		return Vector2(n - 2, 1.0)
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if axis[mid] <= x:
			lo = mid
		else:
			hi = mid
	return Vector2(lo, (x - axis[lo]) / (axis[lo + 1] - axis[lo]))


func eval1(x: float) -> float:
	var c := _cell(axes[0], x)
	var i := int(c.x)
	return lerpf(data[i], data[i + 1], c.y)


func eval2(x: float, y: float) -> float:
	var cx := _cell(axes[0], x)
	var cy := _cell(axes[1], y)
	var nx := axes[0].size()
	var i := int(cx.x)
	var j := int(cy.x)
	var k0 := i + nx * j
	var k1 := k0 + nx
	var a := lerpf(data[k0], data[k0 + 1], cx.y)
	var b := lerpf(data[k1], data[k1 + 1], cx.y)
	return lerpf(a, b, cy.y)


func eval3(x: float, y: float, z: float) -> float:
	var cx := _cell(axes[0], x)
	var cy := _cell(axes[1], y)
	var cz := _cell(axes[2], z)
	var nx := axes[0].size()
	var nxy := nx * axes[1].size()
	var i := int(cx.x)
	var j := int(cy.x)
	var k := int(cz.x)
	var b00 := i + nx * j + nxy * k
	var b10 := b00 + nx
	var b01 := b00 + nxy
	var b11 := b01 + nx
	var a0 := lerpf(lerpf(data[b00], data[b00 + 1], cx.y), lerpf(data[b10], data[b10 + 1], cx.y), cy.y)
	var a1 := lerpf(lerpf(data[b01], data[b01 + 1], cx.y), lerpf(data[b11], data[b11 + 1], cx.y), cy.y)
	return lerpf(a0, a1, cz.y)


## Value stored at grid indices (no interpolation); used by tests.
func at(i: int, j := 0, k := 0) -> float:
	var nx := axes[0].size()
	var ny := axes[1].size() if axes.size() > 1 else 1
	return data[i + nx * (j + ny * k)]


## Piecewise-linear 1D function from breakpoint pairs (digitized figure data).
static func piecewise(points: PackedVector2Array, x: float) -> float:
	var n := points.size()
	if x <= points[0].x:
		return points[0].y
	for i in range(1, n):
		if x <= points[i].x:
			var p0 := points[i - 1]
			var p1 := points[i]
			return lerpf(p0.y, p1.y, (x - p0.x) / (p1.x - p0.x))
	return points[n - 1].y
