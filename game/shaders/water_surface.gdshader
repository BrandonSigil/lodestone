shader_type canvas_item;
// The moving water's surface (CombatBoard WATER slabs, docs/systems/water.md). Flat and painted like the
// key art: one blue, a lighter shallow band and a white line hugging the bank, a few darker patches and
// short white dashes drifting down the river, foam clouds and ripple rings where a fall lands, rings round
// anyone wading. Hard-edged shapes, no gradients.
//
// Vertex UV = the grid point (cells), vertex COLOR = the water's own colour (the tile set's, tinted).
// The field (WaterField) gives the bank distance (R), flow direction (G, B) and churn (A) at every point.

uniform sampler2D field : filter_linear, repeat_disable;
uniform vec2 field_cells = vec2(1.0);  // the grid's size in cells
uniform vec4 wakes[8];  // someone in the water: grid x, y, strength 0..1, seed
uniform int wake_count = 0;
uniform float speed = 0.34;  // cells a second down the river
uniform float richness = 1.22;  // the water's colour, saturated this much
uniform float glint = 0.42;  // how far the moving marks go from the water's tone toward white
uniform float shore_reach = 0.6;  // WaterField.SHORE_REACH

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 rich(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), c, richness) * 0.97, 0.0, 1.0);
}

// 1 inside a band of half-width w round x = at, with aa of soft edge (about a pixel in x's units).
float band(float x, float at, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(x - at));
}

// Short wavy dashes lying along the flow, one in some cells of a jittered lattice. `life` 0..1 grows them
// in and out, so they never pop. pw = a pixel in grid units (never fwidth inside: the lattice jumps).
float dashes(vec2 q, vec2 dir, float seed, float life, float pw) {
	const float CELL = 0.7;
	float grow = smoothstep(0.08, 0.55, life);
	if (grow <= 0.0) {
		return 0.0;
	}
	vec2 g = q / CELL;
	vec2 id = floor(g);
	vec2 side = vec2(-dir.y, dir.x);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cid = id + vec2(float(x), float(y));
			vec2 h = hash22(cid + seed);
			if (h.x > 0.32) {
				continue;
			}
			vec2 centre = (cid + 0.2 + 0.6 * hash22(cid + seed + 7.0)) * CELL;
			vec2 d = q - centre;
			float a = dot(d, dir);
			float len = (0.1 + 0.1 * h.y) * grow;
			float b = dot(d, side) - 0.014 * sin(a / max(len, 0.01) * 3.1416);
			float s = length(vec2(max(abs(a) - len, 0.0), b));
			float aa = pw * 0.6;
			float thick = 0.026 * grow;
			best = max(best, 1.0 - smoothstep(thick - aa, thick + aa, s));
		}
	}
	return best;
}

// Little round flecks of foam on a jittered lattice; `life` swells and shrinks them.
float bubbles(vec2 q, float seed, float life, float pw) {
	const float CELL = 0.2;
	vec2 id = floor(q / CELL);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cid = id + vec2(float(x), float(y));
			vec2 h = hash22(cid + seed);
			if (h.x > 0.5) {
				continue;
			}
			vec2 centre = (cid + 0.25 + 0.5 * hash22(cid + seed + 3.0)) * CELL;
			float r = (0.018 + 0.03 * h.y) * smoothstep(0.1, 0.6, life);
			float d = length((q - centre) * vec2(1.0, 1.0));
			best = max(best, 1.0 - smoothstep(r - pw * 0.6, r + pw * 0.6, d));
		}
	}
	return best;
}

