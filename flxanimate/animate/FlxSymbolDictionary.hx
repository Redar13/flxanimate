package flxanimate.animate;

import flixel.graphics.frames.FlxFramesCollection;
import flxanimate.data.AnimationData.AnimAtlas;
import haxe.extern.EitherType;
import haxe.io.Path;

class FlxSymbolDictionary
{
	@:allow(flxanimate.animate.FlxAnim)
	var _parent:FlxAnim;

	var _mcFrame:Map<String, Int> = new Map<String, Int>();

	var _symbols:Map<String, FlxSymbol> = new Map<String, FlxSymbol>();

	public var length(default, null):Int = 0;

	public var frames:FlxFramesCollection = null;

	public function new(?parent:FlxAnim)
	{
		_parent = parent;
	}

	public function getLibrary(library:String):Map<String, FlxSymbol>
	{
		var path = Utils.directory(Path.addTrailingSlash(library));
		var libraries = new Map<String, FlxSymbol>();
		for (instance => symb in _symbols)
			if (path == instance)
				libraries.set(path, symb);
		return libraries;
	}

	public inline function existsSymbol(symbol:String):Bool
	{
		return _symbols.exists(symbol);
	}

	public inline function getSymbol(symbol:String):FlxSymbol
	{
		return _symbols.get(symbol);
	}

	public function addSymbol(symbol:FlxSymbol, ?overrideSymbol:Bool = false):Void
	{
		if (!_symbols.exists(symbol.getPathKey()))
		{
			length++;
		}
		else if (!overrideSymbol)
		{
			symbol.name += " Copy";
		}

		symbol.location = Utils.directory(symbol.name);
		symbol.name = Utils.withoutDirectory(symbol.name);

		_symbols.set(symbol.getPathKey(), symbol);
	}

	public function addLibrary(library:Map<String, FlxSymbol>, ?overrideSymbol:Bool = false):Void
	{
		for (symbol in library)
		{
			addSymbol(symbol, overrideSymbol);
		}
	}

	public function removeLibrary(library:String):Bool
	{
		var bool:Bool = false;

		var library = getLibrary(library);

		for (symbol in library)
		{
			if (removeSymbol(symbol))
				bool = true;
		}

		return bool;
	}
	public function removeSymbol(symbol:EitherType<FlxSymbol, String>):Bool
	{
		var bool:Bool = _symbols.remove(Std.isOfType(symbol, FlxSymbol) ? cast (symbol, FlxSymbol).name : symbol);

		if (bool)
			length--;

		return bool;
	}

	public function getList():Map<String, FlxSymbol>
	{
		return _symbols;
	}

	public function fromJSON(animation:AnimAtlas):Void
	{
		var AN = animation.AN;
		addSymbol(new FlxSymbol(AN.SN, FlxTimeline.fromJSON(AN.TL)));

		var SD = animation.SD;
		if (SD != null)
		{
			for (symbol in SD.S)
			{
				addSymbol(new FlxSymbol(symbol.SN, FlxTimeline.fromJSON(symbol.TL)));
			}
		}
	}

	public function fromJSONEx(animation:AnimAtlas):Void
	{
		var AN = animation.AN;
		addSymbol(new FlxSymbol(AN.SN, FlxTimeline.fromJSONEx(AN.TL)));

		var SD = animation.SD;
		if (SD != null)
		{
			for (symbol in SD.S)
			{
				addSymbol(new FlxSymbol(symbol.SN, FlxTimeline.fromJSONEx(symbol.TL)));
			}
		}
	}
}