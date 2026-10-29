"""Export the F-16 aero tables to data/*.csv for the Godot sim.

Primary source: NASA TP-1538 (Nguyen et al., 1979), Table III.
Bulk numbers come from reference/matlab/F16-Model-Matlab-main/F16AeroData.h5
(a digitisation of the same table), corrected wherever it disagrees with the
PDF. Every correction is asserted against values transcribed by hand from the
PDF scans so a bad export fails loudly. See docs/GAPS.md for the discrepancy log.

Run:  python -I tools/export_aero.py
"""
import os
import sys

import h5py
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H5 = os.path.join(ROOT, "reference", "matlab", "F16-Model-Matlab-main", "F16AeroData.h5")
OUT = os.path.join(ROOT, "data")

f = h5py.File(H5, "r")
A1 = np.array(f["alpha1"]).ravel()   # 20 points, -20..90 deg
A2 = np.array(f["alpha2"]).ravel()   # 14 points, -20..45 deg (LEF data)
B1 = np.array(f["beta1"]).ravel()    # 19 points, -30..30 deg
DH1 = np.array(f["dh1"]).ravel()     # -25,-10,0,10,25 deg
DH2 = np.array(f["dh2"]).ravel()     # -25,0,25 deg
DH_DS = np.array([-25.0, -10.0, 0.0, 10.0, 15.0, 20.0, 25.0])  # TP-1538 p.73 (dCm_ds)


def h5tab(key, *axes):
    """Return the h5 table as an ndarray indexed [axis0, axis1, ...].
    The file is MATLAB column-major with the first axis varying fastest."""
    shape = tuple(len(a) for a in axes)
    return np.array(f[key]).ravel().reshape(shape[::-1]).transpose(*range(len(axes) - 1, -1, -1))


# ---------------------------------------------------------------- PDF-only data
# Hand transcribed from the TP-1538 Table III scans (PDF page numbers).
PDF_1D = {
    # p.57: dCX,sb(alpha)
    "dCx_sb": [-.0101, -.0101, -.0101, -.0101, -.0101, -.0358, -.0790, -.1227, -.1827, -.1892,
               -.1988, -.2000, -.1874, -.1673, -.1476, -.1310, -.1279, -.1325, -.1250, -.1250],
    # p.64: dCZ,sb(alpha)
    "dCz_sb": [-.3858, -.3858, -.3858, -.3858, -.3858, -.2685, -.3021, -.4248, -.2094, -.0969,
               .0438, .0947, .0014, -.0097, -.0153, -.0520, -.0010, -.0202, -.0369, -.0369],
    # p.71: dCm,sb(alpha)
    "dCm_sb": [-.0034, -.0034, -.0034, -.0034, -.0034, .0289, .0215, .0122, .0241, .0263,
               -.0163, -.0428, -.0704, -.0844, -.0789, -.0603, -.0450, -.0578, -.0107, -.0107],
    # p.72: Cmq(alpha) -- h5 differs for alpha >= 25 deg
    "Cmq": [-6.84, -6.84, -6.84, -3.42, -5.48, -5.45, -6.02, -6.70, -5.69, -6.00,
            -6.20, -6.40, -6.60, -6.00, -5.50, -5.00, -4.50, -3.50, -5.60, -4.04],
    # p.87: Cnr(alpha) -- h5 differs for alpha >= 15 deg
    "Cnr": [-.517, -.517, -.517, -.461, -.414, -.397, -.373, -.455, -.550, -.582,
            -.595, -.637, -1.02, -.840, -.541, -.350, -.350, -.070, -.150, -.150],
    # p.88: Cnp(alpha) -- h5 differs for alpha >= 10 deg
    "Cnp": [-.0006, -.0006, -.0006, .0424, -.0075, -.0214, -.0320, -.0320, .0500, .1500,
            .1300, .1580, .2400, .1500, 0.0, -.2000, -.3000, .1500, 0.0, 0.0],
    # p.97: Clp(alpha) -- h5 differs for alpha >= 30 deg
    "Clp": [-.366, -.366, -.366, -.377, -.345, -.434, -.408, -.388, -.329, -.294,
            -.230, -.210, -.120, -.100, -.100, -.120, -.140, -.100, -.150, -.200],
}
# p.73: dCm,ds(alpha, dh) -- rows alpha1, columns DH_DS. Not in the MATLAB model.
PDF_CM_DS = np.array([[0.0] * 7] * 11 + [
    [0.0, 0.0, 0.0, 0.0, -.0113, -.0132, 0.0],          # 35
    [0.0, .0100, .0100, .0200, .0041, .0297, .0254],    # 40
    [.0480, .0570, .0640, .0700, .0706, .0506, .0407],  # 45
    [.0390, .0540, .1050, .0750, .0792, .0747, .0822],  # 50
    [0.0, .0250, .0750, .0400, .0416, .0500, .0583],    # 55
    [.0840, .0800, .1060, .1000, .0886, .0776, .0785],  # 60
    [.0990, .0750, .1320, .0200, .02875, .0361, .0468], # 70
    [.0200, .0100, .0500, 0.0, .0218, -.0251, -.0210],  # 80
    [0.0, .0100, .0400, 0.0, -.03445, -.0378, -.0378],  # 90
])

