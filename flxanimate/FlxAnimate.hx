package flxanimate;

import openfl.geom.Matrix;
import flixel.math.FlxAngle;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxColor;
import flixel.graphics.FlxGraphic;
import openfl.geom.Rectangle;
import openfl.display.BitmapData;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxRect;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxPoint;
import flixel.FlxCamera;
import flxanimate.animate.*;
import flxanimate.zip.Zip;
import flxanimate.Utils;
import haxe.io.BytesInput;
import flixel.system.FlxSound;
import flixel.FlxG;
import flxanimate.data.AnimationData;
import flixel.FlxSprite;
import flxanimate.animate.FlxAnim;
import flxanimate.frames.FlxAnimateFrames;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import flixel.math.FlxMath;
import flixel.FlxBasic;
import flixel.util.FlxPool;

typedef Settings = {
	?ButtonSettings:Map<String, flxanimate.animate.FlxAnim.ButtonSettings>,
	?FrameRate:Float,
	?Reversed:Bool,
	?OnComplete:Void->Void,
	?ShowPivot:Bool,
	?Antialiasing:Bool,
	?ScrollFactor:FlxPoint,
	?Offset:FlxPoint,
}

class DestroyableFlxMatrix extends FlxMatrix implements IFlxDestroyable {
	public function destroy() {
		identity();
	}
}

@:access(openfl.geom.Rectangle)
class FlxAnimate extends FlxSprite
{
	public static var colorTransformsPool(get, never):openfl.utils.ObjectPool<ColorTransform>;
	inline static function get_colorTransformsPool()
		@:privateAccess
		return ColorTransform.__pool;
	public static var matrixesPool:FlxPool<DestroyableFlxMatrix> = new FlxPool(DestroyableFlxMatrix);
	public var anim(default, null):FlxAnim;

	public var isValid(default, null):Bool;

	// #if FLX_SOUND_SYSTEM
	// public var audio:FlxSound;
	// #end

	// public var rectangle:FlxRect;

	public var relativeX:Float = 0;
	public var relativeY:Float = 0;

	public var showPivot(default, set):Bool = false;

	#if !ANIMATE_NO_PIVOTPOINT
	var _pivot:FlxFrame;
	#end
	/**
	 * # Description
	 * `FlxAnimate` is a texture atlas parser from the drawing software *Adobe Animate* (once being *Adobe Flash*).
	 * It tries to replicate how Adobe Animate works on Haxe so it would be considered (as *MrCheemsAndFriends* likes to call it,) a "*Flash--*", in other words, a replica of Animate's work
	 * on the side of drawing, making symbols, etc.
	 * ## WARNINGS
	 * - This does **NOT** convert the frames into a spritesheet
	 * - Since this is some sort of beta, expect that there could be some inconveniences (bugs, crashes, etc).
	 *
	 * @param X 		The initial X position of the sprite.
	 * @param Y 		The initial Y position of the sprite.
	 * @param Path      The path to the texture atlas, **NOT** the path of the any of the files inside the texture atlas (`Animation.json`, `spritemap.json`, etc).
	 * @param Settings  Optional settings for the animation (antialiasing, framerate, reversed, etc.).
	 */
	public function new(X:Float = 0, Y:Float = 0, ?Path:String, ?Settings:Settings)
	{
		_cashePoints = [];
		super(X, Y);
		anim = new FlxAnim(this);
		if (Path != null)
			loadAtlas(Path);
		if (Settings != null)
			setTheSettings(Settings);
		rect = Rectangle.__pool.get();
	}

	function set_showPivot(v:Bool) {
		#if !ANIMATE_NO_PIVOTPOINT
		if(v && _pivot == null) {
			@:privateAccess
			_pivot = new FlxFrame(FlxGraphic.fromBitmapData(openfl.Assets.getBitmapData("flxanimate/images/pivot.png")));
			_pivot.frame = new FlxRect(0, 0, _pivot.parent.width, _pivot.parent.height);
			_pivot.name = "pivot";
		}
		#end
		return showPivot = v;
	}

	public function loadAtlas(Path:String)
	{
		if (!Utils.exists('$Path/Animation.json') && haxe.io.Path.extension(Path) != "zip")
		{
			isValid = false;
			kill();
			FlxG.log.error('Animation file not found in specified path: "$Path", have you written the correct path?');
			return;
		}
		if (!isValid) revive();
		isValid = true;
		anim._loadAtlas(atlasSetting(Path));
		frames = FlxAnimateFrames.fromTextureAtlas(Path);
	}

