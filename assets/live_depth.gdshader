shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
global uniform bool META_ENVIRONMENT_DEPTH_AVAILABLE;
global uniform highp sampler2DArray META_ENVIRONMENT_DEPTH_TEXTURE : filter_nearest, repeat_disable, hint_default_black;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT;
uniform vec4 live_color : source_color = vec4(0.08, 0.9, 1.0, 1.0);
varying float valid_depth;
vec3 world_at(vec2 uv, float d) {
    vec4 p = META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
    return p.xyz / max(abs(p.w), 0.00001) * sign(p.w);
}
void vertex() {
    vec2 uv = clamp(UV, vec2(0.0001), vec2(0.9999));
    float d = textureLod(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(uv, 0.0), 0.0).r;
    vec2 step_uv = vec2(1.0 / 128.0, 1.0 / 96.0);
    vec2 ux = min(uv + vec2(step_uv.x, 0.0), vec2(0.9999));
    vec2 uy = min(uv + vec2(0.0, step_uv.y), vec2(0.9999));
    float dx = textureLod(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(ux, 0.0), 0.0).r;
    float dy = textureLod(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(uy, 0.0), 0.0).r;
    vec3 world = world_at(uv, d);
    bool samples_ok = d > 0.0001 && d < 0.9999 && dx > 0.0001 && dx < 0.9999 && dy > 0.0001 && dy < 0.9999;
    bool connected = distance(world, world_at(ux, dx)) < 0.35 && distance(world, world_at(uy, dy)) < 0.35;
    valid_depth = (META_ENVIRONMENT_DEPTH_AVAILABLE && samples_ok && connected) ? 1.0 : 0.0;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}
void fragment() {
    if (valid_depth < 0.99) { discard; }
    vec2 grid = abs(fract(UV * vec2(24.0, 18.0) + 0.5) - 0.5);
    float line = 1.0 - smoothstep(0.02, 0.06, min(grid.x, grid.y));
    ALBEDO = live_color.rgb;
    ALPHA = mix(0.13, 0.55, line);
}
