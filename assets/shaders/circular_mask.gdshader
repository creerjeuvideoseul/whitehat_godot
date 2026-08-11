shader_type canvas_item;

// Hard-clips a square texture to a circle inscribed in it (UV distance from
// center vs. radius 0.5) — for avatar images that aren't already perfectly
// pre-cropped to a circle with transparent corners, so the decorative ring
// drawn around them (see ClueBoard._build_avatar) never shows a stray edge
// artifact from the source image poking past it.
//
// `zoom` and `pad_bottom_px` let a caller frame the photo inside that circle
// without resizing the TextureRect itself (which would grow past the ring) —
// zoom samples the texture closer to its center, pad_bottom_px nudges the
// crop window up by that many *final* pixels (more headroom, less chin).
//
// `border_width_px` insets the clip circle by that much so the image (drawn
// on top of the frame's own ring, a Control always draws over its parent's
// background) never paints over the ring's stroke — without this, a zoomed
// image reaches the same outer radius as the ring and fully covers it.

uniform float zoom = 1.0;
uniform float pad_bottom_px = 0.0;
uniform float avatar_size = 190.0;
uniform float border_width_px = 0.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	vec2 shift = vec2(0.0, (pad_bottom_px / avatar_size) / zoom);
	vec2 sample_uv = centered_uv / zoom + vec2(0.5) - shift;
	COLOR = texture(TEXTURE, sample_uv);
	float clip_radius = 0.5 - (border_width_px / avatar_size);
	if (length(centered_uv) > clip_radius) {
		COLOR.a = 0.0;
	}
}
