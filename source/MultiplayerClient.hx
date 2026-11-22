
package;

import haxe.Json;
import StringTools;

class MultiplayerClient
{
    static inline var SERVER:String =
        "https://torajorp-online.tutu18417.workers.dev";

    public var connected(default, null):Bool = false;
    public var closed(default, null):Bool = false;

    var onEvent:Dynamic->Void;
    var onStatus:String->Void;
    var pendingMessages:Array<String> = [];

    public function new(
        roomCode:String,
        token:String,
        onEvent:Dynamic->Void,
        ?onStatus:String->Void
    )
    {
        this.onEvent = onEvent;
        this.onStatus = onStatus;

        var url = "wss://torajorp-online.tutu18417.workers.dev/room/"
            + roomCode
            + "/ws?token="
            + StringTools.urlEncode(token);

        try
        {
            TorajoWebSocket.connect(url);
        }
        catch (e:Dynamic)
        {
            closed = true;
            report("Falha ao iniciar WebSocket: " + Std.string(e));
        }
    }

    public function update():Void
    {
        if (closed) return;

        while (true)
        {
            var message = TorajoWebSocket.poll();

            if (message == null)
                break;

            if (StringTools.startsWith(message, "STATUS:"))
            {
                var status = message.substr(7);

                if (status == "connected")
                {
                    connected = true;
                    report("Conectado ao servidor multiplayer.");

                    var queued = pendingMessages.copy();
                    pendingMessages = [];

                    for (item in queued)
                        sendRaw(item);
                }
                else if (status == "closed")
                {
                    connected = false;
                    closed = true;
                    report("Conexao multiplayer encerrada.");
                }
                else if (StringTools.startsWith(status, "error:"))
                {
                    connected = false;
                    closed = true;
                    report("Erro WebSocket: " + status.substr(6));
                }
                else
                {
                    report("WebSocket: " + status);
                }
            }
            else if (StringTools.startsWith(message, "MESSAGE:"))
            {
                var raw = message.substr(8);

                try
                {
                    var parsed:Dynamic = Json.parse(raw);

                    if (onEvent != null)
                        onEvent(parsed);
                }
                catch (e:Dynamic)
                {
                    trace("WebSocket recebeu JSON invalido: " + Std.string(e));
                }
            }
        }
    }

    public function send(data:Dynamic):Bool
    {
        if (closed) return false;

        var encoded = Json.stringify(data);

        if (!connected)
        {
            if (pendingMessages.length < 128)
            {
                pendingMessages.push(encoded);
                return true;
            }

            return false;
        }

        return sendRaw(encoded);
    }

    function sendRaw(message:String):Bool
    {
        try
        {
            return TorajoWebSocket.send(message);
        }
        catch (e:Dynamic)
        {
            report("Falha ao enviar evento: " + Std.string(e));
            return false;
        }
    }

    public function close():Void
    {
        if (closed) return;

        TorajoWebSocket.close();

        connected = false;
        closed = true;
        pendingMessages = [];
    }

    function report(message:String):Void
    {
        trace(message);

        if (onStatus != null)
            onStatus(message);
    }
}
