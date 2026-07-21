shader_type canvas_item;


uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); 

uniform float border_thickness : hint_range(0.001, 0.2) = 0.01;

uniform float border_softness : hint_range(0.0, 1.0) = 0.005;


void fragment() {
    float left = smoothstep(0.0, border_thickness + border_softness, UV.x);
    float right = 1.0 - smoothstep(1.0 - border_thickness - border_softness, 1.0, UV.x);
    float top = smoothstep(0.0, border_thickness + border_softness, UV.y);
    float bottom = 1.0 - smoothstep(1.0 - border_thickness - border_softness, 1.0, UV.y);
    
    float mask = left * right * top * bottom;
    
    float border_mask = 1.0 - mask;
    
    COLOR = vec4(border_color.rgb, border_color.a * border_mask);
}