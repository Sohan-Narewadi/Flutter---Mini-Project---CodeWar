import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A thin seam over the room WebSocket so tests can substitute a fake.
abstract class RoomChannel {
  /// Decoded JSON messages from the server. Completes when the socket closes.
  Stream<Map<String, dynamic>> get messages;

  void send(Map<String, dynamic> message);

  /// WebSocket close code once closed (e.g. 4401 bad token), else null.
  int? get closeCode;

  Future<void> close();
}

typedef RoomChannelFactory = RoomChannel Function(Uri uri);

class WsRoomChannel implements RoomChannel {
  WsRoomChannel(Uri uri) : _channel = WebSocketChannel.connect(uri);

  final WebSocketChannel _channel;

  @override
  Stream<Map<String, dynamic>> get messages => _channel.stream
      .map((raw) => jsonDecode(raw as String))
      .where((m) => m is Map<String, dynamic>)
      .cast<Map<String, dynamic>>();

  @override
  void send(Map<String, dynamic> message) =>
      _channel.sink.add(jsonEncode(message));

  @override
  int? get closeCode => _channel.closeCode;

  @override
  Future<void> close() async {
    try {
      await _channel.sink.close();
    } catch (_) {}
  }
}
