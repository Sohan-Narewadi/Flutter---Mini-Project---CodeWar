import 'dart:convert';

import 'package:codewar/main.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _player = {
  'id': 1, 'username': 'ada', 'display_name': 'Ada', 'level': 2, 'xp': 10, 'xp_to_next': 1000,
  'hp': 40, 'hp_max': 100, 'gold': 5, 'streak': 0,
};

const _question = {
  'id': 'q1', 'title': 'Find Maximum', 'difficulty': 'Easy', 'tags': ['Arrays'],
  'prompt': 'Return the greatest integer.', 'example_input': 'nums = [1, 5]', 'example_output': '5',
  'starter_code': {'python': 'def find_maximum(nums):\n    pass\n', 'typescript': 'function f() {}\n'},
  'test_cases': [],
};

Map<String, dynamic> _submit(String outcome) => {
      'passed_tests': outcome == 'won' ? 3 : 1, 'total_tests': 3, 'correctness_percent': outcome == 'won' ? 100 : 33,
      'results': outcome == 'won'
          ? []
          : [
              {'input': 'nums = []', 'expected': '0', 'actual': 'None', 'passed': false, 'duration_ms': 3},
            ],
      'outcome': outcome, 'xp_earned': outcome == 'won' ? 80 : 0, 'gold_earned': outcome == 'won' ? 30 : 0,
      'hp_lost': outcome == 'won' ? 0 : 40, 'damage_dealt': outcome == 'won' ? 150 : 0,
      'enemy_hp_remaining': outcome == 'won' ? 0 : 450, 'enemy_hp_max': 450,
      'enemy_defeated': outcome == 'won', 'is_new_best': false, 'best_score_percent': 33,
    };

Future<List<String>> _boot(WidgetTester tester, String outcome) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final calls = <String>[];
  final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    http.Response json(Object o) => http.Response(jsonEncode(o), 200);
    switch (req.url.path) {
      case '/api/player':
        return json(_player);
      case '/api/worlds':
        return json([{'id': 'w2', 'name': 'Array Ruins', 'order': 2, 'description': 'd', 'cleared_percent': 0}]);
      case '/api/levels':
        return json([
          {'id': 3, 'world_id': 'w2', 'order': 1, 'title': 'Syntax Verification', 'difficulty': 'easy', 'status': 'current', 'stars': 0, 'enemy_id': 'e1', 'xp_reward': 80, 'gold_reward': 30},
        ]);
      case '/api/enemies':
        return json([
          {'id': 'e1', 'name': 'Syntax Snake', 'level': 4, 'difficulty': 'easy', 'hp_max': 450, 'hp_current': 450, 'vulnerability': 'Strings', 'tier': 'minion', 'locked': false, 'unlock_hint': '', 'xp_reward': 80, 'gold_reward': 30},
        ]);
      case '/api/battles/start':
        return json({'battle_id': 9, 'enemy_hp_remaining': 450, 'time_limit_s': 240, 'started_at': DateTime.now().toUtc().toIso8601String(), 'question': _question});
      case '/api/battles/9/submit':
        return json(_submit(outcome));
    }
    return http.Response('[]', 200);
  });
  final settings = SettingsStore.memory()..token = 'tok';
  await tester.pumpWidget(CodeWarApp(api: ApiService(settings: settings, client: client)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('continueButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('startBattle')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('battleSubmit')), findsOneWidget);
  await tester.tap(find.byKey(const Key('battleSubmit')));
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('Victory screen reports only what the server returned', (tester) async {
    await _boot(tester, 'won');
    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.text('+80'), findsOneWidget);
    expect(find.text('+30'), findsOneWidget);
    expect(find.textContaining('Sector 05'), findsNothing);
    expect(find.textContaining('Syntax Snake defeated'), findsOneWidget);
  });

  testWidgets('Defeat screen shows the real failing test and no invented content', (tester) async {
    final calls = await _boot(tester, 'lost');
    expect(find.text('DEFEAT'), findsOneWidget);
    expect(find.textContaining('nums = []'), findsOneWidget);
    expect(find.textContaining('None'), findsOneWidget);
    for (final fake in ['IndexError', 'Energy', '50 Coins', 'Pattern Flaw', '3 ticks', '+40 XP', 'Dazed']) {
      expect(find.textContaining(fake), findsNothing, reason: 'must not show invented text "$fake"');
    }
    // Trying again starts a brand new server battle.
    final startsBefore = calls.where((c) => c == 'POST /api/battles/start').length;
    await tester.tap(find.byKey(const Key('retryBattle')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'POST /api/battles/start').length, startsBefore + 1);
    expect(find.byKey(const Key('battleSubmit')), findsOneWidget);
  });
}
