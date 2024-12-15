package flxanimate.display;

import flxanimate.filters.MaskShader;

import flixel.math.FlxPoint;
import flixel.FlxG;

import openfl.display._internal.Context3DGraphics;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObjectRenderer;
import openfl.display.Graphics;
import openfl.display.OpenGLRenderer;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DClearMask;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Rectangle;
import openfl.geom.Matrix;
import openfl.utils._internal.UInt8Array;

import lime.graphics.Image;
import lime.graphics.cairo.Cairo;

#if (js && html5)
import openfl.display.CanvasRenderer;
import openfl.display._internal.CanvasGraphics as GfxRenderer;
import lime._internal.graphics.ImageCanvasUtil;
#else
import openfl.display.CairoRenderer;
import openfl.display._internal.CairoGraphics as GfxRenderer;
#end


@:access(openfl.display.OpenGLRenderer)
@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.Rectangle)
@:access(openfl.display.Stage)
@:access(openfl.display.Graphics)
@:access(openfl.display.Shader)
@:access(openfl.display.BitmapData)
@:access(openfl.geom.ColorTransform)
@:access(openfl.display.DisplayObject)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.CanvasRenderer)
@:access(openfl.display.CairoRenderer)
@:access(openfl.display3D.Context3D)
class FlxAnimateFilterRenderer
{
	var renderer:OpenGLRenderer;
	var context:Context3D;

	static var maskShader:MaskShader = new MaskShader();
	static var maskFilter:ShaderFilter = new ShaderFilter(maskShader);

	public function new()
	{
		// context = new openfl.display3D.Context3D(null);
		renderer = new OpenGLRenderer(FlxG.game.stage.context3D);
		renderer.__worldTransform = new Matrix();
		renderer.__worldColorTransform = new ColorTransform();
	}

	static function checkImageData(bmp:BitmapData):BitmapData
	{
		if (bmp.image == null && bmp.width > 0 && bmp.height > 0 || !bmp.__isValid)
		{
			#if lime
			#if sys
			var buffer = new lime.graphics.ImageBuffer(new UInt8Array(bmp.width * bmp.height * 4), bmp.width, bmp.height);
			buffer.format = BGRA32;
			buffer.premultiplied = true;

			bmp.image = new Image(buffer, 0, 0, bmp.width, bmp.height);
			// #elseif (js && html5)
			// var buffer = new ImageBuffer (null, width, height);
			// var canvas:CanvasElement = cast Browser.document.createElement ("canvas");
			// buffer.__srcCanvas = canvas;
			// buffer.__srcContext = canvas.getContext ("2d");
			//
			// image = new Image (buffer, 0, 0, width, height);
			// image.type = CANVAS;
			//
			// if (fillColor != 0) {
			//
			// image.fillRect (image.rect, fillColor);
			//
			// }
			#else
			bmp.image = new Image(null, 0, 0, bmp.width, bmp.height, 0);
			#end

			bmp.image.transparent = true;
			#end

			bmp.__isValid = true;
			bmp.readable = true;
		}
		return bmp;
	}

	@:noCompletion function setRenderer(renderer:DisplayObjectRenderer, rect:Rectangle)
	{
		@:privateAccess
		if (true)
		{
			var displayObject = FlxG.game;
			var pixelRatio = FlxG.game.stage.__renderer.__pixelRatio;

			var offsetX = rect.x > 0 ? Math.ceil(rect.x) : Math.floor(rect.x);
			var offsetY = rect.y > 0 ? Math.ceil(rect.y) : Math.floor(rect.y);
			if (renderer.__worldTransform == null)
			{
				renderer.__worldTransform = new Matrix();
				renderer.__worldColorTransform = new ColorTransform();
			}
			if (displayObject.__cacheBitmapColorTransform == null) displayObject.__cacheBitmapColorTransform = new ColorTransform();

			renderer.__stage = displayObject.stage;

			renderer.__allowSmoothing = true;
			renderer.__setBlendMode(NORMAL);
			renderer.__worldAlpha = 1 / displayObject.__worldAlpha;

			renderer.__worldTransform.identity();
			renderer.__worldTransform.invert();
			//renderer.__worldTransform.concat(new Matrix());
			renderer.__worldTransform.tx -= offsetX;
			renderer.__worldTransform.ty -= offsetY;

			renderer.__pixelRatio = pixelRatio;

		}
	}

