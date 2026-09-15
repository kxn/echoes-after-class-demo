shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D normals_tex : hint_normal, filter_linear, repeat_disable;
uniform sampler2D response_tex : filter_linear, repeat_disable;
uniform sampler2D blink_tex : source_color, filter_linear, repeat_disable;
uniform float blink_amount=0.0;
uniform vec4 uv_region=vec4(0.0,0.0,1.0,1.0);
uniform bool flipped=false;
uniform bool use_normals=true;
uniform bool faces_sun=true;
uniform float global_exposure=1.0;
uniform float idle_amount=0.0;
uniform float breath_phase=0.0;
uniform vec3 painted_shadow_tint=vec3(0.64,0.64,0.70);
varying vec3 response;
void vertex() {
    // Less than one screen pixel at the shoulders; feet remain planted.
    float upper=smoothstep(-1.7,1.6,VERTEX.y);
    VERTEX.y+=idle_amount*upper*0.009*sin(TIME*1.35+breath_phase);
}
void fragment() {
    vec2 p=UV;
    if(flipped) p.x=1.0-p.x;
    p=uv_region.xy+p*uv_region.zw;
    vec4 c=texture(albedo_tex,p);
    if(blink_amount>0.0) c.rgb=mix(c.rgb,texture(blink_tex,p).rgb,blink_amount);
    ALBEDO=c.rgb;
    EMISSION=c.rgb*painted_shadow_tint*global_exposure;
    ALPHA=c.a;
    ALPHA_SCISSOR_THRESHOLD=0.48;
    vec3 n=texture(normals_tex,p).rgb;
    if(flipped) n.r=1.0-n.r;
    NORMAL_MAP=use_normals?n:vec3(0.5,0.5,1.0);
    NORMAL_MAP_DEPTH=1.0;
    response=texture(response_tex,p).rgb;
    ROUGHNESS=1.0;
    SPECULAR=0.0;
}
void light() {
    // Painted illumination is the baseline. Light only ADDS a selected warm rim.
    // XY normal response intentionally models an illustrated silhouette, not a solid body.
    vec2 incoming=normalize(LIGHT.xy+vec2(0.0001));
    float facing=max(dot(NORMAL.xy,incoming),0.0);
    float edge=pow(clamp(1.0-abs(NORMAL.z),0.0,1.0),0.65);
    float selected=response.r*(facing*0.95+edge*0.15)+response.g*0.065;
    // Turning away keeps the painted/global values, without window-shaped highlights.
    DIFFUSE_LIGHT+=(faces_sun?selected:0.0)*ATTENUATION*LIGHT_COLOR/PI;
}
