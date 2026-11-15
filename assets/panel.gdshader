shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

void fragment() {
    vec2 p = abs(UV - vec2(0.5)) - vec2(0.455, 0.44);
    float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 0.04;
    float mask = 1.0 - smoothstep(-0.004, 0.004, d);
    vec3 top = vec3(0.11, 0.13, 0.15);
    vec3 bottom = vec3(0.045, 0.055, 0.065);
    ALBEDO = mix(bottom, top, UV.y);
    ALPHA = 0.96 * mask;
}
