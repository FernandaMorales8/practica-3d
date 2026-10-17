// Mar estilizado: olas suaves en los vertices, crestas mas claras, reflejo
// del horizonte en los angulos rasantes y destellos que se mueven.
shader_type spatial;
render_mode specular_schlick_ggx;

#include "res://shaders/waves.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.05, 0.45, 0.62);
uniform vec3 crest_color : source_color = vec3(0.3, 0.82, 0.86);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.86, 0.68);
uniform float wave_height = 0.35;
uniform float wave_speed = 0.8;
uniform float sparkle_amount = 0.35;

varying vec3 world_pos;
varying float wave;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_at(w.xz, t);
	// Normal a partir de la pendiente de la ola, para que la luz del sol
	// marque el oleaje.
	float e = 0.5;
	float hx = wave_at(w.xz + vec2(e, 0.0), t);
	float hz = wave_at(w.xz + vec2(0.0, e), t);
	VERTEX.y += h * wave_height;
	NORMAL = normalize(vec3(-(hx - h) * wave_height / e, 1.0, -(hz - h) * wave_height / e));
	wave = h;
	world_pos = w;
}

void fragment() {
	vec3 color = mix(deep_color, crest_color, smoothstep(0.0, 1.2, wave));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	color = mix(color, horizon_color, fresnel * 0.35);

	vec2 p = world_pos.xz;
	// Dos patrones con escalas distintas: los destellos solo salen donde
	// coinciden, asi no forman una reticula regular.
	float s1 = sin(p.x * 1.7 + sin(p.y * 0.5 + TIME * 0.6) * 2.0 + TIME * 0.9)
		* sin(p.y * 1.3 - TIME * 0.7);
	float s2 = sin(p.x * 0.43 - p.y * 0.61 + TIME * 0.4);
	float sparkle = smoothstep(0.96, 0.995, s1) * smoothstep(0.3, 0.8, s2) * sparkle_amount;

	ALBEDO = color + vec3(sparkle);
	ROUGHNESS = 0.35;
	SPECULAR = 0.3;
}
