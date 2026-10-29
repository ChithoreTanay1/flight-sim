shader_type spatial;
// Flat-coloured building walls with a world-space window grid; a random
// subset of windows glows warm. Roofs (upward faces) get no windows.

#include "res://world/shaders/noise.gdshaderinc"

instance uniform vec3 wall : source_color = vec3(0.7, 0.66, 0.6);
instance uniform float windows = 1.0;
uniform vec3 window_warm : source_color = vec3(1.0, 0.72, 0.38);
uniform vec3 glass : source_color = vec3(0.12, 0.14, 0.2);
uniform float window_energy = 3.0;
uniform vec2 cell = vec2(3.2, 3.6);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = wall * (0.92 + 0.12 * vnoise(wpos.xz * 0.3 + wpos.y * 0.2));
	float along = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	vec2 g = vec2(along, wpos.y - 0.8) / cell;
	vec2 f = fract(g);
	float is_win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75)
			* step(abs(wnorm.y), 0.5) * step(0.5, g.y) * windows;
	float lit = step(0.55, hash12(floor(g) + floor(wpos.xz * 0.01) * 13.0));
	ALBEDO = mix(c, glass, is_win);
	EMISSION = window_warm * window_energy * is_win * lit;
	ROUGHNESS = mix(0.85, 0.15, is_win);
}
