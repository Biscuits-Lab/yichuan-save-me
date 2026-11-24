shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fog_texture : repeat_enable, filter_linear;
uniform sampler2D membrane_texture : repeat_disable, filter_linear;
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform float aspect = 1.77778;
uniform float closure = 0.0;
uniform float elapsed = 0.0;
uniform bool entering = true;

void fragment() {
	vec2 scale = vec2(aspect, 1.0);
	float farthest_corner = length(max(player_uv, 1.0 - player_uv) * scale);
	float radius = mix(farthest_corner + 0.30, -0.39, closure);
	float distance_to_hero = length((UV - player_uv) * scale);

	float clouds = texture(fog_texture, UV * vec2(1.28, 1.47) + vec2(-elapsed * 0.11, elapsed * 0.045)).a;
	float wisps = texture(fog_texture, UV * vec2(2.34, 2.18) + vec2(elapsed * 0.06, -elapsed * 0.09)).a;
	vec2 mirrored = 1.0 - abs(2.0 * fract(UV * vec2(1.08, 0.76) + vec2(0.17, elapsed * 0.018)) - 1.0);
	vec3 veins = texture(membrane_texture, mirrored).rgb;
	float edge = distance_to_hero - radius + (clouds - wisps) * 0.25 + (veins.r - 0.5) * 0.12;
	float cover = smoothstep(-0.12, 0.10, edge);
	float drift = smoothstep(0.0, 0.22, closure) * (1.0 - smoothstep(0.72, 1.0, closure));
	float rim = exp(-abs(edge) * 17.0) * drift;
	float haze = (clouds * 0.12 + wisps * 0.07) * drift;

	vec3 umbra = entering ? vec3(0.039, 0.018, 0.052) : vec3(0.052, 0.027, 0.044);
	vec3 glow = entering ? vec3(0.62, 0.24, 0.39) : vec3(0.88, 0.54, 0.26);
	vec3 color = umbra + veins * mix(0.055, 0.24, drift) + glow * (rim * 0.65 + haze);
	COLOR = vec4(color, max(cover, haze + rim * 0.47));
}
