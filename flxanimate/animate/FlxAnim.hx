package flxanimate.animate;

import haxe.extern.EitherType;

import openfl.geom.ColorTransform;

import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
#if FLX_SOUND_SYSTEM
import flixel.sound.FlxSound;
#end
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxSignal;
import flixel.util.FlxStringUtil;
import flixel.FlxG;

import flxanimate.animate.SymbolParameters;
import flxanimate.data.AnimationData;
import flxanimate.geom.FlxMatrix3D;

typedef AnimStuff = {
	var instance:FlxElement;
	var frameRate:Float;
	var loopPoint:Int;
}
typedef ClickStuff = {
	?OnClick:Void->Void,
	?OnRelease:Void->Void
}
typedef ButtonSettings = {
	?Callbacks:ClickStuff,
	#if FLX_SOUND_SYSTEM
	?Sound:FlxSound
	#end
}
@:access(flxanimate.FlxAnimate)
class FlxAnim implements IFlxDestroyable
{
	/**
	 * The amount of frames that are in the current symbol.
	 */
	public var length(get, never):Int;

	/**
	 * The Instance the texture atlas was exported when it was on stage.
	 */
	public var stageInstance:FlxElement;

	/**
	 * The current instance the animation is playing.
	 */
	public var curInstance:FlxElement;

	/**
	 * Metadata. shortcut to display the name of the document and the default framerate.
	 */
	public var metadata:FlxMetaData;

	/**
	 * The current symbol the instance is taking as a reference.
	 */
	public var curSymbol(get, never):FlxSymbol;

	public var curAnim:AnimStuff;
	public var curAnimName:String;

	/**
	 * Whether the animation has finished or not.
	 */
	public var finished(get, never):Bool;

	/**
	 * a reverse option where the animation plays backwards or not.
	 */
	public var reversed(get, set):Bool;

	/**
	 * A map containing all `FlxSymbol` instances, whether prefabricated or not.
	 */
	public var symbolDictionary:Map<String, FlxSymbol>;

	/**
		Checks whether MovieClips should move or not.
	**/
	public var swfRender:Bool = false;

	var buttonMap:Map<String, ButtonSettings> = new Map();
	/**
	 * When ever the animation is playing.
	 */
	public var isPlaying(default, null):Bool;

	/**
	 * A signal dispatched when the animation's over,
	 * when the current frame is equal to the current symbol's length.
	 *
	 * @param   animName     The name of the current animation.
	 * @param   symbolName   The name of the current symbol.
	*/
	public var onComplete = new FlxTypedSignal<(animName:String, symbolName:String)->Void>();

	/**
	 * A signal dispatched when the animation advances one frame.
	 *
	 * @param   animName      The name of the current animation.
	 * @param   symbolName    The name of the current symbol.
	 * @param   frameNumber   The current frame number.
	 */
	public var onFrame = new FlxTypedSignal<(animName:String, symbolName:String, frameNumber:Int)->Void>();

	/**
	 * A signal dispatched when current animation's loop is complete.
	 * Works only with looped animations.
	 *
	 * @param   animName      The name of the current animation.
	 * @param   symbolName    The name of the current symbol.
	 */
	public var onLoop = new FlxTypedSignal<(animName:String, symbolName:String)->Void>();

	/**
	 * The framerate of the current animation.
	 */
	public var framerate(default, set):Float;

	/**
	 * Internal, used for each skip between frames.
	 */
	var frameDelay:Float;

	/**
	 * The frame the animation is currently.
	 */
	public var curFrame(get, set):Int;

	var animsMap:Map<String, AnimStuff> = new Map();

	public var loopPoint(default, null):Int = 0;

	/**
	 *  The looping method of `curSymbol`.
	 *
	 * _Made public since `4.0.0`_
	 */
	public var loopType(get, set):Loop;

	/**
	 * How fast or slow the symbols are going to go.
	 * Default value is `1.0`
	 * @since `4.0.0`
	 */
	public var timeScale:Float = 1.;

