shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fog_texture : repeat_enable, filter_linear;
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform float drift = 0.0;

void fragment() {
	vec2 uv = UV;
	float sheet = texture(fog_texture, uv * vec2(1.18, 1.35) + vec2(drift, 0.13)).a;
	float wisps = texture(fog_texture, uv * vec2(1.75, 2.03) + vec2(-drift * 0.67, 0.37)).a;
	float distance_to_player = length((uv - player_uv) * vec2(1.60, 1.0));
	float far_fog = smoothstep(0.06, 0.61, distance_to_player);
	float opacity = (0.11 + sheet * 0.26 + wisps * 0.21) * (0.28 + far_fog * 0.72);
	COLOR = vec4(0.47, 0.43, 0.52, opacity);
}
