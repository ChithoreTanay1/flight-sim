class_name TFilter
extends RefCounted
## Continuous transfer function (b2 s² + b1 s + b0) / (a2 s² + a1 s + a0),
## discretized with the bilinear (Tustin) transform at a fixed step.
## Tustin keeps every stable continuous filter stable at any step size.

var _n := PackedFloat64Array([0.0, 0.0, 0.0])   # numerator coefficients (z^0, z^-1, z^-2)
var _d := PackedFloat64Array([1.0, 0.0, 0.0])   # denominator, normalized so _d[0] = 1
var _b := PackedFloat64Array()                  # continuous coefficients b0, b1, b2
var _a := PackedFloat64Array()                  # continuous coefficients a0, a1, a2
var _dt := -1.0
var _x1 := 0.0
var _x2 := 0.0
var _y1 := 0.0
var _y2 := 0.0
var value := 0.0


func _init(b0: float, b1: float, b2: float, a0: float, a1: float, a2: float) -> void:
	_b = PackedFloat64Array([b0, b1, b2])
	_a = PackedFloat64Array([a0, a1, a2])


## k·a/(s+a): first-order lag with time constant 1/a.
static func lag(a: float, k := 1.0) -> TFilter:
	return TFilter.new(k * a, 0.0, 0.0, a, 1.0, 0.0)


## k·s/(s+a): washout.
static func washout(a: float, k := 1.0) -> TFilter:
	return TFilter.new(0.0, k, 0.0, a, 1.0, 0.0)


## (b1 s + b0)/(s + a): lead/lag.
static func lead(b1: float, b0: float, a: float) -> TFilter:
	return TFilter.new(b0, b1, 0.0, a, 1.0, 0.0)


func _discretize(dt: float) -> void:
	_dt = dt
	var k := 2.0 / dt
	var k2 := k * k
	var n0 := _b[2] * k2 + _b[1] * k + _b[0]
	var n1 := -2.0 * _b[2] * k2 + 2.0 * _b[0]
	var n2 := _b[2] * k2 - _b[1] * k + _b[0]
	var d0 := _a[2] * k2 + _a[1] * k + _a[0]
	var d1 := -2.0 * _a[2] * k2 + 2.0 * _a[0]
	var d2 := _a[2] * k2 - _a[1] * k + _a[0]
	_n = PackedFloat64Array([n0 / d0, n1 / d0, n2 / d0])
	_d = PackedFloat64Array([1.0, d1 / d0, d2 / d0])


func step(x: float, dt: float) -> float:
	if dt != _dt:
		_discretize(dt)
	var y := _n[0] * x + _n[1] * _x1 + _n[2] * _x2 - _d[1] * _y1 - _d[2] * _y2
	_x2 = _x1
	_x1 = x
	_y2 = _y1
	_y1 = y
	value = y
	return y


## Put the filter in steady state for a constant input u.
func reset(u := 0.0) -> void:
	var dc := _b[0] / _a[0] if absf(_a[0]) > 0.0 else 0.0
	_x1 = u
	_x2 = u
	_y1 = dc * u
	_y2 = dc * u
	value = dc * u


## First-order lag actuator with position and rate limits (TP-1538 App. A).
class Actuator:
	extends RefCounted
	var pos := 0.0
	var bandwidth := 20.2   # 1/time constant, rad/s
	var rate_limit := 60.0  # units/s
	var lo := -25.0
	var hi := 25.0

	func _init(p_bandwidth: float, p_rate: float, p_lo: float, p_hi: float) -> void:
		bandwidth = p_bandwidth
		rate_limit = p_rate
		lo = p_lo
		hi = p_hi

	func step(cmd: float, dt: float) -> float:
		var target := clampf(cmd, lo, hi)
		# Exact discrete lag, then rate limit.
		var desired := target + (pos - target) * exp(-bandwidth * dt)
		var max_step := rate_limit * dt
		pos = clampf(pos + clampf(desired - pos, -max_step, max_step), lo, hi)
		return pos
