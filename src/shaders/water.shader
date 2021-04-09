shader_type spatial;
//render_mode unshaded;
render_mode depth_draw_opaque;
//render_mode blend_mix;

uniform sampler2D albedo_map;
uniform float peer_factor = 0.2;
 
uniform vec4 intersection_color : hint_color;
uniform float intersection_max_threshold = 0.8;
uniform sampler2D displ_tex : hint_white;
uniform float displ_amount = 0.6;
uniform float near = 0.15;
uniform float far = 300.0;
 

void fragment() {
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec2 displ = texture(displ_tex, UV - TIME / 40.0).rg;
	displ = ((displ * 2.0) - 1.0) * displ_amount;
	
	depth = depth * 2.0 - 1.0;
	depth = PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);
	depth = depth + VERTEX.z;
	depth += displ.x;
	
	vec4 albedo = texture(albedo_map, UV);
	
	depth = exp(-depth * peer_factor);
	vec4 col = mix(intersection_color, albedo, step(intersection_max_threshold, clamp(1.0 - depth, 0.0, 0.8)));
	ALBEDO = col.rgb;
	ALPHA = clamp(1.0 - depth * 1.4, 0.0, 1.0);
}