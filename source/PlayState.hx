package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
#if android
import extension.admob.Admob;
import extension.admob.AdmobEvent;
#end
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.input.touch.FlxTouch;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.Assets;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import StringTools;

class PlayState extends FlxState
{
    static inline var GAME_FONT:String = "Assets/fonts/Milky Moringa.ttf";
    static inline var SIDEBAR_WIDTH:Int = 104;
    static inline var GRAVITY:Float = 1500;
    static inline var ALPHA_THRESHOLD:Int = 1;
    static inline var CAMERA_SPEED:Float = 650;
    static inline var CHARACTER_ROOT:String = "Assets/Characters/";

    var characters:Array<CharacterData> = [];
    var characterIcons:Array<FlxSprite> = [];
    var actors:Array<CharacterActor> = [];
    var controlLabels:Map<String, FlxText> = new Map();
    var draggedActor:CharacterActor = null;
    var activeDragTouch:FlxTouch = null;
    var hudCamera:FlxCamera;
    var leftNote:FlxSprite;
    var rightNote:FlxSprite;
    var cameraDirection:Float = 0;
    var backgroundSprites:Array<FlxSprite> = [];
    var segmentPositions:Array<Float> = [];
    var floorBitmaps:Array<BitmapData> = [];
    var floorSurfaces:Array<Array<Int>> = [];
    var segmentWidth:Float = 1280;
    var proceduralBackgroundAsset:String = "";
    var floorAsset:String = "";
    var backButton:FlxSprite;
    #if android
    var multiplayerClient:MultiplayerClient;
    var networkSnapshotElapsed:Float = 0;
    var networkSequence:Int = 0;
    #end
    #if android
    var seeRoomButton:FlxSprite;
    var roomCodeDialogOpen:Bool = false;
    var roomCodeDialogItems:Array<flixel.FlxBasic> = [];
    #end

    // O desbloqueio permanece enquanto o processo do jogo estiver aberto.
    static var secondaryUnlockedSession:Bool = !AdsConfig.ENABLE_ADS;
    #if android
    static var admobStarted:Bool = false;
    static var admobReady:Bool = false;
    #end
    static inline var GAMEPLAY_AD_THRESHOLD:Float = 300;
    var gameplayElapsed:Float = 0;
    var interstitialLoaded:Bool = false;
    var interstitialLoading:Bool = false;
    var pendingMenuReturn:Bool = false;
    var interstitialShowing:Bool = false;
    var pendingActivityCallback:Void->Void = null;
    var originalCharacterIcons:Array<BitmapData> = [];
    var isSecondary:Array<Bool> = [];
    var rewardDialogOpen:Bool = false;
    var rewardPending:Bool = false;
    var rewardedLoaded:Bool = false;
    var rewardedLoading:Bool = false;
    var rewardedShowing:Bool = false;
    var rewardDim:FlxSprite;
    var rewardPanel:FlxSprite;
    var rewardTitle:FlxText;
    var rewardStatus:FlxText;
    var rewardYes:FlxSprite;
    var rewardNo:FlxSprite;
    var rewardYesText:FlxText;
    var rewardNoText:FlxText;

    override public function create():Void
    {
        super.create();
        FlxG.cameras.bgColor = FlxColor.WHITE;
        hudCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
        hudCamera.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(hudCamera, false);
        loadSceneBackgrounds();
        loadCharacterList();
        buildCharacterList();
        startBackgroundMusic();
        createBackButton();
        #if android
        if (MultiplayerSession.active) createSeeRoomButtonUI();
        #end
        createCameraButtons();
        // Sem anuncios, personagens secundarios ficam liberados nesta sessao.
        if (!AdsConfig.ENABLE_ADS) secondaryUnlockedSession = true;
        initializeAdmob();
        #if android
        if (MultiplayerSession.active) connectMultiplayer();
        #end
    }

