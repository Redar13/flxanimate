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
import openfl.display3D.textures.TextureBase;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Rectangle;
import openfl.geom.Matrix;

#if (js && html5)
import openfl.display.CanvasRenderer;
import openfl.display._internal.CanvasGraphics as GfxRenderer;
import lime._internal.graphics.ImageCanvasUtil;
#else
import openfl.display.CairoRenderer;
import openfl.display._internal.CairoGraphics as GfxRenderer;
#end

import lime.graphics.cairo.Cairo;

import openfl.utils._internal.UInt8Array;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.ImageChannel;


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
	// var softRenderer:#if (js && html5) CanvasRenderer #else CairoRenderer #end;
	var hardwareRenderer:OpenGLRenderer;
	var context:Context3D;

	static var maskShader:MaskShader = new MaskShader();
	static var maskFilter:ShaderFilter = new ShaderFilter(maskShader);

	public function new()
	{
		// context = new openfl.display3D.Context3D(null);
		hardwareRenderer = new OpenGLRenderer(FlxG.game.stage.context3D);
		hardwareRenderer.__worldTransform = new Matrix();
		hardwareRenderer.__worldColorTransform = new ColorTransform();

		// #if (js && html5)
		// @:privateAccess
		// softRenderer = new CanvasRenderer(null);
		// #else
		// softRenderer = new CairoRenderer(null);
		// #end
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

		var context = hardwareRenderer.__context3D;

		hardwareRenderer.__setBlendMode(NORMAL);
		hardwareRenderer.__worldAlpha = 1;

		hardwareRenderer.__worldTransform.identity();
		hardwareRenderer.__worldColorTransform.__identity();

		var bitmap:BitmapData = outBmp;
		var bitmap2:BitmapData = casheBmp;
		var bitmap3:BitmapData = casheBmp2;

		if (rect != null)
			startBmp.__renderTransform.translate(Math.abs(rect.x), Math.abs(rect.y));
		hardwareRenderer.__setRenderTarget(bitmap);
		context.clear(0, 0, 0, 0, 0, 0, Context3DClearMask.COLOR);
		if (startBmp != bitmap)
			hardwareRenderer.__renderFilterPass(startBmp, hardwareRenderer.__defaultDisplayShader, true);
		startBmp.__renderTransform.identity();

		for (filter in filters)
		{
			if (filter.__preserveObject)
			{
				hardwareRenderer.__setRenderTarget(bitmap3);
				hardwareRenderer.__renderFilterPass(bitmap, hardwareRenderer.__defaultDisplayShader, filter.__smooth);
			}

			for (i in 0...filter.__numShaderPasses)
			{
				hardwareRenderer.__setBlendMode(filter.__shaderBlendMode);
				hardwareRenderer.__setRenderTarget(bitmap2);
				hardwareRenderer.__renderFilterPass(bitmap, filter.__initShader(hardwareRenderer, i, filter.__preserveObject ? bitmap3 : null), filter.__smooth);

				hardwareRenderer.__setRenderTarget(bitmap);
				hardwareRenderer.__renderFilterPass(bitmap2, hardwareRenderer.__defaultDisplayShader, filter.__smooth);
			}

			filter.__renderDirty = false;
		}

		if (mask != null)
			filters.pop();

		// writeCurToBitmap(bitmap);
		hardwareRenderer.__context3D.setRenderToBackBuffer();
	}

	public function writeCurToBitmap(bitmap:BitmapData, ?renderBuffer:TextureBase, ?format:Null<Int>)
	{
		// if (bitmap == null) return;
		var gl = hardwareRenderer.__gl;
		// if (renderBuffer == null) return;
		renderBuffer ??= bitmap.getTexture(hardwareRenderer.__context3D);
		if (bitmap.image == null || bitmap.image.data == null)
		{
			#if sys
			var buffer = new ImageBuffer(new UInt8Array(bitmap.width * bitmap.height * 4), bitmap.width, bitmap.height);
			buffer.format = BGRA32;
			buffer.premultiplied = true;

			bitmap.image = new Image(buffer, 0, 0, bitmap.width, bitmap.height);

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
			bitmap.image = new Image(null, 0, 0, bitmap.width, bitmap.height, bitmap.fillColor);
			#end

			bitmap.image.transparent = bitmap.transparent;
			bitmap.image.version = 0;

			bitmap.__isValid = true;
			bitmap.readable = true;
		}
		@:privateAccess
		gl.readPixels(0, 0, bitmap.width, bitmap.height, renderBuffer.__format, format ?? /* gl.FASTEST */ gl.UNSIGNED_BYTE, bitmap.image.data);
		@:privateAccess
		bitmap.__textureVersion = -1;
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

	public function graphicstoBitmapData(gfx:Graphics, target:BitmapData, ?pushToImageData:Bool, ?point:FlxPoint)
	{
		if (target == null) return target;

		var bounds = gfx.__owner.getBounds(null);

		hardwareRenderer.__worldTransform.identity();
		hardwareRenderer.__worldTransform.translate(-bounds.x, -bounds.y);
		if (point != null)
		{
			hardwareRenderer.__worldTransform.translate(point.x, point.y);
		}

		/*
		if (openfl.Lib.current.stage.context3D == null)
		{
			// target.fillRect(target.rect, 0);

			softRenderer.__pixelRatio = hardwareRenderer.__pixelRatio;
			// It's working, I guess?
			#if (js && html5)
			ImageCanvasUtil.convertToCanvas(bmp.image);
			@:privateAccess
			softRenderer.setTransform(hardwareRenderer.__worldTransform, target.image.buffer.__srcContext);
			#else
			softRenderer.applyMatrix(hardwareRenderer.__worldTransform, new lime.graphics.cairo.Cairo(target.__surface));
			#end
			softRenderer.__clear();
			GfxRenderer.render(gfx, cast softRenderer);

			return target;
		}
		*/

		var context = hardwareRenderer.__context3D;
		var cacheRTT = context.__state.renderToTexture;
		var cacheRTTDepthStencil = context.__state.renderToTextureDepthStencil;
		var cacheRTTAntiAlias = context.__state.renderToTextureAntiAlias;
		var cacheRTTSurfaceSelector = context.__state.renderToTextureSurfaceSelector;
		// context.setRenderToBackBuffer();

		hardwareRenderer.__setRenderTarget(target);
		var renderBuffer = target.getTexture(context);
		context.setRenderToTexture(renderBuffer);

		if (pushToImageData)
			target.fillRect(target.rect, 0);
		// else
		context.clear(0, 0, 0, 0, 0, 0, Context3DClearMask.COLOR);
		// hardwareRenderer.__clear();

		Context3DGraphics.render(gfx, hardwareRenderer);
		if (pushToImageData)
			writeCurToBitmap(target, renderBuffer);

		hardwareRenderer.__setRenderTarget(null);
		if (cacheRTT != null)
		{
			context.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
		}
		else
		{
			context.setRenderToBackBuffer();
		}
		return target;
	}
}