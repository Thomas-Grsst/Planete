shader_type canvas_item;

uniform float strength = 2.2;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float wave = sin(TIME * 1.4 + world.x * 0.031 + world.y * 0.017) + 0.35 * sin(TIME * 3.1 + world.x * 0.07);
	VERTEX.x += wave * strength * UV.y;
}
