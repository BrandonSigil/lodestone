shader_type canvas_item;
// Trees and bushes bend in the breeze ([USER] 2026-10-30, ambience). On the board's props slabs: a draw whose
// colour alpha is one of the sway marks (CombatBoard.SWAY_TREE 254/255, SWAY_BUSH 253/255) leans from its base,
// more toward its top; a slow wave crosses the map so neighbouring trees are a little out of step. Every other
// draw is untouched. The slab's geometry stays cached: only the vertices move, with TIME.

uniform float wind = 0.0;  // the map's look: 0 still air, 1 a light breeze (data/looks.csv `wind`)
uniform float lean = 2.6;  // board pixels a full tree's top leans at wind 1

void vertex() {
	float a = round(COLOR.a * 255.0);
	float amount = a == 254.0 ? 1.0 : (a == 253.0 ? 0.5 : 0.0);
	if (amount > 0.0) {
		float k = 1.0 - UV.y;  // 0 at the base, 1 at the top of the picture
		float phase = VERTEX.x * 0.004 + VERTEX.y * 0.017;  // the wave across the map; little across one tree, so it bends, not shears
		float gust = 0.65 + 0.35 * sin(TIME * 0.31 + VERTEX.x * 0.004);
		VERTEX.x += sin(TIME * 1.25 + phase) * wind * lean * amount * gust * k * k;
		COLOR.a = 1.0;
	}
}
