shader_type sky;
// Stylized sunset: gradient, sun disc and glow from DirectionalLight 0,
// static fbm cloud layer (no TIME, so radiance is only rebuilt when the sun moves).

#include "res://world/shaders/noise.gdshaderinc"

uniform vec3 zenith_color : source_color = vec3(0.09, 0.11, 0.30);
uniform vec3 mid_color : source_color = vec3(0.42, 0.30, 0.52);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.56, 0.30);
uniform vec3 ground_color : source_color = vec3(0.16, 0.11, 0.12);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.62, 0.45);
uniform vec3 cloud_shade : source_color = vec3(0.30, 0.20, 0.36);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float sun_radius_deg = 0.9;
uniform float sun_energy = 30.0;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(-0.95, 0.09, -0.3);
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0, 0.6, 0.35);
	float cs = dot(d, normalize(sun_dir));
	float toward_sun = 0.5 + 0.5 * dot(normalize(d.xz + 1e-4), normalize(sun_dir.xz + 1e-4));

	float t = max(h, 0.0);
	vec3 hz = mix(horizon_color * vec3(0.75, 0.62, 0.78), horizon_color, toward_sun * toward_sun);
	vec3 col = mix(hz, mid_color, smoothstep(0.0, 0.18, t));
	col = mix(col, zenith_color, smoothstep(0.12, 0.7, t));
	col += sun_col * (pow(max(cs, 0.0), 6.0) * 0.45 + pow(max(cs, 0.0), 80.0) * 1.2);

	if (h > 0.005) {
		vec2 uv = d.xz / (h + 0.08) * 2.2;
		float c = fbm(uv * 1.3 + vec2(3.0, 1.0));
		c = smoothstep(1.0 - cloud_cover, 1.18 - cloud_cover, c) * smoothstep(0.005, 0.12, h);
		float lit = pow(max(cs, 0.0), 3.0);
		vec3 cc = mix(cloud_shade, cloud_lit * sun_col * 1.4, clamp(lit * 1.2 + 0.15, 0.0, 1.0));
		col = mix(col, cc, c * 0.85);
	}
	float ang = acos(clamp(cs, -1.0, 1.0));
	float r = radians(sun_radius_deg);
	col += sun_col * sun_energy * (1.0 - smoothstep(r * 0.8, r, ang)) * step(-0.01, h);

	if (h < 0.0) {
		col = mix(hz * 0.55, ground_color, smoothstep(0.0, -0.08, h));
	}
	COLOR = col;
}
