package flxanimate;

import openfl.display.BitmapData;
#if ANIMATE_SYS_PATHS
import sys.FileSystem;
import sys.io.File;
#else
import openfl.Assets;
#end

using StringTools;

class ReverseArrayIterator<T> {
	final array:Array<T>;
	var current:Int;

	/**
		Create a new `ArrayIterator`.
	**/
	#if !hl inline #end
	public function new(array:Array<T>) {
		this.array = array;
		current = array.length - 1;
	}

	/**
		See `Iterator.hasNext`
	**/
	#if !hl inline #end
	public function hasNext() {
		return current > -1;
	}

	/**
		See `Iterator.next`
	**/
	#if !hl inline #end
	public function next() {
		return array[current--];
	}
    public static inline function reversedValues<T>(arr:Array<T>) {
        return new ReverseArrayIterator(arr);
    }
}

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
			bmp.image.premultiplied = true;
			bmp.getTexture(flixel.FlxG.stage.context3D);

			bmp.__surface = lime.graphics.cairo.CairoImageSurface.fromImage(bmp.image);

			bmp.readable = true;
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

	public dynamic static function getFolderContent(folder:String, ?folders:Null<Bool>, ?addPath:Bool):Array<String>
	{
		if (!folder.endsWith("/"))
			folder += "/";
		final colon = folder.indexOf(":");
		var l = "";
		var files:Array<String>;

		#if ANIMATE_SYS_PATHS
		if (colon == -1)
		{
			files = [
				for (e in FileSystem.readDirectory(folder)) if (folders == null || FileSystem.isDirectory('$folder$e') == folders) e
			];
		}
		else
		{
			l = folder.substring(0, colon);
			var folder = folder.substring(colon);
			files = [
				for (e in FileSystem.readDirectory(folder)) if (folders == null || FileSystem.isDirectory('$folder$e') == folders) e
			];
			l += ":";
		}
		#else
		if (colon == -1)
		{
			files = Assets.list();
		}
		else
		{
			l = folder.substring(0, colon);
			files = Assets.getLibrary(l).list(null);
			l += ":";
		}
		files = filterFileListByPath(files, folder, folders);
		#end

		if (addPath)
		{
			l += folder;
		}
		if (l.length > 0)
		{
			for (i in 0...files.length)
			{
				files[i] = l + files[i];
			}
		}

		return files;
	}

	public static function filterFileListByPath(iterList:Iterable<String>, targetFolder:String, ?getFolders:Null<Bool>):Array<String> {
		if (!targetFolder.endsWith("/"))
			targetFolder = targetFolder + "/";

		var arrList = targetFolder.length == 1 ? [
			for (i in iterList) i
		] : [
			for (i in iterList)
				if (i.startsWith(targetFolder)
				&& (getFolders != null && (i.indexOf("/", targetFolder.length) != -1) == getFolders
				|| getFolders == null))
					i.substr(targetFolder.length)
		];

		if (getFolders != false && arrList.length > 0) {
			var i:Int = arrList.length;
			var i2:Int;
			while (i > 0) {
				i--;
				i2 = arrList[i].indexOf("/");
				if(i2 != -1)
					arrList[i] = arrList[i].substr(0, i2);
			}

			// remove duplicates
			i = arrList.length;
			while (i > 0) {
				i--;
				while (i != arrList.indexOf(arrList[i])) {
					arrList.splice(i, 1);
					i--;
				}
			}
		}
		return arrList;
	}

	public inline static function getText(path:String):String
		return #if ANIMATE_SYS_PATHS File.getContent(path)      #else Assets.getText(path) #end;

	public inline static function getBytes(path:String)
		return #if ANIMATE_SYS_PATHS File.getBytes(path)        #else Assets.getBytes(path) #end;

	public inline static function getBitmapData(path:String):BitmapData
		return #if ANIMATE_SYS_PATHS BitmapData.fromFile(path)  #else Assets.getBitmapData(path) #end;

	public inline static function exists(path:String):Bool
		return #if ANIMATE_SYS_PATHS FileSystem.exists(path)    #else Assets.exists(path) #end;
}
