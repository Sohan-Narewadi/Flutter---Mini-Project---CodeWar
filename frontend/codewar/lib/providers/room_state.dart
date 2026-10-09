import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battle.dart';
import '../models/language.dart';
import '../models/question.dart';
import '../models/room.dart';
import '../services/api_service.dart';
import '../services/room_channel.dart';

enum RoomConnection { idle, connecting, connected, reconnecting, closed }

/// Online rooms (Race / Duel): REST create/join, then one WebSocket that
/// streams snapshots. The server owns the clock and scoring; this class only
/// mirrors what it sends and forwards the player's actions.
class RoomState extends ChangeNotifier {
  RoomState(
    this._api, {
    RoomChannelFactory? channelFactory,
    this.onFinished,
    this.backoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
  }) : _factory = channelFactory ?? ((uri) => WsRoomChannel(uri));

  final ApiService _api;
  final RoomChannelFactory _factory;
  final List<Duration> backoff;

  /// Called once when a match finishes with rewards, so the HUD can refresh.
  final Future<void> Function()? onFinished;

  // Application close codes (see rooms-protocol.md).
  static const _terminalCodes = {4000, 4401, 4403, 4404};

  RoomSnapshot? room;
  Question? question;
  BattleResult? lastRun;
  String? lastRunKind; // 'run' | 'submit'
  String? error;
  bool judging = false;
  RoomConnection connection = RoomConnection.idle;
  Language language = Language.python;
  String code = '';

  RoomChannel? _channel;
  StreamSubscription<Map<String, dynamic>>? _sub;
  int _attempt = 0;
  bool _leaving = false;
  bool _rewardsReported = false;
  DateTime _snapshotAt = DateTime.now();
  String? _code;

  String get serverUrl => _api.baseUrl;

  bool get inRoom =>
      room != null &&
      connection != RoomConnection.closed &&
      connection != RoomConnection.idle;

  /// Seconds left in a running match, counting down locally between snapshots.
  int get secondsLeft {
    final base = room?.secondsLeft;
    if (base == null) return 0;
    final elapsed = DateTime.now().difference(_snapshotAt).inSeconds;
    return (base - elapsed).clamp(0, 1 << 30);
  }

  /// Countdown (3, 2, 1) shown before the problem appears.
  int get countdownNumber {
    final base = room?.countdownLeft;
    if (base == null) return 0;
    final left =
        base - DateTime.now().difference(_snapshotAt).inMilliseconds / 1000;
    return left <= 0 ? 0 : left.ceil();
  }

  RoomPlayer? me(int myId) => room?.playerById(myId);

  // --- entering / leaving ------------------------------------------------

  Future<bool> create({
    String mode = 'race',
    String difficulty = 'easy',
  }) async {
    return _enter(
      () => _api.createRoom(
        mode: mode,
        difficulty: difficulty,
        language: language.id,
      ),
    );
  }

  Future<bool> join(String code) async {
    final cleaned = code.trim().toUpperCase();
    if (cleaned.length != 6) {
      error = 'Room codes have 6 characters.';
      notifyListeners();
      return false;
    }
    return _enter(() => _api.joinRoom(cleaned));
  }

  Future<bool> _enter(Future<RoomSnapshot> Function() call) async {
    await _teardown();
    error = null;
    connection = RoomConnection.connecting;
    notifyListeners();
    try {
      final snap = await call();
      _reset();
      _setRoom(snap);
      _code = snap.code;
      language = Language.fromId(snap.language);
      _openChannel();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      connection = RoomConnection.idle;
      notifyListeners();
      return false;
    }
  }

  void _reset() {
    room = null;
    question = null;
    lastRun = null;
    lastRunKind = null;
    judging = false;
    code = '';
    _attempt = 0;
    _leaving = false;
    _rewardsReported = false;
  }

  void _openChannel() {
    final c = _code;
    if (c == null) return;
    // A result owed by the previous socket will never arrive.
    judging = false;
    final channel = _factory(_api.roomSocketUri(c));
    _channel = channel;
    _sub = channel.messages.listen(
      _onMessage,
      onError: (_) => _onClosed(channel),
      onDone: () => _onClosed(channel),
    );
  }

