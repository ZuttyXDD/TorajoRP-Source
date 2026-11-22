package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.input.touch.FlxTouch;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestMethod;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import haxe.Json;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.filters.GlowFilter;
import openfl.utils.Assets;

/**
 * Tela mobile de salas online.
 * Cria ou entra via REST. Ao receber credenciais validas, guarda a sessao
 * e abre o PlayState. A conexao WebSocket/sincronizacao ainda sera integrada
 * em uma etapa posterior.
 */
class MultiplayerState extends FlxState
{
    static inline var API:String = "https://torajorp-online.tutu18417.workers.dev";

    var code:String = "";
    var statusText:FlxText;
    var codeText:FlxText;
    var usernameInput:TextField;
    var busy:Bool = false;
    var buttons:Array<FlxSprite> = [];
    var buttonIds:Array<Int> = [];
    static inline var GAME_FONT:String = "Assets/fonts/Milky Moringa.ttf";
    static inline var UI_ALPHA:Float = 0.68;

    public function new() super();


    function startMenuMusic():Void
    {
        var path = Assets.exists("_Assets/Sounds/menu.ogg") ? "_Assets/Sounds/menu.ogg" : "Assets/Sounds/menu.ogg";
        if (!Assets.exists(path)) return;
        try
        {
            var music = Assets.getSound(path);
            if (music != null) FlxG.sound.playMusic(music, 1.0, true);
        }
        catch (e:Dynamic) trace('Falha ao iniciar musica do menu no multiplayer: $e');
    }