	var _cashePoints(default, null):Array<FlxPoint>;
	/**
	 * the function `draw()` renders the symbol that `anim` has currently plus a pivot that you can toggle on or off.
	 */
	public override function draw():Void
	{
		if(alpha == 0) return;

		updateTrig();
		updateSkewMatrix();

		for (i => camera in cameras)
		{
			final _point:FlxPoint = getScreenPosition(_cashePoints[i], camera).subtractPoint(offset);
			_point.addPoint(origin);
			if (isPixelPerfectRender(camera))
			{
				_point.floor();
			}
			_cashePoints[i] = _point;
		}

		_flashRect.setEmpty();

		if (frames != null)
			parseElement(anim.curInstance, anim.curFrame, _matrix, colorTransform, true);
		#if !ANIMATE_NO_PIVOTPOINT
		if (showPivot)
		{
			var mat = matrixesPool.get();
			mat.tx = origin.x - _pivot.frame.width * 0.5;
			mat.ty = origin.y - _pivot.frame.height * 0.5;
			drawLimb(_pivot, mat);
			matrixesPool.put(mat);
		}
		#end
		width = _flashRect.width;
		height = _flashRect.height;
		frameWidth = Math.round(width);
		frameHeight = Math.round(height);

		relativeX = _flashRect.x - x;
		relativeY = _flashRect.y - y;

		// trace(_flashRect);
	}
	/**
	 * This basically renders an element of any kind, both limbs and symbols.
	 * It should be considered as the main function that makes rendering a symbol possible.
	 */
	function parseElement(instance:FlxElement, curFrame:Int, m:FlxMatrix, colorFilter:ColorTransform, mainSymbol:Bool = false)
	{
		final colorEffect = colorTransformsPool.get();
		final matrix = matrixesPool.get();
		if (instance.symbol != null && instance.symbol._colorEffect != null)
			colorEffect.concat(instance.symbol._colorEffect);
		colorEffect.concat(colorFilter);
		matrix.concat(instance.matrix);
		/* // testing.
		if (instance.symbol != null)
		{
			matrix.translate(-instance.symbol.transformationPoint.x * (flipX ? 1 : -1), -instance.symbol.transformationPoint.y * (flipY ? 1 : -1));
			matrix.concat(m);
			matrix.translate(instance.symbol.transformationPoint.x * (flipX ? 1 : -1), instance.symbol.transformationPoint.y * (flipY ? 1 : -1));
		}
		else
		*/
		{
			matrix.concat(m);
		}

		if (instance.bitmap != null)
		{
			drawLimb(frames.getByName(instance.bitmap), matrix, colorEffect);

			colorTransformsPool.release(colorEffect);
			matrixesPool.put(matrix);
			return;
		}

		final symbol:FlxSymbol = anim.symbolDictionary.get(instance.symbol.name);
		final firstFrame:Int = switch (instance.symbol.type)
		{
			case Button:	setButtonFrames();
			case Graphic:
				switch (instance.symbol.loop)
				{
					case Loop:		(instance.symbol.firstFrame + curFrame) % symbol.length;
					case PlayOnce:	cast FlxMath.bound(instance.symbol.firstFrame + curFrame, 0, symbol.length - 1);
					default:		instance.symbol.firstFrame + curFrame;
				}
			// default:		instance.symbol.firstFrame;
			default:		0;
		}

		final layers = symbol.timeline.getList();
		var layer:FlxLayer;
		var frame:FlxKeyFrame;
		for (i in 0...layers.length)
		{
			layer = layers[layers.length - 1 - i];

			if (!layer.visible && mainSymbol || (frame = layer.get(firstFrame)) == null) continue;

			if (frame.callbacks != null)
			{
				frame.fireCallbacks();
			}

			for (element in frame.getList())
			{
				final colorEffect2 = colorTransformsPool.get();
				colorEffect2.concat(colorEffect);
				if (frame._colorEffect != null)
					colorEffect2.concat(frame._colorEffect);
				parseElement(element, element.symbol == null || element.symbol.loop == SingleFrame ? 0 : firstFrame - frame.index, matrix, colorEffect2);
				colorTransformsPool.release(colorEffect2);
			}
		}

		colorTransformsPool.release(colorEffect);
		matrixesPool.put(matrix);
	}

