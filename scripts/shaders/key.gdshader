shader_type canvas_item;

uniform float shine_width = 0.18;
uniform float shine_speed = 1.5;
uniform float shine_strength = 2.2;
uniform float shine_wait = 1.0; // seconds to wait after each shine

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // The full cycle is "shine moves across" + "pause"
    float shine_duration = 1.0 / shine_speed;
    float cycle_duration = shine_duration + shine_wait;
    float cycle_time = mod(TIME, cycle_duration);

    float shine_pos = cycle_time * shine_speed;

    // Only draw shine during the shine part, not the wait
    float shine = 0.0;
    if (cycle_time < shine_duration) {
        float dist = abs(UV.x - shine_pos);
        shine = smoothstep(shine_width, 0.0, dist);
    }

    COLOR = tex_color + vec4(vec3(shine_strength * shine), 0.0) * tex_color.a;
}
