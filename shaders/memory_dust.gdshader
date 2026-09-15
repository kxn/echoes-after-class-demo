shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float phase=0.0;
varying float visibility;
void vertex() {
    VERTEX.x+=0.045*sin(TIME*0.13+phase);
    VERTEX.y+=0.10*sin(TIME*0.075+phase*2.0);
    visibility=pow(0.5+0.5*sin(TIME*0.23+phase),3.0);
}
void fragment() {
    float glow=1.0-smoothstep(0.10,0.50,length(UV-vec2(0.5)));
    ALBEDO=vec3(0.94,0.75,0.46);
    ALPHA=glow*visibility*0.18;
}
