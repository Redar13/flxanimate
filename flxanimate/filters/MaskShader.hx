package flxanimate.filters;

import flixel.system.FlxAssets.FlxShader;


/**
 * I did not steal this code from somewhere, specially not IADenner.
 */
class MaskShader extends FlxShader
{
	@:glFragmentSource('
#pragma header

uniform sampler2D mainPalette;
uniform vec2 relativePos;

const vec2 ZEROPOINT = vec2(0., 0.);
const vec2 ONEPOINT = vec2(1., 1.);
// return 1 if v inside the box, return 0 otherwise
float insideBox(vec2 v, vec2 bottomLeft, vec2 topRight)
{
    vec2 s = step(bottomLeft, v) - step(topRight, v);
    return s.x * s.y;
}

void main()
{
	vec2 maskPos = vec2(openfl_TextureCoordv.x + relativePos.x, openfl_TextureCoordv.y + relativePos.y);

	float maskAlpha = texture2D(mainPalette, maskPos).a * insideBox(maskPos, ZEROPOINT, ONEPOINT);

	// if ((maskPos.x < 0. || maskPos.x > 1.) || (maskPos.y < 0. || maskPos.y > 1.))
	// 	maskAlpha = 0.;

	gl_FragColor = texture2D(bitmap, openfl_TextureCoordv) * maskAlpha;
}
')

	public function new()
	{
		super();
		relativePos.value = [0, 0];
		mainPalette.wrap = CLAMP;
	}
}