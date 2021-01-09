import 'dart:async';
import 'dart:convert' show json;

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnChatClient = void Function(ChatClient client);

class ChatServer {
  ChatServer([this.hostname]);

  final String? hostname;
  final _clients = <ChatClient>[];
  var _nextId = 0;

  void close() {
    for (final client in _clients) {
      client.close();
    }
  }

  FutureOr<Response> handleRequest(Request request) {
    List<String>? allowedOrigins;
    if (hostname != null) {
      allowedOrigins = ['http://$hostname', 'https://$hostname'];
      if (hostname == 'localhost') {
        allowedOrigins.add('http://$hostname:8888');
      }
    }
    return webSocketHandler(
      _onWebSocketConnection,
      protocols: ['chat'],
      allowedOrigins: allowedOrigins,
      pingInterval: const Duration(seconds: 1),
    )(request);
  }

  void _onWebSocketConnection(WebSocketChannel channel, String protocol) {
    final client = ChatClient(++_nextId, channel, this);
    client.listen(onConnect, onDisconnect);
  }

  void onConnect(ChatClient client) {
    _clients.add(client);
    send(ChatMessage.connected(client));
  }

  void onDisconnect(ChatClient client) {
    send(ChatMessage.disconnected(client));
    _clients.remove(client);
  }

  void send(ChatMessage message) {
    for (final client in List.of(_clients)) {
      if (client != message.sender) {
        client._channel.sink.add(json.encode(message));
      }
    }
  }

  ChatClient? lookupClient(int id) {
    return _clients
        .cast<ChatClient?>()
        .singleWhere((client) => client?.id == id, orElse: () => null);
  }
}

class ChatClient {
  ChatClient(this.id, this._channel, this._server);

  final int id;
  final WebSocketChannel _channel;
  final ChatServer _server;

  void listen(OnChatClient onConnected, OnChatClient onDisconnect) {
    onConnected(this);
    _channel.stream.listen(
      onData,
      onDone: () => onDisconnect(this),
      cancelOnError: true,
    );
  }

  void close() {
    _channel.sink.close();
  }

  void onData(dynamic data) {
    _server.send(ChatMessage.message(this, data as String));
  }
}

enum MessageType {
  connected,
  message,
  disconnected,
}

class ChatMessage {
  static ChatMessage connected(ChatClient sender) {
    return ChatMessage(
      sender: sender,
      sent: DateTime.now(),
      type: MessageType.connected,
      content: 'connected',
    );
  }

  static ChatMessage message(ChatClient sender, String message) {
    return ChatMessage(
      sender: sender,
      sent: DateTime.now(),
      type: MessageType.message,
      content: message,
    );
  }

  static ChatMessage disconnected(ChatClient sender) {
    return ChatMessage(
      sender: sender,
      sent: DateTime.now(),
      type: MessageType.disconnected,
      content: 'disconnected',
    );
  }

  ChatMessage({
    this.sender,
    required this.sent,
    required this.type,
    required this.content,
  });

  static ChatMessage fromJson(ChatServer server, Map<String, dynamic> json) {
    return ChatMessage(
      sender: server.lookupClient(json['sender'] as int),
      sent: DateTime.parse(json['sent'] as String),
      type: MessageType.values[json['type'] as int],
      content: json['content'] as String,
    );
  }

  final ChatClient? sender;
  final DateTime sent;
  final MessageType type;
  final String content;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sender': sender?.id,
      'sent': sent.toIso8601String(),
      'type': type.index,
      'content': content,
    };
  }
}
