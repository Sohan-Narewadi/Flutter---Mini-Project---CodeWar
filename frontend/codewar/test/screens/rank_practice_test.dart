import 'dart:convert';

import 'package:codewar/main.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _player = {
  'id': 1, 'username': 'ada', 'display_name': 'Ada', 'level': 3, 'xp': 10,
  'xp_to_next': 1000, 'hp': 100, 'hp_max': 100, 'gold': 0, 'streak': 2,
};

Map<String, dynamic> _entry(int rank, String name, int value, {bool me = false}) => {
      'rank': rank, 'player_id': rank, 'name': name, 'level': 5, 'rating': 1000, 'value': value, 'is_me': me,
    };

const _question = {
  'id': 'g_1', 'title': 'Digit Sum Dash', 'difficulty': 'Easy', 'tags': ['Math'],
  'prompt': 'Return the sum of digits of n.', 'example_input': 'n = 123', 'example_output': '6',
  'starter_code': {'python': 'def digit_sum(n):\n    pass\n', 'typescript': 'function digitSum(n: any): any {}\n'},
  'test_cases': [], 'topic': 'math', 'source': 'template',
};

class _Calls {
  final paths = <String>[];
}

MockClient _server(_Calls calls, {bool solve = true}) => MockClient((req) async {
      final path = req.url.path;
      calls.paths.add('${req.method} $path${req.url.hasQuery ? '?${req.url.query}' : ''}');
      http.Response json(Object o, [int code = 200]) => http.Response(jsonEncode(o), code);
      switch (path) {
        case '/api/player':
          return json(_player);
        case '/api/worlds':
          return json([
            {'id': 'w2', 'name': 'Array Ruins', 'order': 2, 'description': 'd', 'cleared_percent': 0}
          ]);
        case '/api/leaderboard':
          return json({
            'scope': req.url.queryParameters['scope'],
            'metric': 'xp',
            'entries': [_entry(1, 'ByteReaper', 900), _entry(2, 'Ada', 500, me: true)],
            'me': _entry(2, 'Ada', 500, me: true),
          });
        case '/api/practice/stats':
          return json({
            'streak': 3,
            'solved_today': 1,
            'topics': [
              {'id': 'math', 'label': 'Math', 'solved': 2, 'mastery_percent': 40},
              {'id': 'arrays', 'label': 'Arrays', 'solved': 0, 'mastery_percent': 0},
            ],
          });
        case '/api/practice/next':
          return json({'practice_id': 5, 'daily': false, 'question': _question});
        case '/api/practice/5/hint':
          return json({'level': 1, 'hint': 'Try looping over the digits.'});
        case '/api/practice/5/submit':
          return json({
            'passed_tests': solve ? 3 : 1, 'total_tests': 3, 'results': [], 'correctness_percent': solve ? 100 : 33,
            'solved': solve, 'xp_earned': solve ? 20 : 0, 'gold_earned': solve ? 5 : 0, 'streak': 4, 'hints_used': 0,
          });
      }
      return http.Response('[]', 200);
    });

Future<_Calls> _boot(WidgetTester tester, {bool solve = true}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  final settings = SettingsStore.memory()..token = 'tok';
  await tester.pumpWidget(CodeWarApp(api: ApiService(settings: settings, client: _server(calls, solve: solve))));
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('Rank screen shows live leaderboard rows and marks the player', (tester) async {
    final calls = await _boot(tester);
    await tester.tap(find.text('Rank').last);
    await tester.pumpAndSettle();
    expect(find.text('ByteReaper'), findsOneWidget);
    expect(find.text('Ada (You)'), findsOneWidget);
    expect(find.text('900 XP'), findsOneWidget);
    expect(calls.paths.any((p) => p.startsWith('GET /api/leaderboard?scope=global')), isTrue);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(calls.paths.any((p) => p.contains('scope=weekly')), isTrue);
  });

  testWidgets('Practice hub shows streak and topics, and starting a topic opens the problem', (tester) async {
    final calls = await _boot(tester);
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsWidgets); // streak
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Mastery 40%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('topic_math')));
    await tester.pumpAndSettle();
    expect(find.text('Digit Sum Dash'), findsOneWidget);
    expect(calls.paths, contains('POST /api/practice/next'));

    await tester.tap(find.byKey(const Key('hintButton')));
    await tester.pumpAndSettle();
    expect(find.text('Try looping over the digits.'), findsOneWidget);
  });

  testWidgets('Submitting a correct solution shows the solved card with XP', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('randomPractice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('submitButton')));
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('solvedCard')), findsOneWidget);
    expect(find.textContaining('+20 XP'), findsOneWidget);
  });

  testWidgets('A wrong submission does not show the solved card', (tester) async {
    await _boot(tester, solve: false);
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('randomPractice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('submitButton')));
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('solvedCard')), findsNothing);
    expect(find.byKey(const Key('testSummary')), findsOneWidget);
  });
}
