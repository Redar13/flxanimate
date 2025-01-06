package flxanimate.frames;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.FlxG;

import openfl.geom.Rectangle;
import openfl.Assets;

import haxe.extern.EitherType;
import haxe.xml.Access;

import flxanimate.data.SpriteMapData;
import flxanimate.format.PropertyList;
import flxanimate.zip.Zip;

class FlxAnimateFrames extends FlxAtlasFrames
{
	// Well.. - Redar13
	public static var framesCollections = new Map<String, FlxAnimateFrames>();

	public function new()
	{
		super(null);
		parents = [];
	}

	static var data:AnimateAtlas = null;
	static var zip:Null<List<haxe.zip.Entry>>;

	public var parents:Array<FlxGraphic>;
	public static function clearCache()
	{
		for (_ => i in FlxAnimateFrames.framesCollections) i.destroy();
		FlxAnimateFrames.framesCollections.clear();
	}

	/**
	 * Helper function to parse several Spritemaps from a texture atlas via `fromSpritemap()`
	 *
	 * @param Path          The Path of the directory.
	 * @return              a new instance of `FlxAnimateFrames`.
	 * @see `fromSpriteMap()`
	 */
	public static function fromTextureAtlas(Path:String):FlxAnimateFrames
	{
		var frames:FlxAnimateFrames = framesCollections.get(Path);
		if (frames == null)
		{
			frames = new FlxAnimateFrames();


			if (zip != null || Utils.extension(Path) == "zip")
			{
				/*
				#if html5
				FlxG.log.error("Zip Stuff isn't supported on Html5 since it can't transform bytes into an image");
				return null;
				#else
				var imagemap:Map<String, haxe.io.Bytes> = new Map();
				var jsonMap:Map<String, AnimateAtlas> = new Map();
				var thing = zip == null ? Zip.unzip(Zip.readZip(Utils.getBytes(Path))) : zip;
				for (list in thing)
				{
					switch (Utils.extension(list.fileName))
					{
						case "json":
							jsonMap.set(list.fileName, haxe.Json.parse(StringTools.replace(list.data.toString(), String.fromCharCode(0xFEFF), "")));
						case "png":
							imagemap.set(list.fileName.split("/").pop(), list.data);
					}
				}
				// Assuming the json has the same stuff as the image stuff
				for (nameFile => curJson in jsonMap)
				{
					var curImage = openfl.display.BitmapData.fromBytes(imagemap[curJson.meta.image]);
					var spritemapFrames:FlxAtlasFrames;
					var graphic:FlxGraphic;
					var limb;
					var rect;
					if (curImage != null)
					{
						graphic = FlxG.bitmap.add(curImage, nameFile);

						spritemapFrames = new FlxAtlasFrames(graphic);
						for (sprite in curJson.ATLAS.SPRITES)
						{
							limb = sprite.SPRITE;
							rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
							if (limb.rotated)
								rect.setSize(rect.height, rect.width);

							sliceFrame(limb.name, limb.rotated, rect, spritemapFrames);
						}
						frames.addAtlas(spritemapFrames);
					}
					else
						FlxG.log.error('the Image called "${curJson.meta.image}" isnt in this zip file!');
				}
				zip = null;
				#end
				*/
				FlxG.log.error("Zip Stuff isn't supported");
				return null;
			}
			else
			{
				// var texts = Assets.list(TEXT).filter(text -> StringTools.startsWith(text, '$Path/sprite'));

				var texts = [];

				if (Utils.exists('$Path/spritemap.json'))
				{
					texts.push('$Path/spritemap.json');
				}
				else
				{
					var i = 1;
					while (Utils.exists('$Path/spritemap$i.json'))
						texts.push('$Path/spritemap${i++}.json');
				}

				var spritemapFrames:FlxAtlasFrames;
				for (text in texts)
				{
					spritemapFrames = fromSpriteMap(text);

					if (spritemapFrames != null)
						frames.addAtlas(spritemapFrames);
				}
			}

			if (frames.frames.length == 0)
			{
				FlxG.log.error("the Frames parsing couldn't parse any of the frames, it's completely empty! \n Maybe you misspelled the Path?");
				return null;
			}

			framesCollections.set(Path, frames);
		}
		return frames;
	}

