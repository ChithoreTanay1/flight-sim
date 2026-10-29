class_name Frames
extends RefCounted
## The one place where axis conventions are converted.
##
## Body axes (TP-1538 fig. 1): X forward, Y right wing, Z down.
## Godot local axes:           X right, Y up, -Z forward.
## The mapping is a proper rotation, so it applies equally to positions,
## velocities, forces, angular rates and moments.


static func to_body(v: Vector3) -> Vector3:
	return Vector3(-v.z, v.x, -v.y)


static func from_body(b: Vector3) -> Vector3:
	return Vector3(b.y, -b.z, -b.x)


## Godot local position from README coordinates (inches; X forward from the
## nozzle reference, Y right, Z up) relative to the CG station.
static func from_readme_inches(x_in: float, y_in: float, z_in: float, cg_x_in: float) -> Vector3:
	const IN := 0.0254
	return from_body(Vector3((x_in - cg_x_in) * IN, y_in * IN, -z_in * IN))


## Euler angles (roll phi, pitch theta, heading psi) in radians from a Godot
## basis. Heading is measured from -Z (north) towards +X (east).
static func euler_from_basis(b: Basis) -> Vector3:
	var fwd := -b.z
	var right := b.x
	var up := b.y
	var theta := asin(clampf(fwd.y, -1.0, 1.0))
	var psi := atan2(fwd.x, -fwd.z)
	var phi := atan2(-right.y, up.y)
	return Vector3(phi, theta, psi)


## Body inertia tensor (TP-1538 sign convention: Ixz enters as -Ixz).
static func inertia_tensor(ixx: float, iyy: float, izz: float, ixz: float) -> Basis:
	return Basis(Vector3(ixx, 0.0, -ixz), Vector3(0.0, iyy, 0.0), Vector3(-ixz, 0.0, izz))
