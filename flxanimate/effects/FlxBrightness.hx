package flxanimate.effects;

class FlxBrightness extends FlxColorEffect
{
	public var brightness(default, set):Float;

	public function new(brightness:Float)
	{
		this.brightness = brightness;

		super();
	}
	override function process()
	{
		c_Transform.redMultiplier = c_Transform.greenMultiplier = c_Transform.blueMultiplier =  1 - Math.abs(brightness);

		if (brightness >= 0)
			c_Transform.redOffset = c_Transform.greenOffset = c_Transform.blueOffset = Math.round(255 * brightness);
		else
			c_Transform.redOffset = c_Transform.greenOffset = c_Transform.blueOffset = 0;
	}

	inline function set_brightness(value:Float)
	{
		if (brightness != value) renderDirty = true;

		return brightness = value;
	}
}