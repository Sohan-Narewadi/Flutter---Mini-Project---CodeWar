import 'package:flutter/foundation.dart';

import '../models/player.dart';
import '../models/world.dart';
import '../models/level_node.dart';
import '../models/enemy.dart';
import '../models/question.dart';
import '../models/battle.dart';
import '../services/api_service.dart';
import '../services/seed_data.dart';

class GameState extends ChangeNotifier {
  GameState({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  bool isLoading = true;

  Player player = SeedData.player;
  List<GameWorld> worlds = SeedData.worlds;
  List<LevelNode> levels = SeedData.world2Nodes;
  List<Enemy> enemies = SeedData.enemies;

  /// The world this app's single-world demo flow (World Map / Sector Path)
  /// is built around ("Array Ruins", world order 2). Resolved from whatever
  /// `worlds` actually contains (live backend data or seed fallback) rather
  /// than assumed to be `worlds.first` - the backend returns World 1 before
  /// World 2 in its list.
  GameWorld get activeWorld {
    if (worlds.isEmpty) return SeedData.world2;
    return worlds.firstWhere(
      (w) => w.order == 2,
      orElse: () => worlds.length > 1 ? worlds[1] : worlds.first,
    );
  }

  // Active battle context
  Enemy? currentEnemy;
  LevelNode? currentLevel;
  Question? currentQuestion;
  String currentLanguage = 'python';
  String? currentCode;
  BattleResult? lastResult;

  // Backend-authoritative battle session state (set by startBattle(), which
  // is required before runTests()/submitAttack() can be called).
  int? battleId;
  int enemyHpRemaining = 0;
  int enemyHpMax = 0;
  int timeLimitS = 300;
  DateTime? battleStartedAt;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      // Worlds must resolve first: the backend's real World 2 id (e.g. "2")
      // is needed to fetch its levels - the seed data's placeholder id
      // ("w2") is not a valid backend world_id and was previously being
      // sent straight through, silently failing every levels request.
      final fetchedPlayer = await _api.fetchPlayer();
      final fetchedWorlds = await _api.fetchWorlds();
      final resolvedWorldId = fetchedWorlds.isEmpty
          ? SeedData.world2.id
          : fetchedWorlds
              .firstWhere((w) => w.order == 2, orElse: () => fetchedWorlds.length > 1 ? fetchedWorlds[1] : fetchedWorlds.first)
              .id;
      final results = await Future.wait([
        _api.fetchLevels(resolvedWorldId),
        _api.fetchEnemies(),
      ]);
      player = fetchedPlayer;
      worlds = fetchedWorlds;
      levels = results[0] as List<LevelNode>;
      enemies = results[1] as List<Enemy>;
    } catch (_) {
      // Guaranteed fallback: keep seed data already set above.
    }
    isLoading = false;
    notifyListeners();
  }

  Enemy enemyById(String id) =>
      enemies.firstWhere((e) => e.id == id, orElse: () => enemies.first);

  /// Resolves the backend Level for a given enemy via the backend's own
  /// Level.enemy_id association, for entry points into Battle Preparation
  /// that don't carry an explicit levelId (Battle Arena's "Fight" button,
  /// Practice's farmable-enemy cards). Works generically for any enemy that
  /// has a level attached in `levels` - not tied to any specific level id.
  /// Returns null if this enemy genuinely has no backend level yet (e.g. an
  /// enemy that isn't wired into the current world's sector path).
  LevelNode? levelForEnemy(String enemyId) {
    final matches = levels.where((l) => l.enemyId == enemyId);
    return matches.isEmpty ? null : matches.first;
  }

  List<LevelNode> get world2Levels =>
      levels.where((l) => l.worldId == activeWorld.id).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<Enemy> get farmableEnemies =>
      enemies.where((e) => !e.locked && e.difficulty == Difficulty.easy).toList();

