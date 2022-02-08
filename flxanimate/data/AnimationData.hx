package flxanimate.data;

@:noCompletion
class AnimationData
{
	@:noCompletion
	public static function parseDurationFrames(frames:Array<Frame>):Array<Frame>
	{
		var result:Array<Frame> = [];

		for (frame in frames)
		{
			var i = 0;

			do
			{
				i++;
				result.push(frame);
			}
			while (i < frame.DU);
		}

		return result;
	}
}

typedef Parsed =
{
	var AN:Animation;
	var SD:SymbolDictionary;
	var MD:AtlasMetaData;
}

typedef Animation =
{
	var SN:String;
	var N:String;
	var TL:Timeline;
	var STI:SettingTimeInstance;
}

typedef SettingTimeInstance =
{
	var SI:SymbolInstance;
}

typedef SymbolDictionary =
{
	var S:Array<Animation>;
}

typedef Timeline =
{
	var L:Array<Layer>;
}

typedef Layer =
{
	var LN:String;
	var FR:Array<Frame>;
}

typedef Frame =
{
	var I:Int;
	var DU:Int;
	var E:Array<Element>;
}

typedef Element =
{
	var SI:SymbolInstance;
	var ASI:AtlasSymbolInstance;
}

typedef SymbolInstance =
{
	var SN:String;
	var ST:SymbolType;

	var FF:Int;
	var LP:LoopType;
	var TRP:TransformationPoint;
	var M3D:Array<Float>;
}

enum abstract LoopType(String) from String to String
{
	var LOOP = "LP";
	var PLAY_ONCE = "PO";
	var SINGLE_FRAME = "SF";
}

enum abstract SymbolType(String) from String to String
{
	var GRAPHIC = "G";
	var MOVIE_CLIP = "MC";
	var BUTTON = "B";
}

typedef AtlasSymbolInstance =
{
	var N:String;
	var M3D:Array<Float>;
}

typedef TransformationPoint =
{
	var x:Float;
	var y:Float;
}

typedef AtlasMetaData =
{
	var FRT:Float;
}