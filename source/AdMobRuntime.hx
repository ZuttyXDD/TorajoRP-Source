package;

#if android
import extension.admob.Admob;
import extension.admob.AdmobEvent;
#end

/**
 * Gerencia a inicializacao unica do AdMob e encaminha eventos para o estado atual.
 * O modo de teste e definido centralmente em AdsConfig.
 */
class AdMobRuntime
{
    public static var started:Bool = false;
    public static var ready:Bool = false;
    static var currentCallback:String->String->Void;

    public static function initialize(callback:String->String->Void):Void
    {
        if (!AdsConfig.ENABLE_ADS) return;
        setCallback(callback);
        #if android
        if (!started)
        {
            started = true;
            Admob.setCallback(dispatch);
            // Na extension-admob 3.0.1, a inicializacao nao recebe parametros.
            // Os anuncios de teste sao determinados pelos IDs de teste configurados.
            Admob.init();
        }
        else if (ready)
        {
            // A extensao ja foi inicializada; apenas atualizamos o receptor.
        }
        #end
    }

    public static function setCallback(callback:String->String->Void):Void
    {
        currentCallback = callback;
        #if android
        Admob.setCallback(dispatch);
        #end
    }

    #if android
    static function dispatch(event:String, message:String):Void
    {
        if (event == AdmobEvent.INIT_OK) ready = true;
        if (currentCallback != null) currentCallback(event, message);
    }
    #end
}
