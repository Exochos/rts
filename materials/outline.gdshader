shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(2.0, 2.0, 0.0, 2.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.05;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}