	/**
	 * Parses a spritemap, proceeding from a texture atlas export.
	 * @param Path
	 * @param Image
	 * @return FlxAtlasFrames
	 */
	public static function fromSpriteMap(Path:FlxSpriteMap, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
		if (Path == null)
			return null;

		var json:AnimateAtlas = null;

		if (Path is String)
		{
			var str:String = cast (Path, String).split("\\").join("/");
			var text = (StringTools.contains(str, "/")) ? Utils.getText(str) : str;
			json = haxe.Json.parse(text.split(String.fromCharCode(0xFEFF)).join(""));
		}
		else
			json = Path;


		if (json == null)
			return null;

		if (Image == null)
		{
			if (Path is String)
				Image = haxe.io.Path.addTrailingSlash(Utils.directory(Path)) + json.meta.image;
			else
				return null;
		}

		var graphic:FlxGraphic = FlxG.bitmap.add((Std.isOfType(Image, String)) ? Utils.getBitmapData(Image) : Image);
		if (graphic == null)
			return null;

		// No need to parse data again
		var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;

		frames = new FlxAtlasFrames(graphic);

		var limb;
		var rect;
		for (sprite in json.ATLAS.SPRITES)
		{
			limb = sprite.SPRITE;
			rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
			if (limb.rotated)
				rect.setSize(rect.height, rect.width);

			sliceFrame(limb.name, limb.rotated, rect, frames);
		}
		return frames;
	}

	#if (flixel < "5.4.0")
	public function addAtlas(collection:FlxFramesCollection, overwriteHash:Bool = false):FlxAtlasFrames
	{
		if (collection.parent == null)
			throw "Cannot add atlas with null parent";

		if (parents.indexOf(collection.parent) == -1)
			parents.push(collection.parent);
		for (frame in collection.frames)
			pushFrame(frame);
		return this;
	}
	#else
	public override function addAtlas(collection:EitherType<FlxFramesCollection, FlxAtlasFrames>, overwriteHash:Bool = false):FlxAtlasFrames
	{
		if (collection is FlxAtlasFrames)
		{
			return super.addAtlas(cast collection, overwriteHash);
		}
		else
		{
			var collection:FlxFramesCollection = cast collection;
			if (collection.parent == null)
				throw "Cannot add atlas with null parent";

			if (parents.indexOf(collection.parent) == -1)
				parents.push(collection.parent);

			for (frame in collection.frames)
				pushFrame(frame, overwriteHash);

			return this;
		}
	}
	#end

	#if FLX_ANIMATE_PSYCH_SUPPOST
	// Compatibility with Psych Engine
    public inline function animateConcat(frames:FlxFramesCollection)
		return addAtlas(frames);

    /**
     *
     * @param Data the Json/XML file content/string
     * @param Image the image which the file is referencing **WARNING:** if you set the path as a json, it's obligatory to set the image!
     * @return A new instance of `FlxAtlasFrames`
     */
	public static function fromAnimateAtlas(Data:AnimateAtlas, Image:FlxGraphicAsset):FlxAnimateFrames
	{
		var graphic = FlxG.bitmap.add(Image);
		if (graphic == null)
			return null;
		var frames:FlxAnimateFrames = new FlxAnimateFrames();
		var spritemapFrames = FlxAtlasFrames.findFrame(graphic);
		if (spritemapFrames == null)
		{
			spritemapFrames = new FlxAtlasFrames(graphic);
			var limb;
			var rect;
			for (curSprite in Data.ATLAS.SPRITES)
			{
				limb = curSprite.SPRITE;
				rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
				if (limb.rotated)
					rect.setSize(rect.height, rect.width);

				sliceFrame(limb.name, limb.rotated, rect, spritemapFrames);
			}
		}
		graphic.addFrameCollection(spritemapFrames);
		frames.concat(spritemapFrames);

		if (frames.frames == [])
		{
			FlxG.log.error("the Frames parsing couldn't parse any of the frames, it's completely empty! \n Maybe you misspelled the Path?");
			return null;
		}
		return frames;
	}
	#end

	/**
	 * a `Sparrow` spritesheet enhancer, providing for the 'add only the XML Path' workflow while adding support to Sparrow v1.
	 * @param Path The direction of the Xml you want to parse.
	 * @param Image (Optional) the image of the Xml.
	 * @return A new instance of `FlxAtlasFrames`
	 */
	public static function fromSparrow(Path:FlxSparrow, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
		if (Path is String && !Utils.exists(Path))
			return null;

		var data:Xml = (Path is String) ? Xml.parse(Utils.getText(Path)).firstElement() : Path.firstElement();
		if (Image == null)
		{
			if (Path is String)
				Image = haxe.io.Path.addTrailingSlash(Utils.directory(Path)) + data.get("imagePath");
			else
				return null;
		}

		for(node in data.elements()) {
			if(node.nodeName == "SubTexture") {
				if(node.exists("w")) {
					node.set("width", node.get("w"));
					node.remove("w");
				}
				if(node.exists("h")) {
					node.set("height", node.get("h"));
					node.remove("h");
				}
			}
		}

		//var realData = data.toString();
		//if (realData.split("w=\"").length > 1)
		//{
		//	realData.split("w=\"").join("width=\"");
		//	realData.split("h=\"").join("height=\"");
		//}

		return fromSparrowDirect(Image, data);
	}