  /// Kicks off a battle: calls POST /api/battles/start (required - a real
  /// battle needs a backend-issued battle_id), then prepares enemy/level/
  /// question context and resets ALL prior submission + combat state so
  /// stale data from a previous battle never leaks into a new one.
  ///
  /// Throws [BattleApiException] on failure - callers must surface this to
  /// the user rather than silently starting a fake local battle.
  Future<void> startBattle({Enemy? enemy, LevelNode? level}) async {
    currentEnemy = enemy ?? (level != null ? enemyById(level.enemyId) : currentEnemy);
    currentLevel = level;

    final levelIdInt = int.tryParse(level?.id ?? '');
    if (levelIdInt == null) {
      throw BattleApiException('This encounter has no backend level to battle against.');
    }

    final start = await _api.startBattle(levelIdInt);

    // Use the question the backend already resolved via this Level - it's
    // the canonical source. A separate fetchQuestion(enemy.questionId) call
    // used to run here, but EnemyOut has no question_id field at all, so
    // that id was always empty and silently mis-resolved to a seed fallback.
    currentQuestion = start.question;
    currentCode = currentQuestion?.starterCode[currentLanguage] ??
        currentQuestion?.starterCode.values.first;

    battleId = start.battleId;
    enemyHpRemaining = start.enemyHpRemaining;
    enemyHpMax = currentEnemy?.hpMax ?? start.enemyHpRemaining;
    timeLimitS = start.timeLimitS;
    battleStartedAt = start.startedAt != null ? DateTime.tryParse(start.startedAt!) : DateTime.now();
    lastResult = null;
    notifyListeners();
  }

  void setLanguage(String lang) {
    currentLanguage = lang;
    currentCode = currentQuestion?.starterCode[lang] ?? currentCode;
    notifyListeners();
  }

  void updateCode(String code) {
    currentCode = code;
  }

  /// Pure preview: evaluate current code against the backend judge without
  /// touching enemy HP, best_score, or player state. Requires an active
  /// battle (call startBattle() first). Throws [BattleApiException] on any
  /// backend failure - never falls back to a fake local result.
  Future<BattleResult> runTests() async {
    final bid = battleId;
    if (bid == null) {
      throw BattleApiException('No active battle - start a battle before running tests.');
    }
    final result = await _api.runBattleTests(bid, currentCode ?? '', language: currentLanguage);
    lastResult = result;
    notifyListeners();
    return result;
  }

  /// Submits the attack to the backend, which is the sole source of truth
  /// for damage/best-score/rewards. Applies the returned deltas to local
  /// state - never computes damage or outcome itself. Safe to call again on
  /// an ordinary partial-credit submit (battle stays "in_progress"); the
  /// backend itself rejects a resubmit after the battle is finalized.
  Future<BattleResult> submitAttack() async {
    final bid = battleId;
    if (bid == null) {
      throw BattleApiException('No active battle - start a battle before submitting.');
    }
    final result = await _api.submitBattle(bid, currentCode ?? '', language: currentLanguage);
    lastResult = result;

    enemyHpRemaining = result.enemyHpRemaining;
    if (result.enemyHpMax > 0) enemyHpMax = result.enemyHpMax;

    // Refresh the player from the backend rather than recomputing xp/gold/hp
    // locally - the backend owns leveling, and this keeps HUD/Profile/Rank
    // screens (which all read GameState.player) consistent with the server.
    if (result.xpEarned > 0 || result.goldEarned > 0 || result.hpLost > 0) {
      player = await _api.fetchPlayer();
    }

    if (result.enemyDefeated && currentEnemy != null) {
      _markDefeated(currentEnemy!.id);
    }

    notifyListeners();
    return result;
  }

  void _markDefeated(String enemyId) {
    enemies = enemies.map((e) {
      if (e.id == enemyId) {
        return Enemy(
          id: e.id,
          name: e.name,
          level: e.level,
          difficulty: e.difficulty,
          hpMax: e.hpMax,
          hpCurrent: 0,
          vulnerability: e.vulnerability,
          tier: e.tier,
          locked: e.locked,
          unlockHint: e.unlockHint,
          xpReward: e.xpReward,
          goldReward: e.goldReward,
          questionId: e.questionId,
          defeated: true,
        );
      }
      return e;
    }).toList();
  }
}
