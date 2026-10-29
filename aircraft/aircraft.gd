class_name Aircraft
extends RigidBody3D
## F-16 rigid body. All forces come from F16Model in _integrate_forces.
##
## custom_integrator is on because Godot's inertia is diagonal only and the
## F-16 has a product of inertia Ixz (TP-1538 Table I): F16Model updates the
## velocities with the full tensor, Godot integrates the pose and resolves
## collisions. Gravity is Godot's (state.total_gravity, 9.80665 m/s²), applied
## once inside the model's velocity update.

signal reset_done

@export var params: AircraftParams = preload("res://aircraft/params_f16.tres")
@export var spawn_point := Vector3.ZERO      ## CG position for a runway start (y is set from the gear)
@export var spawn_heading_deg := 0.0         ## 0 = north (-Z)

var model: F16Model

var _ray := PhysicsRayQueryParameters3D.new()
var _space: PhysicsDirectSpaceState3D
var _probe: Callable
var _pending: Dictionary = {}


func _ready() -> void:
	model = F16Model.new(params)
	custom_integrator = true
	can_sleep = false
	mass = model.si.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	# Diagonal part only, used by Godot for collision response.
	# Body X/Y/Z (fwd/right/down) = Godot -Z/X/-Y.
	var inertia_body := model.si.inertia
	inertia = Vector3(inertia_body.y.y, inertia_body.z.z, inertia_body.x.x)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 2
	collision_mask = 1
	_ray.exclude = [get_rid()]
	_ray.collision_mask = 1
	_ray.hit_from_inside = true
	_probe = _ground_probe
	reset_to_runway()


func _ground_probe(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	return _space.intersect_ray(_ray)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _pending.is_empty():
		state.transform = _pending.transform
		state.linear_velocity = _pending.velocity
		state.angular_velocity = Vector3.ZERO
		_pending = {}
		call_deferred("reset_physics_interpolation")
		reset_done.emit.call_deferred()
		return
	if model.crashed:
		# Wreck: let it settle with friction instead of flying.
		state.linear_velocity = state.linear_velocity.lerp(Vector3.ZERO, 0.05) + state.total_gravity * state.step
		state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, 0.1)
		return
	_space = state.get_space_state()
	var out := model.tick(state.transform, state.linear_velocity, state.angular_velocity,
			state.total_gravity, _probe, state.step)
	state.linear_velocity = out[0]
	state.angular_velocity = out[1]
	# The airframe collision shape touching anything means the jet hit the ground.
	if state.get_contact_count() > 0:
		model.crash("CRASH  %.0f m/s" % state.linear_velocity.length())


## Parked at the spawn point, engine idle, parking brake set.
func reset_to_runway() -> void:
	model.reset_ground()
	# Static CG height: README contact points are the static ground line.
	var origin := spawn_point
	origin.y = spawn_point.y - model.si.nose_gear.y
	var basis := Basis(Vector3.UP, deg_to_rad(-spawn_heading_deg))
	_queue_reset(Transform3D(basis, origin), Vector3.ZERO)


## Trimmed level flight at the given altitude and speed, heading as the runway.
func air_start(altitude := 1500.0, speed := 180.0) -> void:
	var trim := Trim.level(model, speed, altitude)
	if not trim.ok:
		push_warning("Air start trim did not converge: %s" % str(trim))
	model.reset_ground()
	model.apply_trim(trim)
	var s := Trim.initial_state(trim, Vector3(spawn_point.x, altitude, spawn_point.z + 3000.0))
	var heading := Basis(Vector3.UP, deg_to_rad(-spawn_heading_deg))
	var xf: Transform3D = s.transform
	_queue_reset(Transform3D(heading * xf.basis, xf.origin), heading * s.velocity)


func _queue_reset(xf: Transform3D, vel: Vector3) -> void:
	_pending = {"transform": xf, "velocity": vel}