	public static function fromSparrowDirect(source:FlxGraphicAsset, xml:Xml):FlxAtlasFrames
	{
		var graphic:FlxGraphic = FlxG.bitmap.add(source);
		if (graphic == null)
			return null;
		// No need to parse data again
		var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;

		if (xml == null)
			return null;

		frames = new FlxAtlasFrames(graphic);

		var data:Access = new Access(xml);

		static var size:Rectangle = new Rectangle();
		for (texture in data.nodes.SubTexture)
		{
			var trimmed = texture.has.frameX;
			var rotated = (texture.has.rotated && texture.att.rotated == "true");

			var rect = FlxRect.get(Std.parseFloat(texture.att.x), Std.parseFloat(texture.att.y), Std.parseFloat(texture.att.width),
				Std.parseFloat(texture.att.height));

			if (trimmed)
			{
				size.setTo(Std.parseInt(texture.att.frameX), Std.parseInt(texture.att.frameY), Std.parseInt(texture.att.frameWidth),
					Std.parseInt(texture.att.frameHeight));
			}
			else
			{
				size.setTo(0, 0, rect.width, rect.height);
			}

			var sourceSize = FlxPoint.get(size.width, size.height);

			if (rotated && !trimmed)
				sourceSize.set(size.height, size.width);

			frames.addAtlasFrame(rect, sourceSize, FlxPoint.get(-size.left, -size.top), texture.att.name,
					rotated ? FlxFrameAngle.ANGLE_NEG_90 : FlxFrameAngle.ANGLE_0,
					(texture.has.flipX && texture.att.flipX == "true"),
					(texture.has.flipY && texture.att.flipY == "true")
				);
		}

		return frames;
	}

	/**
	 *
	 * @param Path the Json in specific, can be the path of it or the actual json
	 * @param Image the image which the file is referencing **WARNING:** if you set the path as a json, it's obligatory to set the image!
	 * @return A new instance of `FlxAtlasFrames`
	 */
	public static function fromJson(Path:FlxJson, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
		if (Path is String && !Utils.exists(Path))
			return null;
		var data:JsonNormal = (Path is String) ? haxe.Json.parse(Utils.getText(Path)) : Path;
		if (Image == null)
		{
			if (Path is String)
				Image = haxe.io.Path.addTrailingSlash(Utils.directory(Path)) + data.meta.image;
			else
				return null;
		}

		return FlxAtlasFrames.fromTexturePackerJson(Image, data);
	}

	/**
	 * Edge Animate
	 * @param Path the Path of the .eas
	 * @param Image (Optional) the Image
	 * @return Cute little Frames to use ;)
	 */
	public static inline function fromEdgeAnimate(Path:String, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
		return fromJson((StringTools.startsWith(Path, "{")) ? haxe.Json.parse(Path) : Path, Image);
	}

	/**
	 * Starling spritesheet format parser which uses a preference list from Mac computer shit
	 * @param Path the dir of the preference list
	 * @param Image (Optional) the Image
	 * @return Some recently cooked Frames for you ;)
	 */
	public static function fromStarling(Path:FlxPropertyList, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
		if (Path is String && !Utils.exists(Path))
			return null;
		var data:Plist = (Path is String) ? PropertyList.parse(Utils.getText(Path)) : Path;
		if (Image == null)
		{
			if (Path is String)
				Image = haxe.io.Path.addTrailingSlash(Utils.directory(Path)) + data.metadata.textureFileName;
			else
				return null;
		}

		var graphic:FlxGraphic = FlxG.bitmap.add(Image, false);
		if (graphic == null)
			return null;

		// No need to parse data again
		var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
		if (frames != null)
			return frames;

		frames = new FlxAtlasFrames(graphic);

		for (name in Reflect.fields(data.frames))
		{
			var data = Reflect.field(data.frames, name);

			var dimensions = FlxRect.get(Std.parseFloat(data.frame[0]), Std.parseFloat(data.frame[1]), Std.parseFloat(data.frame[2]),
			Std.parseFloat(data.frame[3]));

			var sourceSize = FlxPoint.get(Std.parseFloat(data.sourceSize[0]), Std.parseFloat(data.sourceSize[1]));

			var offset = FlxPoint.get(Std.parseFloat(data.offset[0]), Std.parseFloat(data.offset[1]));

			sliceFrame(name, data.rotated, dimensions, sourceSize, offset, frames);
		}

		return frames;
	}

