package org.haxe.extension;

import java.util.concurrent.LinkedBlockingQueue;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;

public class TorajoWebSocket extends Extension {

    private static OkHttpClient client;
    private static WebSocket socket;

    private static final LinkedBlockingQueue<String> events =
        new LinkedBlockingQueue<>();

    public static synchronized void connect(String url) {
        close();
        events.clear();

        try {
            if (client == null) {
                client = new OkHttpClient();
            }

            Request request = new Request.Builder().url(url).build();

            socket = client.newWebSocket(request, new WebSocketListener() {
                @Override
                public void onOpen(WebSocket webSocket, Response response) {
                    events.offer("STATUS:connected");
                }

                @Override
                public void onMessage(WebSocket webSocket, String text) {
                    events.offer("MESSAGE:" + text);
                }

                @Override
                public void onMessage(WebSocket webSocket, ByteString bytes) {
                    // O protocolo do TorajoRP utiliza mensagens JSON em texto.
                }

                @Override
                public void onClosing(WebSocket webSocket, int code, String reason) {
                    events.offer("STATUS:closing");
                }

                @Override
                public void onClosed(WebSocket webSocket, int code, String reason) {
                    events.offer("STATUS:closed");
                }

                @Override
                public void onFailure(WebSocket webSocket, Throwable error, Response response) {
                    String message = error.getMessage();
                    events.offer("STATUS:error:" + (message == null ? error.toString() : message));
                }
            });
        } catch (Exception error) {
            String message = error.getMessage();
            events.offer("STATUS:error:" + (message == null ? error.toString() : message));
        }
    }

    public static boolean send(String message) {
        WebSocket current = socket;
        return current != null && current.send(message);
    }

    public static String poll() {
        return events.poll();
    }

    public static synchronized void close() {
        if (socket != null) {
            socket.close(1000, "Client disconnected");
            socket = null;
        }
    }

    @Override
    public void onDestroy() {
        close();

        if (client != null) {
            client.dispatcher().executorService().shutdown();
            client = null;
        }
    }
}
