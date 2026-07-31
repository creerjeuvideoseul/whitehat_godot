shader_type canvas_item;

// Faint terminal-style grid drawn procedurally so no texture asset is needed.
uniform vec4 bg_color : source_color = vec4(0.016, 0.043, 0.031, 1.0);
uniform vec4 line_color : source_color = vec4(0.11, 0.32, 0.22, 0.35);
uniform float cell_size = 48.0;
uniform float line_width = 1.2;

void fragment() {
	vec2 cell = mod(FRAGCOORD.xy, cell_size);
	float on_line = step(cell.x, line_width) + step(cell.y, line_width);
	on_line = clamp(on_line, 0.0, 1.0);
	COLOR = mix(bg_color, line_color, on_line);
}