	/**
	 * Cocos2D spritesheet format parser, which basically has 2 versions,
	 * One is basically Starling (2v) and the other one which is a more fucky and weird (3v)
	 * @param Path the Path of the plist
	 * @param Image (Optional) the image
	 * @return Recently made Frames for your dispose ;)
	 */
	public static function fromCocos2D(Path:String, ?Image:FlxGraphicAsset):FlxAtlasFrames
	{
		if (!Utils.exists(Path))
			return null;
		var data:Plist = PropertyList.parse(Utils.getText(Path));
		if (data.metadata.format == 2)
		{
			return fromStarling(Path, Image);
		}
		else
		{
			if (Image == null)
			{
				if (Path is String)
					Image = haxe.io.Path.addTrailingSlash(Utils.directory(Path)) + data.metadata.target.name;
				else
					return null;
			}
			var graphic:FlxGraphic = FlxG.bitmap.add(Image);
			if (graphic == null)
				return null;

			// No need to parse data again
			var frames:FlxAtlasFrames = FlxAtlasFrames.findFrame(graphic);
			if (frames != null)
				return frames;

			frames = new FlxAtlasFrames(graphic);

			for (name in Reflect.fields(data.frames))
			{
				var data = Reflect.field(data.frames, name);

				var dimensions = FlxRect.get(Std.parseFloat(data.frame[0]), Std.parseFloat(data.frame[1]), Std.parseFloat(data.frame[2]),
				Std.parseFloat(data.frame[3]));

				var sourceSize = FlxPoint.get(Std.parseFloat(data.spriteSourceSize[0]), Std.parseFloat(data.spriteSourceSize[1]));

				var offset = FlxPoint.get(Std.parseFloat(data.spriteOffset[0]), Std.parseFloat(data.spriteOffset[1]));

				sliceFrame(name, data.textureRotated, dimensions, sourceSize, offset, frames);
			}

			return frames;
		}
	}

	/**
	 * EaselJS spritesheet format parser, pretty weird stuff.
	 * @param Path The Path of the jsFile
	 * @param Image (optional) the Path of the image
	 * @return New frames made for you to use ;)
	 */
	public static function fromEaselJS(Path:String, ?Image:FlxGraphicAsset):FlxAnimateFrames
	{
		var hugeFrames:FlxAnimateFrames = new FlxAnimateFrames();
		var separatedJS = Utils.getText(Path).split("\n");
		var lines:Array<String> = [];
		for (line in separatedJS)
		{
			if (StringTools.contains(line, "new createjs.SpriteSheet({"))
				lines.push(line);
		}
		var names:Array<String> = [];
		var jsons:Array<JSJson> = [];
		for (line in lines)
		{
			names.push(StringTools.replace(line.split(".")[0], "_", " "));
			var curJson = StringTools.replace(StringTools.replace(line.split("(")[1], ")", ""), ";", "");
			var parsedJson = haxe.Json.parse(~/({|,\s*)(\S+)(\s*:)/g.replace(curJson, '$1\"$2"$3'));
			jsons.push(parsedJson);
		}
		var prevName = "";
		var imagePath = Path.split("/");
		imagePath.pop();
		var times;
		var json;
		var bitmap;
		var frames;
		var initialFrame;
		for (i => name in names)
		{
			times = 0;
			json = jsons[i];
			bitmap = FlxG.bitmap.add(Utils.getBitmapData((Image == null) ? '${imagePath.join("/")}/${json.images[0]}' : Image));
			frames = new FlxAtlasFrames(bitmap);
			initialFrame = [json.frames[0][5], json.frames[0][6]];
			for (frame in json.frames)
			{
				sliceFrame(name, false, FlxRect.get(frame[0], frame[1], frame[2], frame[3]), null,
				FlxPoint.get(frame[5] - initialFrame[0], frame[6] - initialFrame[1]), frames);
				times++;
			}
			hugeFrames.addAtlas(frames);
		}
		return hugeFrames;
	}

	public static function sliceFrame(name:String, rotated:Bool, dimensions:FlxRect, ?sourceSize:FlxPoint, ?offset:FlxPoint, Frames:FlxAtlasFrames)
	{
		if (rotated)
			dimensions.setSize(dimensions.height, dimensions.width);

		if (dimensions.width == 0 || dimensions.height == 0)
			Frames.addEmptyFrame(FlxRect.get(0, 0, 1, 1));
		else
			Frames.addAtlasFrame(dimensions,
				sourceSize ?? FlxPoint.get(dimensions.x, dimensions.y),
				(offset != null) ? offset.negate() : FlxPoint.get(),
				name, (rotated) ? ANGLE_NEG_90 : ANGLE_0);
	}
}
