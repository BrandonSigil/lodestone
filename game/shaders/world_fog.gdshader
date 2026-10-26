shader_type canvas_item;
// Fog of war for the world map: paper with hatching everywhere outside the revealed circles.
// Circles come from Discovery (Game.meta.revealed). Off by default until fog is switched on.

const int MAX_CIRCLES = 128;

uniform vec2 map_size = vec2(1920.0, 1080.0);
uniform int circle_count = 0;
uniform vec3 circles[MAX_CIRCLES];
uniform vec4 paper : source_color = vec4(0.98, 0.95, 0.85, 1.0);
uniform vec4 ink : source_color = vec4(0.18, 0.14, 0.25, 1.0);
uniform float edge = 18.0;  // soft torn edge width in map units

void fragment() {
	vec2 p = UV * map_size;
	float inside = -1e9;  // how far inside the nearest circle, negative when outside all
	for (int i = 0; i < MAX_CIRCLES; i++) {
		if (i >= circle_count) break;
		inside = max(inside, circles[i].z - distance(p, circles[i].xy));
	}
	float wobble = sin(p.x * 0.09) * 4.0 + sin(p.y * 0.07 + 1.3) * 4.0;
	float a = 1.0 - smoothstep(-edge, 0.0, inside + wobble);
	float hatch = step(0.82, fract((p.x + p.y) / 11.0));
	vec4 col = mix(paper, ink, hatch * 0.18);
	// a stitched rim where the known world ends
	if (inside + wobble < 0.0 && inside + wobble > -4.0) col = mix(col, ink, 0.6);
	COLOR = vec4(col.rgb, a);
}
