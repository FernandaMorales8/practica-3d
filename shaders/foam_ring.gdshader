// Espuma alrededor de un pilar que sale del agua: un aro fijo y una onda
// que se abre y se desvanece. Sigue la altura de las olas.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/waves.gdshaderinc"

uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float wave_height = 0.35;
uniform float wave_speed = 0.8;
// Radio del pilar respecto al plano (0..1): la espuma empieza justo ahi.
uniform float inner = 0.42;

varying float phase;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave_at(w.xz, TIME * wave_speed) * wave_height + 0.06;
	// Cada pilar late a destiempo segun donde esta.
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float band = smoothstep(inner, inner + 0.06, r) * (1.0 - smoothstep(inner + 0.14, inner + 0.3, r));
	float ripple = fract(TIME * 0.4 + phase);
	float radius = mix(inner + 0.1, 1.0, ripple);
	float wave_ring = (1.0 - smoothstep(0.0, 0.05, abs(r - radius))) * (1.0 - ripple);
	ALBEDO = foam_color.rgb;
	ALPHA = max(band, wave_ring) * foam_color.a;
}
