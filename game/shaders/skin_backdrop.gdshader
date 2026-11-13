shader_type canvas_item;
// The world behind a skin window (SkinBackdrop): the screen, blurred and pulled toward the window's dark green, cut to
// the window's rounded corners. The blur reads the screen's own mip levels, so it costs one lookup a pixel.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 size = vec2(100.0);
uniform float radius = 6.0;
uniform float blur = 3.2;
uniform vec4 tint : source_color = vec4(0.03, 0.1, 0.09, 0.5);

void fragment() {
	vec2 p = UV * size;
	vec2 d = abs(p - size * 0.5) - (size * 0.5 - vec2(radius));
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	vec3 c = textureLod(screen, SCREEN_UV, blur).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(grey), 0.35);  // calmer behind the words
	COLOR = vec4(mix(c, tint.rgb, tint.a), clamp(0.5 - dist, 0.0, 1.0) * COLOR.a);
}
