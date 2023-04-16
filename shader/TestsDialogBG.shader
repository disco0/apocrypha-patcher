shader_type canvas_item;
render_mode unshaded
    , skip_vertex_transform
	, blend_disabled;
	
/**
 * Based on https://old.reddit.com/r/gamemaker/comments/j7w52h/changing_the_x_y_coordinates_of_a_shader/
 */

// ---- SETTINGS ----------------------------------------------------------------

// cycle multiplier for a given screen height
// 2*PI = you see a complete sine wave from top..bottom
uniform float xSineCycles: hint_range(0.005, 10.0, 0.01) = 6.28;
uniform float ySineCycles: hint_range(0.005, 10.0, 0.01) = 6.28;

uniform float speed: hint_range(0.005, 10.0, 0.05) = 2.0;
// the amount of shearing (shifting of a single column or row)
// 1.0 = entire screen height offset (to both sides, meaning it's 2.0 in total)
uniform float xDistMag: hint_range(0.005, 10.0, 0.05) = 0.05;
uniform float yDistMag: hint_range(0.005, 10.0, 0.05) = 0.05;

uniform float alpha_mult: hint_range(0.001, 1.0, 0.05) = 1.0;

uniform sampler2D albedo_texture : hint_albedo;
uniform vec4 albedo_color: hint_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

const float pivot = 0.5;


// ---- CODE ----------------------------------------------------------------

void vertex()
{
	VERTEX = (WORLD_MATRIX * (EXTRA_MATRIX * vec4(VERTEX, 0.0, 1.0))).xy;
}

void fragment()
{
	vec2 ps = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 res = UV;
	vec2 ratio = (ps.x > ps.y) ? vec2(ps.y / ps.x, 1) : vec2(1, ps.x / ps.y);
	// isotropic scaling, ensuring entire texture fits into the view.
	//float minRes = min(res.x, res.y);

	// do the scaling.
	// After this, you should consider FRAGCOORD = 0..1, usually,
	// aside from overflow for wide-screen.
	vec2 scaled_fragcoord = res.xy / ratio;

	int tstep = 20;
	// the value for the sine has 2 inputs:
	// 1. the time, so that it animates.
	// 2. the y-row, so that ALL scanlines do not distort equally.
	float time   = TIME * speed; // float(int(int(TIME) * tstep) / tstep) * speed;
	float xAngle = time + res.y * ySineCycles;
	float yAngle = time + res.x * xSineCycles;

	vec2 distortOffset =
		// amount of shearing
		vec2(sin(xAngle), -cos(yAngle))
		// magnitude adjustment
		* vec2(xDistMag, yDistMag);

	// shear the coordinates
	scaled_fragcoord = (scaled_fragcoord + distortOffset + uv_offset) * uv_scale;

	COLOR = texture(albedo_texture, scaled_fragcoord);
	COLOR.rgb *= albedo_color.rgb;
	COLOR.a = COLOR.a * alpha_mult;

	// blue shift to look like water
	// COLOR.rgb = vec3(0.0, 0.2, 0.9) +
	//     COLOR.rgb * vec3(0.5, 0.6, 0.1);
}