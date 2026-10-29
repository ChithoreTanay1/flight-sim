class_name SimBody
extends RefCounted
## Headless stand-in for the aircraft RigidBody3D: integrates the pose the
## same way Godot does (semi-implicit Euler, rotation from angular velocity)
## around F16Model.tick(). Used by tests; ground is the plane y = 0.

var xform := Transform3D.IDENTITY
var velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
var gravity := Vector3(0.0, -Atmosphere.G0, 0.0)
var probe := Callable(LandingGear, "flat_ground_probe")
var time := 0.0


func step(model: F16Model, dt: float) -> void:
	var out := model.tick(xform, velocity, angular_velocity, gravity, probe, dt)
	velocity = out[0]
	angular_velocity = out[1]
	xform.origin += velocity * dt
	var w_len := angular_velocity.length()
	if w_len > 0.0:
		xform.basis = Basis(angular_velocity / w_len, w_len * dt) * xform.basis
	xform.basis = xform.basis.orthonormalized()
	time += dt


## Place the body for steady flight from a Trim.level() result.
func set_trim(model: F16Model, trim: Dictionary, position: Vector3) -> void:
	var s := Trim.initial_state(trim, position)
	xform = s.transform
	velocity = s.velocity
	angular_velocity = Vector3.ZERO
	model.apply_trim(trim)
