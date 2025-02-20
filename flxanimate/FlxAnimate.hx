package flxanimate;

import flixel.animation.FlxAnimationController;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
#if FLX_SOUND_SYSTEM
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
#end
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.tile.FlxBaseTilemap;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxPool;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;

import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Sprite;
import openfl.filters.BitmapFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Assets;

import flxanimate.animate.*;
import flxanimate.animate.FlxAnim;
import flxanimate.data.AnimationData;
import flxanimate.display.FlxAnimateFilterRenderer;
import flxanimate.display.FlxPooledMatrix;
import flxanimate.display.FlxPooledCamera;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.geom.FlxMatrix3D;
import flxanimate.interfaces.IFilterable;
import flxanimate.zip.Zip;
import flxanimate.Utils;

import haxe.ds.StringMap;
import haxe.extern.EitherType;
import haxe.io.BytesInput;


typedef Settings = {
	?ButtonSettings:Map<String, flxanimate.animate.FlxAnim.ButtonSettings>,
	?FrameRate:Float,
	?Reversed:Bool,
	?OnComplete:String->String->Void,
	?ShowPivot:Bool,
	?Antialiasing:Bool,
	?ScrollFactor:FlxPoint,
	?Offset:FlxPoint,
}

@:access(flixel.FlxCamera)
@:access(flixel.graphics.frames.FlxFrame)
@:access(flxanimate.animate.FlxAnim)
@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Rectangle)
class FlxAnimate extends FlxSprite // TODO: MultipleAnimateAnims suppost
{
	public var useAtlas(get, never):Bool;
	public var toggleAtlas:Bool = true;

	public var anim(default, null):FlxAnim;

	#if FLX_SOUND_SYSTEM
	public var audioGroup:FlxSoundGroup;
	#end

	var rect:Rectangle;

	public var showPivot(default, set):Bool;
	public var showPosPoint:Bool = true;
	public var showMidPoint:Bool = true;
	public var pivotScale:Float = 0.8;

	public var filters:Array<BitmapFilter> = null; // TODO?

	var _pivot:FlxFrame;
	var _indicator:FlxFrame;

	static var renderer:FlxAnimateFilterRenderer;

	@:isVar
	public var metadata(get, never):FlxMetaData;
	inline function get_metadata()
	{
		return anim.metadata;
	}

	@:isVar
	public var skipFilters(get, set):Bool;
	inline function get_skipFilters()
	{
		return metadata.skipFilters;
	}
	inline function set_skipFilters(i)
	{
		return metadata.skipFilters = i;
	}

	@:isVar
	public var skipBlends(get, set):Bool;
	inline function get_skipBlends()
	{
		return metadata.skipBlends ?? false;
	}
	inline function set_skipBlends(i)
	{
		return metadata.skipBlends = i;
	}

	@:isVar
	public var showHiddenLayers(get, set):Bool;
	inline function get_showHiddenLayers()
	{
		return metadata.showHiddenLayers ?? false;
	}
	inline function set_showHiddenLayers(i)
	{
		return metadata.showHiddenLayers = i;
	}

	public var relativeX:Float = 0;

	public var relativeY:Float = 0;

	/**
	 * # Description
	 * The `FlxAnimate` class calculates in real time a texture atlas through
	 * ## WARNINGS
	 * - This does **NOT** convert the frames into a spritesheet
	 * - Since this is some sort of beta, expect that there could be some inconveniences (bugs, crashes, etc).
	 *
	 * @param X 		The initial X position of the sprite.
	 * @param Y 		The initial Y position of the sprite.
	 * @param Path      The path to the texture atlas, **NOT** the path of the any of the files inside the texture atlas (`Animation.json`, `spritemap.json`, etc).
	 * @param Settings  Optional settings for the animation (antialiasing, framerate, reversed, etc.).
	 * @param predraw  Optional thing for init sizes.
	 */
	public function new(X:Float = 0, Y:Float = 0, ?SimpleGraphic:FlxGraphicAsset, ?Settings:Settings)
	{
		if (FlxAnimate.renderer == null)
			FlxAnimate.renderer = new FlxAnimateFilterRenderer();
		super(X, Y);
		if (SimpleGraphic != null)
		{
			if (Std.isOfType(SimpleGraphic, String))
				loadAtlas(cast SimpleGraphic);
			else
				loadGraphic(SimpleGraphic);
		}
		if (Settings != null)
			setTheSettings(Settings);

		rect = Rectangle.__pool.get();
	}

	public var atlasIsValid(default, null):Bool = false;

