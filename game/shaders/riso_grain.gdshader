shader_type canvas_item;
// Fixed paper grain and soft mottle over the whole frame (style rule R6).
// Grain is keyed to screen pixels, not time, so it never swims.
// Soft-light blend, matching the style lab's canvas "soft-light" pass.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float seed = 7.0;
uniform float grain_strength = 0.55;
uniform float mottle_strength = 0.15;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.137);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 soft_light(vec3 a, vec3 b) {
	return (1.0 - 2.0 * b) * a * a + 2.0 * b * a;
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec2 px = floor(FRAGCOORD.xy);
	float g = 0.463 + (hash(px) - 0.5) * 0.47;
	if (hash(px + 17.0) < 0.012) {
		g -= 0.27;
	}
	vec3 grained = mix(base, soft_light(base, vec3(g)), grain_strength);
	vec2 uv = SCREEN_UV * vec2(2.4, 1.6);
	float m = vnoise(uv + seed) * 0.6 + vnoise(uv * 2.3 - seed) * 0.4;
	vec3 mottled = mix(grained, soft_light(grained, vec3(0.5 + (m - 0.5) * 0.9)), mottle_strength * 2.0);
	COLOR = vec4(mottled, 1.0);
}
