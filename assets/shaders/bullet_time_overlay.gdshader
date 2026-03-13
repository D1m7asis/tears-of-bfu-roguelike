shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float active_strength : hint_range(0.0, 1.0) = 0.0;
uniform float charge_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(0.34, 0.75, 1.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered);

	float chroma = active_strength * (0.007 + (1.0 - charge_ratio) * 0.0105);
	vec2 shift = normalize(centered + vec2(0.0001)) * chroma * smoothstep(0.12, 0.8, dist);

	float r = texture(screen_tex, uv + shift).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - shift).b;
	vec3 color = vec3(r, g, b);

	float line_a = sin((uv.y + TIME * 0.18) * 1100.0) * 0.5 + 0.5;
	float line_b = sin((uv.y - TIME * 0.07) * 420.0) * 0.5 + 0.5;
	float scan_pattern = mix(line_a, line_b, 0.35);
	float scan_mix = active_strength * 0.28;
	color *= 1.0 - scan_mix + scan_pattern * scan_mix;

	float lcd_mask = step(0.5, fract(uv.y * 420.0));
	color *= 1.0 - active_strength * 0.11 * lcd_mask;

	float vignette = smoothstep(0.18, 0.88, dist);
	color = mix(color, color * (1.0 - vignette * (0.5 + active_strength * 0.55)), active_strength);

	float tint_mix = active_strength * (0.14 + (1.0 - charge_ratio) * 0.14);
	color = mix(color, mix(color, tint_color.rgb, 0.58), tint_mix);

	float bloom_edge = smoothstep(0.35, 0.95, dist) * active_strength * 0.12;
	color += tint_color.rgb * bloom_edge;

	COLOR = vec4(color, active_strength);
}
