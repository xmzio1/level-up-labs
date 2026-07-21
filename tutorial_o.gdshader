shader_type canvas_item;

uniform float darkness_intensity : hint_range(0.0, 1.0) = 0.5; // درجة عتمة الظل
uniform float radius : hint_range(0.0, 1.0) = 0.4;             // حجم الدائرة المظلمة

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    float alpha = smoothstep(0.0, radius, dist) * darkness_intensity;
    
    COLOR = vec4(vec3(0.0), alpha);
}