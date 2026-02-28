package flxanimate.animate;

import openfl.display.BlendMode;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.FlxG;

import openfl.display.Sprite;
import openfl.filters.BitmapFilter;
import openfl.geom.ColorTransform;
import openfl.utils.Function;

import haxe.extern.EitherType;

import flxanimate.animate.FlxLayer;
import flxanimate.data.AnimationData;
import flxanimate.effects.FlxColorEffect;

class FlxKeyFrame
{
	public var name(default, set):Null<String>;

	@:allow(flxanimate.FlxAnimate)
	var _filterFrame:FlxFrame;

	public var classicTween(default, set):Bool;

	private var _tFrame:FlxKeyFrame;

	// @:allow(flxanimate.FlxAnimate)
	// var _bitmapMatrix:FlxMatrix;

	@:allow(flxanimate.animate.FlxSymbol)
	@:allow(flxanimate.FlxAnimate)
	var callbacks(default, null):Array<Function>;
	@:allow(flxanimate.animate.FlxLayer)
	var _parent:FlxLayer;

	public var index(default, set):Int;
	public var duration(default, set):Int;
	public var colorEffect(default, set):FlxColorEffect;
	public var blendMode:BlendMode = NORMAL;

	@:allow(flxanimate.FlxAnimate)
	var _elements(default, null):Array<FlxElement>;

	@:allow(flxanimate.FlxAnimate)
	@:allow(flxanimate.animate.FlxLayer)
	var _renderDirty:Bool = false;

	@:allow(flxanimate.animate.FlxLayer)
	var _cacheAsBitmap:Bool;

	@:allow(flxanimate.FlxAnimate)
	var _ff:Int = -1;

	// var clTMat:FlxMatrix = new FlxMatrix();

	public var filters(default, set):Array<BitmapFilter>;

	var _curFrame:Int = 0;
	public function new(index:Int, ?duration:Int = 1, ?elements:Array<FlxElement> = null, ?colorEffect:EitherType<ColorEffect, FlxColorEffect> = null, ?name:String = null)
	{
		this.index = index;
		this.duration = duration;

		this.name = name;
		_elements = elements ?? [];
		this.colorEffect = colorEffect;
		callbacks = [];
		// _bitmapMatrix = FlxAnimate.matrixesPool.get();
	}

	function set_duration(duration:Int)
	{
		var difference:Int = cast this.duration - FlxMath.bound(duration, 1);
		this.duration = cast FlxMath.bound(duration, 1);
		if (_parent != null)
		{
			var frame = _parent.get(index + duration);
			if (frame != null)
				frame.index -= difference;
		}
		return duration;
	}
	function set_filters(value:Array<BitmapFilter>)
	{
		_renderDirty = true;
		if (value != null && value.length > 0)
			_cacheAsBitmap = true;
		return filters = value;
	}

	/**
	 * Get an array of the frame indices that this keyframe spans.
	 * For example, if the keyframe spans from `10` to `15`, the array will be `[10, 11, 12, 13, 14, 15]`.
	 * @return The integer array.
	*/
	public inline function getFrameIndices():Array<Int> {
		return [for (i in index...(index + duration)) i];
	}

