shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
global uniform bool META_ENVIRONMENT_DEPTH_AVAILABLE;
global uniform highp sampler2DArray META_ENVIRONMENT_DEPTH_TEXTURE : filter_nearest, repeat_disable, hint_default_black;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT;
varying float valid_depth;
void vertex() {
    vec2 uv = UV;
    float d = textureLod(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(uv, 0.0), 0.0).r;
    valid_depth = (META_ENVIRONMENT_DEPTH_AVAILABLE && d > 0.0001 && d < 0.9999) ? 1.0 : 0.0;
    vec4 world = META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
    if (abs(world.w) > 0.00001) { VERTEX = (inverse(MODEL_MATRIX) * (world / world.w)).xyz; }
}
void fragment() {
    if (valid_depth < 0.99) { discard; }
    ALBEDO = vec3(0.10, 0.80, 0.75);
    ALPHA = 0.24;
}
