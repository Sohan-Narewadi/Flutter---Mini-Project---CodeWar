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

  /// True once the first successful load has replaced the placeholder data.
  bool hasLoaded = false;

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

  /// True when the last refresh could not reach the server. The data shown
  /// is then the last known (or placeholder) state, and the UI says so.
  bool offline = false;
  String? error;

  ApiService get api => _api;
  bool get hasToken => _api.hasToken;

  /// Loads everything for the signed-in player. Without a token there is
  /// nothing to load: the router sends the user to onboarding.
  Future<void> load() async {
    if (!hasToken) {
      isLoading = false;
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      final fetchedPlayer = await _api.fetchPlayer();
      final fetchedWorlds = await _api.fetchWorlds();
      final world = _pickActiveWorld(fetchedWorlds);
      final results = await Future.wait([
        world == null ? Future.value(<LevelNode>[]) : _api.fetchLevels(world.id),
        _api.fetchEnemies(),
      ]);
      player = fetchedPlayer;
      worlds = fetchedWorlds;
      levels = results[0] as List<LevelNode>;
      enemies = results[1] as List<Enemy>;
      offline = false;
      error = null;
      hasLoaded = true;
    } on ApiException catch (e) {
      if (e.unauthorized) {
        // Token no longer valid (e.g. server reset): start over at onboarding.
        _api.settings.token = null;
      }
      offline = e.network;
      error = e.message;
    }
    isLoading = false;
    notifyListeners();
  }

  GameWorld? _pickActiveWorld(List<GameWorld> list) {
    if (list.isEmpty) return null;
    return list.firstWhere((w) => w.order == 2, orElse: () => list.length > 1 ? list[1] : list.first);
  }

  /// Creates the player on the server, stores the token, and loads the game.
  /// Throws [ApiException] (e.g. name taken) for the onboarding screen.
  Future<void> register(String name) async {
    await _api.createPlayer(name);
    await load();
  }

  /// Lets other state objects (practice, rooms) drop the old player's data.
  VoidCallback? onSignOut;

  void signOut() {
    _api.settings.token = null;
    hasLoaded = false;
    onSignOut?.call();
    notifyListeners();
  }

  /// Re-fetches progress after a battle so the map, enemies and world
  /// progress reflect what the server now says.
  Future<void> refreshProgress() async {
    try {
      final w = await _api.fetchWorlds();
      final world = _pickActiveWorld(w);
      final results = await Future.wait([
        world == null ? Future.value(<LevelNode>[]) : _api.fetchLevels(world.id),
        _api.fetchEnemies(),
        _api.fetchPlayer(),
      ]);
      worlds = w;
      levels = results[0] as List<LevelNode>;
      enemies = results[1] as List<Enemy>;
      player = results[2] as Player;
      offline = false;
    } on ApiException catch (e) {
      offline = e.network;
      error = e.message;
    }
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

    // Refresh from the backend rather than recomputing locally: the server
    // owns leveling, unlocks and progress.
    if (result.finalized || result.xpEarned > 0 || result.goldEarned > 0 || result.hpLost > 0) {
      await refreshProgress();
    }

    notifyListeners();
    return result;
  }
}
