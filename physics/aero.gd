class_name F16Aero
extends RefCounted
## TP-1538 Appendix B total-coefficient build-up (p.43-46), body axes.
## Angles in degrees for table lookup, rates in rad/s, speed in m/s.
## Outputs are dimensionless force and moment coefficients.

const DATA_DIR := "res://data/"

static var _tables := {}

# Outputs of compute()
var cx := 0.0
var cy := 0.0
var cz := 0.0
var cl := 0.0   # rolling moment
var cm := 0.0
var cn := 0.0

var _t := {}
var _b := 9.144
var _cbar := 3.45
var _xcg_ref := 0.35
var _xcg := 0.35


func _init(b: float, cbar: float, xcg_ref: float, xcg: float) -> void:
	_b = b
	_cbar = cbar
	_xcg_ref = xcg_ref
	_xcg = xcg
	_t = tables()


## All tables, loaded once and shared.
static func tables() -> Dictionary:
	if _tables.is_empty():
		var dir := DirAccess.open(DATA_DIR)
		for file in dir.get_files():
			if file.ends_with(".csv"):
				var t := AeroTable.from_csv(DATA_DIR + file)
				_tables[t.name] = t
	return _tables


func compute(alpha: float, beta: float, vt: float, p: float, q: float, r: float,
		dh: float, da: float, dr: float, dlef: float, dsb: float) -> void:
	var t := _t
	var lef := 1.0 - dlef / 25.0
	var sb := dsb / 60.0
	var ail := da / 20.0
	var rud := dr / 30.0
	var v := maxf(vt, 1.0)
	var cq := _cbar / (2.0 * v)
	var bv := _b / (2.0 * v)
	# Tables only cover alpha -20..90 (LEF data to 45); lookups clamp at the edges.
	var a := alpha
	var be := beta

	# X force
	var cx0: float = t.Cx.eval3(a, be, dh)
	var dcx_lef: float = t.Cx_lef.eval2(a, be) - t.Cx.eval3(a, be, 0.0)
	cx = cx0 + dcx_lef * lef \
			+ cq * (t.Cxq.eval1(a) + t.deltaCxq_lef.eval1(a) * lef) * q \
			+ t.dCx_sb.eval1(a) * sb

	# Z force
	var cz0: float = t.Cz.eval3(a, be, dh)
	var dcz_lef: float = t.Cz_lef.eval2(a, be) - t.Cz.eval3(a, be, 0.0)
	cz = cz0 + dcz_lef * lef \
			+ cq * (t.Czq.eval1(a) + t.deltaCzq_lef.eval1(a) * lef) * q \
			+ t.dCz_sb.eval1(a) * sb

	# Pitching moment
	var dcm_lef: float = t.Cm_lef.eval2(a, be) - t.Cm.eval3(a, be, 0.0)
	cm = t.Cm.eval3(a, be, dh) * t.eta_el.eval1(dh) \
			+ cz * (_xcg_ref - _xcg) \
			+ dcm_lef * lef \
			+ t.dCm_sb.eval1(a) * sb \
			+ cq * (t.Cmq.eval1(a) + t.deltaCmq_lef.eval1(a) * lef) * q \
			+ t.deltaCm.eval1(a) \
			+ t.dCm_ds.eval2(a, dh)

	# Side force
	var cy0: float = t.Cy.eval2(a, be)
	var dcy_lef: float = t.Cy_lef.eval2(a, be) - cy0
	var dcy_a20: float = t.Cy_a20.eval2(a, be) - cy0
	var dcy_a20_lef: float = t.Cy_a20_lef.eval2(a, be) - t.Cy_lef.eval2(a, be) - dcy_a20
	var dcy_r30: float = t.Cy_r30.eval2(a, be) - cy0
	cy = cy0 + dcy_lef * lef \
			+ (dcy_a20 + dcy_a20_lef * lef) * ail \
			+ dcy_r30 * rud \
			+ bv * ((t.Cyr.eval1(a) + t.deltaCyr_lef.eval1(a) * lef) * r
				+ (t.Cyp.eval1(a) + t.deltaCyp_lef.eval1(a) * lef) * p)

	# Yawing moment
	var cn_dh0: float = t.Cn.eval3(a, be, 0.0)
	var dcn_lef: float = t.Cn_lef.eval2(a, be) - cn_dh0
	var dcn_a20: float = t.Cn_a20.eval2(a, be) - cn_dh0
	var dcn_a20_lef: float = t.Cn_a20_lef.eval2(a, be) - t.Cn_lef.eval2(a, be) - dcn_a20
	var dcn_r30: float = t.Cn_r30.eval2(a, be) - cn_dh0
	cn = t.Cn.eval3(a, be, dh) + dcn_lef * lef \
			- cy * (_xcg_ref - _xcg) * _cbar / _b \
			+ (dcn_a20 + dcn_a20_lef * lef) * ail \
			+ dcn_r30 * rud \
			+ bv * ((t.Cnr.eval1(a) + t.deltaCnr_lef.eval1(a) * lef) * r
				+ (t.Cnp.eval1(a) + t.deltaCnp_lef.eval1(a) * lef) * p) \
			+ t.deltaCnbeta.eval1(a) * be

	# Rolling moment
	var cl_dh0: float = t.Cl.eval3(a, be, 0.0)
	var dcl_lef: float = t.Cl_lef.eval2(a, be) - cl_dh0
	var dcl_a20: float = t.Cl_a20.eval2(a, be) - cl_dh0
	var dcl_a20_lef: float = t.Cl_a20_lef.eval2(a, be) - t.Cl_lef.eval2(a, be) - dcl_a20
	var dcl_r30: float = t.Cl_r30.eval2(a, be) - cl_dh0
	cl = t.Cl.eval3(a, be, dh) + dcl_lef * lef \
			+ (dcl_a20 + dcl_a20_lef * lef) * ail \
			+ dcl_r30 * rud \
			+ bv * ((t.Clr.eval1(a) + t.deltaClr_lef.eval1(a) * lef) * r
				+ (t.Clp.eval1(a) + t.deltaClp_lef.eval1(a) * lef) * p) \
			+ t.deltaClbeta.eval1(a) * be


## Lift coefficient (stability axes) from the body coefficients, for HUD and tests.
func lift_coefficient(alpha_deg: float) -> float:
	var al := deg_to_rad(alpha_deg)
	return -cz * cos(al) + cx * sin(al)