	public function applyFilter(startBmp:BitmapData, outBmp:BitmapData, casheBmp:BitmapData, casheBmp2:BitmapData, filters:Array<BitmapFilter>, ?rect:Rectangle, ?mask:BitmapData, ?maskPos:FlxPoint)
	{
		if (mask != null)
		{
			if (maskPos == null)
			{
				maskShader.relativePos.value[0] = maskShader.relativePos.value[1] = 0;
			}
			else
			{
				maskShader.relativePos.value[0] = maskPos.x;
				maskShader.relativePos.value[1] = maskPos.y;
			}
			maskShader.mainPalette.input = mask;
			maskFilter.invalidate();
			if (filters == null)
				filters = [maskFilter];
			else
				filters.push(maskFilter);
		}
		else if (filters == null)
			return;
		renderer.__setBlendMode(NORMAL);
		renderer.__worldAlpha = 1;

		renderer.__worldTransform.identity();
		renderer.__worldColorTransform.__identity();

		var bitmap:BitmapData = outBmp;
		var bitmap2:BitmapData = casheBmp;
		var bitmap3:BitmapData = casheBmp2;

		if (rect != null)
			startBmp.__renderTransform.translate(Math.abs(rect.x), Math.abs(rect.y));
		renderer.__setRenderTarget(bitmap);
		if (startBmp != bitmap)
			renderer.__renderFilterPass(startBmp, renderer.__defaultDisplayShader, true);
		startBmp.__renderTransform.identity();

		// startBmp.__renderTransform.identity();

		for (filter in filters)
		{
			if (filter.__preserveObject)
			{
				renderer.__setRenderTarget(bitmap3);
				renderer.__renderFilterPass(bitmap, renderer.__defaultDisplayShader, filter.__smooth);
			}

			for (i in 0...filter.__numShaderPasses)
			{
				renderer.__setBlendMode(filter.__shaderBlendMode);
				renderer.__setRenderTarget(bitmap2);
				renderer.__renderFilterPass(bitmap, filter.__initShader(renderer, i, filter.__preserveObject ? bitmap3 : null), filter.__smooth);

				renderer.__setRenderTarget(bitmap);
				renderer.__renderFilterPass(bitmap2, renderer.__defaultDisplayShader, filter.__smooth);
			}

			filter.__renderDirty = false;
		}

		if (mask != null)
			filters.pop();

		var gl = renderer.__gl;

		var renderBuffer = bitmap.getTexture(renderer.__context3D);
		bitmap = checkImageData(bitmap);
		@:privateAccess
		gl.readPixels(0, 0, bitmap.width, bitmap.height, renderBuffer.__format, gl.UNSIGNED_BYTE, bitmap.image.data);
		bitmap.image.version = 0;
		@:privateAccess
		bitmap.__textureVersion = -1;
		renderer.__context3D.setRenderToBackBuffer();
	}

	public function applyBlend(blend:BlendMode, bitmap:BitmapData)
	{
		bitmap.__update(false, true);
		var bmp = new BitmapData(bitmap.width, bitmap.height, 0);

		#if (js && html5)
		ImageCanvasUtil.convertToCanvas(bmp.image);
		@:privateAccess
		var renderer = new CanvasRenderer(bmp.image.buffer.__srcContext);
		#else
		var renderer = new CairoRenderer(new Cairo(bmp.getSurface()));
		#end

		// setRenderer(renderer, bmp.rect);

		var m = new Matrix();
		var c = new ColorTransform();
		renderer.__allowSmoothing = true;
		renderer.__overrideBlendMode = blend;
		renderer.__worldTransform = m;
		renderer.__worldAlpha = 1;
		renderer.__worldColorTransform = c;

		renderer.__setBlendMode(blend);
		#if (js && html5)
		bmp.__drawCanvas(bitmap, renderer);
		#else
		bmp.__drawCairo(bitmap, renderer);
		#end

		return bitmap;
	}

	public function graphicstoBitmapData(gfx:Graphics, ?target:BitmapData, ?point:FlxPoint) // TODO!: Support for CPU based games (Cairo/Canvas only renderers)
	{
		if (gfx.__bounds == null) return null;

		var cacheRTT = renderer.__context3D.__state.renderToTexture;
		var cacheRTTDepthStencil = renderer.__context3D.__state.renderToTextureDepthStencil;
		var cacheRTTAntiAlias = renderer.__context3D.__state.renderToTextureAntiAlias;
		var cacheRTTSurfaceSelector = renderer.__context3D.__state.renderToTextureSurfaceSelector;

		var bounds = gfx.__owner.getBounds(null);

		if (target == null)
			target = new BitmapData(Math.ceil(bounds.width), Math.ceil(bounds.height), true, 0);

		renderer.__worldTransform.identity();
		renderer.__worldTransform.translate(-bounds.x, -bounds.y);
		if (point != null)
		{
			renderer.__worldTransform.translate(point.x, point.y);
		}

		// GfxRenderer.render(gfx, cast renderer.__softwareRenderer);
		// var target = gfx.__bitmap;

		var context = renderer.__context3D;

		renderer.__setRenderTarget(target);
		var renderBuffer = target.getTexture(context);
		context.setRenderToTexture(renderBuffer);

		Context3DGraphics.render(gfx, renderer);

		var gl = renderer.__gl;

		checkImageData(target);
		@:privateAccess
		gl.readPixels(0, 0, target.width, target.height, renderBuffer.__format, gl.UNSIGNED_BYTE, target.image.data);


		if (cacheRTT != null)
		{
			renderer.__context3D.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
		}
		else
		{
			renderer.__context3D.setRenderToBackBuffer();
		}

		return target;
	}
}