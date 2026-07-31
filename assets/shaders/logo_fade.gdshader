shader_type canvas_item;

// Feathers the texture's edges to alpha 0 so its baked-in background
// blends into whatever sits behind it instead of showing a hard rectangle.
uniform float fade_size = 0.14;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 edge_dist = min(UV, vec2(1.0) - UV);
	float fade = smoothstep(0.0, fade_size, edge_dist.x) * smoothstep(0.0, fade_size, edge_dist.y);
	COLOR = vec4(tex.rgb, tex.a * fade);
}
