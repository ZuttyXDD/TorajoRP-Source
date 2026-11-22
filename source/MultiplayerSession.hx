package;

/** Credenciais da sala online ativas durante a sessao atual. */
class MultiplayerSession
{
    public static var active:Bool = false;
    public static var roomCode:String = "";
    public static var token:String = "";
    public static var playerId:String = "";
    public static var role:String = "";
    public static var username:String = "";

    public static function clear():Void
    {
        active = false; roomCode = ""; token = ""; playerId = ""; role = ""; username = "";
    }
}
