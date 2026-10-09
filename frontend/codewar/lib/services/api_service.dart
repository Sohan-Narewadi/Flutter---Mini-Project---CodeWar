import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/battle.dart';
import '../models/player.dart';
import '../models/world.dart';
import '../models/level_node.dart';
import '../models/enemy.dart';
import '../models/leaderboard.dart';
import '../models/practice.dart';
import '../models/room.dart';
import 'settings_store.dart';

/// Compile-time override: `flutter run --dart-define=API_URL=https://...`
const _envApiUrl = String.fromEnvironment('API_URL');

/// The Android emulator reaches the host machine's localhost via 10.0.2.2;
/// every other target (Windows/macOS/Linux desktop, web, iOS simulator)
/// reaches it directly via 127.0.0.1.
String _defaultBaseUrl() {
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}

/// Any failed backend call. [unauthorized] means the stored token is no
/// longer valid; [network] means the server could not be reached at all.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.network = false});
  final String message;
  final int? statusCode;
  final bool network;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin REST client for the CodeWar backend. Nothing here ever fabricates
/// data: every failure surfaces as an [ApiException] for the UI to show.
class ApiService {
  ApiService({http.Client? client, SettingsStore? settings})
      : _client = client ?? http.Client(),
        settings = settings ?? SettingsStore.memory();

  final http.Client _client;
  final SettingsStore settings;

  // The first request after a cold start can be slow on the emulator's NAT
  // path, and a tunnel adds latency, so keep GETs generous but bounded.
  static const _timeout = Duration(seconds: 8);
  // Battle submissions spawn a fresh process per test case on the server.
  static const _battleTimeout = Duration(seconds: 20);

  static const _offlineMessage =
      'Cannot reach the CodeWar server. Check your connection or the server address in Settings.';

  bool get hasToken => settings.hasToken;

