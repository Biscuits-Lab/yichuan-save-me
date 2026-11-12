shader_type canvas_item;
render_mode unshaded;
uniform vec4 frame_rect;
uniform vec4 next_rect;
uniform float blend_weight : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec2 local_uv = (UV - frame_rect.xy) / frame_rect.zw;
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(TEXTURE, next_rect.xy + local_uv * next_rect.zw);
	float alpha = mix(a.a, b.a, blend_weight);
	vec3 premultiplied = mix(a.rgb * a.a, b.rgb * b.a, blend_weight);
	COLOR = vertex_tint * vec4(alpha > 0.001 ? premultiplied / alpha : vec3(0.0), alpha);
}
