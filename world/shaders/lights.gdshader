shader_type spatial;
render_mode unshaded, shadows_disabled;
// Airfield lights as one MultiMesh. COLOR = light colour, INSTANCE_CUSTOM.x > 0
// marks a PAPI unit with its transition angle in degrees (white above, red below).
// Lights grow with distance so they stay visible as points.

uniform float intensity = 5.0;

varying vec3 col;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	float d = length(to_cam);
	VERTEX *= clamp(d / 250.0, 1.0, 12.0);
	col = COLOR.rgb;
	if (INSTANCE_CUSTOM.x > 0.0) {
		float elev = degrees(asin(clamp(to_cam.y / max(d, 0.01), -1.0, 1.0)));
		col = elev > INSTANCE_CUSTOM.x ? vec3(1.0, 0.95, 0.9) : vec3(1.0, 0.08, 0.05);
	}
}

void fragment() {
	ALBEDO = col * intensity;
}
