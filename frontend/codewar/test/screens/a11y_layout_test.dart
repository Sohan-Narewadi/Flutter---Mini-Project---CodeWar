import 'dart:convert';

import 'package:codewar/main.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Every main tab must lay out without overflow on a small phone (360 wide)
/// with the system font scaled to 130%, using long names and big numbers.
MockClient _server() => MockClient((req) async {
      http.Response json(Object o) => http.Response(jsonEncode(o), 200);
      Map<String, dynamic> entry(int rank, String name, {bool me = false}) => {
            'rank': rank, 'player_id': rank, 'name': name, 'level': 42, 'rating': 1720, 'value': 987654, 'is_me': me, 'tier': 'diamond',
          };
      switch (req.url.path) {
        case '/api/player':
          return json({
            'id': 2, 'username': 'averyverylongname', 'display_name': 'AVeryVeryLongName', 'level': 42, 'xp': 99999, 'xp_to_next': 123456,
            'hp': 100, 'hp_max': 100, 'gold': 987654, 'streak': 365, 'best_streak': 365, 'rating': 1720, 'wins': 250, 'losses': 120, 'tier': 'diamond',
          });
        case '/api/worlds':
          return json([{'id': 'w2', 'name': 'Array Ruins', 'order': 2, 'description': 'd', 'cleared_percent': 50}]);
        case '/api/levels':
          return json([
            {'id': 3, 'world_id': 'w2', 'order': 1, 'title': 'A Level With A Fairly Long Descriptive Title', 'difficulty': 'hard', 'status': 'current', 'stars': 0, 'enemy_id': 'e1', 'xp_reward': 8000, 'gold_reward': 3000},
          ]);
        case '/api/enemies':
          return json([
            {'id': 'e1', 'name': 'Recursive Leviathan Of Doom', 'level': 99, 'difficulty': 'boss', 'hp_max': 50000, 'hp_current': 50000, 'vulnerability': 'Dynamic Programming / Graphs', 'tier': 'boss', 'locked': false, 'unlock_hint': '', 'xp_reward': 8000, 'gold_reward': 3000},
          ]);
        case '/api/leaderboard':
          return json({
            'scope': 'global', 'metric': 'xp',
            'entries': [for (var i = 1; i <= 6; i++) entry(i, 'LongPlayerName$i', me: i == 2)],
            'me': entry(2, 'LongPlayerName2', me: true),
          });
        case '/api/practice/stats':
          return json({
            'streak': 365, 'solved_today': 120, 'total_solved': 12345, 'daily_done': false, 'daily_resets_in': 86399,
            'topics': [
              for (final t in ['Arrays', 'Strings', 'Math', 'Hash Maps', 'Two Pointers', 'Dynamic Programming'])
                {'id': t.toLowerCase(), 'label': t, 'solved': 999, 'mastery_percent': 100},
            ],
          });
        case '/api/badges':
          return json([
            for (var i = 0; i < 17; i++)
              {'key': 'b$i', 'name': 'A Longer Badge Name $i', 'description': 'd', 'icon': 'flag', 'earned_at': i.isEven ? '2026-10-01T10:00:00Z' : null},
          ]);
        case '/api/matches':
          return json([
            {'room_code': 'ABC123', 'mode': 'race', 'rank': 3, 'players_count': 8, 'best_pct': 100, 'rating_before': 1700, 'rating_delta': -24,
             'xp': 400, 'gold': 100, 'opponents': ['LongPlayerName1', 'LongPlayerName3', 'LongPlayerName4'], 'finished_at': '2026-10-01T10:00:00Z'},
          ]);
      }
      return http.Response('[]', 200);
    });

void main() {
  for (final tab in ['Home', 'Practice', 'Rank', 'Profile']) {
    testWidgets('$tab tab has no overflow at 360px wide with 130% text', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      final settings = SettingsStore.memory()..token = 'tok';
      await tester.pumpWidget(CodeWarApp(api: ApiService(settings: settings, client: _server())));
      await tester.pumpAndSettle();
      if (tab != 'Home') {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      // Scroll through the whole page so lazily built rows are laid out too.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Play tab has no overflow at 360px wide with 130% text', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final settings = SettingsStore.memory()..token = 'tok';
    await tester.pumpWidget(CodeWarApp(api: ApiService(settings: settings, client: _server())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navPlay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