    function stopMenuMusic():Void
    {
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }
    }

    override public function create():Void
    {
        super.create();
        FlxG.cameras.bgColor = FlxColor.BLACK;
        startMenuMusic();
        var bgPath = Assets.exists("_Assets/MenuAssets/background.png") ? "_Assets/MenuAssets/background.png" : "Assets/MenuAssets/background.png";
        if (Assets.exists(bgPath))
        {
            var bg = new FlxSprite(0, 0);
            bg.loadGraphic(Assets.getBitmapData(bgPath));
            bg.setGraphicSize(FlxG.width, FlxG.height);
            bg.updateHitbox();
            add(bg);
        }

        addText("MULTIPLAYER", 0, 42, FlxG.width, 48, 34, FlxColor.WHITE, true);
        addText("Digite o codigo de uma sala ou crie a sua.", 0, 100, FlxG.width, 30, 18, 0xFFD0D2DC, true);
        addText("USUARIO", 260, 122, 320, 24, 16, FlxColor.WHITE, false);
        usernameInput = new TextField();
        usernameInput.type = TextFieldType.INPUT;
        usernameInput.x = 260;
        usernameInput.y = 150;
        usernameInput.width = 320;
        usernameInput.height = 44;
        usernameInput.maxChars = 20;
        usernameInput.restrict = "A-Za-z0-9 _-";
        usernameInput.background = true;
        usernameInput.backgroundColor = 0xAA343B50;
        usernameInput.border = true;
        usernameInput.borderColor = 0xAA8992AA;
        usernameInput.textColor = 0xFFFFFFFF;
        usernameInput.alpha = UI_ALPHA;
        usernameInput.defaultTextFormat = new TextFormat("Milky Moringa", 20, 0xFFFFFF, true);
        usernameInput.filters = [new GlowFilter(0x000000, 1, 4, 4, 8, 1)];
        FlxG.stage.addChild(usernameInput);
        addText("CODIGO", 650, 122, 300, 24, 16, FlxColor.WHITE, false);
        codeText = addText("______", 650, 150, 300, 54, 38, FlxColor.WHITE, true);

        var keys:Array<String> = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "APAGAR", "0", "LIMPAR"];
        for (i in 0...keys.length)
        {
            var col = i % 3;
            var row = Std.int(i / 3);
            var actionId = i <= 8 ? i + 1 : (i == 9 ? 10 : (i == 10 ? 0 : 11));
            addButton(keys[i], 390 + col * 170, 220 + row * 72, 150, 58, actionId);
        }

        addButton("ENTRAR NA SALA", 260, 530, 330, 64, 20);
        addButton("VOLTAR", 620, 530, 180, 64, 21);
        addButton("CRIAR SALA", 820, 530, 220, 64, 22);

        statusText = addText("Conecte-se pela internet para jogar com amigos.", 40, 625, FlxG.width - 80, 40, 16, 0xFFBFC5D5, true);
        refreshCode();
    }

    function addText(value:String, x:Float, y:Float, width:Float, height:Float, size:Int, color:Int, centered:Bool):FlxText
    {
        var text = new FlxText(x, y, width, value, size);
        text.font = GAME_FONT;
        text.setFormat(null, size, FlxColor.WHITE, centered ? FlxTextAlign.CENTER : FlxTextAlign.LEFT,
            flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        text.borderSize = 2;
        add(text);
        return text;
    }

    function addButton(label:String, x:Float, y:Float, width:Float, height:Float, id:Int):Void
    {
        var background = new FlxSprite(x, y).makeGraphic(Std.int(width), Std.int(height), 0xAA343B50);
        background.alpha = UI_ALPHA;
        add(background);
        addText(label, x, y + Std.int((height - 24) * 0.5), width, 30, id >= 20 ? 18 : 23, FlxColor.WHITE, true);
        buttons.push(background);
        buttonIds.push(id);
    }

    function refreshCode():Void
    {
        if (codeText != null) codeText.text = code.length == 0 ? "______" : code;
    }

    function pointHits(sprite:FlxSprite, touch:FlxTouch):Bool
    {
        if (sprite == null || touch == null || FlxG.camera == null) return false;
        return sprite.overlapsPoint(touch.getWorldPosition(FlxG.camera));
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (busy) return;

        for (touch in FlxG.touches.list)
        {
            if (!touch.justPressed) continue;
            for (i in 0...buttons.length)
            {
                if (!pointHits(buttons[i], touch)) continue;
                var id = buttonIds[i];
                if (id >= 1 && id <= 9)
                {
                    if (code.length < 6) code += Std.string(id);
                    refreshCode();
                }
                else if (id == 0)
                {
                    if (code.length < 6) code += "0";
                    refreshCode();
                }
                else if (id == 10)
                {
                    if (code.length > 0) code = code.substr(0, code.length - 1);
                    refreshCode();
                }
                else if (id == 11)
                {
                    code = "";
                    refreshCode();
                }
                else if (id == 20) joinRoom();
                else if (id == 21) FlxG.switchState(new MenuState());
                else if (id == 22) createRoom();
                return;
            }
        }
    }

    function send(path:String, payload:Dynamic, onSuccess:Dynamic->Void):Void
    {
        if (busy) return;
        busy = true;
        if (statusText != null) statusText.text = "Conectando ao servidor...";

        var request = new URLRequest(API + path);
        request.method = URLRequestMethod.POST;
        request.contentType = "application/json";
        request.data = Json.stringify(payload);

        var loader = new URLLoader();
        loader.addEventListener(Event.COMPLETE, function(_)
        {
            busy = false;
            var raw = Std.string(loader.data);
            try
            {
                var result:Dynamic = Json.parse(raw);
                var errorValue:Dynamic = Reflect.field(result, "error");
                if (errorValue != null)
                {
                    if (statusText != null) statusText.text = "Erro: " + Std.string(errorValue);
                    return;
                }
                onSuccess(result);
            }
            catch (error:Dynamic)
            {
                trace('Resposta nao-JSON de $path: $raw');
                if (statusText != null) statusText.text = "Resposta invalida do servidor.";
            }
        });

        loader.addEventListener(IOErrorEvent.IO_ERROR, function(_)
        {
            busy = false;
            if (statusText != null) statusText.text = "Falha de conexao. Verifique sua internet e o Worker.";
        });

        try loader.load(request)
        catch (error:Dynamic)
        {
            busy = false;
            if (statusText != null) statusText.text = "Nao foi possivel conectar ao servidor.";
        }
    }

    function getUsername():String
    {
        return usernameInput == null ? "" : StringTools.trim(usernameInput.text).substr(0, 20);
    }

    function detachUsernameInput():Void
    {
        if (usernameInput != null && usernameInput.parent != null)
            usernameInput.parent.removeChild(usernameInput);
    }

    override public function destroy():Void
    {
        detachUsernameInput();
        super.destroy();
    }

    function enterGameplay(result:Dynamic, role:String):Void
    {
        var tokenValue:Dynamic = Reflect.field(result, "token");
        var playerIdValue:Dynamic = role == "host" ? "host" : Reflect.field(result, "playerId");
        if (tokenValue == null || playerIdValue == null)
        {
            if (statusText != null) statusText.text = "O servidor nao retornou as credenciais da sala.";
            return;
        }

        MultiplayerSession.roomCode = code;
        MultiplayerSession.token = Std.string(tokenValue);
        MultiplayerSession.playerId = Std.string(playerIdValue);
        MultiplayerSession.role = role;
        MultiplayerSession.username = getUsername();
        detachUsernameInput();
        stopMenuMusic();
        MultiplayerSession.active = true;

        if (statusText != null) statusText.text = "Sala pronta! Abrindo jogo...";
        FlxG.switchState(new PlayState());
    }

    function createRoom():Void
    {
        var username = getUsername();
        if (username.length == 0)
        {
            if (statusText != null) statusText.text = "Digite seu nome de usuario primeiro."; 
            return;
        }
        send("/room/create", {username: username}, function(result:Dynamic)
        {
            var roomCode:Dynamic = Reflect.field(result, "code");
            if (roomCode == null)
            {
                statusText.text = "O servidor nao retornou o codigo da sala.";
                return;
            }
            code = Std.string(roomCode);
            refreshCode();
            enterGameplay(result, "host");
        });
    }

    function joinRoom():Void
    {
        var username = getUsername();
        if (username.length == 0)
        {
            if (statusText != null) statusText.text = "Digite seu nome de usuario primeiro."; 
            return;
        }
        if (code.length != 6)
        {
            statusText.text = "Digite os 6 numeros do codigo.";
            return;
        }

        send("/room/join", {code: code, username: username}, function(result:Dynamic)
        {
            enterGameplay(result, "guest");
        });
    }
}
