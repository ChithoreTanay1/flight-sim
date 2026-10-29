class_name F16Engine
extends RefCounted
## Afterburning turbofan model, TP-1538 App. B p.46 and Fig. 66 p.224-227.
## Power is in percent: 0-50 idle..military, 50-100 military..max (afterburner).

## Throttle travel at the military detent (Fig. 66b, digitized).
const MIL_DETENT := 0.77

var power := 0.0          # P3, actual power (percent)
var commanded := 0.0      # P2
var thrust := 0.0         # N

var _idle: AeroTable
var _mil: AeroTable
var _max: AeroTable


func _init() -> void:
	var t := F16Aero.tables()
	_idle = t.thrust_idle
	_mil = t.thrust_mil
	_max = t.thrust_max


## Fig. 66b throttle gearing: throttle 0..1 -> commanded power P1 (percent).
static func throttle_to_power(throttle: float) -> float:
	var thr := clampf(throttle, 0.0, 1.0)
	if thr <= MIL_DETENT:
		return 50.0 * thr / MIL_DETENT
	return 50.0 + 50.0 * (thr - MIL_DETENT) / (1.0 - MIL_DETENT)


## Fig. 66c: 1/tau (1/s) as a function of the power error P2 - P3.
static func rtau(dp: float) -> float:
	if dp <= 25.0:
		return 1.0
	if dp >= 50.0:
		return 0.1
	return lerpf(1.0, 0.1, (dp - 25.0) / 25.0)


func thrust_at(p3: float, mach: float, alt_m: float) -> float:
	var t_idle := _idle.eval2(mach, alt_m)
	var t_mil := _mil.eval2(mach, alt_m)
	if p3 < 50.0:
		return t_idle + (t_mil - t_idle) * p3 / 50.0
	var t_max := _max.eval2(mach, alt_m)
	return t_mil + (t_max - t_mil) * (p3 - 50.0) / 50.0


## Fig. 66a logic. Returns thrust in newtons.
func step(throttle: float, mach: float, alt_m: float, dt: float) -> float:
	var p1 := throttle_to_power(throttle)
	var inv_tau: float
	if p1 >= 50.0:
		if power >= 50.0:
			commanded = p1
			inv_tau = 5.0
		else:
			commanded = 60.0
			inv_tau = rtau(commanded - power)
	else:
		if power >= 50.0:
			commanded = 40.0
			inv_tau = 5.0
		else:
			commanded = p1
			inv_tau = rtau(commanded - power)
	# Exact first-order step over dt.
	power = commanded + (power - commanded) * exp(-inv_tau * dt)
	power = clampf(power, 0.0, 100.0)
	thrust = thrust_at(power, mach, alt_m)
	return thrust


## Jump straight to the steady state for a throttle setting.
func settle(throttle: float, mach: float, alt_m: float) -> void:
	power = throttle_to_power(throttle)
	commanded = power
	thrust = thrust_at(power, mach, alt_m)
