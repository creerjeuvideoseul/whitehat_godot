shader_type canvas_item;

// Recouvre tout l'ecran par-dessus le jeu (voir autoloads/screen_effects.gd) :
// simule les artefacts d'un vieux moniteur (scanlines, vignette, flicker,
// micro-glitch rare) pour que l'interface se sente "regardee a travers un
// ecran" plutot que comme une fenetre Godot plate. Tout est volontairement
// discret : le principe de design du projet est de sacrifier le realisme des
// qu'il gene la lisibilite, jamais l'inverse.

uniform float scanline_alpha : hint_range(0.0, 0.3) = 0.05;
uniform float scanline_density : hint_range(100.0, 2000.0) = 800.0;
uniform float vignette_alpha : hint_range(0.0, 0.5) = 0.12;
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.015;
uniform float flicker_speed : hint_range(0.1, 20.0) = 8.0;
// Probabilite par "tick" de glitch (5 fois par seconde, voir glitch_seed
// ci-dessous) qu'une frame soit legerement plus sombre, comme une perte de
// signal tres breve.
uniform float glitch_chance : hint_range(0.0, 1.0) = 0.01;
uniform float glitch_intensity : hint_range(0.0, 0.5) = 0.12;

float pseudo_random(float seed) {
	return fract(sin(seed * 12.9898) * 43758.5453);
}

void fragment() {
	// Lignes horizontales fines et regulieres, tres legerement assombries.
	float line = sin(UV.y * scanline_density) * 0.5 + 0.5;
	float scan_dark = pow(line, 3.0) * scanline_alpha;

	// Vignette : bords un peu plus sombres que le centre.
	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.35, 0.72, length(centered)) * vignette_alpha;

	// Respiration lente de la luminosite globale.
	float breathing = sin(TIME * flicker_speed) * 0.5 + 0.5;
	float flicker = breathing * flicker_amount;

	// Micro-glitch rare : un tick change de valeur 5 fois par seconde, pas a
	// chaque frame, pour rester un evenement ponctuel et non un bruit continu.
	float glitch_seed = floor(TIME * 5.0);
	float glitch_roll = pseudo_random(glitch_seed);
	float glitch_dark = step(1.0 - glitch_chance, glitch_roll) * glitch_intensity;

	float total_dark = clamp(scan_dark + vignette + flicker + glitch_dark, 0.0, 0.6);
	// Teinte vert tres fonce plutot que noir pur, coherent avec la charte
	// "vert hacker" du jeu (Palette.BORDER_ACCENT) sans dependre de Palette,
	// qui n'est pas accessible depuis un shader.
	COLOR = vec4(0.0, 0.03, 0.015, total_dark);
}
