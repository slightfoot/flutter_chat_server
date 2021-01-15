import 'dart:async';
import 'dart:convert' show json;
import 'dart:io';

import 'package:client/web_socket.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() => runApp(ChatApp());

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Client',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        accentColor: Colors.pinkAccent,
      ),
      home: Home(),
    );
  }
}

@immutable
class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _messages = <ChatMessage>[];
  late TextEditingController _messageController;
  late FocusNode _messageFocus;
  WebSocket? _socket;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageFocus = FocusNode();
    _connect().catchError((error, stackTrace) {
      print('Socket connect failed: $error\n$stackTrace');
    });
  }

  Future<void> _connect() async {
    // ignore: close_sinks
    _socket = await webSocketConnect('ws://localhost/chat', protocols: ['chat']);
    if (_socket!.readyState != WebSocket.open) {
      print('socket not ready');
      return;
    }
    _socket!.add('mobile connected');
    _sub = _socket!.listen(
      _onMessageReceived,
      onError: (error, stackTrace) {
        print('Socket error: $error\n$stackTrace');
      },
      onDone: () {
        print('Socket closed: ${_socket?.closeCode}: ${_socket?.closeReason}');
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _socket?.close();
    _messageFocus.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageReceived(dynamic event) {
    setState(() {
      _messages.insert(0, ChatMessage.fromJson(json.decode(event as String)));
    });
  }

  void _onSendPressed() {
    if (_socket == null) return;
    final text = _messageController.text;
    _socket!.add(text);
    setState(() {
      _messages.insert(0, ChatMessage.local(text));
    });
    _messageController.value = TextEditingValue.empty;
    _messageFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final message = _messages[index];
                  return ListTile(
                    title: Text(message.content),
                    subtitle: Text('Sent by ${message.sender}, ${message.sentAgo}'),
                  );
                },
              ),
            ),
            BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocus,
                          decoration: InputDecoration(
                            hintText: 'Enter Message',
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _onSendPressed(),
                        ),
                      ),
                      FlatButton(
                        onPressed: _onSendPressed,
                        child: Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MessageType {
  connected,
  message,
  disconnected,
}

class ChatMessage {
  ChatMessage({
    required this.sender,
    required this.sent,
    required this.type,
    required this.content,
  });

  static ChatMessage local(String content) {
    return ChatMessage(
      sender: -1,
      sent: DateTime.now(),
      type: MessageType.message,
      content: content,
    );
  }

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as int,
      sent: DateTime.parse(json['sent'] as String),
      type: MessageType.values[json['type'] as int],
      content: json['content'] as String,
    );
  }

  final int sender;
  final DateTime sent;
  final MessageType type;
  final String content;

  String get sentAgo => timeago.format(sent);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sender': sender,
      'sent': sent.toIso8601String(),
      'type': type.index,
      'content': content,
    };
  }
}
