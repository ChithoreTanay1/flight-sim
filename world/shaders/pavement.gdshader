shader_type spatial;
// Runway (mode 0), taxiway (mode 1) and apron (mode 2) with painted markings.
// Meshes are unit planes scaled by the instance size; markings are computed
// in metres from UV, so one material serves every pavement piece.

#include "res://world/shaders/noise.gdshaderinc"

instance uniform vec2 size = vec2(45.0, 3000.0);
instance uniform int mode = 0;
uniform vec3 asphalt : source_color = vec3(0.36, 0.35, 0.37);
uniform vec3 paint : source_color = vec3(0.92, 0.92, 0.9);
uniform vec3 yellow : source_color = vec3(0.95, 0.72, 0.15);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box(vec2 p, vec2 lo, vec2 hi) {
	vec2 s = step(lo, p) * step(p, hi);
	return s.x * s.y;
}

float runway_marks(float x, float v, float len) {
	float ax = abs(x);
	float vv = min(v, len - v);              // mirror both ends
	float m = step(size.x * 0.5 - 0.9, ax);  // edge lines
	m += step(ax, 0.45) * step(0.62, fract(v / 50.0)) * step(90.0, vv);    // centreline 30 m / 20 m gaps
	m += box(vec2(ax, vv), vec2(3.0, 6.0), vec2(20.0, 36.0)) * step(fract((ax - 3.0) / 3.4), 0.53);  // piano keys
	m += box(vec2(ax, vv), vec2(6.0, 400.0), vec2(16.0, 445.0));           // aiming point
	for (int i = 0; i < 5; i++) {                                         // touchdown zone
		float s = 150.0 * float(i + 1);
		if (i == 1) continue;
		float bars = i < 1 ? 3.0 : (i < 3 ? 2.0 : 1.0);
		float in_bar = step(fract((ax - 4.0) / 2.6), 0.62) * step(4.0, ax) * step(ax, 4.0 + 2.6 * bars);
		m += box(vec2(ax, vv), vec2(0.0, s), vec2(30.0, s + 22.5)) * in_bar;
	}
	return clamp(m, 0.0, 1.0);
}

void fragment() {
	vec2 q = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
	vec2 p = wpos.xz;
	float n = fbm(p * 0.35);
	vec3 c = asphalt * (0.82 + 0.35 * n) * (0.95 + 0.1 * vnoise(p * 4.0));
	float marks = 0.0;
	vec3 mark_col = paint;
	if (mode == 0) {
		// rubber deposits in the touchdown zones
		float vv = min(q.y, size.y - q.y);
		c *= 1.0 - 0.35 * smoothstep(12.0, 2.0, abs(q.x)) * smoothstep(900.0, 250.0, vv) * smoothstep(120.0, 250.0, vv) * fbm(p * vec2(1.5, 0.08));
		marks = runway_marks(q.x, q.y, size.y);
	} else {
		mark_col = yellow;
		float ax = abs(q.x);
		marks = mode == 1 ? step(ax, 0.15) + step(size.x * 0.5 - 0.5, ax) * step(ax, size.x * 0.5 - 0.2) : 0.0;
		marks = clamp(marks, 0.0, 1.0);
		if (mode == 2) {
			c *= 1.15;
		}
	}
	marks *= 0.85 + 0.15 * n;   // worn paint
	ALBEDO = mix(c, mark_col, marks);
	ROUGHNESS = mix(0.88, 0.7, marks);
	SPECULAR = 0.3;
}