	/**
	 	The type of the current symbol.
	 	This can be of three types:

	 	- `MovieClip`
	 	- `Graphic`
		- `Button`

	 */
	public var symbolType(get, set):SymbolT;

	var _parent:FlxAnimate;

	var _tick:Float;

	/**
	 * Creates a new `FlxAnim` instance.
	 * @param parent The `FlxAnimate` instance it's gonna control.
	 * @param coolParsed The Animation file.
	 */
	public function new(parent:FlxAnimate, ?coolParsed:AnimAtlas)
	{
		_tick = 0;
		_parent = parent;
		isPlaying = false;
		if (coolParsed != null) _loadAtlas(coolParsed);
	}
	@:allow(flxanimate.FlxAnimate)
	function _loadAtlas(animationFile:AnimAtlas)
	{
		symbolDictionary = [];
		stageInstance = null;

		if (animationFile == null) return;
		setSymbols(animationFile);

		stageInstance = (animationFile.AN.STI != null) ? FlxElement.fromJSON(cast animationFile.AN.STI) : new FlxElement(new SymbolParameters(animationFile.AN.SN));

		curInstance = stageInstance;

		curFrame = stageInstance.symbol.firstFrame;

		_parent.origin.copyFrom(stageInstance.symbol.transformationPoint);
		metadata = new FlxMetaData(animationFile.AN.N, animationFile.MD.FRT);
		framerate = metadata.frameRate;
	}
	/**
	 * Plays an animation.
	 * @param Name The name of an animation or an `FlxSymbol`
	 * @param Force Whether it should Force a reset to the animation before playing.
	 * @param Reverse If the animation will go on reverse or not.
	 * @param Frame To which frame it will begin.
	 */
	public function play(?Name:String = "", ?Force:Bool = false, ?Reverse:Bool = false, ?Frame:Int = 0)
	{
		pause();

		if (finished)
			Force = true;

		var curThing:AnimStuff = null;
		if (Name != "")
		{
			curThing = animsMap.get(Name);
			if (curThing == null)
			{
				function editCurThing()
				{
					curThing = {
						instance: curInstance,
						frameRate: metadata.frameRate,
						loopPoint: 0
					}
					animsMap.set(Name, curThing);
				}
				if (Name == metadata.name)
				{
					curInstance = stageInstance;
					editCurThing();
				}
				else if (symbolDictionary.exists(Name))
				{
					curInstance.symbol.reset();
					curInstance.symbol.name = Name;
					editCurThing();
				}
				else if (addByFrameLabel(Name, Name))
				{
					curThing = animsMap.get(Name);
				}
				if (curThing == null)
					FlxG.log.error('There\'s no animation called $Name!');
			}
			if (curThing != null)
			{
				Force = Force || curInstance != curThing.instance;

				curAnim = curThing;
				curInstance = curThing.instance;
				curAnimName = Name;
			}
		}


		if (Force || finished)
		{
			curFrame = Reverse ? length - 1 - Frame : Frame;
			_tick = 0;
		}
		reversed = Reverse;
		if (curThing == null)
		{
			framerate = metadata.frameRate;
			loopPoint = 0;
		}
		else
		{
			framerate = curThing.frameRate == 0 ? metadata.frameRate : curThing.frameRate;
			loopPoint = curThing.loopPoint;
		}

		resume();
	}

	public function playElement(element:FlxElement, ?Force:Bool = false, ?Reverse:Bool = false, ?Frame:Int = 0)
	{
		if (finished || curInstance != element)
			Force = true;

		if (curInstance == element && !Force) return;

		pause();

		if (element != null)
			curInstance = element;
		else
			curInstance = stageInstance;

		if (Force)
		{
			curFrame = Reverse ? length - 1 - Frame : Frame;
			_tick = 0;
		}

		resume();
	}

