shader_type spatial;

render_mode wireframe, unshaded, cull_disabled, blend_mix;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 1.0, 0.5);

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA  = outline_color.a;
}
