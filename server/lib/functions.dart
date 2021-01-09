import 'dart:async';
import 'dart:io';

import 'package:functions_framework/functions_framework.dart';
import 'package:path/path.dart' as path;
import 'package:server/chat.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

final staticHandler = createStaticHandler(
  path.join(Directory.current.path, 'public'),
  defaultDocument: 'index.html',
);

final chatServer = ChatServer();

@CloudFunction()
FutureOr<Response> function(Request request, RequestLogger logger) {
  final uriPath = request.requestedUri.path;
  if (uriPath.startsWith('/chat')) {
    return chatServer.handleRequest(request);
  } else {
    return staticHandler(request);
  }
}
