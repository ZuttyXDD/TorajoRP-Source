package;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxFrame;

class CharacterActor
{
    public var data:CharacterData;
    public var sprite:FlxSprite;
    public var verticalSpeed:Float = 0;
    public var dragging:Bool = false;
    public var dragOffsetX:Float = 0;
    public var dragOffsetY:Float = 0;
    public var grounded:Bool = false;
    public var cachedFrame:FlxFrame;
    public var visibleMinX:Int = 0;
    public var visibleMinY:Int = 0;
    public var visibleMaxX:Int = 0;
    public var visibleMaxY:Int = 0;
    public var hasVisiblePixels:Bool = false;

    // Estado de sincronizacao online.
    public var remoteControlled:Bool = false;
    public var networkTargetX:Float = 0;
    public var networkTargetY:Float = 0;
    public var networkLerpRemaining:Float = 0;
    public var networkLerpDuration:Float = 0.5;
    public var networkHasTarget:Bool = false;
    public var networkLastSentX:Float = 0;
    public var networkLastSentY:Float = 0;
    public var networkHasSentPosition:Bool = false;
    public var controllerUsername:String = "";

    public function new(data:CharacterData, sprite:FlxSprite)
    {
        this.data = data;
        this.sprite = sprite;
    }
}
