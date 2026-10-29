class_name AircraftParams
extends Resource
## All aircraft data, in the units of the source document, with its source.
## "TP" = NASA Technical Paper 1538 (PDF page numbers), "README" = README.txt.
## Values marked PLACEHOLDER are not in any source; see docs/GAPS.md §4.
## Call to_si() once at load time; nothing else converts units.

@export_group("Mass and inertia")
@export var weight_lbf := 20500.0                 ## TP Table I p.49 (91 188 N)
@export var ixx_slugft2 := 9496.0                 ## TP Table I p.49
@export var iyy_slugft2 := 55814.0                ## TP Table I p.49
@export var izz_slugft2 := 63100.0                ## TP Table I p.49
@export var ixz_slugft2 := 982.0                  ## TP Table I p.49
@export var engine_momentum_slugft2s := 160.0     ## TP App. B p.46

@export_group("Reference geometry")
@export var wing_area_ft2 := 300.0                ## TP Table I p.49
@export var span_ft := 30.0                       ## TP Table I p.49
@export var mac_ft := 11.32                       ## TP Table I p.49
@export var xcg_ref := 0.35                       ## TP Table I p.49 (fraction of c̄)
@export var xcg := 0.35                           ## TP p.14 nominal flight CG

@export_group("Control surfaces (deg, deg/s, s)")
@export var dh_limit_deg := 25.0                  ## TP Table I p.49
@export var dd_limit_deg := 5.375                 ## TP Table I p.49 (per surface)
@export var da_limit_deg := 21.5                  ## TP Table I p.49
@export var dr_limit_deg := 30.0                  ## TP Table I p.49
@export var lef_max_deg := 25.0                   ## TP Table I p.49
@export var sb_max_deg := 60.0                    ## TP Table I p.49
@export var surface_lag_s := 0.0495               ## TP App. A p.40-41 (stab, aileron, rudder)
@export var stab_rate_dps := 60.0                 ## TP App. A p.40
@export var aileron_rate_dps := 80.0              ## TP App. A p.41
@export var rudder_rate_dps := 120.0              ## TP App. A p.41
@export var lef_lag_s := 0.136                    ## TP App. A p.40
@export var lef_rate_dps := 25.0                  ## TP App. A p.40
@export var sb_rate_dps := 30.0                   ## PLACEHOLDER: no speed-brake rate in sources
@export var dd_per_da := 0.25                     ## TP App. A p.41 (4° δa per 1° δd)

@export_group("Reference points (README, inches, X fwd from nozzle, Z up)")
@export var cg_x_in := 201.3                      ## README "Center of Gravity"
@export var nose_gear_in := Vector3(332.2, 0.0, -73.0)    ## README "Nose landing gear"
@export var main_gear_in := Vector3(171.9, 46.7, -73.0)   ## README "Main landing gear" (±Y)
@export var pilot_eye_in := Vector3(384.7, 0.0, 33.2)     ## README "Pilot's eyepoint"
@export var radome_tip_in := Vector3(525.0, 0.0, -13.0)   ## README "Radome tip"
@export var fin_top_in := Vector3(0.0, 0.0, 127.5)        ## README "Top vertical tail"
@export var wingtip_in := Vector3(128.0, 197.0, 0.0)      ## README "Wingtip"
@export var intake_in := Vector3(350.7, 0.0, -41.0)       ## README "Air intake"
@export var ventral_fin_in := Vector3(111.1, 24.0, -51.3) ## README "Ventral fin"

@export_group("Landing gear")
@export var main_stroke_in := 10.5                ## README MLG stroke
@export var nose_stroke_in := 10.0                ## README NLG stroke
@export var main_wheel_radius_in := 11.0          ## README MLG static rolling radius
@export var nose_wheel_radius_in := 7.5           ## README NLG static rolling radius
@export var static_compression_frac := 0.5        ## PLACEHOLDER
@export var gear_damping_ratio := 0.6             ## PLACEHOLDER
@export var mu_rolling := 0.02                    ## PLACEHOLDER
@export var mu_brake := 0.5                       ## PLACEHOLDER
@export var mu_lateral := 0.8                     ## PLACEHOLDER
@export var tyre_stiffness_npm := 2.0e5           ## PLACEHOLDER (numerical static-friction spring)
@export var tyre_damping_ratio := 0.7             ## PLACEHOLDER
@export var nws_limit_low_deg := 32.0             ## PLACEHOLDER (taxi)
@export var nws_limit_high_deg := 6.0             ## PLACEHOLDER (at nws_fade_speed)
@export var nws_fade_speed_mps := 40.0            ## PLACEHOLDER
@export var gear_transit_s := 6.0                 ## PLACEHOLDER

@export_group("Flaps (README wing profiles)")
@export var tef_down_deg := 20.0                  ## README: take-off/approach/landing TEF
@export var tef_up_deg := -2.0                    ## README: high-speed course TEF

