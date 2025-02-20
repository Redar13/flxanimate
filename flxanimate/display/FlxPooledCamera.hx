package flxanimate.display;

import flixel.util.FlxPool;
import flxanimate.Utils;

class FlxPooledCamera extends flixel.FlxCamera implements IFlxPooled
{
	static var pool:FlxPool<FlxPooledCamera> = new FlxPool(FlxPooledCamera);
	public function put()
	{
		pool.put(this);
	}
	public static inline function get()
	{
		return pool.get();
	}
	public override function destroy() {
		Utils.clearCameraDraws(this);
	}
	public function superDestroy()
	{
		super.destroy();
	}
}
