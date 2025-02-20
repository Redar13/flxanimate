package flxanimate.display;

import flixel.util.FlxPool;
import flxanimate.Utils;

class FlxPooledMatrix extends flixel.math.FlxMatrix implements IFlxPooled
{
	static var pool:FlxPool<FlxPooledMatrix> = new FlxPool(FlxPooledMatrix);
	public function put()
	{
		pool.put(this);
	}
	public static inline function get()
	{
		return pool.get();
	}
	public function destroy() {
		identity();
	}
}