	public function update(frame:Int)
	{
		if (filters == null || filters.length == 0 || _renderDirty) return;

		for (filter in filters)
		{
			@:privateAccess
			if (filter.__renderDirty)
			{
				_renderDirty = true;
				return;
			}
		}
	}
	public inline function updateRender(elapsed:Float, curFrame:Int, dictionary:Map<String, FlxSymbol>, ?swfRender:Bool = false)
	{
		var curFrame = curFrame - index;

		update(curFrame);

		for (element in _elements)
		{
			element.updateRender(elapsed, curFrame, dictionary, swfRender);
		}
	}
	public function add(element:EitherType<FlxElement, Function>)
	{
		if (element is FlxElement)
		{
			var element:FlxElement = element;
			if (element == null)
			{
				FlxG.log.error("this element is null!");
				return null;
			}
			element._parent = this;
			_elements.push(element);
		}
		else
		{
			if (element == null)
			{
				FlxG.log.error("this callback is null!");
				return null;
			}
			callbacks.push(element);
		}

		return element;
	}
	public inline function get(element:Int)
	{
		return _elements[element];
	}
	public inline function getList()
	{
		return _elements;
	}
	public function remove(element:EitherType<FlxElement, Function>)
	{
		if (element == null) return null;

		if (element is FlxElement)
		{
			if (element == null || !_elements.remove(element))
			{
				FlxG.log.error("this element doesn't exist!");
				return null;
			}
		}
		else
		{
			if (element == null || !callbacks.remove(element))
			{
				FlxG.log.error("this callback doesn't exist!");
				return null;
			}
		}
		return element;
	}
	public function fireCallbacks()
	{
		var i = 0;
		while (i < callbacks.length)
		{
			callbacks[i]();
			i++;
		}
	}
	public inline function removeCallbacks()
	{
		callbacks = [];
	}
	public function clone()
	{
		var keyframe = new FlxKeyFrame(duration, _elements, colorEffect, name);
		keyframe.blendMode = blendMode;
		keyframe.callbacks = callbacks;
		return keyframe;
	}

	public function destroy()
	{
		_parent = null;
		name = null;
		index = 0;
		duration = 0;
		callbacks = null;
		blendMode = null;
		colorEffect = null;
		// FlxAnimate.matrixesPool.put(_bitmapMatrix);
		for (element in _elements)
		{
			element.destroy();
		}
	}

	public inline function toString()
	{
		return '{name: $name, index: $index, duration: $duration}';
	}
	function set_colorEffect(value:EitherType<ColorEffect, FlxColorEffect>)
	{
		if (value == null)
			value = None;
		if (value is ColorEffect)
			colorEffect = AnimationData.parseColorEffect(value);
		else
			colorEffect = value;

		return colorEffect;
	}

	function set_index(i:Int)
	{
		index = i;
		if (_parent != null)
		{
			_parent.remove(this);
			_parent.add(this);
		}
		return index;
	}
	function set_name(name:String)
	{
		if (_parent != null)
		{
			if (_parent._labels[this.name] == this)
				_parent._labels.remove(this.name);
			_parent._labels.set(name, this);
		}
		return this.name = name;
	}
	function set_classicTween(value:Bool)
	{
		classicTween = value;

		if (_parent != null)
			_tFrame = classicTween ? _parent._keyframes[_parent._keyframes.indexOf(this) + 1] : null;

		return value;
	}

	public static function fromJSON(frame:Frame)
	{
		if (frame == null) return null;

		var name = frame.N;
		final keyframe = new FlxKeyFrame(frame.I, frame.DU, null, AnimationData.fromColorJson(frame.C), name);
		final E = frame.E;
		if (E != null)
			for (element in E)
				keyframe.add(FlxElement.fromJSON(element));

		if (name != null && name.length > 0)
		{
			if (FlxElement._eregBlendStartKey.match(name))
			{
				var endIsValid = FlxElement._eregBlendEndKey.match(FlxElement._eregBlendStartKey.matchedRight());
				keyframe.blendMode = FlxElement.blendModeFromString(endIsValid ? FlxElement._eregBlendEndKey.matchedLeft() : FlxElement._eregBlendStartKey.matchedRight());
			}
			else
			{
				keyframe.blendMode = FlxElement.blendModeFromString(name);
			}
		}
		keyframe.filters = AnimationData.fromFilterJson(frame.F);

		return keyframe;
	}

	public static function fromJSONEx(frame:Frame)
	{
		if (frame == null) return null;

		var keyframe = new FlxKeyFrame(frame.I, frame.DU, null, AnimationData.fromColorJson(frame.C), frame.N);
		final E = frame.E;
		if (E != null)
			for (element in E)
				keyframe.add(FlxElement.fromJSONEx(element));

		keyframe.blendMode = (frame.B ?? NORMAL);
		keyframe.filters = AnimationData.fromFilterJsonEx(frame.F);

		return keyframe;
	}
}