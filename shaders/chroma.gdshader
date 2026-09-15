shader_type canvas_item;
render_mode unshaded;
uniform float exposure : hint_range(0.5, 1.2) = 0.9;
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    // Generated RGB sprite plates use a magenta key. Preserve warm cloth and skin.
    float key = min(c.r, c.b) - c.g;
    float alpha = 1.0 - smoothstep(0.09, 0.30, key);
    vec3 ink = c.rgb;
    float spill = max(0.0, key - 0.08) * (1.0 - alpha);
    ink.rb -= vec2(spill * 0.55);
    COLOR = vec4(ink * exposure, c.a * alpha);
}
