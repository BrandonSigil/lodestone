shader_type canvas_item;
// World map ground: flat region fills with warped Voronoi borders, coast ripples on water.
// Mirrors WorldMap.region_hit() in scripts/world/world_map.gd. Keep the two in step.

const int MAX_REGIONS = 24;
const int MAX_WALL = 12;

uniform vec2 map_size = vec2(1920.0, 1080.0);
uniform vec4 phase;
uniform vec3 warp_f = vec3(0.006, 0.013, 0.045);
uniform vec2 warp_a = vec2(55.0, 8.0);
uniform int region_count = 0;
uniform vec2 region_pos[MAX_REGIONS];
uniform float region_weight[MAX_REGIONS];
uniform float region_east[MAX_REGIONS];
uniform float region_water[MAX_REGIONS];
uniform vec4 region_fill[MAX_REGIONS];
uniform vec4 region_mark[MAX_REGIONS];
uniform int wall_count = 0;
uniform vec2 wall_pts[MAX_WALL];

vec2 warp(vec2 p) {
	vec2 big = vec2(
		sin(p.y * warp_f.x + phase.x) + 0.5 * sin((p.x + p.y) * warp_f.y + phase.y),
		sin(p.x * warp_f.x + phase.z) + 0.5 * sin((p.x - p.y) * warp_f.y + phase.w));
	vec2 small = vec2(sin(p.y * warp_f.z + phase.y), sin(p.x * warp_f.z + phase.x));
	return p + big * warp_a.x + small * warp_a.y;
}

float wall_x(float y) {
	if (y <= wall_pts[0].y) return wall_pts[0].x;
	for (int i = 1; i < MAX_WALL; i++) {
		if (i >= wall_count) break;
		if (y <= wall_pts[i].y) {
			return mix(wall_pts[i - 1].x, wall_pts[i].x, (y - wall_pts[i - 1].y) / (wall_pts[i].y - wall_pts[i - 1].y));
		}
	}
	return wall_pts[wall_count - 1].x;
}

void fragment() {
	vec2 p = UV * map_size;
	vec2 wp = warp(p);
	float east = p.x > wall_x(p.y) ? 1.0 : 0.0;
	float best = 1e9;
	float second = 1e9;
	int idx = 0;
	for (int i = 0; i < MAX_REGIONS; i++) {
		if (i >= region_count) break;
		float cost = distance(wp, region_pos[i]) - region_weight[i];
		if (region_east[i] != east) cost += 100000.0;
		if (cost < best) {
			second = best;
			best = cost;
			idx = i;
		} else if (cost < second) {
			second = cost;
		}
	}
	float margin = (second - best) * 0.5;
	vec4 col = region_fill[idx];
	if (region_water[idx] > 0.5) {
		// ripple rings that follow the coast, fading out to sea
		float m = margin + sin(p.x * 0.05 + phase.x) * 2.0;
		if (m < 70.0 && fract(m / 15.0) < 0.2 + 0.1 * (1.0 - m / 70.0)) col = region_mark[idx];
	} else if (margin < 2.0) {
		col = region_mark[idx];
	}
	COLOR = col;
}
