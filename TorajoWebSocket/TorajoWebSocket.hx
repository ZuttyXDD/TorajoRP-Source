package;

#if android
import lime.system.JNI;
#end

class TorajoWebSocket {

    #if android
    private static var jniConnect =
        JNI.createStaticMethod(
            "org.haxe.extension.TorajoWebSocket",
            "connect",
            "(Ljava/lang/String;)V"
        );

    private static var jniSend =
        JNI.createStaticMethod(
            "org.haxe.extension.TorajoWebSocket",
            "send",
            "(Ljava/lang/String;)Z"
        );

    private static var jniPoll =
        JNI.createStaticMethod(
            "org.haxe.extension.TorajoWebSocket",
            "poll",
            "()Ljava/lang/String;"
        );

    private static var jniClose =
        JNI.createStaticMethod(
            "org.haxe.extension.TorajoWebSocket",
            "close",
            "()V"
        );
    #end

    public static function connect(url:String):Void {
        #if android
        jniConnect(url);
        #end
    }

    public static function send(message:String):Bool {
        #if android
        return jniSend(message);
        #else
        return false;
        #end
    }

    public static function poll():Null<String> {
        #if android
        return jniPoll();
        #else
        return null;
        #end
    }

    public static function close():Void {
        #if android
        jniClose();
        #end
    }
}
