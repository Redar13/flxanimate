package flxanimate.animate;

import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;

import flxanimate.data.AnimationData;
import flxanimate.geom.FlxMatrix3D;

@:access(flxanimate.animate.SymbolParameters)
class FlxElement extends FlxObject implements IFlxDestroyable
{
	@:allow(flxanimate.animate.FlxKeyFrame)
	var _parent:FlxKeyFrame;
	/**
	 * All the other parameters that are exclusive to the symbol (instance, type, symbol name, etc.)
	 */
	public var symbol(default, null):SymbolParameters = null;
	/**
	 * The name of the bitmap itself.
	 */
	public var bitmap(default, set):String;
	/**
	 * The matrix that the symbol or bitmap has.
	 * **WARNING** The positions here are constant, so if you use `x` or `y`, this will concatenate to the matrix,
	 * not replace it!
	 */
	public var matrix(default, set):FlxMatrix;

	public var useShader:Bool = false;
	public var shader(default, set):Null<FlxShader> = null;

	public var flipX:Bool;
	public var flipY:Bool;

	@:allow(flxanimate.FlxAnimate)
	var _matrix:FlxMatrix = new FlxMatrix();

	@:allow(flxanimate.FlxAnimate)
	var _color:ColorTransform = new ColorTransform();

	/**
	 * Creates a new `FlxElement` instance.
	 * @param name the name of the element. `WARNING:` this name is dynamic, in other words, this name can used for the limb or the symbol!
	 * @param symbol the symbol settings, ignore this if you want to add a limb.
	 * @param matrix the matrix of the element.
	 */
	public function new(?bitmap:String = null, ?symbol:SymbolParameters = null, ?matrix:FlxMatrix = null)
	{
		super();
		this.bitmap = bitmap;
		this.symbol = symbol;
		if (symbol != null)
			symbol._parent = this;
		this.matrix = (matrix == null) ? new FlxMatrix() : matrix;

	}

	public override function toString()
	{
		return '{matrix: $matrix, bitmap: $bitmap, symbol: $symbol}';
	}
	public override function destroy()
	{
		super.destroy();
		_parent = null;
		if (symbol != null)
			symbol.destroy();
		bitmap = null;
		matrix = null;
		shader = null;
	}

	function set_bitmap(value:String)
	{
		if (value != bitmap && symbol != null && symbol.cacheAsBitmap)
			symbol._renderDirty = true;

		return bitmap = value;
	}
	function set_matrix(value:FlxMatrix)
	{
		(value == null) ? matrix.identity() : matrix = value;

		return value;
	}
	function set_shader(value)
	{
		if (value != shader && symbol != null && symbol.cacheAsBitmap)
			symbol._renderDirty = true;
		return shader = value;
	}

	static var _updCurSym:FlxSymbol;
	public function updateRender(elapsed:Float, curFrame:Int, dictionary:Map<String, FlxSymbol>, ?swfRender:Bool = false)
	{
		if (symbol != null && (_updCurSym = dictionary.get(symbol.name)) != null)
		{
			var curFF = (symbol.type == MovieClip) ? 0 : switch (symbol.loop)
			{
				case Loop:		(symbol.firstFrame + curFrame) % _updCurSym.length;
				case PlayOnce:	cast FlxMath.bound(symbol.firstFrame + curFrame, 0, _updCurSym.length - 1);
				default:		symbol.firstFrame;
			}

			symbol.update(curFF);
			@:privateAccess
			if (symbol._renderDirty && _parent != null && _parent._cacheAsBitmap)
			{
				symbol._renderDirty = false;
				_parent._renderDirty = true;
			}
			_updCurSym.updateRender(elapsed, curFF, dictionary, swfRender);
		}
		update(elapsed);
	}

	inline extern static final _eregOpt = "i";
	inline extern static final _eregSpace = "(?:_)?";

	// Suppost Eng & Rus
	static final _eregADD		  = new EReg("add|сложение|0", _eregOpt);
	static final _eregALPHA		  = new EReg("alpha|альфа|1", _eregOpt);
	static final _eregDARKEN	  = new EReg("darken|(?:замена+" + _eregSpace + ")?теймны(м|й)|2", _eregOpt);
	static final _eregDIFFERENCE  = new EReg("difference|разница|3", _eregOpt);
	static final _eregERASE		  = new EReg("erase|удаление|4", _eregOpt);
	static final _eregHARDLIGHT	  = new EReg("hardlight|жесткий" + _eregSpace + "свет|5", _eregOpt);
	static final _eregINVERT	  = new EReg("negative|invert|инверсия|негатив|6", _eregOpt);
	static final _eregLAYER		  = new EReg("layer|слой|7", _eregOpt);
	static final _eregLIGHTEN	  = new EReg("lighten|(?:замена+" + _eregSpace + ")?светлы(м|й)|8", _eregOpt);
	static final _eregMULTIPLY	  = new EReg("multiply|умножение|9", _eregOpt);
	static final _eregOVERLAY	  = new EReg("overlay|перекрытие|11", _eregOpt);
	static final _eregSCREEN	  = new EReg("screen|осветление|12", _eregOpt);
	static final _eregSUBTRACT	  = new EReg("substract|нормальное|14", _eregOpt);

	// suppost list: openfl.display.OpenGLRenderer.hx:1030

	public static final _eregBlendStartKey	 = new EReg("_bl|blend" + _eregSpace + "|смешение" + _eregSpace + "|наложнение" + _eregSpace, _eregOpt);
	public static final _eregBlendEndKey	 = new EReg("(?:_)?end", _eregOpt);

