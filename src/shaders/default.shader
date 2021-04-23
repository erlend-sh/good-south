shader_type spatial;
render_mode unshaded;
uniform sampler2D mat_cap;
uniform sampler2D default_texture;
uniform bool shaded = true;

void fragment() {
	vec2 v_n = (NORMAL.xy * 0.5) + vec2(0.5, 0.5);
	v_n.y = 1.0 - v_n.y;
	vec3 _matcap = texture(mat_cap, v_n).rgb;
	vec3 _default = texture(default_texture, UV).rgb;
	float color_sum = _default.r + _default.g + _default.b;
	vec3 v_col = vec3(COLOR[0], COLOR[1], COLOR[2]);
	if (shaded) {
		ALBEDO = (_matcap.r * v_col + _matcap.g * v_col + _matcap.b * v_col) / 2.0;
	}
	else {
		ALBEDO = v_col;
	}
}