	/**
	 * Loads a regular atlas.
	 * @param Path The path where the atlas is located. Must be the folder, **NOT** any of the contents of it!
	 */
	public function loadAtlas(Path:String)
	{
		var oldValid = atlasIsValid;
		atlasIsValid = false;
		if (!Utils.exists('$Path/Animation.json') && Utils.extension(Path) != "zip")
		{
			// kill();
			FlxG.log.error('Animation file not found in specified path: "$Path", have you written the correct path?');
			return;
		}
		// if (!oldValid) revive();
		anim = FlxDestroyUtil.destroy(anim);
		anim = new FlxAnim(this);
		atlasIsValid = true;
		if (Utils.exists('$Path/metadata.json'))
		{
			// BetterTA https://github.com/Dot-Stuff/BetterTextureAtlas
			loadSeparateAtlas(null, FlxAnimateFrames.fromTextureAtlas(Path));
			anim._loadExAtlas(Path);
		}
		else
		{
			loadSeparateAtlas(atlasSetting(Path), FlxAnimateFrames.fromTextureAtlas(Path));
		}
	}
	/**
	 * Function in handy to load atlases that share same animation/frames but dont necessarily mean it comes together.
	 * @param animation The animation file. This should be the content of the `JSON`, **NOT** the path of it.
	 * @param frames The collection of frames.
	 */
	public function loadSeparateAtlas(?animation:String = null, ?frames:FlxFramesCollection = null)
	{
		if (frames != null)
			this.frames = frames;
		if (animation != null)
		{
			/*
			var eReg = ~/"(F|filters)": /,
				eReg2 = ~/(\{([^{}]|(?R))*\})/s,
				eReg3 = ~/("(.+)")/;

			var lastMatch = 0, position, filterPos = null;


			while (eReg.matchSub(animation, lastMatch))
			{
				position = eReg.matchedPos();

				if (eReg2.matchSub(animation, position.pos + position.len))
				{

					var string = eReg2.matched(0);
					if (lastMatch == 0)
					{
						var pos = eReg2.matchedPos();
						filterPos = {pos: position.pos, len: position.len + (pos.pos - position.pos + pos.len)};
					}
					position = eReg2.matchedPos();

					var len = 0;
					var repeated:Map<String, Int> = [];
					while (eReg3.matchSub(animation, position.pos + len, filterPos.pos + filterPos.len))
					{
						var filter = eReg3.matched(0);
						position = eReg3.matchedPos();


						if (repeated.exists(filter))
						{
							var mod = '"${filter.substring(1, filter.length - 1)}_${repeated.get(filter) + 1}"';

							animation = animation.substring(0, position.pos) + mod + animation.substring(position.pos + position.len);
							repeated.set(filter, repeated.get(filter) + 1);
						}
						else
							repeated.set(filter, 0);

						len += position.len;

						if (eReg2.matchSub(animation, position.pos + len))
						{
							var pos = eReg2.matchedPos();
							len += (pos.pos - position.pos) + pos.len;
						}
					}

					position = eReg2.matchedPos();
				}

				lastMatch = position.pos + position.len;
			}
			*/

			anim._loadAtlas(haxe.Json.parse(animation));

			if (anim != null && anim.curInstance != null)
				origin = anim.curInstance.symbol.transformationPoint;
		}
	}

	// TODO: PRECASHE FILTERS FUNC

	var _camerasCashePoints(default, null):Array<FlxPoint> = [];
	/**
	 * the function `draw()` renders the symbol that `anim` has currently plus a pivot that you can toggle on or off.
	 */
	public override function draw():Void
	{
		if(alpha == 0) return;
		//updateSkewMatrix();

		if (useAtlas)
		{
			var _point:FlxPoint;
			for (i => camera in cameras)
			{
				_point = getScreenPosition(_camerasCashePoints[i], camera);
				_point.subtractPoint(offset);
				_point.addPoint(origin);
				_camerasCashePoints[i] = _point;
			}

			updateTrig();
			if (anim.curInstance != null)
			{
				_flashRect.setEmpty();

				anim.curInstance.updateRender(_lastElapsed, anim.curFrame, anim.symbolDictionary, anim.swfRender);
				_matrix.identity();
				if (flipX != anim.curInstance.flipX)
				{
					_matrix.a *= -1;
					// _matrix.tx += width;
				}
				if (flipY != anim.curInstance.flipY)
				{
					_matrix.d *= -1;
					// _matrix.ty += height;
				}
				if (frames != null)
				{
					parseElement(anim.curInstance, _matrix, colorTransform, null, false, blend, cameras);
				}

				width = Math.abs(_flashRect.width);
				height = Math.abs(_flashRect.height);
				frameWidth = Math.round(width / scale.x);
				frameHeight = Math.round(height / scale.y);

				relativeX = _flashRect.x - x;
				relativeY = _flashRect.y - y;
				#if FLX_DEBUG
				if (FlxG.debugger.drawDebug) // draw hitbox
				{
					drawDebug();
				}
				#end

			}
		}
		else
		{
			relativeX = relativeY = 0;
			basicDraw();
		}

		if (showPivot && (showPosPoint || showMidPoint))
		{
			var mat = FlxPooledMatrix.get();
			if (showMidPoint)
			{
				mat.translate(-_pivot.frame.width * 0.5, -_pivot.frame.height * 0.5);
				mat.scale(pivotScale / camera.zoom, pivotScale / camera.zoom);
				mat.translate(origin.x, origin.y);
				// mat.translate(-offset.x, -offset.y);
				drawPivotLimb(_pivot, mat, cameras);
				mat.identity();
			}
			if (showPosPoint)
			{
				mat.translate(-_indicator.frame.width * 0.5, -_indicator.frame.height * 0.5);
				mat.scale(pivotScale / camera.zoom, pivotScale / camera.zoom);
				// mat.translate(-offset.x, -offset.y);
				drawPivotLimb(_indicator, mat, cameras);
			}
			mat.put();
		}
	}

