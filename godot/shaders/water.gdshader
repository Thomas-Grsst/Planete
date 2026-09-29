shader_type canvas_item;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	float ripple = sin(world_pos.x * 0.07 + TIME * 1.1) * sin(world_pos.y * 0.16 - TIME * 0.8);
	float swell = sin((world_pos.x + world_pos.y) * 0.015 + TIME * 0.4) * 0.5 + 0.5;
	vec3 tint = COLOR.rgb * (0.92 + swell * 0.12);
	tint += vec3(0.85, 0.95, 1.0) * smoothstep(0.82, 1.0, ripple) * 0.22;
	COLOR = vec4(tint, COLOR.a);
}