  String get baseUrl {
    final stored = settings.apiUrl;
    final raw = (stored != null && stored.isNotEmpty)
        ? stored
        : (_envApiUrl.isNotEmpty ? _envApiUrl : _defaultBaseUrl());
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Duration timeout = _timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (settings.token != null) 'Authorization': 'Bearer ${settings.token}',
    };
    try {
      final res = method == 'GET'
          ? await _client.get(uri, headers: headers).timeout(timeout)
          : await _client
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.body.isEmpty ? null : jsonDecode(res.body);
      }
      throw ApiException(_readableError(res), statusCode: res.statusCode);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(_offlineMessage, network: true);
    } on SocketException {
      throw ApiException(_offlineMessage, network: true);
    } on http.ClientException {
      throw ApiException(_offlineMessage, network: true);
    } on FormatException {
      throw ApiException('The server sent an unexpected response.');
    }
  }

  String _readableError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        final d = body['detail'];
        if (d is String) return d;
        if (d is List && d.isNotEmpty && d.first is Map) {
          return (d.first as Map)['msg']?.toString() ?? 'Invalid request.';
        }
        return d.toString();
      }
    } catch (_) {}
    return 'The server returned an error (HTTP ${res.statusCode}).';
  }

  // --- Accounts -----------------------------------------------------------

  /// Registers a new player and stores the issued token.
  Future<Player> createPlayer(String name) async {
    final json = await _request('POST', '/api/players', body: {'name': name})
        as Map<String, dynamic>;
    settings.token = json['token'] as String;
    settings.playerName = name;
    return Player.fromJson(json['player'] as Map<String, dynamic>);
  }

  // --- Read endpoints -----------------------------------------------------

  Future<Player> fetchPlayer() async =>
      Player.fromJson(await _request('GET', '/api/player') as Map<String, dynamic>);

  Future<List<GameWorld>> fetchWorlds() async {
    final list = await _request('GET', '/api/worlds') as List;
    return list.map((e) => GameWorld.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LevelNode>> fetchLevels(String worldId) async {
    final list = await _request('GET', '/api/levels?world_id=$worldId') as List;
    return list.map((e) => LevelNode.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Enemy>> fetchEnemies() async {
    final list = await _request('GET', '/api/enemies') as List;
    return list.map((e) => Enemy.fromJson(e as Map<String, dynamic>)).toList();
  }

  // --- Rooms ----------------------------------------------------------------

  Future<RoomSnapshot> createRoom({String mode = 'race', String difficulty = 'easy', String language = 'python'}) async =>
      RoomSnapshot.fromJson(await _request('POST', '/api/rooms',
          body: {'mode': mode, 'difficulty': difficulty, 'language': language}) as Map<String, dynamic>);

  Future<RoomSnapshot> joinRoom(String code) async => RoomSnapshot.fromJson(
      await _request('POST', '/api/rooms/${Uri.encodeComponent(code.trim().toUpperCase())}/join') as Map<String, dynamic>);

  /// WebSocket address for a room: same host as the REST API, ws:// or wss://.
  Uri roomSocketUri(String code) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}/ws/rooms/${code.toUpperCase()}',
      queryParameters: {'token': settings.token ?? ''},
    );
  }

  // --- Leaderboard & friends ----------------------------------------------

  Future<Leaderboard> fetchLeaderboard({String scope = 'global', String metric = 'xp', int limit = 50}) async =>
      Leaderboard.fromJson(await _request('GET', '/api/leaderboard?scope=$scope&metric=$metric&limit=$limit')
          as Map<String, dynamic>);

  Future<void> addFriend(String name) async {
    await _request('POST', '/api/friends', body: {'name': name});
  }

  // --- Practice -------------------------------------------------------------

  Future<PracticeStats> fetchPracticeStats() async =>
      PracticeStats.fromJson(await _request('GET', '/api/practice/stats') as Map<String, dynamic>);

  Future<PracticeSession> practiceNext({String difficulty = 'easy', String? topic, bool daily = false}) async =>
      PracticeSession.fromJson(await _request('POST', '/api/practice/next',
          body: {'difficulty': difficulty, 'topic': topic, 'daily': daily}, timeout: _battleTimeout)
          as Map<String, dynamic>);

  Future<BattleResult> practiceRun(int practiceId, String code, String language) async =>
      BattleResult.fromRunJson(await _request('POST', '/api/practice/$practiceId/run',
          body: {'code': code, 'language': language}, timeout: _battleTimeout) as Map<String, dynamic>);

  Future<PracticeSubmitResult> practiceSubmit(int practiceId, String code, String language) async =>
      PracticeSubmitResult.fromJson(await _request('POST', '/api/practice/$practiceId/submit',
          body: {'code': code, 'language': language}, timeout: _battleTimeout) as Map<String, dynamic>);

  Future<Hint> practiceHint(int practiceId, String code, String language) async =>
      Hint.fromJson(await _request('POST', '/api/practice/$practiceId/hint',
          body: {'code': code, 'language': language}, timeout: _battleTimeout) as Map<String, dynamic>);

  // --- Battle endpoints ---------------------------------------------------
  // These surface failures as BattleApiException so battle screens can show
  // the message directly.

  Future<T> _battle<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw BattleApiException(e.message);
    }
  }

  Future<BattleStartResult> startBattle(int levelId) => _battle(() async {
        final json = await _request('POST', '/api/battles/start',
            body: {'level_id': levelId}, timeout: _battleTimeout) as Map<String, dynamic>;
        return BattleStartResult.fromJson(json);
      });

  Future<BattleResult> runBattleTests(int battleId, String code, {String language = 'python'}) =>
      _battle(() async {
        final json = await _request('POST', '/api/battles/$battleId/run',
            body: {'code': code, 'language': language}, timeout: _battleTimeout) as Map<String, dynamic>;
        return BattleResult.fromRunJson(json);
      });

  Future<BattleResult> submitBattle(int battleId, String code, {String language = 'python'}) =>
      _battle(() async {
        final json = await _request('POST', '/api/battles/$battleId/submit',
            body: {'code': code, 'language': language}, timeout: _battleTimeout) as Map<String, dynamic>;
        return BattleResult.fromSubmitJson(json);
      });
}
