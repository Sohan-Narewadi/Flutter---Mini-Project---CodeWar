import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/battle.dart';
import '../models/player.dart';
import '../models/world.dart';
import '../models/level_node.dart';
import '../models/enemy.dart';
import '../models/question.dart';
import 'seed_data.dart';

/// Thin REST client for the CodeWar backend. The Android emulator reaches
/// the host machine's localhost via 10.0.2.2.
///
/// Every method has a short timeout and falls back to local seed data on
/// any failure (timeout, connection refused, bad shape) so the demo never
/// shows a blank or broken screen even if the backend isn't running.
class ApiService {
  ApiService({this.baseUrl = 'http://10.0.2.2:8000'});

  final String baseUrl;
  // The very first HTTP call after a cold app start can take noticeably
  // longer than later ones on the emulator's NAT'd 10.0.2.2 path (ARP/route
  // warm-up), which was causing GameState.load()'s first request to time
  // out and silently fall back to seed data even while every later request
  // in the same load() succeeded. 5s comfortably covers that cold-start
  // cost while still failing fast if the backend is genuinely unreachable.
  static const _timeout = Duration(seconds: 5);
  // Battle submissions spawn a fresh sandboxed process per test case (see
  // backend judge.py), so they're slower than a plain GET - give them real
  // headroom rather than a generous-looking-but-still-too-short timeout.
  static const _battleTimeout = Duration(seconds: 20);

  Future<Player> fetchPlayer() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/player'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return Player.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // fall through to seed data
    }
    return SeedData.player;
  }

  Future<List<GameWorld>> fetchWorlds() async {
    try {
      final res =
          await http.get(Uri.parse('$baseUrl/api/worlds')).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .map((e) => GameWorld.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return SeedData.worlds;
  }

  Future<List<LevelNode>> fetchLevels(String worldId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/levels?world_id=$worldId'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .map((e) => LevelNode.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return SeedData.world2Nodes;
  }

  Future<List<Enemy>> fetchEnemies() async {
    try {
      final res =
          await http.get(Uri.parse('$baseUrl/api/enemies')).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .map((e) => Enemy.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return SeedData.enemies;
  }

  Future<Question> fetchQuestion(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/questions/$id'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return Question.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return SeedData.questionById(id);
  }

  // --- Battle submission endpoints ---------------------------------------
  // Unlike the read-only GETs above, these NEVER silently fall back to fake
  // local data on failure: a real battle submission requires the backend to
  // be reachable, so any failure throws a BattleApiException with a message
  // the UI can surface directly (e.g. as a snackbar).

  Future<BattleStartResult> startBattle(int levelId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/battles/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'level_id': levelId}),
          )
          .timeout(_battleTimeout);
      if (res.statusCode == 200) {
        return BattleStartResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      throw BattleApiException(_readableError(res));
    } on BattleApiException {
      rethrow;
    } on SocketException {
      throw BattleApiException('Connection to battle server lost — check the backend is running.');
    } on TimeoutException {
      throw BattleApiException('Connection to battle server lost — check the backend is running.');
    } catch (e) {
      throw BattleApiException('Could not start battle: $e');
    }
  }

  Future<BattleResult> runBattleTests(int battleId, String code, {String language = 'python'}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/battles/$battleId/run'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': code, 'language': language}),
          )
          .timeout(_battleTimeout);
      if (res.statusCode == 200) {
        return BattleResult.fromRunJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      throw BattleApiException(_readableError(res));
    } on BattleApiException {
      rethrow;
    } on SocketException {
      throw BattleApiException('Connection to battle server lost — check the backend is running.');
    } on TimeoutException {
      throw BattleApiException('Connection to battle server lost — check the backend is running.');
    } catch (e) {
      throw BattleApiException('Could not run tests: $e');
    }
  }

  Future<BattleResult> submitBattle(int battleId, String code, {String language = 'python'}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/battles/$battleId/submit'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': code, 'language': language}),
          )
          .timeout(_battleTimeout);
      if (res.statusCode == 200) {
        return BattleResult.fromSubmitJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      throw BattleApiException(_readableError(res));
    } on BattleApiException {
      rethrow;
    } on SocketException {
      throw BattleApiException('Connection to battle server lost — check the backend is running.');
    } on TimeoutException {
      throw BattleApiException('Connection to battle server lost — check the backend is running.');
    } catch (e) {
      throw BattleApiException('Could not submit attack: $e');
    }
  }

  String _readableError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return 'Battle server returned an error (HTTP ${res.statusCode}).';
  }
}
