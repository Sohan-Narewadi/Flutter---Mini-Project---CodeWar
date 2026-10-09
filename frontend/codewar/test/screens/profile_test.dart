import 'dart:convert';

import 'package:codewar/main.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _player = {
  'id': 1, 'username': 'ada', 'display_name': 'Ada', 'level': 3, 'xp': 10, 'xp_to_next': 1000,
  'hp': 90, 'hp_max': 100, 'gold': 25, 'streak': 2, 'best_streak': 6, 'rating': 1120, 'wins': 3, 'losses': 1, 'tier': 'silver',
};

Future<List<String>> _boot(WidgetTester tester, {List<Map<String, dynamic>> matches = const []}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final paths = <String>[];
  final client = MockClient((req) async {
    paths.add('${req.method} ${req.url.path}');
    http.Response json(Object o) => http.Response(jsonEncode(o), 200);
    switch (req.url.path) {
      case '/api/player':
        return json(_player);
      case '/api/worlds':
        return json([{'id': 'w2', 'name': 'Array Ruins', 'order': 2, 'description': 'd', 'cleared_percent': 0}]);
      case '/api/badges':
        return json([
          {'key': 'first_win', 'name': 'Victor', 'description': 'Win an online match.', 'icon': 'emoji_events', 'earned_at': '2026-10-01T10:00:00Z'},
          {'key': 'win_5', 'name': 'Contender', 'description': 'Win 5 online matches.', 'icon': 'workspace_premium', 'earned_at': null},
        ]);
      case '/api/matches':
        return json(matches);
      case '/api/practice/stats':
        return json({
          'streak': 2, 'solved_today': 0, 'total_solved': 12, 'daily_done': false, 'daily_resets_in': 3600,
          'topics': [{'id': 'math', 'label': 'Math', 'solved': 4, 'mastery_percent': 40}],
        });
    }
    return http.Response('[]', 200);
  });
  final settings = SettingsStore.memory()..token = 'tok';
  await tester.pumpWidget(CodeWarApp(api: ApiService(settings: settings, client: client)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profile').last);
  await tester.pumpAndSettle();
  return paths;
}

void main() {
  testWidgets('Profile shows tier, real stats and both earned and locked badges', (tester) async {
    final paths = await _boot(tester);
    expect(find.text('Ada'), findsWidgets);
    expect(find.text('SILVER'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget); // 3 wins of 4 games
    expect(find.text('1120'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // practice solved
    expect(find.text('6'), findsOneWidget); // best streak
    expect(find.byKey(const Key('badge_first_win')), findsOneWidget);
    expect(find.byKey(const Key('badge_win_5')), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(paths, containsAll(['GET /api/badges', 'GET /api/matches']));
  });

  testWidgets('Profile shows an honest empty state when there are no matches', (tester) async {
    await _boot(tester);
    expect(find.textContaining('No online matches yet'), findsOneWidget);
  });

  testWidgets('Profile lists real match history with rating change', (tester) async {
    await _boot(tester, matches: [
      {
        'room_code': 'ABC123', 'mode': 'duel', 'rank': 1, 'players_count': 2, 'best_pct': 100, 'rating_before': 1100,
        'rating_delta': 20, 'xp': 40, 'gold': 10, 'opponents': ['Bob'], 'finished_at': '2026-10-01T10:00:00Z',
      },
    ]);
    expect(find.text('Duel vs Bob'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('1st'), findsOneWidget);
    expect(find.textContaining('No online matches yet'), findsNothing);
  });

  testWidgets('Tapping a badge explains how to earn it', (tester) async {
    await _boot(tester);
    await tester.tap(find.byKey(const Key('badge_win_5')));
    await tester.pumpAndSettle();
    expect(find.text('Win 5 online matches.'), findsOneWidget);
    expect(find.text('NOT EARNED YET'), findsOneWidget);
  });

  testWidgets('Sign out asks for confirmation and returns to onboarding', (tester) async {
    await _boot(tester);
    await tester.ensureVisible(find.byKey(const Key('signOutButton')));
    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsNothing);

    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSignOut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nameField')), findsOneWidget);
  });
}
