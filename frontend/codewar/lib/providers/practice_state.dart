import 'package:flutter/foundation.dart';

import '../models/battle.dart';
import '../models/language.dart';
import '../models/practice.dart';
import '../services/api_service.dart';
import '../services/sfx.dart';

/// Practice mode: topic mastery, the endless problem stream, and the active
/// problem (code, test runs, hints). The server is authoritative for solving,
/// XP and streaks; this class only mirrors what it returns.
class PracticeState extends ChangeNotifier {
  PracticeState(this._api, {this.onProgress});

  final ApiService _api;

  /// Called after a solve so the HUD/profile (GameState) can refresh.
  final Future<void> Function()? onProgress;

  PracticeStats stats = PracticeStats.empty;
  bool loadingStats = false;
  String? statsError;

  // --- Active problem ---
  PracticeSession? session;
  Language language = Language.python;
  String code = '';
  bool starting = false;
  bool running = false;
  bool submitting = false;
  bool hinting = false;
  String? error;
  BattleResult? lastRun;
  PracticeSubmitResult? lastSubmit;
  final List<Hint> hints = [];

  String difficulty = 'easy';
  String? topic; // null = random topic

  bool get busy => starting || running || submitting || hinting;

  /// Forgets everything about the current player (used on sign-out).
  void reset() {
    stats = PracticeStats.empty;
    statsError = null;
    session = null;
    code = '';
    error = null;
    lastRun = null;
    lastSubmit = null;
    hints.clear();
    starting = running = submitting = hinting = false;
    notifyListeners();
  }

  Future<void> loadStats() async {
    loadingStats = true;
    statsError = null;
    notifyListeners();
    try {
      stats = await _api.fetchPracticeStats();
    } on ApiException catch (e) {
      statsError = e.message;
    }
    loadingStats = false;
    notifyListeners();
  }

  void setDifficulty(String d) {
    difficulty = d;
    notifyListeners();
  }

  void setTopic(String? t) {
    topic = t;
    notifyListeners();
  }

  /// Starts a fresh problem (or today's daily). Returns false on failure,
  /// leaving [error] set for the UI to display.
  Future<bool> start({bool daily = false, String? topicOverride}) async {
    starting = true;
    error = null;
    notifyListeners();
    try {
      final s = await _api.practiceNext(
        difficulty: difficulty,
        topic: daily ? null : (topicOverride ?? topic),
        daily: daily,
      );
      session = s;
      code = s.question.starterCode[language.id] ?? s.question.starterCode.values.firstOrNull ?? '';
      lastRun = null;
      lastSubmit = null;
      hints.clear();
      starting = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      starting = false;
      notifyListeners();
      return false;
    }
  }

  void setLanguage(Language l) {
    language = l;
    code = session?.question.starterCode[l.id] ?? code;
    lastRun = null;
    notifyListeners();
  }

  void updateCode(String c) => code = c;

  Future<void> run() async {
    final s = session;
    if (s == null || busy) return;
    running = true;
    error = null;
    notifyListeners();
    try {
      lastRun = await _api.practiceRun(s.practiceId, code, language.id);
    } on ApiException catch (e) {
      error = e.message;
    }
    running = false;
    notifyListeners();
  }

  Future<void> submit() async {
    final s = session;
    if (s == null || busy) return;
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final r = await _api.practiceSubmit(s.practiceId, code, language.id);
      lastSubmit = r;
      lastRun = r.run;
      Sfx.play(r.solved ? Cue.success : Cue.error);
      if (r.solved) {
        await loadStatsQuietly();
        await onProgress?.call();
      }
    } on ApiException catch (e) {
      error = e.message;
    }
    submitting = false;
    notifyListeners();
  }

  Future<void> loadStatsQuietly() async {
    try {
      stats = await _api.fetchPracticeStats();
    } on ApiException {
      // keep old stats
    }
  }

  Future<void> hint() async {
    final s = session;
    if (s == null || busy) return;
    hinting = true;
    error = null;
    notifyListeners();
    try {
      hints.add(await _api.practiceHint(s.practiceId, code, language.id));
    } on ApiException catch (e) {
      error = e.message;
    }
    hinting = false;
    notifyListeners();
  }
}