# ------------------------------------------------------------- build the tables
T = {}
T["Cx"] = (h5tab("_Cx", A1, B1, DH1), [("alpha_deg", A1), ("beta_deg", B1), ("dh_deg", DH1)])
T["Cz"] = (h5tab("_Cz", A1, B1, DH1), [("alpha_deg", A1), ("beta_deg", B1), ("dh_deg", DH1)])
T["Cm"] = (h5tab("_Cm", A1, B1, DH1), [("alpha_deg", A1), ("beta_deg", B1), ("dh_deg", DH1)])
T["Cl"] = (h5tab("_Cl", A1, B1, DH2), [("alpha_deg", A1), ("beta_deg", B1), ("dh_deg", DH2)])
T["Cn"] = (h5tab("_Cn", A1, B1, DH2), [("alpha_deg", A1), ("beta_deg", B1), ("dh_deg", DH2)])
T["Cy"] = (h5tab("_Cy", A1, B1), [("alpha_deg", A1), ("beta_deg", B1)])
for k in ["Cx_lef", "Cz_lef", "Cm_lef", "Cy_lef", "Cn_lef", "Cl_lef",
          "Cy_a20_lef", "Cn_a20_lef", "Cl_a20_lef"]:
    T[k] = (h5tab("_" + k, A2, B1), [("alpha_deg", A2), ("beta_deg", B1)])
for k in ["Cy_a20", "Cn_a20", "Cl_a20", "Cy_r30", "Cn_r30", "Cl_r30"]:
    T[k] = (h5tab("_" + k, A1, B1), [("alpha_deg", A1), ("beta_deg", B1)])
for k in ["Cxq", "Cyr", "Cyp", "Czq", "Clr", "Clp", "Cmq", "Cnr", "Cnp",
          "deltaCnbeta", "deltaClbeta", "deltaCm"]:
    T[k] = (h5tab("_" + k, A1), [("alpha_deg", A1)])
for k in ["deltaCxq_lef", "deltaCyr_lef", "deltaCyp_lef", "deltaCzq_lef", "deltaClr_lef",
          "deltaClp_lef", "deltaCmq_lef", "deltaCnr_lef", "deltaCnp_lef"]:
    T[k] = (h5tab("_" + k, A2), [("alpha_deg", A2)])
T["eta_el"] = (h5tab("_eta_el", DH1), [("dh_deg", DH1)])

# Correction 1: lateral tables. TP-1538 prints Cl, Cn, Cy (and their LEF
# versions) as exactly 0 at beta = 0; the h5 carries a per-row bias equal to
# the base table's beta=0 value. The control-increment tables carry the same
# bias as their base table, so the increments used in the coefficient build-up
# are unchanged by this correction.
bias = {}
for base in ["Cl", "Cn"]:
    t, ax = T[base]
    bias[base] = t[:, 9, :].copy()            # [alpha, dh]
    T[base] = (t - bias[base][:, None, :], ax)
bias["Cy"] = T["Cy"][0][:, 9].copy()
T["Cy"] = (T["Cy"][0] - bias["Cy"][:, None], T["Cy"][1])
for base in ["Cl", "Cn", "Cy"]:
    lef_t, lef_ax = T[base + "_lef"]
    lef_bias = lef_t[:, 9].copy()
    T[base + "_lef"] = (lef_t - lef_bias[:, None], lef_ax)
    b0 = bias[base] if base == "Cy" else bias[base][:, 1]  # dh = 0 slice
    for k in [base + "_a20", base + "_r30"]:
        T[k] = (T[k][0] - b0[:, None], T[k][1])
    T[base + "_a20_lef"] = (T[base + "_a20_lef"][0] - lef_bias[:, None], T[base + "_a20_lef"][1])

# Correction 2: 1D damping tables where the PDF disagrees with the h5.
for k in ["Cmq", "Cnr", "Cnp", "Clp"]:
    T[k] = (np.array(PDF_1D[k]), [("alpha_deg", A1)])

# PDF-only tables.
for k in ["dCx_sb", "dCz_sb", "dCm_sb"]:
    T[k] = (np.array(PDF_1D[k]), [("alpha_deg", A1)])