@export_group("Limits")
@export var hard_landing_sink_fps := 10.0         ## PLACEHOLDER (3.05 m/s)
@export var overstress_pos_g := 9.0               ## PLACEHOLDER
@export var overstress_neg_g := -4.5              ## PLACEHOLDER

@export_group("Visual geometry (README)")
@export var fuselage_length_in := 593.9           ## README 49 ft 5.9 in
@export var height_in := 200.5                    ## README 16 ft 8.5 in
@export var wing_taper := 0.2275                  ## README
@export var wing_sweep_le_deg := 40.0             ## README
@export var flaperon_area_ft2 := 31.32            ## README
@export var lef_area_ft2 := 36.71                 ## README
@export var htail_area_ft2 := 63.70               ## README
@export var htail_semispan_ft := 5.80             ## README
@export var htail_taper := 0.390                  ## README
@export var htail_sweep_le_deg := 40.0            ## README
@export var htail_dihedral_deg := -10.0           ## README
@export var vtail_area_ft2 := 54.75               ## README
@export var vtail_taper := 0.437                  ## README
@export var vtail_sweep_le_deg := 47.5            ## README
@export var rudder_area_ft2 := 11.65              ## README
@export var speed_brake_area_ft2 := 14.26         ## README
@export var ventral_fin_area_ft2 := 8.03          ## README
@export var engine_length_in := 191.16            ## README
@export var nozzle_exit_area_ft2 := 4.32          ## README


## Plain SI view of the parameters (metres, kilograms, newtons, radians where noted).
class SI:
	extends RefCounted
	var mass: float
	var weight: float
	var inertia: Basis          # body axes (X fwd, Y right, Z down), kg·m²
	var inertia_inv: Basis
	var engine_h: float         # kg·m²/s about body X
	var s: float
	var b: float
	var cbar: float
	var xcg_ref: float
	var xcg: float
	var nose_gear: Vector3      # Godot local, metres from CG (static contact point)
	var main_gear_l: Vector3
	var main_gear_r: Vector3
	var pilot_eye: Vector3
	var nose_stroke: float
	var main_stroke: float
	var nose_wheel_r: float
	var main_wheel_r: float
	var nose_k: float
	var main_k: float
	var nose_c: float
	var main_c: float
	var hard_landing_sink: float


const SLUGFT2 := 1.35581795       # slug·ft² → kg·m²
const FT := 0.3048
const IN := 0.0254
const LBF := 4.4482216152605
const G0 := 9.80665


func to_si() -> SI:
	var si := SI.new()
	si.weight = weight_lbf * LBF
	si.mass = si.weight / G0
	si.inertia = Frames.inertia_tensor(ixx_slugft2 * SLUGFT2, iyy_slugft2 * SLUGFT2,
			izz_slugft2 * SLUGFT2, ixz_slugft2 * SLUGFT2)
	si.inertia_inv = si.inertia.inverse()
	si.engine_h = engine_momentum_slugft2s * SLUGFT2
	si.s = wing_area_ft2 * FT * FT
	si.b = span_ft * FT
	si.cbar = mac_ft * FT
	si.xcg_ref = xcg_ref
	si.xcg = xcg
	si.nose_gear = Frames.from_readme_inches(nose_gear_in.x, nose_gear_in.y, nose_gear_in.z, cg_x_in)
	si.main_gear_l = Frames.from_readme_inches(main_gear_in.x, -main_gear_in.y, main_gear_in.z, cg_x_in)
	si.main_gear_r = Frames.from_readme_inches(main_gear_in.x, main_gear_in.y, main_gear_in.z, cg_x_in)
	si.pilot_eye = Frames.from_readme_inches(pilot_eye_in.x, pilot_eye_in.y, pilot_eye_in.z, cg_x_in)
	si.nose_stroke = nose_stroke_in * IN
	si.main_stroke = main_stroke_in * IN
	si.nose_wheel_r = nose_wheel_radius_in * IN
	si.main_wheel_r = main_wheel_radius_in * IN
	# Static load split from the gear geometry (moments about the CG).
	var xn := -si.nose_gear.z   # forward distance of nose gear, m
	var xm := -si.main_gear_r.z # (negative: mains are aft)
	var nose_share := -xm / (xn - xm)
	var main_share := (1.0 - nose_share) * 0.5
	si.nose_k = nose_share * si.weight / (static_compression_frac * si.nose_stroke)
	si.main_k = main_share * si.weight / (static_compression_frac * si.main_stroke)
	si.nose_c = 2.0 * gear_damping_ratio * sqrt(si.nose_k * nose_share * si.mass)
	si.main_c = 2.0 * gear_damping_ratio * sqrt(si.main_k * main_share * si.mass)
	si.hard_landing_sink = hard_landing_sink_fps * FT
	return si
