package flxanimate;

import openfl.display.BitmapData;
#if ANIMATE_SYS_PATHS
import sys.FileSystem;
import sys.io.File;
#else
import openfl.Assets;
#end

class Utils
{
	@:access(flixel.FlxCamera)
	public inline static function clearCameraDraws(camera:flixel.FlxCamera):flixel.FlxCamera
	{
		camera.clearDrawStack();
		camera.canvas.graphics.clear();
		return camera;
	}

	public inline static function directory(path:String):String
	{
		return path.substring(0, path.lastIndexOf("/"));
	}
	public inline static function withoutExtension(path:String):String
	{
		var cp = path.lastIndexOf(".");
		return cp == -1 ? path : path.substring(0, cp);
	}
	public inline static function extension(path:String):String
	{
		var cp = path.lastIndexOf(".");
		return cp == -1 ? null : path.substring(cp + 1);
	}

	@:access(openfl.display.BitmapData)
	public static function createBitmap(width:Int, height:Int, ?onlyTexture:Bool = true):BitmapData
	{
		var bmp = new BitmapData(width, height, true, 0x00000000);
		if (onlyTexture)
		{
			// if (bmp.__texture == null)
			{
				bmp.image.premultiplied = true;
				bmp.getTexture(flixel.FlxG.stage.context3D);
			}
			bmp.__surface = lime.graphics.cairo.CairoImageSurface.fromImage(bmp.image);

			// bmp.readable = true;
			bmp.image.data = null;
		}
		return bmp;
	}


	@:access(openfl.display.BitmapData)
	public static function dispose(bmp:BitmapData):BitmapData
	{
		if (bmp != null)
		{
			bmp.__texture?.dispose();
			bmp.dispose();
		}
		return null;
	}

	public inline static function withoutDirectory(path:String):String
		return path.substring(path.lastIndexOf("/") + 1);

	public inline static function getText(path:String):String
		return #if ANIMATE_SYS_PATHS File.getContent(path)      #else Assets.getText(path) #end;

	public inline static function getBytes(path:String)
		return #if ANIMATE_SYS_PATHS File.getBytes(path)        #else Assets.getBytes(path) #end;

	public inline static function getBitmapData(path:String):BitmapData
		return #if ANIMATE_SYS_PATHS BitmapData.fromFile(path)  #else Assets.getBitmapData(path) #end;

	public inline static function exists(path:String):Bool
		return #if ANIMATE_SYS_PATHS FileSystem.exists(path)    #else Assets.exists(path) #end;
}