  /// Drops all room state without telling the server (used on sign-out).
  Future<void> reset() async {
    _leaving = true;
    await _teardown();
    _reset();
    _code = null;
    room = null;
    question = null;
    error = null;
    connection = RoomConnection.idle;
    notifyListeners();
  }

  Future<void> leave() async {
    _leaving = true;
    final ch = _channel;
    ch?.send({'type': 'leave'});
    await _teardown();
    room = null;
    question = null;
    connection = RoomConnection.idle;
    notifyListeners();
  }

  Future<void> _teardown() async {
    await _sub?.cancel();
    _sub = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) await ch.close();
  }

  // --- incoming ------------------------------------------------------------

  void _setRoom(RoomSnapshot snap) {
    final wasRunning = room?.status == 'running';
    room = snap;
    _snapshotAt = DateTime.now();
    if (snap.status == 'running' && !wasRunning && question != null) {
      _seedCode();
    }
    if (snap.status == 'finished' &&
        !_rewardsReported &&
        (snap.standings?.any((s) => s.hasRewards) ?? false)) {
      _rewardsReported = true;
      onFinished?.call();
    }
  }

  void _seedCode() {
    final q = question;
    if (q == null) return;
    code = q.starterCode[language.id] ?? q.starterCode.values.firstOrNull ?? '';
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'snapshot':
        connection = RoomConnection.connected;
        _attempt = 0;
        _setRoom(RoomSnapshot.fromJson(msg['room'] as Map<String, dynamic>));
      case 'question':
        final fresh = question == null;
        question = Question.fromJson(msg['question'] as Map<String, dynamic>);
        if (fresh) _seedCode();
      case 'run_result':
        judging = false;
        lastRunKind = msg['kind']?.toString();
        lastRun = BattleResult.fromRunJson(msg);
      case 'error':
        judging = false;
        error = msg['message']?.toString() ?? 'Something went wrong.';
      default:
        return;
    }
    notifyListeners();
  }

  void _onClosed(RoomChannel channel) {
    if (!identical(channel, _channel)) {
      return; // an old, replaced, or already-handled socket
    }
    // web_socket_channel reports one failed connection as an error AND a done
    // event; handle it once so it costs one retry, not two.
    _channel = null;
    final closeCode = channel.closeCode;
    if (_leaving) return;
    final finished = room?.status == 'finished';
    if (_terminalCodes.contains(closeCode) || finished || room == null) {
      if (closeCode == 4401) {
        error = 'Your session is no longer valid. Please sign in again.';
      }
      if (closeCode == 4404) error = 'That room no longer exists.';
      if (closeCode == 4000) {
        error = 'This account joined the room from another device.';
      }
      connection = finished ? RoomConnection.closed : RoomConnection.closed;
      notifyListeners();
      return;
    }
    if (_attempt >= backoff.length) {
      connection = RoomConnection.closed;
      error = 'Lost connection to the room.';
      notifyListeners();
      return;
    }
    connection = RoomConnection.reconnecting;
    final delay = backoff[_attempt++];
    notifyListeners();
    Timer(delay, () {
      if (_leaving || connection != RoomConnection.reconnecting) return;
      _sub?.cancel();
      _openChannel();
    });
  }

  // --- outgoing --------------------------------------------------------------

  void clearError() {
    error = null;
    notifyListeners();
  }

  void setLanguage(Language l) {
    language = l;
    code = question?.starterCode[l.id] ?? code;
    lastRun = null;
    notifyListeners();
  }

  void updateCode(String c) => code = c;

  void start() {
    error = null;
    _channel?.send({'type': 'start'});
    notifyListeners();
  }

  void run() => _judge('run');
  void submit() => _judge('submit');

  void _judge(String kind) {
    if (judging || _channel == null) return;
    judging = true;
    error = null;
    _channel!.send({'type': kind, 'code': code, 'language': language.id});
    notifyListeners();
  }

  @override
  void dispose() {
    _leaving = true;
    _sub?.cancel();
    _channel?.close();
    super.dispose();
  }
}
