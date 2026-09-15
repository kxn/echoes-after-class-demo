shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D painting : source_color, filter_linear, repeat_disable;
uniform sampler2D silhouette_0 : filter_linear, repeat_disable;
uniform sampler2D silhouette_1 : filter_linear, repeat_disable;
uniform sampler2D silhouette_2 : filter_linear, repeat_disable;
uniform sampler2D silhouette_3 : filter_linear, repeat_disable;
uniform vec4 card_bounds[4];
uniform vec4 regions[4];
uniform vec4 depths;
uniform vec4 flips;
uniform vec3 sun_ray=vec3(-0.45,-0.52,1.0);
uniform bool sun_enabled=true;
varying vec3 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float alpha_at(sampler2D tex,vec2 p,vec4 region) {
    if(any(lessThan(p,vec2(0.0)))||any(greaterThan(p,vec2(1.0)))) return 0.0;
    return texture(tex,region.xy+p*region.zw).a;
}
float soft_alpha(sampler2D tex,vec2 p,vec4 region,float r) {
    float a=alpha_at(tex,p,region)*0.20;
    a+=alpha_at(tex,p+vec2(r,0),region)*0.12;
    a+=alpha_at(tex,p-vec2(r,0),region)*0.12;
    a+=alpha_at(tex,p+vec2(0,r),region)*0.12;
    a+=alpha_at(tex,p-vec2(0,r),region)*0.12;
    a+=alpha_at(tex,p+vec2(r,r)*0.7,region)*0.08;
    a+=alpha_at(tex,p+vec2(-r,r)*0.7,region)*0.08;
    a+=alpha_at(tex,p+vec2(r,-r)*0.7,region)*0.08;
    a+=alpha_at(tex,p-vec2(r,r)*0.7,region)*0.08;
    return a;
}
float cast_shadow(sampler2D tex,int i) {
    float travel=(world_point.z-depths[i])/max(sun_ray.z,0.01);
    if(travel<=0.0) return 0.0;
    // Trace the exterior sun ray BACK to the animated character's actual card plane.
    vec3 hit=world_point-sun_ray*travel;
    vec2 p=(hit.xy-card_bounds[i].xy)/card_bounds[i].zw;
    p.y=1.0-p.y;
    if(flips[i]>0.5) p.x=1.0-p.x;
    float radius=0.004+travel*0.003;
    // Reject pixels outside the projected card before issuing nine texture taps.
    if(any(lessThan(p,vec2(-radius)))||any(greaterThan(p,vec2(1.0+radius)))) return 0.0;
    return soft_alpha(tex,p,regions[i],radius);
}
void fragment() {
    vec3 c=texture(painting,UV).rgb;
    float shadow=0.0;
    if(sun_enabled) {
        shadow=cast_shadow(silhouette_0,0);
        shadow=max(shadow,cast_shadow(silhouette_1,1));
        shadow=max(shadow,cast_shadow(silhouette_2,2));
        shadow=max(shadow,cast_shadow(silhouette_3,3));
    }
    float painted_sun=smoothstep(0.035,0.30,dot(c,vec3(0.2126,0.7152,0.0722)));
    ALBEDO=c*mix(vec3(1.0),vec3(0.49,0.54,0.63),shadow*painted_sun);
}
