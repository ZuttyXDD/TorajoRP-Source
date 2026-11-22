package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.input.touch.FlxTouch;
import openfl.utils.Assets;
import haxe.Json;

class CreditsState extends FlxState
{
    var backButton:FlxSprite;
    var config:Dynamic = {};

    function assetPath(path:String):String
    {
        if (Assets.exists("_" + path)) return "_" + path;
        if (Assets.exists(path)) return path;
        return null;
    }

    function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);


    function startMenuMusic():Void
    {
        var path = assetPath("Assets/Sounds/menu.ogg");
        if (path == null) return;
        try
        {
            var music = Assets.getSound(path);
            if (music != null) FlxG.sound.playMusic(music, 1.0, true);
        }
        catch (e:Dynamic) trace('Falha ao iniciar musica do menu nos creditos: $e');
    }

    override public function create():Void
    {
        super.create();
        startMenuMusic();
        FlxG.cameras.bgColor = FlxColor.BLACK;
        var cfgPath = assetPath("Assets/Config.json");
        if (cfgPath != null) try config = Json.parse(Assets.getText(cfgPath)) catch (e:Dynamic) trace('Config invalido: $e');

        var bgPath = assetPath("Assets/MenuAssets/background.png");
        if (bgPath != null)
        {
            var bg = new FlxSprite(0, 0);
            bg.loadGraphic(Assets.getBitmapData(bgPath));
            bg.setGraphicSize(FlxG.width, FlxG.height);
            bg.updateHitbox();
            add(bg);
        }

        var credits = field(config, "credits");
        var message = field(credits, "text") == null ? "Jogo inteiramente feito por Arthur Melo!" : Std.string(field(credits, "text"));
        var size = field(credits, "fontSize") == null ? 30 : Std.int(field(credits, "fontSize"));
        var credit = new FlxText(0, 0, FlxG.width, message, size);
        credit.font = "Assets/fonts/Milky Moringa.ttf";
        credit.setFormat(null, size, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        credit.borderSize = 2;
        var xOffset = field(credits, "xOffset") == null ? 0 : Std.parseFloat(Std.string(field(credits, "xOffset")));
        var yOffset = field(credits, "yOffset") == null ? 0 : Std.parseFloat(Std.string(field(credits, "yOffset")));
        credit.screenCenter();
        credit.x += xOffset;
        credit.y += yOffset;
        add(credit);

        createBackButton();
    }

    function createBackButton():Void
    {
        var path = assetPath("Assets/UI/backButton.png");
        if (path == null) { trace("backButton.png nao encontrado em Assets/UI."); return; }
        backButton = new FlxSprite();
        backButton.loadGraphic(Assets.getBitmapData(path));
        backButton.setGraphicSize(72, 72);
        backButton.updateHitbox();
        backButton.x = FlxG.width - backButton.width - 20;
        backButton.y = 20;
        add(backButton);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        for (touch in FlxG.touches.list)
        {
            if (!touch.justPressed || backButton == null) continue;
            var p = touch.getWorldPosition();
            if (backButton.overlapsPoint(p))
            {
                FlxG.switchState(new MenuState());
                return;
            }
        }
    }
}
