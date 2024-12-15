package flxanimate.animate;

import haxe.extern.EitherType;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxDestroyUtil;
import flixel.FlxG;
import flixel.FlxObject;

import flxanimate.data.AnimationData.Frame;
import flxanimate.data.AnimationData.LayerType;
import flxanimate.data.AnimationData.Layers;
import flxanimate.display.FlxAnimateFilterRenderer;
import flxanimate.interfaces.IFilterable;
import flxanimate.motion.easing.*;
import flxanimate.FlxAnimate.FlxPooledCamera;
import flxanimate.Utils;

@:allow(flxanimate.FlxAnimate)
class FlxLayer extends FlxObject implements IFilterable
{
	public var onFrameUpdate:(prevFrame:FlxKeyFrame, curFrame:FlxKeyFrame)->Void;

	public var name(default, null):String;
	public var type(default, set):LayerType;
	public var length(get, never):Int;

	var _filterCamera:FlxPooledCamera;
	var maskCamera:FlxPooledCamera;

	// var _mcMap:Map<String, Int>;
	var _filterFrame:FlxFrame;
	var _bmp1:BitmapData;
	var _bmp2:BitmapData;

	// var _bmpGraphic1:FlxGraphic;
	// var _bmpGraphic2:FlxGraphic;

	var _filterMatrix:FlxMatrix;

	var _renderable:Bool = true;

	@:allow(flxanimate.animate.FlxTimeline)
	var _parent(default, set):FlxTimeline;

	@:allow(flxanimate.animate.FlxKeyFrame)
	@:allow(flxanimate.animate.FlxSymbol)
	var _labels:Map<String, FlxKeyFrame>;


	@:allow(flxanimate.animate.FlxKeyFrame)
	var _keyframes(default, null):Array<FlxKeyFrame>;

	var _correctClip:Bool = false;

	var _clipper:FlxLayer = null;

	var _currFrame:FlxKeyFrame;

	public function new(?name:String, ?keyframes:Array<FlxKeyFrame>)
	{
		super();
		this.name = name;
		type = Normal;
		_keyframes = (keyframes != null) ? keyframes : [];
		visible = true;
		_labels = [];
		// _mcMap = [];
		_filterMatrix = new FlxMatrix();
	}

	public inline function hide()
	{
		visible = false;
	}
	public inline function show()
	{
		visible = true;
	}
	override public function destroy()
	{
		super.destroy();
		if (_filterFrame != null)
		{
			FlxG.bitmap.remove(_filterFrame.parent);
		}
		_filterFrame = FlxDestroyUtil.destroy(_filterFrame);
		_filterCamera = FlxDestroyUtil.put(cast _filterCamera);
		_filterCamera = FlxDestroyUtil.destroy(_filterCamera);
		maskCamera = FlxDestroyUtil.put(cast maskCamera);
		maskCamera = FlxDestroyUtil.destroy(maskCamera);
		_filterMatrix = null;
		// FlxG.bitmap.remove(_bmpGraphic1);
		_bmp1 = Utils.dispose(_bmp1);
		// FlxG.bitmap.remove(_bmpGraphic2);
		_bmp2 = Utils.dispose(_bmp2);

		for (keyframe in _keyframes)
		{
			keyframe.destroy();
		}
		_keyframes = null;
	}

