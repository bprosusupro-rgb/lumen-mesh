shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform bool highlighted = false;
void fragment() {
    vec2 p = abs(UV - vec2(0.5)) - vec2(0.48, 0.34);
    float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 0.14;
    float mask = 1.0 - smoothstep(-0.012, 0.012, d);
    ALBEDO = highlighted ? vec3(0.08, 0.25, 0.28) : vec3(0.11, 0.13, 0.16);
    ALPHA = (highlighted ? 0.95 : 0.55) * mask;
}