	public static function blendModeFromString(str:String):BlendMode
	{
		if (_eregADD.match(str))		 return BlendMode.ADD;
		if (_eregALPHA.match(str))		 return BlendMode.ALPHA;
		if (_eregDARKEN.match(str))		 return BlendMode.DARKEN;
		if (_eregDIFFERENCE.match(str))	 return BlendMode.DIFFERENCE;
		if (_eregERASE.match(str))		 return BlendMode.ERASE;
		if (_eregHARDLIGHT.match(str))	 return BlendMode.HARDLIGHT;
		if (_eregINVERT.match(str))		 return BlendMode.INVERT;
		if (_eregLAYER.match(str))		 return BlendMode.LAYER;
		if (_eregLIGHTEN.match(str))	 return BlendMode.LIGHTEN;
		if (_eregMULTIPLY.match(str))	 return BlendMode.MULTIPLY;
		if (_eregOVERLAY.match(str))	 return BlendMode.OVERLAY;
		if (_eregSCREEN.match(str))		 return BlendMode.SCREEN;
		if (_eregSUBTRACT.match(str))	 return BlendMode.SUBTRACT;
		// return BlendMode.NORMAL;
		return null;
	}
	public static function fromJSON(element:Element)
	{
		var SI = element.SI;
		var ASI = element.ASI;
		var symbol = SI != null;
		var params:SymbolParameters = null;
		if (symbol)
		{
			params = new SymbolParameters();
			params.instance = SI.IN;
			params.type = switch (SI.ST)
			{
				case movieclip, "movieclip": MovieClip;
				case button, "button":		 Button;
				default:					 Graphic;
			}
			if (params.instance != null && params.instance.length > 0)
			{
				if (_eregBlendStartKey.match(params.instance))
				{
					var endIsValid = _eregBlendEndKey.match(_eregBlendStartKey.matchedRight());
					params.blendMode = blendModeFromString(endIsValid ? _eregBlendEndKey.matchedLeft() : _eregBlendStartKey.matchedRight());
					// params.instance = params.instance.substring(end + 1);
				}
				else
				{
					params.blendMode = blendModeFromString(params.instance);
				}
			}
			final lpStr = SI.LP;
			params.loop = switch (lpStr == null ? loop : lpStr.split("R")[0]) // remove the reverse sufix
			{
				case playonce, "playonce":			PlayOnce;
				case singleframe, "singleframe":	SingleFrame;
				default:							Loop;
			}
			params.reverse = (lpStr == null) ? false : StringTools.contains(lpStr, "R");
			params.firstFrame = SI.FF;
			params.colorEffect = AnimationData.fromColorJson(SI.C);
			params.name = SI.SN;
			var transformationPoint = SI.TRP;
			params.transformationPoint.set(transformationPoint.x, transformationPoint.y);
			params.filters = AnimationData.fromFilterJson(SI.F);
		}

		var m3d = symbol ? SI.M3D : ASI.M3D;
		var m:Array<Float>;

		if (m3d == null)
		{
			// Initialize with identity matrix if m3d is null
    		m = [
				1, 0, 0,
				1, 0, 0
			];
		}
		else if (Std.isOfType(m3d, Array))
		{
			m = [m3d[0], m3d[1], m3d[4], m3d[5], m3d[12], m3d[13]];
		}
		else
		{
			m = [];
    		// Assuming m3d is an object with properties m00, m01, m02, etc.
			static final rowColNames = ["m00","m01","m10","m11","m30","m31"];
			m.resize(rowColNames.length);
			var fieldName:String;
			for (i in 0...rowColNames.length) {
				fieldName = rowColNames[i];
				m[i] = Reflect.hasField(m3d, fieldName) ? Reflect.field(m3d, fieldName) : 0;
			}
		}

		var pos = symbol ? SI.bitmap.POS : ASI.POS;
		if (pos != null)
		{
			m[4] += pos.x;
			m[5] += pos.y;
		}
		return new FlxElement(symbol ? SI.bitmap.N : ASI.N, params, new FlxMatrix(m[0], m[1], m[2], m[3], m[4], m[5]));
	}

	public static function fromJSONEx(element:Element)
	{
		var SI = element.SI;
		var ASI = element.ASI;
		var symbol = SI != null;
		var params:SymbolParameters = null;
		if (symbol)
		{
			params = new SymbolParameters();
			params.instance = SI.IN;
			params.type = switch (SI.ST)
			{
				case movieclip, "movieclip": MovieClip;
				case button, "button": Button;
				default: Graphic;
			}
			params.blendMode = SI.B;

			var lp:LoopType = (SI.LP == null) ? loop : SI.LP.split("R")[0];
			params.loop = switch (lp) // remove the reverse sufix
			{
				case playonce, "playonce": PlayOnce;
				case singleframe, "singleframe": SingleFrame;
				default: Loop;
			}
			params.reverse = (SI.LP == null) ? false : StringTools.contains(SI.LP, "R");
			params.firstFrame = SI.FF ?? 0;
			params.colorEffect = AnimationData.fromColorJson(SI.C);
			params.name = SI.SN;
			params.transformationPoint = FlxPoint.weak(SI.TRP.x, SI.TRP.y);
			params.filters = AnimationData.fromFilterJsonEx(SI.F);
		}
		var m:Array<Float> = null;
		var mx = symbol ? SI.MX : ASI.MX;
		if (mx != null)
		{
			m = mx;
		}
		else
		{
			var m3d = symbol ? SI.M3D : ASI.M3D;
			if (m3d != null)
			{
				m = m3d;
			}
		}
		m ??= [
			1, 0, 0,
			1, 0, 0
		];
		return new FlxElement(symbol ? SI.bitmap.N : ASI.N, params, new FlxMatrix(m[0], m[1], m[2], m[3], m[4], m[5]));
	}
}