void fragment() {
	vec2 p = UV;
	vec4 f = texture(field, p / field_cells);
	float shore = f.r * shore_reach;  // cells to the bank
	vec2 flow = f.gb * 2.0 - 1.0;
	float churn = f.a;
	vec2 dir = length(flow) > 0.01 ? normalize(flow) : vec2(1.0, 0.0);
	vec3 base = rich(COLOR.rgb);
	vec3 deep = base * vec3(0.88, 0.92, 0.96);
	vec3 shallow = mix(base, vec3(1.0), 0.16);
	vec3 white = vec3(1.0);
	vec3 mark = mix(base, white, glint);  // the moving marks: lighter water, not white
	float pw = length(fwidth(p));  // a pixel, in cells

	// Flow mapping: two copies of the pattern slide down the river half a beat apart and cross-fade, so
	// it runs forever without stretching. Near the banks the water runs slower.
	float slow = 0.55 + 0.45 * f.r;
	float t = TIME * speed / 1.3;
	float ph0 = fract(t);
	float ph1 = fract(t + 0.5);
	float w0 = 1.0 - abs(1.0 - 2.0 * ph0);
	float w1 = 1.0 - w0;
	vec2 q0 = p - dir * ph0 * 1.3 * slow;
	vec2 q1 = p - dir * ph1 * 1.3 * slow + vec2(5.3, 2.9);

	// Darker patches: blended noise, cut hard into flat shapes.
	float n = vnoise(q0 * 1.7) * w0 + vnoise(q1 * 1.7) * w1;
	n = 0.5 + (n - 0.5) / sqrt(w0 * w0 + w1 * w1);
	float naa = max(fwidth(n), 0.002);
	float patch = smoothstep(0.74 - naa, 0.74 + naa, n) * smoothstep(0.08, 0.2, shore);
	vec3 col = mix(base, deep, patch);

	// The shallow band and the bank line, which laps in and out.
	float lap = (vnoise(p * 4.0 + vec2(TIME * 0.4, -TIME * 0.25)) - 0.5) * 0.022 + 0.007 * sin(TIME * 1.4 + p.x * 2.3 + p.y * 1.7);
	float edge = 0.085 + lap;
	float aa = pw * 0.6;
	col = mix(col, shallow, 1.0 - smoothstep(edge - aa, edge + aa, shore));
	float line = band(shore, edge, 0.016, aa);
	// A thin ripple leaving the bank now and then.
	float k = fract(TIME * 0.3 + vnoise(p * 1.2) * 0.8);
	float ripple = band(shore, edge + 0.05 + k * 0.2, 0.009, aa) * (1.0 - k) * step(0.5, vnoise(p * 2.0 + 9.0));

	// Flow dashes.
	float dash = max(dashes(q0, dir, 3.0, w0, pw), dashes(q1, dir, 11.0, w1, pw)) * smoothstep(0.1, 0.16, shore);

	// Where a fall lands: foam clouds that boil, and rings that spread out from the foot.
	float boil = vnoise(p * 5.0 + vec2(0.0, -TIME * 0.9)) * 0.6 + vnoise(p * 11.0 + TIME * 0.6) * 0.4;
	float fv = churn - (boil - 0.5) * 0.5;
	float faa = max(fwidth(fv), 0.002);
	float foam = smoothstep(0.5 - faa, 0.5 + faa, fv);
	// Bits of foam breaking off and riding away down the river.
	float bits = max(bubbles(q0, 5.0, w0, pw), bubbles(q1, 9.0, w1, pw)) * smoothstep(0.08, 0.3, churn);
	foam = max(foam, bits);
	float out_d = (1.0 - churn) * 1.1;
	float rings = band(fract(out_d * 2.4 - TIME * 0.8), 0.5, 0.06, fwidth(out_d) * 2.4 + 0.001) * smoothstep(0.02, 0.25, churn) * (1.0 - foam);
	col = mix(col, shallow, smoothstep(0.35, 0.36, fv) * (1.0 - foam));

	// Anyone wading: rings spreading from their feet.
	float wake = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= wake_count) {
			break;
		}
		vec4 w = wakes[i];
		float d = length(p - w.xy);
		for (int j = 0; j < 2; j++) {
			float age = fract(TIME * 0.55 + w.w + float(j) * 0.5);
			float r = 0.12 + age * 0.55;
			wake = max(wake, band(d, r, 0.012, aa) * (1.0 - age) * w.z);
		}
		wake = max(wake, band(d, 0.1, 0.014, aa) * w.z);
	}

	col = mix(col, mix(base, white, 0.62), line);  // the bank line stands out a little more than the rest
	col = mix(col, mark, max(max(dash, ripple * 0.7), max(rings * 0.6, wake * 0.8)));
	col = mix(col, mix(mark, white, 0.75), foam);
	COLOR = vec4(col, 1.0);
}
