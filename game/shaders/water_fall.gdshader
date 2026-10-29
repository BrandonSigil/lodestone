shader_type canvas_item;
// Waterfalls (CombatBoard FALLS slabs, docs/systems/water.md). Two kinds of piece share this shader:
//
// The sheet: the water bends white over the lip, lighter and darker streaks pour down it in tones close to
// the water's own. Vertex UV.x = position along the lip in screen cell widths (so streaks carry on across
// cells), UV.y = levels down from the lip (0 and up). Vertex COLOR = the water's colour; alpha = drop / 10.
//
// A spill: a fall off the map's edge, with no pool to land in. As the sheet, but UV.y runs from 100 at
// the lip, COLOR's alpha is its length / 20 levels, and it thins out into mist toward its end.
//
// The splash cap: a band of foam clouds sitting over the seam where the sheet meets the pool below, puffing
// up over the sheet's foot and spilling out onto the water, a soft blue shadow under its puffs. Vertex UV.x
// as the sheet's, UV.y from -1 (the cap's top) to -2 (its bottom, out on the pool). COLOR = the water's
// colour; alpha = how full the cap is there (it thins out where the sheet ends against rock).

uniform float speed = 1.8;  // levels a second down the sheet
uniform float richness = 1.22;  // the water's colour, saturated this much
uniform float glint = 0.4;  // how far the moving streaks go from the water's tone toward white
uniform float cap_px = 34.0;  // the cap's height in screen pixels (CombatBoard.CAP_UP and CAP_OUT)
uniform float cap_seam = 0.66;  // where the seam crosses the cap, top 0 to bottom 1

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float cut(float x, float at) {
	float aa = max(fwidth(x), 0.002);
	return smoothstep(at - aa, at + aa, x);
}

vec3 rich(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), c, richness) * 0.97, 0.0, 1.0);
}

// 1 inside a circle, with a fixed pixel of soft edge (never fwidth: the lanes jump).
float disc(vec2 px, vec2 at, float r) {
	return 1.0 - smoothstep(r - 0.7, r + 0.7, length(px - at));
}

void cap(float u, float t, vec3 base, float full, inout vec4 out_col) {
	vec2 px = vec2(u * 32.0, t * cap_px);  // a screen cell width is 32 px of u
	float seam = cap_seam * cap_px;
	float mid = seam - 1.0;
	// The band of foam along the seam, its top and bottom edges made of puffs that slowly swell.
	float body = 1.0 - smoothstep(5.0 * full - 0.7, 5.0 * full + 0.7, abs(px.y - mid));
	float lane = floor(px.x / 11.0);
	for (int j = -1; j <= 1; j++) {
		float id = lane + float(j);
		float h = hash11(id * 7.3 + 1.0);
		float breathe = 0.5 * sin(TIME * (1.2 + h * 0.8) + h * 6.3);
		float x = id * 11.0 + 5.5 + (h - 0.5) * 4.0;
		float top = disc(px, vec2(x, mid - (4.0 + h * 3.5) * full), (5.6 + h * 3.2 + breathe) * full);
		float low = disc(px, vec2(x + 4.0, mid + 4.0 * full), (3.4 + h * 2.0 - breathe * 0.5) * full);
		body = max(body, max(top, low));
	}
	// A few flecks thrown up off the top.
	float flecks = 0.0;
	for (int j = -1; j <= 1; j++) {
		float id = floor(px.x / 11.0) + float(j);
		float h = hash11(id * 3.1 + 5.0);
		float age = fract(TIME * (0.5 + h * 0.4) + h * 9.0);
		vec2 at = vec2(id * 11.0 + 5.5 + (h - 0.5) * 6.0 + (age - 0.5) * (h - 0.5) * 8.0,
			mid - 10.0 * full - sin(age * 3.1416) * (4.0 + h * 5.0));
		flecks = max(flecks, disc(px, at, (1.2 + h * 1.1) * (1.0 - age) * full));
	}
	vec3 white = vec3(0.97, 0.99, 1.0);
	vec3 shade = mix(base, white, 0.55);
	vec3 col = mix(white, shade, smoothstep(mid + 0.5, mid + 1.5, px.y));  // the lower half sits in shadow
	out_col = vec4(col, max(body, flecks));
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	vec3 base = rich(COLOR.rgb);
	if (v < -0.5) {
		vec4 c;
		cap(u, -v - 1.0, base, COLOR.a, c);
		COLOR = c;
	} else {
		bool spill = v > 50.0;
		if (spill) {
			v -= 100.0;
		}
		float drop = COLOR.a * (spill ? 20.0 : 10.0);
		vec3 sheet = mix(base, vec3(1.0), 0.2);
		vec3 dark = mix(base, vec3(1.0), 0.06);
		vec3 white = vec3(1.0);
		// Streaks: noise stretched long down the sheet and pulled down it.
		float n = vnoise(vec2(u * 11.0, v * 0.55 - TIME * speed * 0.55));
		float m = vnoise(vec2(u * 23.0 + 4.0, v * 0.4 - TIME * speed * 0.8));
		vec3 col = mix(sheet, dark, cut(n, 0.62));
		col = mix(col, mix(sheet, white, glint), cut(m, 0.84));
		// The lip: the water bends white over the edge.
		float lip = 0.1 + 0.04 * vnoise(vec2(u * 9.0, TIME * 1.2));
		col = mix(col, mix(sheet, white, 0.8), 1.0 - cut(v, lip));
		if (spill) {  // thins out into mist
			float gone = smoothstep(drop * 0.45, drop, v + (vnoise(vec2(u * 6.0, TIME * 0.8)) - 0.5) * 0.8);
			COLOR = vec4(mix(col, white, gone * 0.5), 0.97 * (1.0 - gone));
		} else {  // the foot whitens into the splash cap that covers it
			col = mix(col, white, cut(v, drop - 0.35));
			COLOR = vec4(col, 0.97);
		}
	}
}
