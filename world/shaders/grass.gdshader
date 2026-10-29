shader_type spatial;
render_mode specular_schlick_ggx;
// Procedural grass: large-scale colour patches, mowing stripes near the
// runway, fine detail fading with distance. World-space so the mesh is one quad.

#include "res://world/shaders/noise.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.30, 0.42, 0.14);
uniform vec3 grass_b : source_color = vec3(0.46, 0.52, 0.2);
uniform vec3 dry : source_color = vec3(0.56, 0.47, 0.24);
uniform float strip_half_width = 140.0;
uniform float strip_half_length = 1750.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 c = mix(grass_a, grass_b, fbm(p * 0.004));
	c = mix(c, dry, smoothstep(0.5, 0.78, fbm(p * 0.0011 + 7.0)) * 0.75);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fine = mix(0.82 + 0.3 * vnoise(p * 0.7), 1.0, clamp(dist / 200.0, 0.0, 1.0));
	c *= (0.88 + 0.22 * vnoise(p * 0.05)) * fine;
	float in_strip = smoothstep(strip_half_width + 20.0, strip_half_width, abs(p.x - 90.0))
			* smoothstep(strip_half_length + 20.0, strip_half_length, abs(p.y));
	c *= mix(1.0, 0.93 + 0.1 * step(0.5, fract(p.x / 14.0)), in_strip);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