T["dCm_ds"] = (PDF_CM_DS, [("alpha_deg", A1), ("dh_deg", DH_DS)])

# TP-1538 Table VI p.99 (SI part), thrust in newtons. Rows: Mach, columns: altitude (m).
MACH_T = np.array([0.2, 0.4, 0.6, 0.8, 1.0])
ALT_T = np.array([0.0, 3048.0, 6096.0, 9144.0, 12192.0, 15240.0])
THRUST = {
    "thrust_idle": [[2824, 1890, 3069, 4492, 5916, 7562],
                    [267, 111, 1535, 3358, 5026, 6783],
                    [-4537, -3158, -1334, 1557, 4048, 6049],
                    [-12010, -8451, -5782, -1099, 2669, 4893],
                    [-16013, -6227, -2647, -1521, -890, 3114]],
    "thrust_mil": [[56401, 40699, 28080, 17970, 10987, 6227],
                   [56089, 41420, 29401, 19082, 11565, 6939],
                   [56223, 43764, 31536, 20728, 12632, 7384],
                   [55111, 45263, 34472, 23663, 14456, 8585],
                   [51953, 43804, 35806, 27133, 16902, 10275]],
    "thrust_max": [[95276, 69834, 49929, 32573, 19727, 11565],
                   [100970, 74993, 54488, 36269, 22240, 12610],
                   [107820, 84112, 61204, 41300, 25354, 14300],
                   [115959, 93742, 71057, 49440, 30513, 17570],
                   [128485, 103723, 81398, 59977, 38440, 22494]],
}
# Cross-check the SI table against the U.S. customary half of Table VI (lbf).
LBF = 4.44822
US_MAX_SL = [21420, 22700, 24240, 26070, 28886]
if np.max(np.abs(np.array(THRUST["thrust_max"])[:, 0] / LBF - US_MAX_SL)) > 2.0:
    sys.exit("Table VI SI/US mismatch")
for k, rows in THRUST.items():
    T[k] = (np.array(rows, dtype=float), [("mach", MACH_T), ("alt_m", ALT_T)])

# ---------------------------------------------------- checks against PDF scans
def check(name, got, ref, tol=6e-5):
    err = float(np.max(np.abs(np.asarray(got) - np.asarray(ref))))
    status = "ok" if err <= tol else "FAIL"
    print(f"  {status:4s} {name:40s} max err {err:.6f}")
    return err <= tol

ok = True
print("Spot checks vs TP-1538 Table III:")
ok &= check("Cx(a=-20..10, b=-30, dh=-25) p.51", T["Cx"][0][:7, 0, 0],
            [-.1837, -.1714, -.1531, -.1151, -.0907, -.0514, -.0079])
ok &= check("Cx(a=-20, b=-30..-2, dh=-25) p.51", T["Cx"][0][0, :9, 0],
            [-.1837, -.1853, -.1904, -.1899, -.1949, -.1914, -.1872, -.1860, -.1860])
ok &= check("Cl(a=-20, all b, dh=0) p.90", T["Cl"][0][0, :, 1],
            [-.0153, -.0028, .0091, .0188, .0234, .0173, .0106, .0090, .0041, 0, -.0031,
             -.0064, -.0084, -.0128, -.0171, -.0120, -.0022, .0097, .0225])
ok &= check("Cl_lef(a=45, all b) p.92", T["Cl_lef"][0][13, :],
            [.0500, .0493, .0351, .0306, .0179, .0158, .0128, .0077, .0019, 0, -.0118,
             -.0124, -.0150, -.0173, -.0214, -.0341, -.0386, -.0528, -.0535])
ok &= check("Cl_a20(a=0, all b) p.93", T["Cl_a20"][0][4, :],
            [-.0403, -.0371, -.0326, -.0301, -.0322, -.0341, -.0372, -.0413, -.0450, -.0481,
             -.0509, -.0535, -.0569, -.0594, -.0623, -.0644, -.0619, -.0574, -.0542])
ok &= check("Cl_a20_lef(a=-20, all b) p.94", T["Cl_a20_lef"][0][0, :],
            [-.0536, -.0402, -.0309, -.0204, -.0147, -.0228, -.0244, -.0228, -.0227, -.0233,
             -.0231, -.0256, -.0288, -.0303, -.0318, -.0259, -.0151, -.0052, .0087])
ok &= check("Cl_r30(a=-20, b=-30..-2) p.95", T["Cl_r30"][0][0, :9],
            [-.0115, .0042, .0163, .0276, .0350, .0349, .0321, .0301, .0236])
ok &= check("Cy(a=-20, all b) p.74", T["Cy"][0][0, :],
            [.3677, .3070, .2460, .1844, .1062, .0850, .0677, .0380, .0186, 0, -.0232,
             -.0467, -.0747, -.1078, -.1421, -.2221, -.2861, -.3461, -.4081])
