import 'dart:convert';

import 'package:codewar/main.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _player = {
  'id': 1, 'username': 'ada', 'display_name': 'Ada', 'level': 1, 'xp': 0,
  'xp_to_next': 1000, 'hp': 100, 'hp_max': 100, 'gold': 0, 'streak': 0,
};

MockClient _server({bool taken = false}) => MockClient((req) async {
      final path = req.url.path;
      if (path == '/api/players') {
        if (taken) return http.Response('{"detail":"That name is taken."}', 409);
        return http.Response(jsonEncode({'player_id': 1, 'token': 'tok', 'player': _player}), 201);
      }
      if (path == '/api/player') return http.Response(jsonEncode(_player), 200);
      if (path == '/api/worlds') {
        return http.Response(
            jsonEncode([
              {'id': 'w2', 'name': 'Array Ruins', 'order': 2, 'description': 'd', 'cleared_percent': 0}
            ]),
            200);
      }
      return http.Response('[]', 200);
    });

void main() {
  testWidgets('without a token the app shows onboarding', (tester) async {
    await tester.pumpWidget(CodeWarApp(
      api: ApiService(settings: SettingsStore.memory(), client: _server()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nameField')), findsOneWidget);
  });

  testWidgets('name taken shows an error and stays on onboarding', (tester) async {
    final settings = SettingsStore.memory();
    await tester.pumpWidget(CodeWarApp(
      api: ApiService(settings: settings, client: _server(taken: true)),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Ada');
    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pumpAndSettle();
    expect(find.text('That name is taken.'), findsOneWidget);
    expect(settings.token, isNull);
  });

  testWidgets('registering stores the token and opens the world map', (tester) async {
    final settings = SettingsStore.memory();
    await tester.pumpWidget(CodeWarApp(
      api: ApiService(settings: settings, client: _server()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Ada');
    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pumpAndSettle();
    expect(settings.token, 'tok');
    expect(find.byKey(const Key('nameField')), findsNothing);
    expect(find.text('Sector Path'), findsWidgets);
  });
}
