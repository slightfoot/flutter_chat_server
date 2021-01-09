import 'dart:async';
import 'dart:convert' show json;
import 'dart:html';

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
  late WebSocket _socket;
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    final schema = window.location.protocol == 'http:' ? 'ws' : 'wss';
    _socket = WebSocket('$schema://${window.location.host}/chat', ['chat']);
    _sub = _socket.onMessage.listen(_onMessageReceived);
  }

  @override
  void dispose() {
    _sub.cancel();
    _socket.close();
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageReceived(MessageEvent event) {
    setState(() {
      _messages.insert(0, ChatMessage.fromJson(json.decode(event.data as String)));
    });
  }

  void _onSendPressed() {
    _socket.send(_messageController.text);
    _messageController.value = TextEditingValue.empty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
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
      bottomNavigationBar: Material(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
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