	public function basicDraw()
	{
		super.draw();
	}

	@:access(flixel.group.FlxTypedGroup)
	public override function overlaps(objectOrGroup:FlxBasic, inScreenSpace:Bool = false, ?camera:FlxCamera):Bool
	{
		var group = FlxTypedGroup.resolveGroup(objectOrGroup);
		if (group != null) // if it is a group
		{
			return group.any(overlapsCallback.bind(_, 0, 0, inScreenSpace, camera));
		}

		if (objectOrGroup.flixelType == TILEMAP)
		{
			// Since tilemap's have to be the caller, not the target, to do proper tile-based collisions,
			// we redirect the call to the tilemap overlap here.
			var tilemap:FlxBaseTilemap<Dynamic> = cast objectOrGroup;
			return tilemap.overlaps(this, inScreenSpace, camera);
		}

		var object:FlxObject = cast objectOrGroup;
		if (!inScreenSpace)
		{
			return (object.x + object.width > x + relativeX) && (object.x < x + relativeX + width) && (object.y + object.height > y + relativeY) && (object.y < y + relativeY + height);
		}

		if (camera == null)
		{
			camera = FlxG.camera;
		}
		var objectScreenPos:FlxPoint = object.getScreenPosition(null, camera);
		getScreenPosition(_point, camera);
		_point.add(relativeX, relativeY);
		return (objectScreenPos.x + object.width > _point.x)
			&& (objectScreenPos.x < _point.x + width)
			&& (objectScreenPos.y + object.height > _point.y)
			&& (objectScreenPos.y < _point.y + height);
	}

	override public function overlapsPoint(point:FlxPoint, inScreenSpace = false, ?camera:FlxCamera):Bool
	{
		if (!inScreenSpace)
		{
			var x = this.x + relativeX;
			var y = this.y + relativeY;
			var result = (point.x >= x) && (point.x < x + width) && (point.y >= y) && (point.y < y + height);
			point.putWeak();
			return result;
		}

		if (camera == null)
		{
			camera = FlxG.camera;
		}
		var xPos:Float = point.x - camera.scroll.x;
		var yPos:Float = point.y - camera.scroll.y;
		getScreenPosition(_point, camera);
		_point.add(relativeX, relativeY);
		point.putWeak();
		return (xPos >= _point.x) && (xPos < _point.x + width) && (yPos >= _point.y) && (yPos < _point.y + height);
	}

	public override function getBoundingBox(camera:FlxCamera):FlxRect
	{
		getScreenPosition(_point, camera);

		_rect.set(_point.x + relativeX, _point.y + relativeY, width, height);
		_rect = camera.transformRect(_rect);

		if (isPixelPerfectRender(camera))
		{
			_rect.floor();
		}

		return _rect;
	}

	public override function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (newRect == null)
			newRect = FlxRect.get();

		if (camera == null)
			camera = FlxG.camera;

