import 'dart:convert' show base64;
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String _webSocketGUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/// We have cloned the standard WebSocket.connect without compression to resolved
/// an outstanding bug: https://github.com/dart-lang/sdk/issues/43574
Future<WebSocket> webSocketConnect(
  String url, {
  List<String>? protocols,
  Map<String, dynamic>? headers,
}) async {
  Uri uri = Uri.parse(url);
  if (uri.scheme != 'ws' && uri.scheme != 'wss') {
    throw new WebSocketException("Unsupported URL scheme '${uri.scheme}'");
  }
  uri = uri.replace(scheme: uri.scheme == 'wss' ? 'https' : 'http');

  Random random = Random();
  // Generate 16 random bytes.
  Uint8List nonceData = Uint8List(16);
  for (int i = 0; i < 16; i++) {
    nonceData[i] = random.nextInt(256);
  }
  String nonce = base64.encode(nonceData);

  final request = await HttpClient().getUrl(uri);

  if (headers != null) {
    headers.forEach((field, value) => request.headers.add(field, value));
  }

  request.headers //
    ..set(HttpHeaders.connectionHeader, 'Upgrade')
    ..set(HttpHeaders.upgradeHeader, 'websocket')
    ..set('Cache-Control', 'no-cache')
    ..set('Sec-WebSocket-Key', nonce)
    ..set('Sec-WebSocket-Version', '13');

  if (protocols != null) {
    request.headers.set('Sec-WebSocket-Protocol', protocols);
  }

  // For some reason dart-lang/sdk adds a "content-length: 0" header for
  // GET based requests when it shouldn't causing some servers to
  // disconnect after payload.
  request.headers.removeAll(HttpHeaders.contentLengthHeader);

  final response = await request.close();

  Never error(String message) {
    // Flush data.
    response.detachSocket().then((socket) {
      socket.destroy();
    });
    throw new WebSocketException(message);
  }

  String? accept = response.headers.value('Sec-WebSocket-Accept');
  if (accept == null) {
    error("Response did not contain a 'Sec-WebSocket-Accept' header");
  }
  final sha = sha1.convert('$nonce$_webSocketGUID'.codeUnits);
  final receivedAccept = base64.decode(accept);
  if (sha.bytes.length != receivedAccept.length) {
    error("Response header 'Sec-WebSocket-Accept' is the wrong length");
  }
  for (int i = 0; i < sha.bytes.length; i++) {
    if (sha.bytes[i] != receivedAccept[i]) {
      error("Bad response 'Sec-WebSocket-Accept' header");
    }
  }

  final protocol = response.headers.value('Sec-WebSocket-Protocol');

  // ignore: close_sinks
  final socket = await response.detachSocket();

  return WebSocket.fromUpgradedSocket(
    socket,
    protocol: protocol,
    serverSide: false,
    compression: CompressionOptions.compressionOff,
  );
}