	public function updateRender(elapsed:Float, curFrame:Int, dictionary:Map<String, FlxSymbol>, ?swfRender:Bool = false)
	{
		var _prevFrame = _currFrame;
		_setCurFrame(curFrame);
		/*
		if (_clipper == null)
		{
			switch (type)
			{
				case Clipped(l) if (_parent != null):
					var l = _parent.get(l);
					if (l != null)
					{
						l._correctClip = true;

						_clipper = l;
					}
				case _:
			}
		}
		else if (_clipper != null)
		{
			if (_clipper._currFrame._renderDirty)
			{
				_currFrame._renderDirty = true;
			}
		}
		*/

		if (_currFrame != null)
		{
			if (_prevFrame != _currFrame)
			{
				_currFrame._renderDirty = true;
				_prevFrame = _currFrame;
				if (_clipper != null)
				{
					_clipper._renderable = _currFrame.getList().length > 0;
					_clipper._currFrame._renderDirty = true;
				}
				// _currFrame.updateRender(elapsed, curFrame, dictionary, swfRender);
			}
			_currFrame.updateRender(elapsed, curFrame, dictionary, swfRender);
		}
		update(elapsed);
	}
	public inline function get(frame:EitherType<String, Int>)
	{
		return _get(frame, false);
	}
	function _get(frame:EitherType<String, Int>, _animateRendering:Bool = true)
	{
		if (frame != null)
		{
			if (_animateRendering && _parent != null && type.match(Clipped(_)))
			{
				var layers = _parent.getList();
				var layer = layers[layers.indexOf(this) - 1];
				if (layer != null && layer.type == Clipper)
				{
					layer._renderable = false;
					// _clipper = layer;
				}
			}
			if (frame is String)
			{
				return _labels.get(frame);
			}
			else
			{
				var index:Int = cast frame;
				if (index < 0 || index == Math.NaN)
					index = 0;
				else if (index > length)
					return null;
				for (keyframe in _keyframes)
				{
					if (keyframe.index + keyframe.duration > index)
					{
						return keyframe;
					}
				}
			}
		}

		return null;
	}

	public function add(keyFrame:FlxKeyFrame)
	{
		if (keyFrame == null) return null;
		var index = keyFrame.index;
		if (keyFrame.name != null)
			_labels.set(keyFrame.name, keyFrame);

		var keyframe = get(cast FlxMath.bound(index, 0, length - 1));
		if (length == 0)
		{
			keyframe = new FlxKeyFrame(0, 1);
			_keyframes.push(keyframe);
		}
		var difference:Int = cast Math.abs(index - keyframe.index);

		if (index == keyframe.index)
		{
			keyFrame.duration += keyframe.duration - 1;

			_keyframes.insert(_keyframes.indexOf(keyframe), keyFrame);
			_keyframes.remove(keyframe);
			keyframe.destroy();
		}
		else
		{
			var dur = keyframe.duration;
			keyframe.duration += difference - dur;
			keyFrame.duration += cast FlxMath.bound(dur - difference - 1, 0);
			_keyframes.insert(_keyframes.indexOf(keyframe) + 1, keyFrame);
		}

		keyFrame._parent = this;
		return keyFrame;
	}
	public function remove(frame:EitherType<Int, FlxKeyFrame>)
	{
		if ((frame is FlxKeyFrame))
		{
			_keyframes.remove(frame);
			return frame;
		}
		var index:Int = frame;
		if (length > index)
		{
			var keyframe = get(index);
			(keyframe.duration > 1) ? keyframe.duration-- : _keyframes.remove(keyframe);
			return keyframe;
		}
		return null;
	}
	public function rename(name:String = "")
	{
		_correctClip = false;
		//if (["", null].indexOf(name) != -1 && ["", null].indexOf(this.name) != -1)
		if (name != "" && name != null && this.name != "" && this.name != null)
		{
			name = 'Layer ${(_parent != null) ? _parent.getList().length : 1}';
		}
		if (_parent != null && _parent.get(name) != null)
		{
			name += " copy";
		}
		//if (["", null].indexOf(name) == -1)
		if (name != "" && name != null)
			this.name = name;
	}
	inline function set__parent(par:FlxTimeline)
	{
		_parent = par;
		_clipper = null;
		if (_parent != null)
		{
			switch(type)
			{
				case Clipped(layer):
					var layer = _parent.get(layer);
					if (layer != null && layer.type == Clipper)
					{
						_clipper = layer;
					}
				default:
			}
		}
		rename();
		return par;
	}
	inline function get_length()
	{
		var keyframe = _keyframes[_keyframes.length - 1];
		return (keyframe != null) ? keyframe.index + keyframe.duration : 0;
	}
	function set_type(value:LayerType)
	{
		_clipper = null;
		if (value != null)
		{
			switch(value)
			{
				case Clipped(layer):
					if (_parent != null)
					{
						var layer = _parent.get(layer);
						if (layer != null && layer.type == Clipper)
						{
							_clipper = layer;
						}
					}
				case Clipper:
					maskCamera = FlxPooledCamera.get();
				default:
			}
		}
		else
			value = Normal;
		return type = value;
	}
	function _setCurFrame(frame:Int)
	{
		if (length == 0 || frame > length)
		{
			_currFrame = null;
			return;
		}

		if (_currFrame != null)
		{
			if (_currFrame.index <= frame && _currFrame.index + _currFrame.duration > frame) return;

			var i = _keyframes.indexOf(_currFrame);

			var prevFrame = _currFrame;

			var nextKeyframe = _currFrame;
			if (nextKeyframe.index + nextKeyframe.duration <= frame)
			{
				while (nextKeyframe != null && nextKeyframe.index + nextKeyframe.duration <= frame)
				{
					nextKeyframe = _keyframes[++i];
				}
			}
			else if (nextKeyframe.index > frame)
			{
				while (nextKeyframe != null && nextKeyframe.index > frame)
				{
					nextKeyframe = _keyframes[--i];
				}
			}
			_currFrame = nextKeyframe;
			if (onFrameUpdate != null)
				onFrameUpdate(prevFrame, _currFrame);
		}
		else
			_currFrame = get(frame);
	}

