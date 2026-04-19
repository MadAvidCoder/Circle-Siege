shader_type canvas_item;

uniform vec2 drift_dir = vec2(0.07, 0.03);
uniform float drift_strength = 0.20;
uniform float warp2 = 0.06;
uniform float warp2_scale = 1.8;

uniform vec2 p0 = vec2(0.25, 0.30);
uniform vec2 p1 = vec2(0.75, 0.28);
uniform vec2 p2 = vec2(0.35, 0.78);
uniform vec2 p3 = vec2(0.78, 0.75);

uniform vec3 dark_col: source_color = vec3(0.04, 0.03, 0.06);
uniform vec3 light_col: source_color = vec3(0.83, 0.78, 1);

uniform float mix_strength = 0.47;
uniform float mid = 0.50;
uniform float range = 0.55;

uniform float softness = 1.5;
uniform float flow = 0.07;
uniform float time_scale = 0.035;
uniform float energy = 0.0;
uniform float beat = 0.0;

uniform float contrast = 1.0;
uniform float grain = 0.010;
uniform float vignette = 0.44;
uniform float brightness = 1.0;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

vec2 warp(vec2 uv, float t, float amt) {
    uv += amt * vec2(
        sin((uv.y * 3.0) + t * 0.7) + sin((uv.y * 7.0) - t * 0.35),
        sin((uv.x * 3.5) - t * 0.6) + sin((uv.x * 6.5) + t * 0.30)
    ) * 0.02;
    return uv;
}

float w_gauss(vec2 uv, vec2 p, float k) {
    vec2 d = uv - p;
    float r2 = dot(d, d);
    return exp(-r2 * k);
}

void fragment() {
    vec2 uv = UV;

    float t = TIME * time_scale * (1.0 + energy * 0.6);

	uv += drift_dir * t * drift_strength;

	float warp_amt = flow * (0.7 + energy * 0.9 + beat * 0.8);
	uv = warp(uv, t, warp_amt);

	uv = warp(uv, t * warp2_scale + 13.7, warp2 * (0.7 + energy * 0.6));

    float k = mix(6.0, 2.2, clamp(softness, 0.0, 2.0));
    float w0 = w_gauss(uv, p0, k);
    float w1 = w_gauss(uv, p1, k);
    float w2 = w_gauss(uv, p2, k);
    float w3 = w_gauss(uv, p3, k);

	float s = w0 + w1 + w2 + w3 + 1e-6;

	float n0 = w0 / s;
	float n1 = w1 / s;
	float n2 = w2 / s;
	float n3 = w3 / s;


	float dom = max(max(n0, n1), max(n2, n3)); // 0.25..1.0

	float field = clamp((dom - 0.25) / 0.75, 0.0, 1.0);

    float pop = 1.0 + beat * 0.25;
    field = pow(clamp(field, 0.0, 1.0), 1.0 / (contrast * pop));

	float f = (field - mid) / max(range, 1e-4) + 0.5;
	f = clamp(f, 0.0, 1.0);

	vec3 duo = mix(dark_col, light_col, f);
	vec3 base = mix(dark_col, light_col, 0.5);
	vec3 col = mix(base, duo, mix_strength);
	
    vec2 q = uv - vec2(0.5);
    float v = smoothstep(0.9, 0.1, dot(q, q) * 2.0);
    col *= mix(1.0 - vignette, 1.0, v);

    col *= brightness * (0.92 + energy * 0.18 + beat * 0.08);

    float g = (hash(uv * vec2(900.0, 500.0) + TIME) - 0.5) * 2.0;
    col += g * grain;

    COLOR = vec4(col, 1.0);
}