	/**
	 * Pauses the current animation.
	 */
	public inline function pause()
	{
		isPlaying = false;
	}

	/**
	 * stops the current animation.
	 */
	public inline function stop()
	{
		pause();
		curFrame = 0;
	}

	public inline function finish()
	{
		stop();

		curFrame = reversed ? 0 : length - 1;
	}

	/**
	 * Resumes the current animation.
	 */
	public inline function resume()
	{
		isPlaying = true;
	}

	function setSymbols(Anim:AnimAtlas)
	{
		symbolDictionary.set(Anim.AN.SN, new FlxSymbol(Utils.withoutDirectory(Anim.AN.SN), FlxTimeline.fromJSON(Anim.AN.TL)));

		if (Anim.SD != null)
		{
			for (symbol in Anim.SD.S)
			{
				symbolDictionary.set(symbol.SN, new FlxSymbol(Utils.withoutDirectory(symbol.SN), FlxTimeline.fromJSON(symbol.TL)));
			}
		}
	}

	public function update(elapsed:Float)
	{
		var animElapsed = elapsed * timeScale #if (flixel >= "5.5.0") * FlxG.animationTimeScale #end;
		if (frameDelay != 0 && isPlaying && !finished && animElapsed > 0)
		{
			_tick += animElapsed;

			while (_tick > frameDelay)
			{
				// reversed ? curFrame-- : curFrame++;
				_tick -= frameDelay;
				if (reversed)
				{
					if (loopType == Loop && curFrame == loopPoint)
					{
						curFrame = length - 1;
						onLoop.dispatch(curInstance.symbol.name, curSymbol.name);
					}
					else
						curFrame--;
				}
				else
				{
					if (loopType == Loop && curFrame == length - 1)
					{
						curFrame = loopPoint;
						onLoop.dispatch(curInstance.symbol.name, curSymbol.name);
					}
					else
						curFrame++;
				}
				curSymbol.fireCallbacks();
				onFrame.dispatch(curInstance.symbol.name, curSymbol.name, curFrame);
			}


			if (finished)
			{
				if (loopType == PlayOnce)
					pause();
				onComplete.dispatch(curInstance.symbol.name, curSymbol.name);
			}
		}
	}
	function get_finished()
		return switch(loopType)
		{
			case SingleFrame:	true;
			case PlayOnce:		reversed && curFrame == 0 || !reversed && curFrame >= length - 1;
			default:			false;
		}

	function get_curFrame()
	{
		return curSymbol?.curFrame ?? 0;
	}
	function set_curFrame(Value:Int)
	{
		if (curSymbol == null)
			return 0;

		return curSymbol.curFrame = (symbolType == MovieClip && !swfRender) ? 0 : switch (loopType)
		{
			case Loop:		(Value < 0) ? curSymbol.length - 1 : Value % curSymbol.length;
			case PlayOnce:	cast FlxMath.bound(Value, 0, curSymbol.length - 1);
			default:		Value;
		}
	}

	@:noCompletion var __addByFrameLabel:Bool;

	/**
	 * Creates an animation.
	 * @param Name The name of the animation to add.
	 * @param Prefix The name of the symbol or label animation you're looking.
	 * @param FrameRate The framerate of the animation to use.
	 * @param Looped Whether the animation should loop or not.
	 * @param Indices The indices you're gonna be using for the animation, like `[0,1,2]`.
	 * @param X A x offset to apply to the animation.
	 * @param Y A y offset to apply to the animation.
	 */
	public function addAnimation(Name:String, Prefix:String, FrameRate:Float = 0, Looped:Bool = true, ?Indices:Array<Int>, ?X:Float, ?Y:Float)
	{
		if (animsMap.exists(Name))
		{
			FlxG.log.error('There\'s animation "$Name" is already added!');
			return;
		}
		if (Indices != null && Indices.length > 0)
			addBySymbolIndices(Name, Prefix, Indices, FrameRate, Looped, X, Y);
		else
			addBySymbol(Name, Prefix, FrameRate, Looped, X, Y);
		if (!animsMap.exists(Name))
			FlxG.log.error('The animation "$Name" doesn\'t exist!');
	}

