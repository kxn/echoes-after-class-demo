shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 light_uv = vec2(0.85, 0.32);
uniform float strength = 0.3;
uniform bool enabled = true;
void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 scene = texture(screen_tex, uv).rgb;
    vec2 p = (uv-light_uv)*vec2(1.6,1.0);
    float halo = exp(-dot(p,p)*6.5);
    float core = exp(-dot(p,p)*120.0);
    float streak = exp(-abs(p.y)*170.0)*exp(-abs(p.x)*2.6);
    vec2 ghost_center = vec2(0.5)+(vec2(0.5)-light_uv)*0.58;
    float ghost_dist=length((uv-ghost_center)*vec2(1.6,1.0));
    float ring=exp(-pow((ghost_dist-0.11)*90.0,2.0))*0.025;
    vec3 flare=(vec3(1.0,0.59,0.22)*(halo*0.17+core*0.14+streak*0.1)+vec3(0.75,0.55,0.28)*ring)*strength;
    float vignette = smoothstep(0.3,0.91,length((uv-0.5)*vec2(1.05,0.86)));
    // Stationary grain, a matte finish; never obscure the HUD (drawn later).
    float grain = fract(sin(dot(floor(uv*vec2(1440.0,900.0)), vec2(12.9898,78.233)))*43758.5453)-0.5;
    COLOR=vec4(scene*(1.0-vignette*0.19)+ (enabled ? flare : vec3(0.0)) + grain*0.006,1.0);
}