		newRect.setPosition(x + relativeX, y + relativeY);
		if (pixelPerfectPosition)
			newRect.floor();
		_scaledOrigin.set(origin.x * scale.x, origin.y * scale.y);
		newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x + origin.x - _scaledOrigin.x;
		newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y + origin.y - _scaledOrigin.y;
		if (isPixelPerfectRender(camera))
			newRect.floor();
		newRect.setSize(frameWidth * Math.abs(scale.x), frameHeight * Math.abs(scale.y));
		return newRect.getRotatedBounds(angle, _scaledOrigin, newRect);
	}

	public var skew(default, null):FlxPoint = FlxPoint.get();

	static var _skewMatrix:FlxMatrix = new FlxMatrix();

	function updateSkewMatrix():Void
	{
		_skewMatrix.identity();

		if (skew.x != 0 || skew.y != 0)
		{
			_skewMatrix.b = Math.tan(skew.y * FlxAngle.TO_RAD);
			_skewMatrix.c = Math.tan(skew.x * FlxAngle.TO_RAD);
		}
	}

	/**
	 * Tranformation matrix for this sprite.
	 * Used only when matrixExposed is set to true
	 */
	public var transformMatrix(default, null):FlxMatrix = new FlxMatrix();

	/**
	 * Bool flag showing whether transformMatrix is used for rendering or not.
	 * False by default, which means that transformMatrix isn't used for rendering
	 */
	public var matrixExposed:Bool = false;

	@:noCompletion
	override function drawComplex(camera:FlxCamera):Void
	{
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);

		if (bakedRotationAngle <= 0)
		{
			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

		getScreenPosition(_point, camera).subtractPoint(offset);
		_point.add(origin.x, origin.y);
		if (matrixExposed)
		{
			_matrix.concat(transformMatrix);
		}
		else
		{
			updateSkewToMatrix(_matrix);
		}
		_matrix.translate(_point.x, _point.y);

		if (isPixelPerfectRender(camera))
		{
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}

		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}

	inline function _caltBasicMatrix(matrix:FlxMatrix, nextMatrix:FlxMatrix, instance:FlxElement)
	{
		matrix.copyFrom(instance.matrix);
		matrix.translate(instance.x, instance.y);
		matrix.concat(nextMatrix);
		return matrix;
	}

	inline function _caltFilterMatrix(matrix:FlxMatrix, nextMatrix:FlxMatrix, instance:FlxElement, filterInstance:IFilterable)
	{
		// matrix.copyFrom(instance.matrix);
		// matrix.concat(filterInstance._filterMatrix);
		matrix.copyFrom(filterInstance._filterMatrix);
		matrix.translate(instance.x, instance.y);
		matrix.concat(nextMatrix);
		return matrix;
	}

	function parseElement(instance:FlxElement, m:FlxMatrix, colorFilter:ColorTransform, ?filterInstance:FlxElement, ?filterin:Bool, ?blendMode:BlendMode, ?cameras:Array<FlxCamera>)
	{
		if (instance == null || !instance.visible)
			return;

		var mainSymbol = instance == anim.curInstance;

		if (cameras == null)
			cameras = this.cameras;

		var symbol:FlxSymbol = (instance.symbol != null) ? anim.symbolDictionary.get(instance.symbol.name) : null;

		if (instance.bitmap == null && symbol == null)
			return;

		var matrix = _caltBasicMatrix(instance._matrix, m, instance);

		var colorEffect = instance._color;

		colorEffect.__copyFrom(colorFilter);

		if (!skipBlends && instance.symbol != null && instance.symbol.blendMode != NORMAL)
			blendMode = instance.symbol.blendMode;

		if (instance.bitmap != null)
		{
			drawLimb(frames.getByName(instance.bitmap), matrix, colorEffect, filterin, blendMode, cameras);
			return;
		}

		final curIndexFrame:Int = switch (instance.symbol.type)
		{
			case Button: setButtonFrames(instance, matrix);
			default:	 instance.symbol._curFrame;
		}

		// var cacheToBitmap = !skipFilters && (instance.symbol.cacheAsBitmap/* || this.filters != null && mainSymbol*/) && filterInstance != instance;
		var cacheToBitmap = !skipFilters && instance.symbol.cacheAsBitmap && (!filterin || filterInstance != instance);

		if (cacheToBitmap)
		{
			if (instance.symbol._renderDirty || instance.symbol._filterFrame == null)
			{
				instance.symbol._filterCamera ??= FlxPooledCamera.get();

				instance.symbol._filterMatrix.identity();
				// instance.symbol._filterMatrix.copyFrom(instance.matrix);

				var colTr = ColorTransform.__pool.get();
				parseElement(instance, instance.symbol._filterMatrix, colTr, instance, true, [instance.symbol._filterCamera]);

				renderFilter(instance.symbol, instance.symbol.filters);
				instance.symbol._renderDirty = false;

				ColorTransform.__pool.release(colTr);
			}

			if (instance.symbol._filterFrame != null)
			{
				if (instance.symbol.colorEffect != null)
					colorEffect.concat(instance.symbol.colorEffect.getColor());

				matrix.copyFrom(instance.symbol._filterMatrix);
				matrix.concat(m);

				drawLimb(instance.symbol._filterFrame, matrix, colorEffect, filterin, blendMode, cameras);
			}
		}
		else
		{
			if (instance.symbol.colorEffect != null && (!filterin || filterInstance != instance))
				colorEffect.concat(instance.symbol.colorEffect.getColor());

			var layers = symbol.timeline.getList();

			var mat_temp = FlxPooledMatrix.get();
			var colorEffect_temp = ColorTransform.__pool.get();
			var layer:FlxLayer;
			var frame:FlxKeyFrame;
			for (i in 0...layers.length)
			{
				layer = layers[layers.length - 1 - i];

				if (!layer.visible && (!filterin && mainSymbol || !showHiddenLayers) /*|| layer.type == Clipper && layer._correctClip*/) continue;

				/*
				if (layer._clipper != null)
				{
					var layer = layer._clipper;
					layer._setCurFrame(curIndexFrame);
					frame = layer._currFrame;
					if (frame != null && frame._renderDirty)
					{
						maskCamera = FlxPooledCamera.get();
						mat_temp.identity();
						colorEffect_temp.__identity();
						renderLayer(frame, mat_temp, colorEffect_temp, instance, null, [maskCamera]);

						frame._renderDirty = false;
					}
				}
				*/

				layer._setCurFrame(curIndexFrame);

				frame = layer._currFrame;

				if (frame == null) continue;

				var toBitmap = !skipFilters && frame.filters != null;
				var isMasked = layer._clipper != null;
				var isMasker = layer.type == Clipper;

				colorEffect_temp.__copyFrom(colorEffect);
				if (frame.colorEffect != null)
					colorEffect_temp.concat(frame.colorEffect.getColor());

				if (toBitmap || isMasker)
				{
					if (!frame._renderDirty && layer._filterFrame != null)
					{
						drawLimb(layer._filterFrame, _caltFilterMatrix(mat_temp, matrix, instance, layer), colorEffect_temp, filterin, blendMode, (isMasked) ? [layer._clipper.maskCamera] : cameras);
						continue;
					}
					else
					{
						layer._filterCamera ??= FlxPooledCamera.get();
						if (isMasker && layer._filterFrame != null && frame.getList().length == 0)
							layer.updateBitmaps(layer._bmp1.rect);
					}
				}

				if (isMasked)
				{
					if (layer._clipper == null || layer._clipper._currFrame == null || layer._clipper._currFrame.getList().length == 0)
					{
						isMasked = false;
					}
					else
					{
						layer._clipper.maskCamera ??= FlxPooledCamera.get();
						if (!frame._renderDirty)
							continue;
					}
				}

				final useFilter = toBitmap || isMasker || isMasked;

				if (useFilter) mat_temp.identity();

				renderLayer(frame, useFilter ? mat_temp : matrix, colorEffect_temp, useFilter ? null : filterInstance, useFilter || filterin, useFilter ? null : blendMode, (toBitmap || isMasker) ? [layer._filterCamera] : (isMasked) ? [layer._clipper.maskCamera] : cameras);

				if (toBitmap)
				{
					layer._filterMatrix.identity();

					renderFilter(layer, frame.filters);

					frame._renderDirty = false;

					drawLimb(layer._filterFrame, _caltFilterMatrix(mat_temp, matrix, instance, layer), colorEffect_temp, filterin, blendMode, (isMasked) ? [layer._clipper.maskCamera] : cameras);
				}
				if (isMasker)
				{
					layer._filterMatrix.identity();

					renderMask(layer);

					drawLimb(layer._filterFrame, _caltFilterMatrix(mat_temp, matrix, instance, layer), colorEffect_temp, filterin, blendMode, cameras);
				}

				/*
				var toBitmap = !skipFilters && frame.filters != null;
				var isMasked = layer._clipper != null;
				var isMasker = layer.type == Clipper;

				colorEffect_temp.__copyFrom(colorEffect);
				if (frame.colorEffect != null)
					colorEffect_temp.concat(frame.colorEffect.getColor());

				if (!skipFilters && (frame.filters != null || layer.type.match(Clipped(_))))
				{
					if (frame._renderDirty || layer._filterFrame == null)
					{
						// render layer to _filterFrame
						var filterCamera = FlxPooledCamera.get();
						var colTr = ColorTransform.__pool.get();
						mat_temp.identity();
						layer._filterMatrix.identity();
						// layer._filterMatrix.concat(instance.matrix);
						renderLayer(frame, mat_temp, colTr, instance, null, [filterCamera]);
						renderFilter(layer, frame.filters, filterCamera, maskCamera);

						filterCamera.put();
						// maskCamera = FlxDestroyUtil.put();
						ColorTransform.__pool.release(colTr);

						frame._renderDirty = false;
					}

					mat_temp.copyFrom(layer._filterMatrix);
					mat_temp.translate(instance.x, instance.y);
					mat_temp.concat(m);
					mat_temp.translate(layer.x, layer.y);

					drawLimb(layer._filterFrame, mat_temp, colorEffect_temp, filterin, blendMode, cameras);
				}
				else
				{
					mat_temp.copyFrom(matrix);
					mat_temp.translate(layer.x, layer.y);
					renderLayer(frame, mat_temp, colorEffect_temp, filterInstance, blendMode, cameras);
				}
				*/
			}
			mat_temp.put();
			ColorTransform.__pool.release(colorEffect_temp);
		}
	}
	function renderLayer(frame:FlxKeyFrame, matrix:FlxMatrix, colorEffect:ColorTransform, ?filterInstance:FlxElement, ?filterin:Bool, ?blendMode:BlendMode, ?cameras:Array<FlxCamera>)
	{
		for (element in frame.getList())
			parseElement(element, matrix, colorEffect, filterInstance, filterin, blendMode, cameras);
	}
	@:access(flixel.FlxCamera)
	@:access(openfl.display.DisplayObject)
	@:access(openfl.filters.BitmapFilter)
	function renderFilter(filterInstance:IFilterable, filters:Array<BitmapFilter>)
	{
		var filterCamera = filterInstance._filterCamera;
		filterCamera.render();
		var graphicSize = filterCamera.canvas.getBounds(null);

		if (filters != null && filters.length > 0)
		{
			var extension = Rectangle.__pool.get();

			for (filter in filters)
			{
				extension.__expand(-filter.__leftExtension, -filter.__topExtension,
					filter.__leftExtension + filter.__rightExtension,
					filter.__topExtension + filter.__bottomExtension);
			}
			extension.__transform(extension, filterInstance._filterMatrix);
			graphicSize.width += extension.width * 1.5;
			graphicSize.height += extension.height * 1.5;
			graphicSize.x = extension.x * 1.5;
			graphicSize.y = extension.y * 1.5;

			Rectangle.__pool.release(extension);
		}
		else
		{
			graphicSize.x = graphicSize.y = 0;
		}
		filterInstance.updateBitmaps(graphicSize);

		var gfx = FlxAnimate.renderer.graphicstoBitmapData(filterCamera.canvas.graphics, filterInstance._bmp1);

		if (gfx == null)
		{
			Utils.clearCameraDraws(filterCamera);
			return;
		}

		var bounds = Rectangle.__pool.get();

		filterCamera.canvas.__getBounds(bounds, filterInstance._filterMatrix);

		FlxAnimate.renderer.applyFilter(gfx, filterInstance._filterFrame.parent.bitmap, filterInstance._bmp1, filterInstance._bmp2, filters, graphicSize);

		// filterInstance._filterMatrix.identity();
		filterInstance._filterMatrix.translate(bounds.x + graphicSize.x, bounds.y + graphicSize.y);

		Rectangle.__pool.release(bounds);
		Utils.clearCameraDraws(filterCamera);
	}

	function renderMask(instance:FlxLayer)
	{
		var masker = instance._filterCamera;
		masker.render();

		var bounds = masker.canvas.getBounds(null);

		if (bounds.width == 0 || bounds.height == 0)
		{
			Utils.clearCameraDraws(masker);
			return;
		}
		instance.updateBitmaps(bounds);

		var mask = instance.maskCamera;

		mask.render();
		var mBounds = mask.canvas.getBounds(null);

		if (mBounds.width == 0 || mBounds.height == 0)
		{
			Utils.clearCameraDraws(masker);
			Utils.clearCameraDraws(mask);
			return;
		}

		var lMask = FlxAnimate.renderer.graphicstoBitmapData(mask.canvas.graphics, instance._bmp1,
				new FlxPoint(mBounds.x - bounds.x, mBounds.y - bounds.y)
			);
		var mrBmp = FlxAnimate.renderer.graphicstoBitmapData(masker.canvas.graphics, instance._bmp2);
		// instance._filterFrame.parent.bitmap.copyPixels(instance._bmp1, instance._bmp1.rect, instance._bmp1.rect.topLeft, instance._bmp2, instance._bmp2.rect.topLeft, true);
		FlxAnimate.renderer.applyFilter(lMask, instance._filterFrame.parent.bitmap, lMask, null, null, mrBmp);

		// instance._filterMatrix.translate(mBounds.x + bounds.x, mBounds.y + bounds.y);

		instance._filterMatrix.translate(bounds.x, bounds.y);

		Utils.clearCameraDraws(masker);
		Utils.clearCameraDraws(mask);
	}

	static var _mousePoint:FlxPoint = new FlxPoint();
	var pressed:Bool = false;
	function setButtonFrames(instance:FlxElement, matrix:FlxMatrix) // TODO
	{
		var frame:Int = 0;
		#if (FLX_MOUSE && !mobile)
		var limb = frames.getByName(instance.bitmap);
		if (limb == null)
		{
			// trace("no boobs " + Std.string(instance));
			return 0;
		}
		var badPress:Bool = false;
		var goodPress:Bool = false;
		var isOverlaped:Bool = false;
		for (i in cameras)
		{
			FlxG.mouse.getScreenPosition(camera, _mousePoint);

			limb.frame.copyToFlash(rect);
			rect.setTo(0, 0, rect.width, rect.width);
			rect.__transform(rect, matrix);

			if (isOverlaped = FlxMath.pointInCoordinates(_mousePoint.x, _mousePoint.y, rect.x, rect.y, rect.width, rect.height))
				break;
		}
		final isPressed = FlxG.mouse.pressed;
		if (isPressed && isOverlaped)
		{
			goodPress = true;
		}
		if (isPressed && !isOverlaped && !goodPress)
		{
			badPress = true;
		}
		if (!isPressed)
		{
			badPress = false;
			goodPress = false;
		}
		if (isOverlaped && !badPress)
		{
			var event = anim.buttonMap.get(anim.curSymbol.name);
			if (FlxG.mouse.justPressed && !pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnClick : null #if FLX_SOUND_SYSTEM , event.Sound #end).fire();
				pressed = true;
			}
			frame = (isPressed) ? 2 : 1;

			if (FlxG.mouse.justReleased && pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnRelease : null #if FLX_SOUND_SYSTEM , event.Sound #end).fire();
				pressed = false;
			}
		}
		else
		{
			frame = 0;
		}
		#else
		FlxG.log.error("Button stuff isn't available");
		#end
		return frame;
	}
	function drawPivotLimb(limb:FlxFrame, matrix:FlxMatrix, ?cameras:Array<FlxCamera>)
	{
		if (limb == null || limb.type == EMPTY || limb.parent.isDestroyed)
			return;

		cameras ??= this.cameras;

		for (camera in cameras)
		{
			if (camera == null || !camera.visible || !camera.exists)
				return;

			_matrix.copyFrom(matrix);

			getScreenPosition(_point, camera);

			_matrix.translate(_point.x, _point.y);

			if (isPixelPerfectRender(camera))
			{
				_matrix.tx = Math.floor(_matrix.tx);
				_matrix.ty = Math.floor(_matrix.ty);
			}

			if (limbOnScreen(limb, _matrix, false, camera))
			{
				camera.drawPixels(limb, null, _matrix, null, null, antialiasing, this.shader);
				#if FLX_DEBUG
				FlxBasic.visibleCount++;
				#end
			}
		}
	}

	function drawLimb(limb:FlxFrame, matrix:FlxMatrix, ?colorTransform:ColorTransform, ?filterin:Bool, ?blendMode:BlendMode, ?cameras:Array<FlxCamera>)
	{
		if (/*colorTransform != null && (colorTransform.alphaMultiplier == 0 || colorTransform.alphaOffset == -255) ||*/ limb == null || limb.type == EMPTY)
			return;

		cameras ??= this.cameras;

		for (i => camera in cameras)
		{
			if (camera == null || !camera.visible || !camera.exists)
				return;

			limb.prepareMatrix(_matrix);
			_matrix.concat(matrix);

			if (!filterin)
			{
				_matrix.translate(-origin.x, -origin.y);

				_matrix.scale(scale.x, scale.y);

				if (bakedRotationAngle <= 0)
				{
					if (angle != 0)
						_matrix.rotateWithTrig(_cosAngle, _sinAngle);
				}

				if (matrixExposed)
				{
					_matrix.concat(transformMatrix);
				}
				else
				{
					updateSkewToMatrix(_matrix);
				}

				_matrix.translate(_camerasCashePoints[i].x, _camerasCashePoints[i].y);

				if (isPixelPerfectRender(camera))
				{
					_matrix.tx = Math.ffloor(_matrix.tx);
					_matrix.ty = Math.ffloor(_matrix.ty);
				}

				if (!limbOnScreen(limb, _matrix, true, camera))
					continue;
				#if FLX_DEBUG
				FlxBasic.visibleCount++;
				/*
				if (FlxG.debugger.drawDebug && !ignoreDrawDebug)
				{
					_rect.set(rect.x, rect.y, rect.width, rect.height);
					// _rect = camera.transformRect(_rect);
					// if (isPixelPerfectRender(camera))
					// {
					// 	_rect.floor();
					// }

					drawDebugLimbBoundingBox(beginDrawDebug(camera), _rect);
					endDrawDebug(camera);
				}
				*/
				#end
			}
			camera.drawPixels(limb, null, _matrix, colorTransform, blendMode, filterin || antialiasing, filterin ? null : this.shader);
		}
	}

	function updateSkewToMatrix(matrix:Matrix):Void // thx to rich
	{
		final tanX = -skew.x * FlxAngle.TO_RAD, tanY = skew.y * FlxAngle.TO_RAD;

		var old = matrix.a + matrix.b * tanX;
		matrix.b = matrix.a * tanY + matrix.b;
		matrix.a = old;

		old = matrix.c + matrix.d * tanX;
		matrix.d = matrix.c * tanY + matrix.d;
		matrix.c = old;

		old = matrix.tx + matrix.ty * tanX;
		matrix.ty = matrix.tx * tanY + matrix.ty;
		matrix.tx = old;
	}

	#if FLX_DEBUG
	/**
	 * Color used for the debug limbs rect.
	 * @since 4.2.0
	 */
	public var debugBoundingLimbBoxColor(default, set):FlxColor = FlxColor.PURPLE;

	@:noCompletion
	function set_debugBoundingLimbBoxColor(color:FlxColor)
	{
		return debugBoundingLimbBoxColor = color;
	}

	function drawDebugLimbBoundingBox(gfx:openfl.display.Graphics, rect:FlxRect)
	{
		// fill static graphics object with square shape
		gfx.lineStyle(0.7, debugBoundingLimbBoxColor, 0.4);
		gfx.drawRect(rect.x, rect.y, rect.width, rect.height);
	}
	#end

	function limbOnScreen(limb:FlxFrame, m:FlxMatrix, ?writeSize:Bool = true, ?Camera:FlxCamera)
	{
		Camera ??= FlxG.camera;

		rect.setTo(0, 0, limb.frame.width, limb.frame.height);

		rect.__transform(rect, m);

		_point.set(rect.x, rect.y);

		if (writeSize)
		{
			if (_flashRect.width == 0 || _flashRect.height == 0)
			{
				_flashRect.copyFrom(rect);
			}
			else if (rect.width != 0 && rect.height != 0)
			{
				var x0 = _flashRect.x > rect.x ? rect.x : _flashRect.x;
				var y0 = _flashRect.y > rect.y ? rect.y : _flashRect.y;
				var x1 = _flashRect.right < rect.right ? rect.right : _flashRect.right;
				var y1 = _flashRect.bottom < rect.bottom ? rect.bottom : _flashRect.bottom;

				_flashRect.setTo(x0, y0, x1 - x0, y1 - y0);
			}
		}

		return Camera.containsRect(FlxRect.weak(rect.x, rect.y, rect.width, rect.height));
	}

	override function destroy()
	{
		skew = FlxDestroyUtil.put(skew);
		anim = FlxDestroyUtil.destroy(anim);
		_camerasCashePoints = FlxDestroyUtil.putArray(_camerasCashePoints);
		super.destroy();
	}

	var _lastElapsed:Float;
	public override function updateAnimation(elapsed:Float)
	{
		_lastElapsed = elapsed;
		if (useAtlas)
		{
			anim.update(elapsed);
			// if (anim.curInstance != null) // TODO: Fix the animation update sequence
			// 	anim.curInstance.updateRender(elapsed, anim.curFrame, anim.symbolDictionary, anim.swfRender);
		}
		else
		{
			animation.update(elapsed);
		}
	}

	public function setButtonPack(button:String, callbacks:ClickStuff #if FLX_SOUND_SYSTEM , sound:FlxSound #end):Void
	{
		anim.buttonMap.set(button, {Callbacks: callbacks, #if FLX_SOUND_SYSTEM Sound:  sound #end});
	}

	function set_showPivot(value:Bool)
	{
		if (value != showPivot && (showPivot = value))
		{
			_pivot ??= FlxGraphic.fromBitmapData(Assets.getBitmapData("flxanimate/images/pivot.png"), "__pivot").imageFrame.frame;
			_indicator ??= FlxGraphic.fromBitmapData(Assets.getBitmapData("flxanimate/images/indicator.png"), "__indicator").imageFrame.frame;
		}

		return value;
	}

	/**
	 * Sets variables via a typedef. Something similar as having an ID class.
	 * @param Settings
	 */
	public function setTheSettings(?Settings:Settings):Void
	{
		antialiasing = Settings.Antialiasing;
		if (Settings.ButtonSettings != null)
		{
			anim.buttonMap = Settings.ButtonSettings;
			if (anim.symbolType != Button)
				anim.symbolType = Button;
		}
		if (Settings.Reversed != null)
			anim.reversed = Settings.Reversed;
		if (Settings.FrameRate != null)
			anim.framerate = (Settings.FrameRate > 0) ? metadata.frameRate : Settings.FrameRate;
		if (Settings.OnComplete != null)
			anim.onComplete.add(Settings.OnComplete);
		if (Settings.ShowPivot != null)
			showPivot = Settings.ShowPivot;
		if (Settings.Antialiasing != null)
			antialiasing = Settings.Antialiasing;
		if (Settings.ScrollFactor != null)
			scrollFactor = Settings.ScrollFactor;
		if (Settings.Offset != null)
			offset = Settings.Offset;
	}

	public static function fromSettings()
	{}

	function atlasSetting(Path:String)
	{
		var jsontxt:String = null;
		if (Utils.extension(Path) == "zip")
		{
			var thing = Zip.readZip(Utils.getBytes(Path));

			for (list in Zip.unzip(thing))
			{
				if (list.fileName.indexOf("Animation.json") != -1)
				{
					jsontxt = list.data.toString();
					thing.remove(list);
					continue;
				}
			}
			@:privateAccess
			FlxAnimateFrames.zip = thing;
		}
		else
		{
			jsontxt = Utils.getText('$Path/Animation.json');
		}

		return jsontxt;
	}

	#if FLX_ANIMATE_PSYCH_SUPPOST
	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String, myJson:Dynamic)
	{
		var animJson:AnimAtlas = null;
		var trimmed:String = StringTools.trim(pathOrStr);
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		if(myJson is String)
		{
			if(trimmed == '.json') myJson = Utils.getText(myJson); //is a path
			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		if(trimmed == '.json') //Path is json
		{
			myData = _removeBOM(Utils.getText(pathOrStr));
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			myData = _removeBOM(Utils.getText(pathOrStr));
			isXml = true;
		}

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		anim._loadAtlas(animJson);
		frames = isXml ? FlxAnimateFrames.fromSparrow(cast myData, img) : FlxAnimateFrames.fromAnimateAtlas(cast myData, img);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	static function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}
	#end

	@:noCompletion
	inline function get_useAtlas()
	{
		return toggleAtlas && atlasIsValid;
	}
}