	var pressed:Bool = false;
	function setButtonFrames()
	{
		var frame:Int = 0;
		#if FLX_MOUSE
		var badPress:Bool = false;
		var goodPress:Bool = false;
		final isOverlaped:Bool = FlxG.mouse.overlaps(this);
		final isPressed = FlxG.mouse.pressed;
		if (isPressed && isOverlaped)
			goodPress = true;
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
			@:privateAccess
			var event = anim.buttonMap.get(anim.curSymbol.name);
			if (FlxG.mouse.justPressed && !pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnClick : null #if FLX_SOUND_SYSTEM, event.Sound #end).fire();
				pressed = true;
			}
			frame = (FlxG.mouse.pressed) ? 2 : 1;

			if (FlxG.mouse.justReleased && pressed)
			{
				if (event != null)
					new ButtonEvent((event.Callbacks != null) ? event.Callbacks.OnRelease : null #if FLX_SOUND_SYSTEM, event.Sound #end).fire();
				pressed = false;
			}
		}
		else
		{
			frame = 0;
		}
		#else
		FlxG.log.error("Button stuff isn't available for mobile!");
		#end
		return frame;
	}

	var rect:Rectangle;

	static var rMatrix = new FlxMatrix();

	function drawLimb(limb:FlxFrame, _matrix:FlxMatrix, ?colorTransform:ColorTransform)
	{
		if (limb == null || limb.type == EMPTY || colorTransform != null && (colorTransform.alphaMultiplier == 0 || colorTransform.alphaOffset == -255))
			return;

		for (i => camera in cameras)
		{
			if (!camera.visible || !camera.exists)
				continue;

			/*
			rMatrix.identity();
			rMatrix.translate(-limb.offset.x, -limb.offset.y);
			if (limb.angle == FlxFrameAngle.ANGLE_NEG_90)
			{
				rMatrix.rotateByNegative90();
				rMatrix.translate(0, limb.sourceSize.x);
			}
			*/
			limb.prepareMatrix(rMatrix);
			rMatrix.concat(_matrix);
			if (true)
			{
				rMatrix.translate(-origin.x, -origin.y);
				#if ANIMATE_NO_PIVOTPOINT
				rMatrix.scale(scale.x, scale.y);
				#else
				if (limb == _pivot)
					rMatrix.a = rMatrix.d = 0.7 / camera.zoom;
				else
					rMatrix.scale(scale.x, scale.y);
				#end
				if (angle != 0)
					rMatrix.rotateWithTrig(_cosAngle, _sinAngle);

				rMatrix.concat(matrixExposed ? transformMatrix : _skewMatrix);

				rMatrix.translate(_cashePoints[i].x, _cashePoints[i].y);
				if (!limbOnScreen(limb, rMatrix, camera))
				{
					continue;
				}
			}
			camera.drawPixels(limb, null, rMatrix, colorTransform, blend, antialiasing, #if FLX_CNE_FORK shaderEnabled ? shader : null #else shader #end);
			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}
		// doesnt work, needs to be remade
		//#if FLX_DEBUG
		//if (FlxG.debugger.drawDebug)
		//	drawDebug();
		//#end
	}

	public var skew(default, null):FlxPoint = FlxPoint.get();

	static var _skewMatrix:FlxMatrix = new FlxMatrix();

	/**
	 * Tranformation matrix for this sprite.
	 * Used only when matrixExposed is set to true
	 */
	public var transformMatrix(default, null):Matrix = new Matrix();

	/**
	 * Bool flag showing whether transformMatrix is used for rendering or not.
	 * False by default, which means that transformMatrix isn't used for rendering
	 */
	public var matrixExposed:Bool = false;

	function updateSkewMatrix():Void
	{
		_skewMatrix.identity();

		if (skew.x != 0 || skew.y != 0)
		{
			_skewMatrix.b = Math.tan(skew.y * FlxAngle.TO_RAD);
			_skewMatrix.c = Math.tan(skew.x * FlxAngle.TO_RAD);
		}
	}

	function limbOnScreen(limb:FlxFrame, m:FlxMatrix, ?Camera:FlxCamera)
	{
		if (Camera == null)
			Camera = FlxG.camera;

		limb.frame.copyToFlash(rect);

		rect.offset(-rect.x, -rect.y);

		rect.__transform(rect, m);

		#if !ANIMATE_NO_PIVOTPOINT
		if (_pivot != limb)
		#end
		{
			if (_flashRect.width == 0 || _flashRect.height == 0)
			{
				_flashRect.copyFrom(rect);
			}
			else if (rect.width != 0 && rect.height != 0)
			{
				_flashRect.setTo(
					_flashRect.x > rect.x ? rect.x : _flashRect.x,
					_flashRect.y > rect.y ? rect.y : _flashRect.y,
					_flashRect.right < rect.right ? rect.width : _flashRect.width,
					_flashRect.bottom < rect.bottom ? rect.height : _flashRect.height
				);
			}	
		}

		return Camera.containsPoint(_point.set(rect.x, rect.y), rect.width, rect.height);
	}

	// function checkSize(limb:FlxFrame, m:FlxMatrix)
	// {
	// 	// var rect = new Rectangle(x,y,limb.frame.width,limb.frame.height);
	// 	// @:privateAccess
	// 	// rect.__transform(rect, m);
	// 	return {width: rect.width, height: rect.height};
	// }
	var oldMatrix:FlxMatrix;
	override function set_flipX(Value:Bool)
	{
		if (oldMatrix == null)
		{
			oldMatrix = new FlxMatrix();
			oldMatrix.concat(_matrix);
		}
		if (Value)
		{
			_matrix.a = -oldMatrix.a;
			_matrix.c = -oldMatrix.c;
		}
		else
		{
			_matrix.a = oldMatrix.a;
			_matrix.c = oldMatrix.c;
		}
		return Value;
	}
	override function set_flipY(Value:Bool)
	{
		if (oldMatrix == null)
		{
			oldMatrix = new FlxMatrix();
			oldMatrix.concat(_matrix);
		}
		if (Value)
		{
			_matrix.b = -oldMatrix.b;
			_matrix.d = -oldMatrix.d;
		}
		else
		{
			_matrix.b = oldMatrix.b;
			_matrix.d = oldMatrix.d;
		}
		return Value;
	}

	override function destroy()
	{
		/*#if FLX_SOUND_SYSTEM
		audio = FlxDestroyUtil.destroy(audio);
		#end*/
		anim = FlxDestroyUtil.destroy(anim);
		skew = FlxDestroyUtil.put(skew);
		_cashePoints = FlxDestroyUtil.putArray(_cashePoints);
		Rectangle.__pool.release(rect);
		super.destroy();
	}

	public override function updateAnimation(elapsed:Float)
	{
		anim.update(elapsed);
	}

	public function setButtonPack(button:String, callbacks:ClickStuff #if FLX_SOUND_SYSTEM , sound:FlxSound #end):Void
	{
		@:privateAccess
		anim.buttonMap.set(button, {Callbacks: callbacks, #if FLX_SOUND_SYSTEM Sound:  sound #end});
	}

	function setTheSettings(?Settings:Settings):Void
	{
		@:privateAccess
		if (true)
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
				anim.framerate = (Settings.FrameRate > 0) ? anim.metadata.frameRate : Settings.FrameRate;
			if (Settings.OnComplete != null)
				anim.onComplete = Settings.OnComplete;
			if (Settings.ShowPivot != null)
				showPivot = Settings.ShowPivot;
			if (Settings.Antialiasing != null)
				antialiasing = Settings.Antialiasing;
			if (Settings.ScrollFactor != null)
				scrollFactor = Settings.ScrollFactor;
			if (Settings.Offset != null)
				offset = Settings.Offset;
		}
	}

	function atlasSetting(Path:String):AnimAtlas
	{
		var jsontxt:AnimAtlas = null;
		if (haxe.io.Path.extension(Path) == "zip")
		{
			var thing = Zip.readZip(Utils.getBytes(Path));

			for (list in Zip.unzip(thing))
			{
				if (list.fileName.indexOf("Animation.json") != -1)
				{
					jsontxt = haxe.Json.parse(list.data.toString());
					thing.remove(list);
					continue;
				}
			}
			@:privateAccess
			FlxAnimateFrames.zip = thing;
		}
		else
		{
			jsontxt = haxe.Json.parse(Utils.getText('$Path/Animation.json'));
		}

		return jsontxt;
	}
}