	function updateBitmaps(rect:Rectangle)
	{
		if (_filterFrame == null || (rect.width > _filterFrame.parent.bitmap.width || rect.height > _filterFrame.parent.bitmap.height))
		{
			var wid = Math.ceil((_filterFrame == null || rect.width > _filterFrame.parent.width) ? rect.width : _filterFrame.parent.width);
			var hei = Math.ceil((_filterFrame == null || rect.height > _filterFrame.parent.height) ? rect.height : _filterFrame.parent.height);
			if (_filterFrame != null)
			{
				_filterFrame.parent.destroy();
				// FlxG.bitmap.remove(_bmpGraphic1);
				// FlxG.bitmap.remove(_bmpGraphic2);
			}
			else
			{
				@:privateAccess
				_filterFrame = new FlxFrame(null);
			}
			_filterFrame.parent = FlxG.bitmap.add(new BitmapData(wid, hei, 0), true);
			Utils.dispose(_bmp1);
			_bmp1 = new BitmapData(wid, hei, 0);
			// _bmpGraphic1 = FlxGraphic.fromBitmapData(_bmp1, true);
			Utils.dispose(_bmp2);
			_bmp2 = new BitmapData(wid, hei, 0);
			// _bmpGraphic2 = FlxGraphic.fromBitmapData(_bmp2, true);
			_filterFrame.frame = new FlxRect(0, 0, wid, hei);
			// _filterFrame.offset.set(rect.x, rect.y);
			_filterFrame.sourceSize.set(rect.width, rect.height);
			@:privateAccess
			_filterFrame.cacheFrameMatrix();
		}
		else
		{
			_bmp1.fillRect(_bmp1.rect, 0);
			_filterFrame.parent.bitmap.fillRect(_filterFrame.parent.bitmap.rect, 0);
			_bmp2.fillRect(_bmp2.rect, 0);
		}

	}

	public static function fromJSON(layer:Layers)
	{
		if (layer == null) return null;
		var l = new FlxLayer(layer.LN);
		final clpb = layer.Clpb;
		l.type = (layer.LT != null) ? Clipper : (clpb != null) ? Clipped(clpb) : Normal;
		final FR = layer.FR;
		if (FR != null)
		{
			for (frame in FR)
			{
				l.add(FlxKeyFrame.fromJSON(frame));
			}
		}

		return l;
	}
}