	public function addByFrameLabel(Name:String, FrameLabel:String, FrameRate:Float = 0, Indices:Array<Int> = null, Looped:Bool = true, ?X:Float, ?Y:Float) {
		if (symbolDictionary == null)
			return false;
		var keyFrame:FlxKeyFrame = symbolDictionary.get(stageInstance.symbol.name)?.getFrameLabel(FrameLabel);
		if (keyFrame == null)
			return false;

		__addByFrameLabel = true;
		if (keyFrame.duration > 1)
		{
			addBySymbolIndices(Name, stageInstance.symbol.name,
				(Indices == null || Indices.length == 0) ? keyFrame.getFrameIndices() : Indices,
				FrameRate, Looped, X, Y);
		}
		else
		{
			var listElements:Array<FlxElement> = keyFrame.getList();
			var element:FlxElement;
			for (i in 0...listElements.length)
			{
				element = listElements[listElements.length - 1 - i];
				if (element?.symbol != null)
				{
					if (Indices == null)
						addBySymbol(Name, element.symbol.name, FrameRate, Looped, X, Y);
					else
						addBySymbolIndices(Name, element.symbol.name, Indices, FrameRate, Looped, X, Y);
					break;
				}
			}
		}
		__addByFrameLabel = false;
		return true;
	}

	/**
	 * Creates an animation using an already made symbol from a texture atlas
	 * @param Name The name of the animation
	 * @param SymbolName the name of the symbol you're looking. if you have two symbols beginning by the same name, use `\` at the end to differ one symbol from another
	 * @param X the *x* axis of the animation.
	 * @param Y  the *y* axis of the animation.
	 * @param FrameRate the framerate of the animation.
	 */
	public function addBySymbol(Name:String, SymbolName:String, FrameRate:Float = 0, Looped:Bool = true, ?X:Float, ?Y:Float)
	{
		if (symbolDictionary == null || (!__addByFrameLabel && addByFrameLabel(Name, SymbolName, FrameRate, null, Looped, X, Y)))
		{
			return;
		}
		var params = new FlxElement(new SymbolParameters(Looped ? Loop : PlayOnce), new FlxMatrix(1,0,0,1,X,Y));
		for (name in symbolDictionary.keys())
		{
			if (startsWith(name, SymbolName))
			{
				params.symbol.name = name;
				break;
			}
		}
		if (params.symbol.name != null)
			animsMap.set(Name, {
				instance: params,
				frameRate: FrameRate,
				loopPoint: 0
			});
		else
			FlxG.log.error('No symbol was found with the name $SymbolName!');
	}
	function startsWith(reference:String, string:String):Bool
	{
		if (StringTools.endsWith(string, "\\"))
			return reference == string.substring(0, string.length - 1)
		else
			return StringTools.startsWith(reference, string);
	}
	/**
	 * Creates an animation using the indices, looking as a reference the main animation of the texture atlas.
	 * @param Name The name of the animation you're creating
	 * @param Indices The indices you're gonna be using for the animation, like `[0,1,2]`.
	 * @param FrameRate the framerate of the animation.
	 */
	public function addByAnimIndices(Name:String, Indices:Array<Int>, ?FrameRate:Float)
	{
		addBySymbolIndices(Name, stageInstance.symbol.name, Indices, FrameRate, stageInstance.symbol.loop == Loop, 0,0);
	}
	public function addBySymbolIndices(Name:String, SymbolName:String, Indices:Array<Int>, FrameRate:Float = 0, Looped:Bool = true, ?X:Float, ?Y:Float)
	{
		if (symbolDictionary == null || (!__addByFrameLabel && addByFrameLabel(Name, SymbolName, FrameRate, Indices, Looped, X, Y)))
		{
			return;
		}
		__addByFrameLabel = false;
		if (!symbolDictionary.exists(SymbolName))
		{
			FlxG.log.error('$SymbolName does not exist as a symbol! maybe you misspelled it?');
			return;
		}
		var params = new FlxElement(new SymbolParameters(Looped ? Loop : PlayOnce), new FlxMatrix(1,0,0,1,X,Y));
		var timeline = new FlxTimeline();
		timeline.add("Layer 1");

		for (index => i in Indices)
		{
			var keyframe = new FlxKeyFrame(index);

			var params = new SymbolParameters(SymbolName, params.symbol.loop);
			params.firstFrame = i;
			keyframe.add(new FlxElement(params));
			timeline.get(0).add(keyframe);
		}
		var symbol = new FlxSymbol(Name, timeline);
		params.symbol.name = symbol.name;

		symbolDictionary.set(symbol.name, symbol);

		animsMap.set(Name, {
			instance: params,
			frameRate: FrameRate,
			loopPoint: 0
		});
	}

