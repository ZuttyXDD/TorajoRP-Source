package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxSave;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
import flixel.input.touch.FlxTouch;
import openfl.media.Sound;
import openfl.utils.Assets;
import haxe.Json;
import StringTools;
#if android
import extension.admob.Admob;
import extension.admob.AdmobEvent;
import extension.admob.AdmobBannerAlign;
#end

class MenuState extends FlxState
{
    var playButton:FlxSprite;
    var creditsButton:FlxSprite;
    #if android
    var multiplayerButton:FlxSprite;
    #end
    var selected:Int = 0;
    var activating:Bool = false;
    var activationElapsed:Float = 0;
    var activatedButton:Int = -1;
    var config:Dynamic = {};
    var menuConfig:Dynamic;
    var activationConfig:Dynamic;

    static inline var TERMS_URL:String = "https://github.com/ZuttyXDD/TorajoRP-Source";
    static inline var PRIVACY_URL:String = "https://zuttyxdd.github.io/TorajoRP/";

       // Mostrar a janela de Termos e Privacidade?
    static inline var SHOW_CONSENT_WINDOW:Bool = true;
    #end

    var consentSave:FlxSave;
    var consentRequired:Bool = false;
    var consentOverlay:FlxSprite;
    var consentPanel:FlxSprite;
    var consentTitle:FlxText;
    var consentMessage:FlxText;
    var consentTermsLink:FlxText;
    var consentPrivacyLink:FlxText;
    var consentAcceptButton:FlxSprite;
    var consentAcceptLabel:FlxText;
    
    #if android
    var menuBannerRequested:Bool = false;