    override public function destroy():Void
    {
        #if android
        if (multiplayerClient != null)
        {
            multiplayerClient.close();
            multiplayerClient = null;
        }
        #end
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }
        removeRewardDialog();
        if (hudCamera != null)
        {
            FlxG.cameras.remove(hudCamera, true);
            hudCamera = null;
        }
        super.destroy();
    }

    function createBackButton():Void
    {
        var path = Assets.exists("_Assets/UI/backButton.png") ? "_Assets/UI/backButton.png" : "Assets/UI/backButton.png";
        if (!Assets.exists(path))
        {
            trace("backButton.png nao encontrado em Assets/UI.");
            return;
        }
        backButton = new FlxSprite();
        backButton.loadGraphic(Assets.getBitmapData(path));
        backButton.setGraphicSize(72, 72);
        backButton.updateHitbox();
        backButton.x = FlxG.width - backButton.width - 20;
        backButton.y = 20;
        backButton.scrollFactor.set(0, 0);
        backButton.cameras = [hudCamera];
        add(backButton);
    }

    #if android
    function createSeeRoomButtonUI():Void
    {
        if (!MultiplayerSession.active || backButton == null) return;
        var path = findAsset(["_Assets/UI/seeRoom.png", "Assets/UI/seeRoom.png"]);
        if (path == "")
        {
            trace("seeRoom.png nao encontrado em Assets/UI.");
            return;
        }

        seeRoomButton = new FlxSprite();
        seeRoomButton.loadGraphic(Assets.getBitmapData(path));
        // Mesmo tamanho do botao Voltar, sem configuracao separada no Config.json.
        seeRoomButton.setGraphicSize(Std.int(backButton.width), Std.int(backButton.height));
        seeRoomButton.updateHitbox();
        var gap:Float = 16;
        seeRoomButton.x = backButton.x - gap - seeRoomButton.width;
        seeRoomButton.y = backButton.y;
        seeRoomButton.scrollFactor.set(0, 0);
        seeRoomButton.cameras = [hudCamera];
        add(seeRoomButton);
    }

    function configNumber(object:Dynamic, field:String, fallback:Float):Float
    {
        if (object == null) return fallback;
        var value:Dynamic = Reflect.field(object, field);
        if (value == null) return fallback;
        var parsed = Std.parseFloat(Std.string(value));
        return Math.isNaN(parsed) ? fallback : parsed;
    }

    function showRoomCodeDialog():Void
    {
        if (roomCodeDialogOpen) return;
        roomCodeDialogOpen = true;
        var panel = new FlxSprite(FlxG.width * 0.5 - 260, FlxG.height * 0.5 - 95)
            .makeGraphic(520, 190, 0xEE202535);
        panel.scrollFactor.set(0, 0); panel.cameras = [hudCamera]; add(panel);
        roomCodeDialogItems.push(panel);

        var title = new FlxText(panel.x + 20, panel.y + 25, 480, "CODIGO DA SALA", 24);
        title.font = GAME_FONT;
        title.setFormat(null, 24, FlxColor.WHITE, FlxTextAlign.CENTER);
        title.scrollFactor.set(0, 0); title.cameras = [hudCamera]; add(title);
        roomCodeDialogItems.push(title);

        var code = new FlxText(panel.x + 20, panel.y + 72, 480, MultiplayerSession.roomCode, 40);
        code.font = GAME_FONT;
        code.setFormat(null, 40, FlxColor.WHITE, FlxTextAlign.CENTER);
        code.scrollFactor.set(0, 0); code.cameras = [hudCamera]; add(code);
        roomCodeDialogItems.push(code);

        var close = new FlxText(panel.x + 20, panel.y + 140, 480, "TOQUE PARA FECHAR", 16);
        close.font = GAME_FONT;
        close.setFormat(null, 16, 0xFFBFC5D5, FlxTextAlign.CENTER);
        close.scrollFactor.set(0, 0); close.cameras = [hudCamera]; add(close);
        roomCodeDialogItems.push(close);
    }

    function closeRoomCodeDialog():Void
    {
        for (item in roomCodeDialogItems) remove(item, true);
        roomCodeDialogItems = [];
        roomCodeDialogOpen = false;
    }
    #end

    function createCameraButtons():Void
    {
        var leftId = findAsset(["_Assets/UI/leftNote.png", "Assets/UI/leftNote.png"]);
        var rightId = findAsset(["_Assets/UI/rightNote.png", "Assets/UI/rightNote.png"]);
        if (leftId != "")
        {
            leftNote = new FlxSprite(SIDEBAR_WIDTH + 14, FlxG.height - 104);
            leftNote.loadGraphic(Assets.getBitmapData(leftId));
            leftNote.setGraphicSize(76, 76);
            leftNote.updateHitbox();
            leftNote.scrollFactor.set(0, 0);
            leftNote.cameras = [hudCamera];
            add(leftNote);
        }
        else trace("leftNote.png nao encontrado em Assets/UI.");
        if (rightId != "")
        {
            rightNote = new FlxSprite(FlxG.width - 92, FlxG.height - 104);
            rightNote.loadGraphic(Assets.getBitmapData(rightId));
            rightNote.setGraphicSize(76, 76);
            rightNote.updateHitbox();
            rightNote.scrollFactor.set(0, 0);
            rightNote.cameras = [hudCamera];
            add(rightNote);
        }
        else trace("rightNote.png nao encontrado em Assets/UI.");
    }

    function startBackgroundMusic():Void
    {
        var id = "Assets/Sounds/Music.ogg";
        if (!Assets.exists(id))
        {
            trace("Music.ogg nao encontrado em Assets/Sounds.");
            return;
        }
        try
        {
            var music:Sound = Assets.getSound(id);
            if (music != null) FlxG.sound.playMusic(music, 1.0, true);
            else trace("Nao foi possivel carregar Music.ogg.");
        }
        catch (e:Dynamic) trace('Falha ao iniciar Music.ogg: $e');
    }

    function findAsset(candidates:Array<String>):String
    {
        for (candidate in candidates) if (Assets.exists(candidate)) return candidate;
        return "";
    }

    function loadSceneBackgrounds():Void
    {
        var lobbyId = findAsset(["_Assets/MainGameBG/GameLobby.png", "Assets/MainGameBG/GameLobby.png"]);
        proceduralBackgroundAsset = findAsset(["_Assets/MainGameBG/GameProcedural.png", "Assets/MainGameBG/GameProcedural.png"]);
        floorAsset = findAsset(["_Assets/MainGameBG/floor.png", "Assets/MainGameBG/floor.png"]);

        if (lobbyId == "")
        {
            trace("GameLobby.png nao encontrado em Assets/MainGameBG.");
            return;
        }

        try
        {
            var lobby = Assets.getBitmapData(lobbyId);
            segmentWidth = lobby.width;
            addWorldSegment(0, lobby);
        }
        catch (e:Dynamic) trace('Falha ao carregar GameLobby.png: $e');
    }

    function addWorldSegment(worldX:Float, bgBitmap:BitmapData):Void
    {
        for (position in segmentPositions)
            if (Math.abs(position - worldX) < 0.1) return;

        var bg = new FlxSprite(worldX, 0);
        bg.loadGraphic(bgBitmap);
        bg.scrollFactor.set(1, 1);
        add(bg);
        backgroundSprites.push(bg);
        segmentPositions.push(worldX);

        if (floorAsset != "")
        {
            try
            {
                var floor = Assets.getBitmapData(floorAsset);
                floorBitmaps.push(floor);
                floorSurfaces.push(buildFloorMask(floor));
            }
            catch (e:Dynamic)
            {
                trace('Falha ao carregar floor para segmento: $e');
                floorBitmaps.push(null);
                floorSurfaces.push([]);
            }
        }
        else
        {
            floorBitmaps.push(null);
            floorSurfaces.push([]);
        }
    }

    function buildFloorMask(bitmap:BitmapData):Array<Int>
    {
        var result:Array<Int> = [];
        for (x in 0...bitmap.width)
        {
            var surface = -1;
            for (y in 0...bitmap.height)
            {
                if (((bitmap.getPixel32(x, y) >>> 24) & 0xFF) >= ALPHA_THRESHOLD)
                {
                    surface = y;
                    break;
                }
            }
            result.push(surface);
        }
        return result;
    }

    function ensureProceduralSegment(worldX:Float):Void
    {
        if (proceduralBackgroundAsset == "") return;
        for (position in segmentPositions)
            if (Math.abs(position - worldX) < 0.1) return;
        try
        {
            var bitmap = Assets.getBitmapData(proceduralBackgroundAsset);
            if (bitmap.width != Std.int(segmentWidth))
                trace('Aviso: GameProcedural.png tem largura ${bitmap.width}, mas GameLobby.png tem ${segmentWidth}. Use imagens com a mesma largura para evitar emendas.');
            addWorldSegment(worldX, bitmap);
        }
        catch (e:Dynamic) trace('Falha ao criar fundo procedural: $e');
    }

    function updateWorldStreaming():Void
    {
        if (segmentPositions.length == 0) return;
        var minPosition = segmentPositions[0];
        var maxPosition = segmentPositions[0];
        for (position in segmentPositions)
        {
            if (position < minPosition) minPosition = position;
            if (position > maxPosition) maxPosition = position;
        }
        var cameraLeft = FlxG.camera.scroll.x;
        var cameraRight = cameraLeft + FlxG.width;
        var margin = segmentWidth * 0.5;
        if (cameraLeft < minPosition + margin) ensureProceduralSegment(minPosition - segmentWidth);
        if (cameraRight > maxPosition + segmentWidth - margin) ensureProceduralSegment(maxPosition + segmentWidth);
    }

    function loadCharacterList():Void
    {
        characters = [];
        var entries = Assets.list();
        var infoIds:Array<String> = [];
        for (id in entries)
            if (StringTools.startsWith(id, CHARACTER_ROOT) && StringTools.endsWith(id, "/CharacterInfo.json"))
                infoIds.push(id);
        infoIds.sort(Reflect.compare);

        for (infoId in infoIds)
        {
            var folder = infoId.substr(0, infoId.length - "/CharacterInfo.json".length);
            var iconId = folder + "/Icon.png";
            var sheetId = folder + "/CharacterAnimation.png";
            var xmlId = folder + "/CharacterAnimation.xml";
            if (!Assets.exists(iconId) || !Assets.exists(sheetId) || !Assets.exists(xmlId)) continue;
            try
            {
                var info:Dynamic = Json.parse(Assets.getText(infoId));
                var displayName = Reflect.field(info, "name") != null ? Std.string(Reflect.field(info, "name")) : folder.substr(CHARACTER_ROOT.length);
                characters.push(new CharacterData(folder, displayName, readCharacterScale(info)));
            }
            catch (e:Dynamic) trace('Personagem ignorado ($folder): $e');
        }
    }

    function readCharacterScale(info:Dynamic):Float
    {
        var display:Dynamic = Reflect.field(info, "display");
        if (display == null) return 1.0;
        var raw:Dynamic = Reflect.field(display, "scale");
        if (raw == null) return 1.0;
        var value = Std.parseFloat(Std.string(raw));
        if (Math.isNaN(value) || value <= 0 || value == Math.POSITIVE_INFINITY) return 1.0;
        return value;
    }

    function buildCharacterList():Void
    {
        var icons:Array<BitmapData> = [];
        var iconYs:Array<Float> = [];
        var validCharacters:Array<CharacterData> = [];
        var y:Float = 24;
        for (data in characters)
        {
            try
            {
                var bitmap = Assets.getBitmapData(data.iconAsset);
                icons.push(bitmap);
                originalCharacterIcons.push(bitmap);
                iconYs.push(y);
                validCharacters.push(data);
                isSecondary.push(isSecondaryCharacter(data));
                y += 82;
            }
            catch (e:Dynamic) trace('Falha ao carregar icone de ${data.name}: $e');
        }
        characters = validCharacters;
        if (icons.length > 0)
        {
            var colors:Array<Int> = [];
            for (bitmap in icons) colors.push(getDominantIconColor(bitmap));
            var gradient = new FlxSprite(0, 0).loadGraphic(makeBlurredSidebarGradient(colors, iconYs, FlxG.height));
            gradient.scrollFactor.set(0, 0);
            gradient.cameras = [hudCamera];
            add(gradient);
        }
        for (i in 0...icons.length)
        {
            var icon = new FlxSprite(17, iconYs[i]);
            icon.loadGraphic(isSecondary[i] && !secondaryUnlockedSession ? makeGrayscale(icons[i]) : icons[i]);
            icon.setGraphicSize(68, 68);
            icon.updateHitbox();
            icon.scrollFactor.set(0, 0);
            icon.cameras = [hudCamera];
            add(icon);
            characterIcons.push(icon);
        }
    }

    function isSecondaryCharacter(data:CharacterData):Bool
    {
        var folderName = data.folder;
        var slash = folderName.lastIndexOf("/");
        if (slash >= 0) folderName = folderName.substr(slash + 1);
        var candidates = [data.name.toLowerCase(), folderName.toLowerCase()];
        for (candidate in candidates)
        {
            var normalized = StringTools.trim(candidate);
            normalized = StringTools.replace(normalized, " ", "");
            if (normalized == "azedo" || normalized == "pessy" || normalized == "jay" || normalized == "margo") return true;
        }
        return false;
    }

    function makeGrayscale(source:BitmapData):BitmapData
    {
        var result = new BitmapData(source.width, source.height, true, 0x00000000);
        for (py in 0...source.height)
        for (px in 0...source.width)
        {
            var pixel = source.getPixel32(px, py);
            var alpha = (pixel >>> 24) & 0xFF;
            var r = (pixel >>> 16) & 0xFF;
            var g = (pixel >>> 8) & 0xFF;
            var b = pixel & 0xFF;
            var gray = Std.int(r * 0.299 + g * 0.587 + b * 0.114);
            result.setPixel32(px, py, (alpha << 24) | (gray << 16) | (gray << 8) | gray);
        }
        return result;
    }

    function refreshCharacterIconColors():Void
    {
        for (i in 0...characterIcons.length)
        {
            if (!isSecondary[i]) continue;
            characterIcons[i].loadGraphic(secondaryUnlockedSession ? originalCharacterIcons[i] : makeGrayscale(originalCharacterIcons[i]));
            characterIcons[i].setGraphicSize(68, 68);
            characterIcons[i].updateHitbox();
        }
    }

    function getDominantIconColor(bitmap:BitmapData):Int
    {
        var counts:Map<Int, Int> = new Map();
        var stepX = Std.int(Math.max(1, bitmap.width / 48));
        var stepY = Std.int(Math.max(1, bitmap.height / 48));
        for (y in 0...bitmap.height)
        {
            if (y % stepY != 0) continue;
            for (x in 0...bitmap.width)
            {
                if (x % stepX != 0) continue;
                var pixel = bitmap.getPixel32(x, y);
                if (((pixel >>> 24) & 0xFF) < 100) continue;
                var r = (pixel >>> 16) & 0xFF;
                var g = (pixel >>> 8) & 0xFF;
                var b = pixel & 0xFF;
                var key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
                counts.set(key, (counts.exists(key) ? counts.get(key) : 0) + 1);
            }
        }
        var bestKey = 0;
        var bestCount = -1;
        for (key in counts.keys())
        {
            var count = counts.get(key);
            if (count > bestCount) { bestCount = count; bestKey = key; }
        }
        return (((bestKey >> 8) & 15) * 17 << 16) | (((bestKey >> 4) & 15) * 17 << 8) | ((bestKey & 15) * 17);
    }

    function makeBlurredSidebarGradient(colors:Array<Int>, positions:Array<Float>, height:Int):BitmapData
    {
        var bitmap = new BitmapData(SIDEBAR_WIDTH, height, true, 0x00000000);
        var centers:Array<Float> = [];
        for (y in positions) centers.push(y + 34);
        for (py in 0...height)
        {
            var total:Float = 0; var rr:Float = 0; var gg:Float = 0; var bb:Float = 0;
            for (i in 0...colors.length)
            {
                var distance = py - centers[i];
                var sigma:Float = 52;
                var weight = Math.exp(-(distance * distance) / (2 * sigma * sigma));
                if (i == colors.length - 1 && distance > 0) weight = Math.max(weight, 0.20 * Math.exp(-distance / 260));
                var color = colors[i];
                rr += ((color >>> 16) & 0xFF) * weight;
                gg += ((color >>> 8) & 0xFF) * weight;
                bb += (color & 0xFF) * weight;
                total += weight;
            }
            if (total <= 0.0001) continue;
            var r = Std.int(rr / total); var g = Std.int(gg / total); var b = Std.int(bb / total);
            var alpha = Std.int(Math.min(120, 90 * Math.min(1, total)));
            var color32 = (alpha << 24) | (r << 16) | (g << 8) | b;
            for (px in 0...SIDEBAR_WIDTH) bitmap.setPixel32(px, py, color32);
        }
        return bitmap;
    }

    #if android
    function initializeAdmob():Void
    {
        if (!AdsConfig.ENABLE_ADS) return;
        AdMobRuntime.initialize(onAdmobEvent);
        admobStarted = AdMobRuntime.started;
        admobReady = AdMobRuntime.ready;
        if (admobReady)
        {
            loadRewardedAd();
            loadInterstitialAd();
        }
    }

    function onAdmobEvent(event:String, message:String):Void
    {
        trace('AdMob: $event - $message');
        switch (event)
        {
            case AdmobEvent.INIT_OK:
                admobReady = true;
                loadRewardedAd();
                loadInterstitialAd();
            case AdmobEvent.INTERSTITIAL_LOADED:
                interstitialLoading = false;
                interstitialLoaded = true;
                if (pendingMenuReturn) showExitInterstitial();
            case AdmobEvent.INTERSTITIAL_DISMISSED:
                interstitialShowing = false;
                interstitialLoaded = false;
                if (pendingMenuReturn) finishReturnToMenu();
                else continueAfterActivityInterstitial();
            case AdmobEvent.INTERSTITIAL_FAILED_TO_LOAD:
                interstitialLoading = false;
                interstitialLoaded = false;
                if (pendingMenuReturn) finishReturnToMenu();
                else continueAfterActivityInterstitial();
            case AdmobEvent.INTERSTITIAL_FAILED_TO_SHOW:
                interstitialShowing = false;
                interstitialLoaded = false;
                if (pendingMenuReturn) finishReturnToMenu();
                else continueAfterActivityInterstitial();
            case AdmobEvent.REWARDED_LOADED:
                rewardedLoading = false;
                rewardedLoaded = true;
                if (rewardPending && rewardDialogOpen) showRewardedAd();
            case AdmobEvent.REWARDED_EARNED:
                // Somente este evento concede a recompensa.
                secondaryUnlockedSession = true;
                rewardPending = false;
                rewardedShowing = false;
                refreshCharacterIconColors();
                removeRewardDialog();
            case AdmobEvent.REWARDED_DISMISSED:
                rewardedShowing = false;
                if (!secondaryUnlockedSession && rewardDialogOpen)
                {
                    rewardPending = false;
                    if (rewardStatus != null) rewardStatus.text = "Anuncio fechado sem recompensa.\nOs personagens continuam bloqueados.";
                }
                loadRewardedAd();
            case AdmobEvent.REWARDED_FAILED_TO_LOAD:
                rewardedLoading = false;
                rewardedLoaded = false;
                rewardPending = false;
                if (rewardDialogOpen && rewardStatus != null) rewardStatus.text = "Nao foi possivel carregar o anuncio.\nTente novamente mais tarde.";
            case AdmobEvent.REWARDED_FAILED_TO_SHOW:
                rewardedShowing = false;
                rewardPending = false;
                rewardedLoaded = false;
                if (rewardDialogOpen && rewardStatus != null) rewardStatus.text = "Nao foi possivel exibir o anuncio.\nTente novamente mais tarde.";
                loadRewardedAd();
            default:
        }
    }

    function loadInterstitialAd():Void
    {
        if (!AdsConfig.ENABLE_ADS || !admobReady || interstitialLoading || interstitialLoaded || interstitialShowing) return;
        interstitialLoading = true;
        Admob.loadInterstitial(AdsConfig.INTERSTITIAL_AD_UNIT_ID);
    }

    function showExitInterstitial():Void
    {
        if (!pendingMenuReturn || !interstitialLoaded || interstitialShowing) return;
        interstitialLoaded = false;
        interstitialShowing = true;
        Admob.showInterstitial();
    }

    function finishReturnToMenu():Void
    {
        // Esta funcao tambem e usada quando ainda nao houve 5 minutos
        // ou quando o intersticial nao esta disponivel. Nunca bloquear a volta.
        pendingMenuReturn = false;
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }
        #if android
        MultiplayerSession.clear();
        #end
        FlxG.switchState(new MenuState());
    }

    function requestReturnToMenu():Void
    {
        if (!AdsConfig.ENABLE_ADS)
        {
            finishReturnToMenu();
            return;
        }
        // O contador apenas habilita o anuncio; nunca tira o jogador do mapa.
        if (gameplayElapsed >= GAMEPLAY_AD_THRESHOLD && interstitialLoaded && !interstitialShowing)
        {
            pendingMenuReturn = true;
            showExitInterstitial();
            return;
        }
        // Se ainda nao completou 5 minutos ou o anuncio nao carregou,
        // a navegacao continua imediatamente, sem bloquear o jogador.
        finishReturnToMenu();
    }

    /**
     * Ponto de integracao para futuras telas de conclusao de missao/minijogo.
     * Chamar somente numa pausa real, depois de implementar essas atividades.
     */
    public function requestActivityBreakInterstitial(onContinue:Void->Void):Void
    {
        if (!AdsConfig.ENABLE_ADS)
        {
            if (onContinue != null) onContinue();
            return;
        }
        #if android
        if (admobReady && interstitialLoaded && !interstitialShowing)
        {
            pendingActivityCallback = onContinue;
            interstitialLoaded = false;
            interstitialShowing = true;
            Admob.showInterstitial();
        }
        else if (onContinue != null) onContinue();
        #else
        if (onContinue != null) onContinue();
        #end
    }

    function continueAfterActivityInterstitial():Void
    {
        if (pendingActivityCallback == null) return;
        var callback = pendingActivityCallback;
        pendingActivityCallback = null;
        callback();
        loadInterstitialAd();
    }

    function loadRewardedAd():Void
    {
        if (!AdsConfig.ENABLE_ADS || !admobReady || rewardedLoading || rewardedLoaded || rewardedShowing || secondaryUnlockedSession) return;
        rewardedLoading = true;
        Admob.loadRewarded(AdsConfig.REWARDED_AD_UNIT_ID);
    }

    function showRewardedAd():Void
    {
        if (!AdsConfig.ENABLE_ADS || !rewardedLoaded || rewardedShowing) return;
        rewardedLoaded = false;
        rewardedShowing = true;
        Admob.showRewarded();
    }
    #else
    function initializeAdmob():Void {}
    #end

    function createRewardDialog():Void
    {
        if (!AdsConfig.ENABLE_ADS || rewardDialogOpen || secondaryUnlockedSession) return;
        rewardDialogOpen = true;
        rewardDim = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        rewardDim.alpha = 0.68;
        rewardDim.scrollFactor.set(0, 0);
        rewardDim.cameras = [hudCamera];
        add(rewardDim);

        var panelWidth = Std.int(Math.min(760, FlxG.width - 150));
        var panelHeight = 300;
        var panelX = Std.int((FlxG.width - panelWidth) * 0.5);
        var panelY = Std.int((FlxG.height - panelHeight) * 0.5);
        rewardPanel = new FlxSprite(panelX, panelY).makeGraphic(panelWidth, panelHeight, 0xFF242424);
        rewardPanel.scrollFactor.set(0, 0);
        rewardPanel.cameras = [hudCamera];
        add(rewardPanel);

        rewardTitle = new FlxText(panelX + 28, panelY + 30, panelWidth - 56,
            "Deseja assistir um anuncio para desbloquear\nos secundarios?", 25);
        rewardTitle.font = GAME_FONT;
        rewardTitle.setFormat(null, 25, FlxColor.WHITE, FlxTextAlign.CENTER);
        rewardTitle.scrollFactor.set(0, 0);
        rewardTitle.cameras = [hudCamera];
        add(rewardTitle);

        rewardStatus = new FlxText(panelX + 28, panelY + 112, panelWidth - 56, "A recompensa libera Azedo, Pessy, Jay e Margo nesta sessao.", 16);
        rewardStatus.font = GAME_FONT;
        rewardStatus.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER);
        rewardStatus.scrollFactor.set(0, 0);
        rewardStatus.cameras = [hudCamera];
        add(rewardStatus);

        var buttonY = panelY + 210;
        rewardYes = new FlxSprite(panelX + 100, buttonY).makeGraphic(220, 58, 0xFF287A42);
        rewardYes.scrollFactor.set(0, 0); rewardYes.cameras = [hudCamera]; add(rewardYes);
        rewardYesText = new FlxText(rewardYes.x, rewardYes.y + 14, rewardYes.width, "SIM", 22);
        rewardYesText.font = GAME_FONT;
        rewardYesText.setFormat(null, 22, FlxColor.WHITE, FlxTextAlign.CENTER); rewardYesText.scrollFactor.set(0, 0); rewardYesText.cameras = [hudCamera]; add(rewardYesText);

        rewardNo = new FlxSprite(panelX + panelWidth - 320, buttonY).makeGraphic(220, 58, 0xFF8A3030);
        rewardNo.scrollFactor.set(0, 0); rewardNo.cameras = [hudCamera]; add(rewardNo);
        rewardNoText = new FlxText(rewardNo.x, rewardNo.y + 14, rewardNo.width, "NAO", 22);
        rewardNoText.font = GAME_FONT;
        rewardNoText.setFormat(null, 22, FlxColor.WHITE, FlxTextAlign.CENTER); rewardNoText.scrollFactor.set(0, 0); rewardNoText.cameras = [hudCamera]; add(rewardNoText);
    }

    function removeRewardDialog():Void
    {
        rewardDialogOpen = false;
        rewardPending = false;
        var objects:Array<flixel.FlxBasic> = [rewardDim, rewardPanel, rewardTitle, rewardStatus, rewardYes, rewardNo, rewardYesText, rewardNoText];
        for (object in objects) if (object != null) remove(object, true);
        rewardDim = null; rewardPanel = null; rewardTitle = null; rewardStatus = null;
        rewardYes = null; rewardNo = null; rewardYesText = null; rewardNoText = null;
    }

    function handleRewardDialogInput():Bool
    {
        if (!rewardDialogOpen) return false;
        for (touch in FlxG.touches.list)
        {
            if (!touch.justPressed) continue;
            if (touchHits(rewardYes, touch))
            {
                #if android
                rewardPending = true;
                if (rewardStatus != null) rewardStatus.text = "Carregando anuncio...";
                if (rewardedLoaded) showRewardedAd(); else loadRewardedAd();
                #else
                if (rewardStatus != null) rewardStatus.text = "Anuncios disponiveis somente na versao Android.";
                #end
                return true;
            }
            if (touchHits(rewardNo, touch))
            {
                removeRewardDialog();
                return true;
            }
            return true;
        }
        return true;
    }

    function spawnOrFocusCharacter(data:CharacterData):Void
    {
        if (AdsConfig.ENABLE_ADS && !secondaryUnlockedSession && isSecondaryCharacter(data))
        {
            createRewardDialog();
            return;
        }
        for (actor in actors)
        {
            if (actor.data.id == data.id)
            {
                bringActorToFront(actor);
                return;
            }
        }

        var x = FlxG.camera.scroll.x + (FlxG.width + SIDEBAR_WIDTH) * 0.5;
        var actor = createCharacterActor(data, x, 80, false);
        if (actor == null) return;
        snapToFloorIfNeeded(actor);
        #if android
        if (MultiplayerSession.active) sendCharacterSpawn(actor);
        #end
    }

    function createCharacterActor(data:CharacterData, x:Float, y:Float, remote:Bool):CharacterActor
    {
        try
        {
            var sprite = new FlxSprite(x, y);
            sprite.frames = FlxAtlasFrames.fromSparrow(Assets.getBitmapData(data.sheetAsset), Assets.getText(data.xmlAsset));
            sprite.animation.addByPrefix("idle", "idle", 2, true);
            sprite.animation.play("idle", true);
            sprite.antialiasing = true;
            sprite.useFramePixels = true;
            sprite.scale.set(data.scale, data.scale);
            sprite.updateHitbox();
            var actor = new CharacterActor(data, sprite);
            actor.remoteControlled = remote;
            actor.networkTargetX = x;
            actor.networkTargetY = y;
            actor.networkLastSentX = x;
            actor.networkLastSentY = y;
            actor.networkHasSentPosition = true;
            actors.push(actor);
            add(sprite);
            refreshVisibleBounds(actor);
            return actor;
        }
        catch (e:Dynamic)
        {
            trace('Falha ao abrir ${data.name}: $e');
            return null;
        }
    }

    function bringActorToFront(actor:CharacterActor):Void
    {
        remove(actor.sprite, false);
        add(actor.sprite);
    }

    function refreshVisibleBounds(actor:CharacterActor):Bool
    {
        var sprite = actor.sprite;
        sprite.updateFramePixels();
        var bitmap = sprite.framePixels;
        if (bitmap == null) return false;
        if (actor.cachedFrame == sprite.frame && actor.hasVisiblePixels) return false;
        actor.cachedFrame = sprite.frame;
        var minX = bitmap.width; var minY = bitmap.height; var maxX = -1; var maxY = -1;
        for (py in 0...bitmap.height)
        for (px in 0...bitmap.width)
        {
            if (((bitmap.getPixel32(px, py) >>> 24) & 0xFF) >= ALPHA_THRESHOLD)
            {
                if (px < minX) minX = px;
                if (py < minY) minY = py;
                if (px > maxX) maxX = px;
                if (py > maxY) maxY = py;
            }
        }
        actor.hasVisiblePixels = maxX >= minX && maxY >= minY;
        if (actor.hasVisiblePixels)
        {
            actor.visibleMinX = minX; actor.visibleMinY = minY; actor.visibleMaxX = maxX; actor.visibleMaxY = maxY;
        }
        else
        {
            actor.visibleMinX = 0; actor.visibleMinY = 0; actor.visibleMaxX = bitmap.width - 1; actor.visibleMaxY = bitmap.height - 1;
        }
        return true;
    }

    function visibleTop(actor:CharacterActor):Float
        return actor.sprite.y - actor.sprite.offset.y + actor.visibleMinY * actor.sprite.scale.y;

    function visibleBottom(actor:CharacterActor):Float
        return actor.sprite.y - actor.sprite.offset.y + (actor.visibleMaxY + 1) * actor.sprite.scale.y;

    function floorYUnderActor(actor:CharacterActor):Float
    {
        if (floorSurfaces.length == 0) return -1;
        var sprite = actor.sprite;
        var left = sprite.x - sprite.offset.x + actor.visibleMinX * sprite.scale.x;
        var right = sprite.x - sprite.offset.x + (actor.visibleMaxX + 1) * sprite.scale.x;
        var bestY:Float = -1;
        for (i in 0...segmentPositions.length)
        {
            var bitmap = floorBitmaps[i];
            var surface = floorSurfaces[i];
            if (bitmap == null || surface == null || surface.length == 0) continue;
            var segX = segmentPositions[i];
            var overlapLeft = Math.max(left, segX);
            var overlapRight = Math.min(right, segX + bitmap.width);
            if (overlapRight <= overlapLeft) continue;
            var firstX = Std.int(Math.max(0, Math.floor(overlapLeft - segX)));
            var lastX = Std.int(Math.min(bitmap.width - 1, Math.ceil(overlapRight - segX) - 1));
            for (localX in firstX...(lastX + 1))
            {
                var sourceY = surface[localX];
                if (sourceY >= 0 && (bestY < 0 || sourceY < bestY)) bestY = sourceY;
            }
        }
        return bestY;
    }

    function snapToFloorIfNeeded(actor:CharacterActor):Void
    {
        var surface = floorYUnderActor(actor);
        if (surface < 0) return;
        var bottom = visibleBottom(actor);
        if (bottom >= surface)
        {
            actor.sprite.y += surface - bottom;
            actor.verticalSpeed = 0;
            actor.grounded = true;
        }
    }

    #if android
    function connectMultiplayer():Void
    {
        if (multiplayerClient != null || !MultiplayerSession.active) return;
        multiplayerClient = new MultiplayerClient(
            MultiplayerSession.roomCode,
            MultiplayerSession.token,
            handleNetworkMessage,
            function(message:String) trace('[TorajoRP Online] $message')
        );
    }

    function sendNetworkEvent(data:Dynamic):Void
    {
        if (multiplayerClient != null) multiplayerClient.send(data);
    }

    function sendCharacterSpawn(actor:CharacterActor):Void
    {
        sendNetworkEvent({
            type: "character_spawn",
            characterId: actor.data.id,
            x: actor.sprite.x,
            y: actor.sprite.y
        });
        actor.networkLastSentX = actor.sprite.x;
        actor.networkLastSentY = actor.sprite.y;
        actor.networkHasSentPosition = true;
    }

    function sendCharacterMove(actor:CharacterActor):Void
    {
        networkSequence++;
        sendNetworkEvent({
            type: "character_move",
            characterId: actor.data.id,
            x: actor.sprite.x,
            y: actor.sprite.y,
            sequence: networkSequence,
            interpolation: 0.5
        });
        actor.networkLastSentX = actor.sprite.x;
        actor.networkLastSentY = actor.sprite.y;
        actor.networkHasSentPosition = true;
    }

    function sendCharacterPositions():Void
    {
        var positions:Array<Dynamic> = [];
        for (actor in actors)
        {
            if (actor.remoteControlled) continue;
            var moved = !actor.networkHasSentPosition ||
                Math.abs(actor.sprite.x - actor.networkLastSentX) > 0.5 ||
                Math.abs(actor.sprite.y - actor.networkLastSentY) > 0.5;
            if (!moved) continue;
            positions.push({
                characterId: actor.data.id,
                x: actor.sprite.x,
                y: actor.sprite.y
            });
            actor.networkLastSentX = actor.sprite.x;
            actor.networkLastSentY = actor.sprite.y;
            actor.networkHasSentPosition = true;
        }
        if (positions.length == 0) return;
        networkSequence++;
        sendNetworkEvent({
            type: "character_positions",
            sequence: networkSequence,
            characters: positions
        });
    }
    function sendStateSnapshot():Void
    {
        var snapshot:Array<Dynamic> = [];
        for (actor in actors)
        {
            snapshot.push({
                characterId: actor.data.id,
                x: actor.sprite.x,
                y: actor.sprite.y
            });
        }
        sendNetworkEvent({type: "state_snapshot", characters: snapshot});
    }

    function findCharacterData(id:String):CharacterData
    {
        for (data in characters)
            if (data.id == id || data.folder == id) return data;
        return null;
    }

    function findActor(id:String):CharacterActor
    {
        for (actor in actors)
            if (actor.data.id == id) return actor;
        return null;
    }

    function receiveRemoteSpawn(characterId:String, x:Float, y:Float, senderId:String):Void
    {
        trace('[MULTIPLAYER] Spawn recebido: $characterId em ($x, $y)');
        var data = findCharacterData(characterId);
        if (data == null) return;
        var existing = findActor(characterId);
        if (existing != null)
        {
            if (!existing.dragging) applyRemotePosition(existing, x, y);
            return;
        }
        var actor = createCharacterActor(data, x, y, true);
        if (actor != null)
        {
            actor.networkTargetX = x;
            actor.networkTargetY = y;
            actor.networkHasTarget = false;
        }
    }

    function applyRemotePosition(actor:CharacterActor, x:Float, y:Float):Void
    {
        if (actor == null || actor.dragging) return;
        actor.remoteControlled = true;
        actor.grounded = false;
        actor.verticalSpeed = 0;
        actor.networkTargetX = x;
        actor.networkTargetY = y;
        actor.networkLerpDuration = 0.05;
        actor.networkLerpRemaining = 0.05;
        actor.networkHasTarget = true;
    }

    function setCharacterController(actor:CharacterActor, username:String, active:Bool):Void
    {
        if (actor == null) return;
        var id = actor.data.id;
        var label = controlLabels.get(id);
        if (!active)
        {
            if (label != null) { remove(label, true); controlLabels.remove(id); }
            actor.controllerUsername = "";
            return;
        }
        actor.controllerUsername = username == null || username.length == 0 ? "Jogador" : username;
        if (label == null)
        {
            label = new FlxText(0, 0, 300, "", 14);
        label.font = GAME_FONT;
            label.setFormat(null, 14, FlxColor.WHITE, FlxTextAlign.CENTER);
            add(label);
            controlLabels.set(id, label);
        }
        label.text = actor.controllerUsername + " está controlando " + id;
    }

    function updateControlLabels():Void
    {
        var ids:Array<String> = [];
        for (id in controlLabels.keys()) ids.push(id);
        for (id in ids)
        {
            var actor = findActor(id);
            var label = controlLabels.get(id);
            if (actor == null || label == null) { if (label != null) remove(label, true); controlLabels.remove(id); continue; }
            var visibleLeft = actor.sprite.x - actor.sprite.offset.x + actor.visibleMinX * actor.sprite.scale.x;
            var visibleRight = actor.sprite.x - actor.sprite.offset.x + (actor.visibleMaxX + 1) * actor.sprite.scale.x;
            label.x = (visibleLeft + visibleRight) * 0.5 - label.width * 0.5;
            label.y = visibleTop(actor) - label.height - 7;
        }
    }

    function clearControlLabels():Void
    {
        var ids:Array<String> = [];
        for (id in controlLabels.keys()) ids.push(id);
        for (id in ids) { var label = controlLabels.get(id); if (label != null) remove(label, true); controlLabels.remove(id); }
    }

    function handleNetworkGameEvent(event:Dynamic, senderId:String):Void
    {
        if (event == null) return;
        var typeValue:Dynamic = Reflect.field(event, "type");
        if (typeValue == null) return;
        var type = Std.string(typeValue);

        switch (type)
        {
            case "character_spawn":
                var id = Reflect.field(event, "characterId");
                var x = Reflect.field(event, "x");
                var y = Reflect.field(event, "y");
                if (id != null && x != null && y != null)
                    receiveRemoteSpawn(Std.string(id), Std.parseFloat(Std.string(x)), Std.parseFloat(Std.string(y)), senderId);

            case "character_positions":
                var list:Dynamic = Reflect.field(event, "characters");
                if (list != null)
                {
                    var entries:Array<Dynamic> = cast list;
                    for (entry in entries)
                    {
                        var id = Reflect.field(entry, "characterId");
                        var x = Reflect.field(entry, "x");
                        var y = Reflect.field(entry, "y");
                        if (id != null && x != null && y != null)
                        {
                            var actor = findActor(Std.string(id));
                            if (actor != null)
                            {
                                applyRemotePosition(
                                    actor,
                                    Std.parseFloat(Std.string(x)),
                                    Std.parseFloat(Std.string(y))
                                );
                            }
                        }
                    }
                }
            case "character_move":
                var id = Reflect.field(event, "characterId");
                var x = Reflect.field(event, "x");
                var y = Reflect.field(event, "y");
                if (id != null && x != null && y != null)
                    applyRemotePosition(findActor(Std.string(id)), Std.parseFloat(Std.string(x)), Std.parseFloat(Std.string(y)));

            case "state_snapshot":
                var list:Dynamic = Reflect.field(event, "characters");
                if (list != null)
                {
                    var entries:Array<Dynamic> = cast list;
                    for (entry in entries)
                    {
                        var id = Reflect.field(entry, "characterId");
                        var x = Reflect.field(entry, "x");
                        var y = Reflect.field(entry, "y");
                        if (id != null && x != null && y != null)
                            receiveRemoteSpawn(Std.string(id), Std.parseFloat(Std.string(x)), Std.parseFloat(Std.string(y)), senderId);
                    }
                }

            case "character_control":
                var id = Reflect.field(event, "characterId");
                var activeValue = Reflect.field(event, "active");
                var usernameValue = Reflect.field(event, "controllerUsername");
                if (id != null)
                {
                    var controlledActor = findActor(Std.string(id));
                    if (controlledActor != null)
                    {
                        if (activeValue == true)
                        {
                            controlledActor.remoteControlled = true;
                            controlledActor.grounded = false;
                            controlledActor.verticalSpeed = 0;
                            controlledActor.networkHasTarget = false;
                        }
                        else
                        {
                            controlledActor.remoteControlled = false;
                        }
                    }
                    setCharacterController(controlledActor, usernameValue == null ? "Jogador" : Std.string(usernameValue), activeValue == true);
                }

            case "character_remove":
                var id = Reflect.field(event, "characterId");
                if (id != null)
                {
                    var actor = findActor(Std.string(id));
                    if (actor != null && !actor.dragging)
                    {
                        actors.remove(actor);
                        remove(actor.sprite, true);
                    }
                }
            default:
        }
    }

    function handleNetworkMessage(message:Dynamic):Void
    {
        if (message == null) return;
        trace("[MULTIPLAYER] Mensagem recebida: " + haxe.Json.stringify(message));
        var typeValue:Dynamic = Reflect.field(message, "type");
        if (typeValue == null) return;
        switch (Std.string(typeValue))
        {
            case "connected":
                // O jogador recem-conectado informa seu estado; os jogadores
                // existentes tambem respondem ao evento player_joined.
                sendStateSnapshot();
            case "player_joined":
                sendStateSnapshot();
            case "game_event":
                var sender:Dynamic = Reflect.field(message, "playerId");
                var eventData:Dynamic = Reflect.field(message, "data");
                var remoteUsername:Dynamic = Reflect.field(message, "username");
                if (eventData != null && remoteUsername != null) Reflect.setField(eventData, "controllerUsername", Std.string(remoteUsername));
                handleNetworkGameEvent(eventData, sender == null ? "" : Std.string(sender));
            case "player_left":
                clearControlLabels();
                trace('[TorajoRP Online] Um jogador saiu: ' + Std.string(Reflect.field(message, "playerId")));
            case "room_closed":
                trace("[TorajoRP Online] O anfitriao encerrou a sala.");
                MultiplayerSession.clear();
                if (multiplayerClient != null)
                {
                    multiplayerClient.close();
                    multiplayerClient = null;
                }
            default:
        }
    }

    function updateNetwork(elapsed:Float):Void
    {
        if (multiplayerClient == null) return;
        multiplayerClient.update();

        // Interpolacao local dos personagens controlados por outros jogadores.
        for (actor in actors)
        {
            if (!actor.remoteControlled || !actor.networkHasTarget || actor.dragging) continue;
            if (actor.networkLerpRemaining <= 0)
            {
                actor.sprite.x = actor.networkTargetX;
                actor.sprite.y = actor.networkTargetY;
                actor.networkHasTarget = false;
            }
            else
            {
                var step = Math.min(1, elapsed / actor.networkLerpRemaining);
                actor.sprite.x += (actor.networkTargetX - actor.sprite.x) * step;
                actor.sprite.y += (actor.networkTargetY - actor.sprite.y) * step;
                actor.networkLerpRemaining -= elapsed;
                if (actor.networkLerpRemaining <= 0)
                {
                    actor.sprite.x = actor.networkTargetX;
                    actor.sprite.y = actor.networkTargetY;
                    actor.networkHasTarget = false;
                }
            }
        }

        // No maximo 30 lotes por segundo; cada lote agrupa varios personagens.
        networkSnapshotElapsed += elapsed;
        var networkInterval:Float = 1.0 / 30.0;
        if (networkSnapshotElapsed >= networkInterval)
        {
            networkSnapshotElapsed = networkSnapshotElapsed % networkInterval;
            sendCharacterPositions();
        }
    }
    #end

    function pointInsideVisibleBounds(actor:CharacterActor, x:Float, y:Float):Bool
    {
        var sprite = actor.sprite;
        var left = sprite.x - sprite.offset.x + actor.visibleMinX * sprite.scale.x;
        var right = sprite.x - sprite.offset.x + (actor.visibleMaxX + 1) * sprite.scale.x;
        return x >= left && x <= right && y >= visibleTop(actor) && y <= visibleBottom(actor);
    }

    function touchPoint(touch:FlxTouch):{x:Float, y:Float}
    {
        var point = touch.getWorldPosition();
        return {x: point.x, y: point.y};
    }

    function touchHits(sprite:FlxSprite, touch:FlxTouch):Bool
    {
        if (sprite == null || hudCamera == null) return false;
        // Os botoes do HUD usam uma camera propria; converte o toque para
        // coordenadas dessa camera, sem depender de gameX/gameY (ausentes
        // em algumas versoes do HaxeFlixel usadas no projeto Android).
        var point = touch.getWorldPosition(hudCamera);
        return point.x >= sprite.x && point.x <= sprite.x + sprite.width &&
               point.y >= sprite.y && point.y <= sprite.y + sprite.height;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        #if android
        updateNetwork(elapsed);
        #end
        gameplayElapsed += elapsed;
        if (handleRewardDialogInput()) return;

        // Atualiza a camera por toque continuo nas setas.
        cameraDirection = 0;
        for (touch in FlxG.touches.list)
        {
            if (!touch.pressed) continue;
            if (touchHits(leftNote, touch)) cameraDirection = -1;
            else if (touchHits(rightNote, touch)) cameraDirection = 1;
        }
        if (cameraDirection != 0) FlxG.camera.scroll.x += cameraDirection * CAMERA_SPEED * elapsed;
        updateWorldStreaming();

        for (actor in actors)
        {
            var changed = refreshVisibleBounds(actor);
            if (actor.grounded && changed && !actor.dragging && !actor.remoteControlled)
            {
                var support = floorYUnderActor(actor);
                if (support >= 0) actor.sprite.y += support - visibleBottom(actor);
                else actor.grounded = false;
                actor.verticalSpeed = 0;
            }
        }

        // Processa primeiro o toque que ja esta controlando o personagem.
        // Outros dedos nao podem iniciar outro arraste simultaneamente.
        if (activeDragTouch != null)
        {
            if (activeDragTouch.pressed && draggedActor != null)
            {
                var p = touchPoint(activeDragTouch);
                draggedActor.sprite.x = p.x + draggedActor.dragOffsetX;
                draggedActor.sprite.y = p.y + draggedActor.dragOffsetY;
                // A posicao do toque esta em coordenadas do mundo. Limitar pelo
                // FlxG.width prendia o personagem na borda do primeiro fundo
                // (GameLobby). So impedimos que ele entre na area da sidebar;
                // nao existe limite horizontal do lado direito.
                draggedActor.sprite.x = Math.max(FlxG.camera.scroll.x + SIDEBAR_WIDTH, draggedActor.sprite.x);
            }
            if (activeDragTouch.justReleased || !activeDragTouch.pressed)
            {
                if (draggedActor != null)
                {
                    draggedActor.dragging = false;
                    draggedActor.grounded = false;
                    #if android
                    if (MultiplayerSession.active)
                    {
                        sendCharacterMove(draggedActor);
                        sendNetworkEvent({ type: "character_control", characterId: draggedActor.data.id, active: false });
                    }
                    #end
                }
                draggedActor = null;
                activeDragTouch = null;
            }
        }

        for (touch in FlxG.touches.list)
        {
            if (!touch.justPressed) continue;

            // Setas e botao voltar tem prioridade sobre o mundo.
            if (touchHits(leftNote, touch) || touchHits(rightNote, touch)) continue;
            #if android
            if (roomCodeDialogOpen)
            {
                closeRoomCodeDialog();
                return;
            }
            if (seeRoomButton != null && touchHits(seeRoomButton, touch))
            {
                showRoomCodeDialog();
                return;
            }
            #end
            if (backButton != null && touchHits(backButton, touch))
            {
                requestReturnToMenu();
                return;
            }

            var p = touchPoint(touch);
            var clickedIcon = false;
            for (i in 0...characterIcons.length)
            {
                if (touchHits(characterIcons[i], touch))
                {
                    spawnOrFocusCharacter(characters[i]);
                    clickedIcon = true;
                    break;
                }
            }
            if (clickedIcon) continue;

            // Apenas um dedo pode controlar um personagem por vez.
            if (draggedActor == null && activeDragTouch == null)
            {
                var i = actors.length - 1;
                while (i >= 0)
                {
                    var actor = actors[i];
                    if (pointInsideVisibleBounds(actor, p.x, p.y))
                    {
                        draggedActor = actor;
                        #if android
                        if (MultiplayerSession.active) sendNetworkEvent({ type: "character_control", characterId: actor.data.id, active: true });
                        #end
                        activeDragTouch = touch;
                        bringActorToFront(actor);
                        actor.dragging = true;
                        actor.remoteControlled = false;
                        actor.networkHasTarget = false;
                        actor.dragOffsetX = actor.sprite.x - p.x;
                        actor.dragOffsetY = actor.sprite.y - p.y;
                        actor.verticalSpeed = 0;
                        actor.grounded = false;
                        break;
                    }
                    i--;
                }
            }
        }

        updateControlLabels();

        for (actor in actors)
        {
            if (actor.dragging || actor.remoteControlled) continue;
            refreshVisibleBounds(actor);
            var oldBottom = visibleBottom(actor);
            var supportBefore = floorYUnderActor(actor);
            if (supportBefore >= 0 && oldBottom >= supportBefore - 1 && actor.verticalSpeed >= 0)
            {
                actor.sprite.y += supportBefore - oldBottom;
                actor.verticalSpeed = 0;
                actor.grounded = true;
            }
            else
            {
                actor.grounded = false;
                actor.verticalSpeed += GRAVITY * elapsed;
                actor.sprite.y += actor.verticalSpeed * elapsed;
                var newBottom = visibleBottom(actor);
                var supportAfter = floorYUnderActor(actor);
                if (supportAfter >= 0 && oldBottom <= supportAfter && newBottom >= supportAfter)
                {
                    actor.sprite.y += supportAfter - newBottom;
                    actor.verticalSpeed = 0;
                    actor.grounded = true;
                }
            }
        }
    }
}