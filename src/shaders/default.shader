shader_type spatial;
render_mode unshaded;
uniform sampler2D mat_cap;
uniform sampler2D default_texture;


void fragment() {
  vec2 v_n = (NORMAL.xy * 0.5) + vec2(0.5, 0.5);
  v_n.y = 1.0 - v_n.y;

  //This applies your MatCap to Model using the created UV
  //ALBEDO = (texture(mat_cap, v_n).rgb * 1.4) * texture(default_texture, UV).rgb;
	vec3 _matcap = texture(default_texture, UV).rgb;
	vec3 _default = texture(mat_cap, v_n).rgb;
	float color_sum = _default.r + _default.g + _default.b;

	ALBEDO = (_default.r * _matcap.rgb +
	          _default.g * _matcap.rgb +
	          _default.b * _matcap.rgb)/ 2.0;
}
