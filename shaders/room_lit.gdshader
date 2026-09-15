shader_type spatial;
render_mode cull_disabled;
uniform sampler2D room_tex : source_color, filter_linear;
uniform bool is_floor = false;
uniform vec3 pigment : source_color = vec3(1.0);
bool glass(vec2 p) {
    bool band=p.y>0.120 && p.y<0.515;
    bool opening=(p.x>0.169&&p.x<0.242)||(p.x>0.289&&p.x<0.360)||(p.x>0.416&&p.x<0.493)||(p.x>0.607&&p.x<0.682)||(p.x>0.733&&p.x<0.806)||(p.x>0.850&&p.x<0.914);
    return band&&opening;
}
void fragment() {
    vec2 tex_uv=UV;
    if(is_floor) tex_uv=vec2(UV.x,0.718+UV.y*0.280);
    vec3 color=texture(room_tex,tex_uv).rgb;
    ALBEDO=color*pigment;
    ROUGHNESS=0.97;
    SPECULAR=0.07;
    if(!is_floor&&glass(UV)) { ALBEDO=vec3(0.0); EMISSION=color*0.86; }
}