ok &= check("Cy(a=-5, all b) p.74", T["Cy"][0][3, :],
            [.5538, .4778, .3758, .2818, .1833, .1449, .1055, .0662, .0325, 0, -.0420,
             -.0763, -.1177, -.1575, -.2072, -.3041, -.4001, -.5013, -.5794])
ok &= check("Cn(a=-20, all b, dh=-25) p.80", T["Cn"][0][0, :, 0],
            [-.0633, -.0667, -.0565, -.0418, -.0175, -.0093, -.0006, .0047, .0034, 0, -.0048,
             -.0106, -.0074, -.0015, .0052, .0297, .0443, .0545, .0510])
ok &= check("Cn(a=-5, all b, dh=-25) p.80", T["Cn"][0][3, :, 0],
            [-.0850, -.0761, -.0639, -.0478, -.0354, -.0263, -.0184, -.0114, -.0055, 0, .0054,
             .0112, .0189, .0290, .0392, .0516, .0680, .0800, .0886])
ok &= check("Cxq(alpha) p.57", T["Cxq"][0],
            [.953, .953, .953, 1.55, 1.90, 2.46, 2.92, 3.30, 2.76, 2.05, 1.50, 1.49, 1.83,
             1.21, 1.33, 1.61, .91, 3.43, .617, .273])
ok &= check("deltaCm(alpha) p.71", T["deltaCm"][0],
            [.019] * 6 + [.02, .04, .04, .05] + [.06] * 10)
ok &= check("eta_el(dh) p.71", T["eta_el"][0], [1, 1, 1, 1, .95])
if not ok:
    sys.exit("Export aborted: a table disagrees with the PDF transcription.")

# ------------------------------------------------------------------- write CSVs
SOURCES = {
    "dCx_sb": "TP-1538 Table III p.57 (hand transcribed)",
    "dCz_sb": "TP-1538 Table III p.64 (hand transcribed)",
    "dCm_sb": "TP-1538 Table III p.71 (hand transcribed)",
    "dCm_ds": "TP-1538 Table III p.73 (hand transcribed)",
    "Cmq": "TP-1538 Table III p.72 (hand transcribed; overrides h5)",
    "Cnr": "TP-1538 Table III p.87 (hand transcribed; overrides h5)",
    "Cnp": "TP-1538 Table III p.88 (hand transcribed; overrides h5)",
    "Clp": "TP-1538 Table III p.97 (hand transcribed; overrides h5)",
    "thrust_idle": "TP-1538 Table VI p.99 (hand transcribed, SI part)",
    "thrust_mil": "TP-1538 Table VI p.99 (hand transcribed, SI part)",
    "thrust_max": "TP-1538 Table VI p.99 (hand transcribed, SI part)",
}
os.makedirs(OUT, exist_ok=True)
for name, (vals, axes) in sorted(T.items()):
    src = SOURCES.get(name, "F16AeroData.h5 (matches TP-1538 Table III)")
    if name in ("Cl", "Cn", "Cy", "Cl_lef", "Cn_lef", "Cy_lef", "Cl_a20", "Cn_a20", "Cy_a20",
                "Cl_r30", "Cn_r30", "Cy_r30", "Cl_a20_lef", "Cn_a20_lef", "Cy_a20_lef"):
        src += "; beta=0 bias removed to match TP-1538"
    lines = [f"# table: {name}", f"# source: {src}",
             "# layout: one 'axis' row per independent variable; 'row' lines hold the first",
             "# axis for successive combinations of the others (second axis varies fastest).",
             "# units: thrust in N, altitude in m" if name.startswith("thrust")
             else "# units: angles in degrees, coefficients dimensionless"]
    for an, av in axes:
        lines.append("axis," + an + "," + ",".join(f"{x:g}" for x in av))
    v = np.asarray(vals)
    if v.ndim == 1:
        lines.append("row," + ",".join(f"{x:.6g}" for x in v))
    else:
        if v.ndim == 3:
            # axis 1 varies fastest across rows, then axis 2
            rows = [v[:, j, k] for k in range(v.shape[2]) for j in range(v.shape[1])]
        else:
            rows = [v[:, j] for j in range(v.shape[1])]
        for r in rows:
            lines.append("row," + ",".join(f"{x:.6g}" for x in r))
    with open(os.path.join(OUT, name + ".csv"), "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    # Godot would otherwise import .csv files as translations.
    with open(os.path.join(OUT, name + ".csv.import"), "w", newline="\n") as fh:
        fh.write('[remap]\n\nimporter="keep"\n')
print(f"Wrote {len(T)} tables to {OUT}")