    function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);

    function number(value:Dynamic, fallback:Float):Float
    {
        if (value == null) return fallback;
        var parsed = Std.parseFloat(Std.string(value));
        return Math.isNaN(parsed) ? fallback : parsed;
    }

    function assetPath(path:String):String
    {
        if (Assets.exists("_" + path)) return "_" + path;
        if (Assets.exists(path)) return path;
        return null;
    }

    override public function create():Void
    {
        super.create();
        FlxG.cameras.bgColor = FlxColor.BLACK;
        var configPath = assetPath("Assets/Config.json");
        if (configPath != null) try config = Json.parse(Assets.getText(configPath)) catch (e:Dynamic) trace('Config invalido: $e');
        menuConfig = field(config, "menu");
        activationConfig = field(menuConfig, "activation");
        startMenuMusic();

        if (SHOW_CONSENT_WINDOW)
    checkTermsAcceptance();
else
    consentRequired = false;

        var bgPath = assetPath("Assets/MenuAssets/background.png");
        if (bgPath != null)
        {
            var bg = new FlxSprite(0, 0);
            bg.loadGraphic(Assets.getBitmapData(bgPath));
            if (field(field(menuConfig, "background"), "fitScreen") != false)
                bg.setGraphicSize(FlxG.width, FlxG.height);
            bg.updateHitbox();
            add(bg);
        }

        playButton = loadButton("play");
        creditsButton = loadButton("credits");
        #if android
        multiplayerButton = loadButton("multiplayer");
        #end
        positionButton(playButton, field(field(menuConfig, "buttons"), "play"), -1);
        positionButton(creditsButton, field(field(menuConfig, "buttons"), "credits"), 1);
        #if android
        positionButton(multiplayerButton, field(field(menuConfig, "buttons"), "multiplayer"), 0);
        #end
        if (playButton != null) add(playButton);
        if (creditsButton != null) add(creditsButton);
        #if android
        if (multiplayerButton != null) add(multiplayerButton);
        #end
        updateButtonAnimations();

        if (consentRequired)
            createConsentWindow();
        else
            initializeMenuAds();
    }

    function checkTermsAcceptance():Void
    {
        consentSave = new FlxSave();
        consentSave.bind("TorajoRPConsent");
        // A ausencia desta chave indica que o jogador ainda nao aceitou nesta instalacao.
        // Depois de aceitar, o FlxSave persiste o booleano e a janela nao aparece novamente.
        consentRequired = consentSave.data.termsAccepted == true ? false : true;
    }

    function createConsentWindow():Void
    {
        var panelWidth = Math.min(FlxG.width - 40, 920);
        var panelHeight = Math.min(FlxG.height - 40, 500);
        var panelX = (FlxG.width - panelWidth) * 0.5;
        var panelY = (FlxG.height - panelHeight) * 0.5;

        consentOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        consentOverlay.alpha = 0.78;
        consentOverlay.scrollFactor.set(0, 0);
        add(consentOverlay);

        consentPanel = new FlxSprite(panelX, panelY).makeGraphic(Std.int(panelWidth), Std.int(panelHeight), FlxColor.fromRGB(29, 32, 38));
        consentPanel.scrollFactor.set(0, 0);
        add(consentPanel); 

        consentTitle = new FlxText(panelX + 28, panelY + 26, panelWidth - 56, "Antes de continuar...", 34);
        consentTitle.setFormat(null, 34, FlxColor.WHITE, CENTER);
        consentTitle.scrollFactor.set(0, 0);
        add(consentTitle);

        consentMessage = new FlxText(panelX + 54, panelY + 105, panelWidth - 108,
            "Se isso apareceu, parabéns! o jogo compilou normalmente, pode desativar isso no ínicio do script, em "SHOW_CONSENT_WINDOW" marcando false, aqui vai alguns links se necessário!", 19);
        consentMessage.setFormat(null, 19, FlxColor.WHITE, CENTER);
        consentMessage.wordWrap = true;
        consentMessage.scrollFactor.set(0, 0);
        add(consentMessage);

        consentTermsLink = new FlxText(panelX + 45, panelY + panelHeight - 145, panelWidth * 0.42, "Repositorio GitHub", 20);
        consentTermsLink.setFormat(null, 20, FlxColor.fromRGB(80, 165, 255), CENTER);
        consentTermsLink.scrollFactor.set(0, 0);
        add(consentTermsLink);

        consentPrivacyLink = new FlxText(panelX + panelWidth * 0.53, panelY + panelHeight - 145, panelWidth * 0.42, "Pagina de downloads", 20);
        consentPrivacyLink.setFormat(null, 20, FlxColor.fromRGB(80, 165, 255), CENTER);
        consentPrivacyLink.scrollFactor.set(0, 0);
        add(consentPrivacyLink);

        var buttonWidth = Math.min(440, panelWidth - 70);
        consentAcceptButton = new FlxSprite((FlxG.width - buttonWidth) * 0.5, panelY + panelHeight - 82)
            .makeGraphic(Std.int(buttonWidth), 52, FlxColor.fromRGB(0, 190, 125));
        consentAcceptButton.scrollFactor.set(0, 0);
        add(consentAcceptButton);

        consentAcceptLabel = new FlxText(consentAcceptButton.x, consentAcceptButton.y + 13, buttonWidth, "Aceitar e continuar", 22);
        consentAcceptLabel.setFormat(null, 22, FlxColor.WHITE, CENTER);
        consentAcceptLabel.scrollFactor.set(0, 0);
        add(consentAcceptLabel);
    }

    function initializeMenuAds():Void
    {
        #if android
        if (AdsConfig.ENABLE_ADS)
        {
            AdMobRuntime.initialize(onMenuAdmobEvent);
            if (AdMobRuntime.ready) showMenuBanner();
        }
        #end
    }

    function acceptTerms():Void
    {
        if (consentSave == null) return;
        consentSave.data.termsAccepted = true;
        consentSave.flush();
        consentRequired = false;
        if (consentOverlay != null) remove(consentOverlay, true);
        if (consentPanel != null) remove(consentPanel, true);
        if (consentTitle != null) remove(consentTitle, true);
        if (consentMessage != null) remove(consentMessage, true);
        if (consentTermsLink != null) remove(consentTermsLink, true);
        if (consentPrivacyLink != null) remove(consentPrivacyLink, true);
        if (consentAcceptButton != null) remove(consentAcceptButton, true);
        if (consentAcceptLabel != null) remove(consentAcceptLabel, true);
        initializeMenuAds();
    }

    function consentClickAt(x:Float, y:Float):Void
    {
        var point = new flixel.math.FlxPoint(x, y);
        if (consentTermsLink != null && consentTermsLink.overlapsPoint(point))
            FlxG.openURL(TERMS_URL);
        else if (consentPrivacyLink != null && consentPrivacyLink.overlapsPoint(point))
            FlxG.openURL(PRIVACY_URL);
        else if (consentAcceptButton != null && consentAcceptButton.overlapsPoint(point))
            acceptTerms();
        point.put();
    }

    #if android
    function onMenuAdmobEvent(event:String, message:String):Void
    {
        trace('AdMob Menu: $event - $message');
        if (event == AdmobEvent.INIT_OK) showMenuBanner();
        else if (event == AdmobEvent.BANNER_FAILED_TO_LOAD) menuBannerRequested = false;
    }

    function showMenuBanner():Void
    {
        if (!AdsConfig.ENABLE_ADS || menuBannerRequested) return;
        menuBannerRequested = true;
        // ID configurado centralmente em AdsConfig.hx.
        Admob.showBanner(AdsConfig.BANNER_AD_UNIT_ID, 0, AdmobBannerAlign.TOP);
    }
    #end

    override public function destroy():Void
    {
        #if android
        if (menuBannerRequested)
        {
            Admob.hideBanner();
            menuBannerRequested = false;
        }
        #end
        super.destroy();
    }

    /**
     * Musica do menu configuravel em directories.menuMusic.
     * O arquivo precisa estar incluido nos assets do projeto Android.
     * Padrao: Assets/Sounds/MenuMusic.ogg
     */
    function startMenuMusic():Void
    {
        var directories = field(config, "directories");
        var configured = field(directories, "menuMusic");
        var raw = configured == null || Std.string(configured).length == 0
            ? "Assets/Sounds/MenuMusic.ogg"
            : Std.string(configured);

        var candidates:Array<String> = [];
        if (StringTools.startsWith(raw, "Assets/"))
        {
            candidates.push(assetPath(raw));
            candidates.push(assetPath("_" + raw));
        }
        else if (StringTools.startsWith(raw, "_Assets/"))
        {
            candidates.push(assetPath(raw));
            candidates.push(assetPath(raw.substr(1)));
        }
        else
        {
            candidates.push(assetPath("Assets/Sounds/" + raw));
            candidates.push(assetPath("Assets/" + raw));
        }

        var asset:String = null;
        for (candidate in candidates)
        {
            if (candidate != null && Assets.exists(candidate))
            {
                asset = candidate;
                break;
            }
        }

        if (asset == null)
        {
            trace('Musica do menu nao encontrada: $raw. Confira directories.menuMusic e a inclusao do arquivo nos assets.');
            return;
        }

        try
        {
            if (FlxG.sound.music != null)
            {
                FlxG.sound.music.stop();
                FlxG.sound.music = null;
            }
            var music:Sound = Assets.getSound(asset);
            if (music == null)
            {
                trace('Nao foi possivel carregar a musica do menu: $asset');
                return;
            }
            FlxG.sound.playMusic(music, 1.0, true);
            trace('Musica do menu iniciada: $asset');
        }
        catch (e:Dynamic)
        {
            trace('Falha ao iniciar musica do menu ($asset): $e');
        }
    }

    function stopMenuMusic():Void
    {
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
            FlxG.sound.music = null;
        }
    }

    function loadButton(name:String):FlxSprite
    {
        var png = assetPath("Assets/MenuAssets/" + name + ".png");
        var xml = assetPath("Assets/MenuAssets/" + name + ".xml");
        if (png == null || xml == null) return null;
        try
        {
            var button = new FlxSprite();
            button.frames = FlxAtlasFrames.fromSparrow(Assets.getBitmapData(png), Assets.getText(xml));
            var fps = Std.int(number(field(menuConfig, "buttonFPS"), 10));
            button.animation.addByPrefix("idle", "idle", fps, true);
            button.animation.addByPrefix("selection", "selection", fps, true);
            button.animation.play("idle", true);
            button.antialiasing = true;
            button.updateHitbox();
            return button;
        }
        catch (e:Dynamic) { trace('Falha ao carregar botao $name: $e'); return null; }
    }

    function positionButton(button:FlxSprite, cfg:Dynamic, direction:Int):Void
    {
        if (button == null) return;
        button.scale.set(number(field(cfg, "scaleX"), 1), number(field(cfg, "scaleY"), 1));
        button.updateHitbox();
        var w = number(field(cfg, "width"), 0);
        var h = number(field(cfg, "height"), 0);
        if (w > 0 || h > 0)
        {
            button.setGraphicSize(Std.int(w > 0 ? w : button.width), Std.int(h > 0 ? h : button.height));
            button.updateHitbox();
        }
        var gap = number(field(menuConfig, "buttonGap"), 36);
        button.x = (FlxG.width - button.width) * 0.5 + number(field(cfg, "xOffset"), 0);
        button.y = (FlxG.height - button.height) * 0.5 + number(field(cfg, "yOffset"), direction * gap * 0.5);
    }

    function playSound(name:String):Void
    {
        var sounds = field(config, "sounds");
        var value = field(sounds, name);
        if (value == null) return;
        var raw = Std.string(value);
        var path = assetPath(StringTools.startsWith(raw, "Assets/") ? raw : "Assets/Sounds/" + raw);
        if (path != null)
        {
            try
            {
                var sound:Sound = Assets.getSound(path);
                if (sound != null) FlxG.sound.play(sound);
            }
            catch (e:Dynamic) trace('Falha ao tocar som $path: $e');
        }
    }

    function updateButtonAnimations():Void
    {
        if (playButton != null) playButton.animation.play(selected == 0 ? "selection" : "idle", true);
        if (creditsButton != null) creditsButton.animation.play(selected == 1 ? "selection" : "idle", true);
        #if android
        if (multiplayerButton != null) multiplayerButton.animation.play(selected == 2 ? "selection" : "idle", true);
        #end
    }

    function selectButton(index:Int):Void
    {
        if (selected == index) return;
        selected = index;
        updateButtonAnimations();
        playSound("select");
    }

    function activateButton(index:Int):Void
    {
        var button = index == 0 ? playButton : creditsButton;
        #if android
        if (index == 2) button = multiplayerButton;
        #end
        if (activating || button == null) return;
        selected = index;
        activatedButton = index;
        activating = true;
        activationElapsed = 0;
        playSound("activate");
        button.animation.play("idle", true);
        if (index == 0 && creditsButton != null) creditsButton.animation.play("idle", true);
        if (index == 1 && playButton != null) playButton.animation.play("idle", true);
        #if android
        if (index == 2) { if (playButton != null) playButton.animation.play("idle", true); if (creditsButton != null) creditsButton.animation.play("idle", true); }
        #end
    }

    function pointHits(sprite:FlxSprite, touch:FlxTouch):Bool
    {
        if (sprite == null) return false;
        var p = touch.getWorldPosition();
        return sprite.overlapsPoint(p);
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        if (consentRequired)
        {
            if (FlxG.mouse.justPressed)
            {
                var mousePoint = FlxG.mouse.getWorldPosition();
                consentClickAt(mousePoint.x, mousePoint.y);
            }
            if (consentRequired)
            {
                for (touch in FlxG.touches.list)
                {
                    if (touch.justPressed)
                    {
                        var touchPoint = touch.getWorldPosition();
                        consentClickAt(touchPoint.x, touchPoint.y);
                        if (!consentRequired) break;
                    }
                }
            }
            return;
        }
        if (activating)
        {
            activationElapsed += elapsed;
            var button = activatedButton == 0 ? playButton : creditsButton;
            #if android
            if (activatedButton == 2) button = multiplayerButton;
            #end
            var fps = number(field(activationConfig, "blinkFPS"), 10);
            var alpha = number(field(activationConfig, "blinkAlpha"), 0.15);
            var duration = number(field(activationConfig, "blinkDuration"), 0.8);
            if (button != null) button.alpha = (Std.int(activationElapsed * fps) % 2 == 0) ? 1 : alpha;
            if (activationElapsed >= duration)
            {
                if (button != null) button.alpha = 1;
                stopMenuMusic();
                if (activatedButton == 0) FlxG.switchState(new PlayState());
                else if (activatedButton == 1) FlxG.switchState(new CreditsState());
                #if android
                else FlxG.switchState(new MultiplayerState());
                #else
                else FlxG.switchState(new CreditsState());
                #end
            }
            return;
        }
        for (touch in FlxG.touches.list)
        {
            if (!touch.justPressed) continue;
            if (pointHits(playButton, touch)) { activateButton(0); break; }
            if (pointHits(creditsButton, touch)) { activateButton(1); break; }
            #if android
            if (pointHits(multiplayerButton, touch)) { activateButton(2); break; }
            #end
        }
    }
}
