shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D normals_tex : hint_normal, filter_linear, repeat_disable;
uniform vec4 uv_region = vec4(0.0,0.0,1.0,1.0);
uniform bool flipped = false;
uniform bool use_normals = true;
uniform float backscatter : hint_range(0.0,0.4) = 0.19;
void fragment() {
    vec2 local_uv=UV;
    if (flipped) local_uv.x=1.0-local_uv.x;
    vec2 tex_uv=uv_region.xy+local_uv*uv_region.zw;
    vec4 c=texture(albedo_tex,tex_uv);
    ALBEDO=c.rgb;
    ALPHA=c.a;
    ALPHA_SCISSOR_THRESHOLD=0.48;
    vec3 n=texture(normals_tex,tex_uv).rgb;
    if(flipped) n.r=1.0-n.r;
    NORMAL_MAP=use_normals ? n : vec3(0.5,0.5,1.0);
    NORMAL_MAP_DEPTH=0.85;
    ROUGHNESS=0.95;
    SPECULAR=0.08;
}
void light() {
    float ndl=dot(NORMAL,LIGHT);
    // Restrained painted cloth backscatter, modulated by the REAL shadow map.
    // This is an art-directed approximation, not recovered cloth thickness.
    float diffuse=max(ndl,0.0)+max(-ndl,0.0)*backscatter;
    DIFFUSE_LIGHT+=diffuse*ATTENUATION*LIGHT_COLOR/PI;
}
