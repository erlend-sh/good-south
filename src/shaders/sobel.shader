/*
	Sobel/Depth アウトラインシェーダー by あるる（きのもと 結衣）
	Sobel/Depth Outline Shader by Yui Kinomoto @arlez80

	MIT License
*/

shader_type spatial;
render_mode unshaded;

const vec3 MONOCHROME_SCALE = vec3( 0.298912, 0.586611, 0.114478 );

uniform vec4 outline_color : hint_color = vec4( 0.0, 0.0, 0.0, 1.0 );
uniform float luma_coef = 80.0;
uniform float color_coef = 80.0;
uniform float depth_coef = 8.0;
uniform float cutoff = 0.1;

float gaussian3x3( sampler2D tex, vec2 uv, vec2 pixel_size )
{
	float p = 0.0;
	float coef[25] = { 0.00390625, 0.015625, 0.0234375, 0.015625, 0.00390625, 0.015625, 0.0625, 0.09375, 0.0625, 0.015625, 0.0234375, 0.09375, 0.140625, 0.09375, 0.0234375, 0.015625, 0.0625, 0.09375, 0.0625, 0.015625, 0.00390625, 0.015625, 0.0234375, 0.015625, 0.00390625 };

	for( int y=-1; y<=1; y++ ) {
		for( int x=-1; x<=1; x ++ ) {
			p += textureLod( tex, uv + vec2( float( x ), float( y ) ) * pixel_size, 0.0 ).r * coef[(y+2)*5 + (x+2)];
		}
	}

	return p;
}

void fragment( )
{
	vec3 color[9];
	float depth[9];
	vec2 pixel_size = ( vec2( 1.0, 1.0 ) / VIEWPORT_SIZE ) * 1.15;

	// Gaussian FilterとSobel FilterでColor/Depthで取る
	for( int y=0; y<3; y ++ ) {
		for( int x=0; x<3; x ++ ) {
			vec2 uv = SCREEN_UV + vec2( float( x-1 ), float( y-1 ) ) * pixel_size;
			vec4 screen_pixel_vertex = vec4( 0.0, 0.0, gaussian3x3( DEPTH_TEXTURE, uv, pixel_size ) * 2.0 - 1.0, 1.0 );
			vec4 screen_pixel_coord = INV_PROJECTION_MATRIX * screen_pixel_vertex;

			color[y*3+x] = textureLod( SCREEN_TEXTURE, uv, 0.0 ).rgb;
			depth[y*3+x] = -( screen_pixel_coord.z / screen_pixel_coord.w );
		}
	}

	vec3 color_sobel_src_x = (
		color[0] * -1.0
	+	color[3] * -2.0
	+	color[6] * -1.0
	+	color[2] * 1.0
	+	color[5] * 2.0
	+	color[8] * 1.0
	);
	vec3 color_sobel_src_y = (
		color[0] * -1.0
	+	color[1] * -2.0
	+	color[2] * -1.0
	+	color[6] * 1.0
	+	color[7] * 2.0
	+	color[8] * 1.0
	);
	vec3 color_sobel = sqrt( color_sobel_src_x * color_sobel_src_x + color_sobel_src_y * color_sobel_src_y );

	vec2 depth_sobel_src = vec2(
		(
			depth[0] * -1.0
		+	depth[3] * -2.0
		+	depth[6] * -1.0
		+	depth[2] * 1.0
		+	depth[5] * 2.0
		+	depth[8] * 1.0
		)
	,	(
			depth[0] * -1.0
		+	depth[1] * -2.0
		+	depth[2] * -1.0
		+	depth[6] * 1.0
		+	depth[7] * 2.0
		+	depth[8] * 1.0
		)
	);
	float depth_sobel = clamp( sqrt( dot( depth_sobel_src, depth_sobel_src ) ), 0.0, 1.0 );
	// 
	ALBEDO = outline_color.rgb;
	ALPHA = clamp(
		depth_sobel * depth_coef
	+	depth_sobel * dot( color_sobel, MONOCHROME_SCALE ) * luma_coef
	+	depth_sobel * length( color_sobel ) * color_coef
	-	cutoff
	,	0.0
	,	1.0
	);
	DEPTH = 0.0;
}
