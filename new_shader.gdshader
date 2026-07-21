shader_type canvas_item;

uniform vec2 shadow_offset = vec2(3.0, 3.0); // مسافة الإزاحة (تقليلها يعطي ظل أحدث وأصغر)
uniform float shadow_scale : hint_range(0.1, 1.0) = 0.8; // نسبة تصغير الظل (0.8 = 80% من حجم الشخصية)
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // لون وشفافية الظل

void fragment() {
    vec2 shadow_uv = (UV - vec2(0.5)) / shadow_scale + vec2(0.5);
    
    shadow_uv -= shadow_offset * TEXTURE_PIXEL_SIZE;
    
    vec4 shadow_tex = vec4(0.0);
    if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 && shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0) {
        shadow_tex = texture(TEXTURE, shadow_uv);
    }
    
    vec4 shadow = vec4(shadow_color.rgb, shadow_tex.a * shadow_color.a);
    
    vec4 current_color = texture(TEXTURE, UV);
    
    COLOR = mix(shadow, current_color, current_color.a);
}