	inline function set_framerate(value:Float):Float
	{
		frameDelay = value == 0 ? 0 : 1 / value;
		return framerate = value;
	}
	/**
	 * This adds a new animation by adding a custom timeline, obviously taking as a reference the timeline syntax!
	 * **WARNING**: I, *CheemsAndFriends*, do **NOT** recommend this unless you're using an extern json file to do this!
	 * if you wanna make a custom symbol to play around and is separated from the texture atlas, go ahead! but if you wanna just make a new symbol,
	 * just do it in Flash directly
	 * @param Name The name of the new Symbol.
	 * @param Timeline The timeline which will have the symbol.
	 * @param FrameRate The framerate it'll go, by default is 30.
	 */
	public function addByCustomTimeline(Name:String, Timeline:FlxTimeline, FrameRate:Float = 0, Looped:Bool = true)
	{
		symbolDictionary.set(Name, new FlxSymbol(Utils.withoutDirectory(Name), Timeline));
		var params = new FlxElement(new SymbolParameters(Looped ? Loop : PlayOnce));
		animsMap.set(Name, {
			instance: params,
			frameRate: FrameRate,
			loopPoint: 0
		});
	}

	public inline function get_length()
		return curSymbol.length;

	public inline function getFrameLabel(name:String, ?layer:EitherType<Int, String>):FlxKeyFrame
		return curSymbol.getFrameLabel(name, layer);

	public function getLabel(Label:String, ?layer:EitherType<Int, String>, ?instance:FlxSymbol)
	{
		instance = instance == null ? symbolDictionary.get(stageInstance.symbol.name) : instance;
		return instance == null ? null : instance.getFrameLabel(Label, layer);
	}

