class_name Atmosphere
extends RefCounted
## International Standard Atmosphere: troposphere to 11 km, isothermal above.
## Altitude is geometric height in metres; outputs are SI.

const G0 := 9.80665
const R_AIR := 287.05287
const GAMMA := 1.4
const T0 := 288.15
const P0 := 101325.0
const RHO0 := 1.225
const LAPSE := 0.0065
const H_TROPOPAUSE := 11000.0
const T_TROPOPAUSE := T0 - LAPSE * H_TROPOPAUSE
static var P_TROPOPAUSE := P0 * pow(T_TROPOPAUSE / T0, G0 / (LAPSE * R_AIR))


static func temperature(h: float) -> float:
	return T0 - LAPSE * h if h < H_TROPOPAUSE else T_TROPOPAUSE


static func pressure(h: float) -> float:
	if h < H_TROPOPAUSE:
		return P0 * pow(temperature(h) / T0, G0 / (LAPSE * R_AIR))
	return P_TROPOPAUSE * exp(-G0 * (h - H_TROPOPAUSE) / (R_AIR * T_TROPOPAUSE))


static func density(h: float) -> float:
	return pressure(h) / (R_AIR * temperature(h))


static func speed_of_sound(h: float) -> float:
	return sqrt(GAMMA * R_AIR * temperature(h))