	public function toString()
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("symbolDictionary", symbolDictionary),
			LabelValuePair.weak("framerate", framerate)
		]);
	}

	/**
	 * Redirects the frame into a frame with a frame label of that type.
	 * @param name the name of the label.
	 */
	public function goToFrameLabel(name:String, ?layer:EitherType<Int, String>)
	{
		pause();

		var label = getFrameLabel(name, layer);

		if (label != null)
			curFrame = label.index;

		resume();
	}

	/**
	 * Checks the next frame label name you're looking for.
	 * **WARNING: DO NOT** confuse with `anim.curSymbol.getNextToFrameLabel`!!
	 * @param name the name of the frame label.
	 * @return A `String`. WARNING: it can be `null`
	 */
	public function getNextToFrameLabel(name:String):Null<String>
		return curSymbol.getNextToFrameLabel(name).name;

	/**
	 * Links a callback into a label.
	 * @param label the name of the label.
	 * @param callback the callback you're going to add
	 */
	public inline function addCallbackTo(label:String, callback:()->Void)
		return curSymbol.addCallbackTo(label, callback);

	public inline function removeCallbackFrom(label:String, callback:()->Void)
		return curSymbol.removeCallbackFrom(label, callback);

	public inline function removeAllCallbacksFrom(label:String)
		return curSymbol.removeAllCallbacksFrom(label);

	public inline function getFrameLabels(?layer:EitherType<Int, String>)
		return curSymbol.getFrameLabels(layer);

	public inline function getFrameLabelNames(?layer:EitherType<Int, String>)
		return curSymbol.getFrameLabelNames(layer);

	inline function get_loopType()
		return curInstance.symbol.loop;

	inline function set_loopType(type:Loop)
		return curInstance.symbol.loop = type;

	inline function get_symbolType()
		return curInstance.symbol.type;

	inline function set_symbolType(type:SymbolT)
		return curInstance.symbol.type = type;

	inline function get_reversed()
		return curInstance.symbol.reverse;

	inline function set_reversed(value:Bool)
		return curInstance.symbol.reverse = value;

	public inline function getByName(name:String)
		return animsMap.get(name);


	public function getByInstance(instance:String, ?frame:Int = null, ?layer:EitherType<String, Int>)
	{
		if (frame == null) frame = curFrame;

		var symbol:FlxSymbol = null;

		var layers = (layer == null) ? curSymbol.timeline.getList() : [curSymbol.timeline.get(layer)];
		for (layer in layers)
		{
			if (layer == null) continue;
			var elements = layer.get(frame);

			if (elements == null || instance == "") continue;

			for (element in elements.getList())
			{
				if (element.symbol != null && element.symbol.instance == instance)
				{
					return symbolDictionary.get(element.symbol.name);
				}
			}
		}

		FlxG.log.error("This instance doesn't exist! Have you checked if the layer exists or the instance isn't misspelled?");
		return null;
	}

	public function getSymbolNameByLayerMark(layerMark:String)
	{
		var mainSymbol = symbolDictionary.get(stageInstance.symbol.name);
		var label = mainSymbol == null ? null : mainSymbol.getFrameLabel(layerMark);
		if (label == null) // search from main symbol
			return null;
		var elements = label.getList();
		return elements.length > 0 ? elements[0].symbol.name : null;
	}

	inline public function existsByName(name:String)
	{
		return animsMap.exists(name);
	}

	inline function get_curSymbol()
	{
		return symbolDictionary.get(curInstance.symbol.name);
	}

	public function destroy()
	{
		FlxDestroyUtil.destroy(onComplete);
		FlxDestroyUtil.destroy(onFrame);
		FlxDestroyUtil.destroy(onLoop);

		isPlaying = false;
		curFrame = 0;
		framerate = 0;
		_tick = 0;
		buttonMap = null;
		animsMap = null;
		// curInstance.destroy();
		curInstance = null;
		stageInstance.destroy();
		stageInstance = null;
		metadata.destroy();
		metadata = null;
		swfRender = false;
		_parent = null;
		for (symbol in symbolDictionary.iterator())
		{
			symbol.destroy();
		}
		symbolDictionary = null;
	}
}
/**
 * This class shows what framerate the animation was initially set.
 * (Remind myself to include more than this, like more metadata to stuff lmao)
 */
class FlxMetaData implements IFlxDestroyable
{
	public var name:String;

	public var frameRate:Float;

	public var showHiddenLayers:Bool;

	public var skipFilters:Bool;

	public var skipBlends:Bool;

	public function new(name:String, frameRate:Float)
	{
		this.name = name;
		this.frameRate = frameRate;
		showHiddenLayers = false;
		skipFilters = false;
		skipBlends = false;
	}
	public function toString()
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("name", name),
			LabelValuePair.weak("frameRate", frameRate),
			LabelValuePair.weak("showHiddenLayers", showHiddenLayers),
			LabelValuePair.weak("skipFilters", skipFilters),
			LabelValuePair.weak("skipBlends", skipBlends)
		]);
	}
	public function destroy()
	{
		name = null;
		frameRate = 0;
	}
}
