import 'dart:convert';

import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _playerJson = {
  'id': 7, 'username': 'ada', 'display_name': 'Ada', 'level': 1, 'xp': 0,
  'xp_to_next': 1000, 'hp': 100, 'hp_max': 100, 'gold': 0, 'streak': 0,
  'rating': 1000, 'wins': 0, 'losses': 0,
};

void main() {
  test('sends bearer token and uses stored api url', () async {
    http.Request? seen;
    final settings = SettingsStore.memory()
      ..apiUrl = 'https://abc.trycloudflare.com/'
      ..token = 'tok123';
    final api = ApiService(
      settings: settings,
      client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode(_playerJson), 200);
      }),
    );
    final p = await api.fetchPlayer();
    expect(p.displayName, 'Ada');
    expect(seen!.url.toString(), 'https://abc.trycloudflare.com/api/player');
    expect(seen!.headers['Authorization'], 'Bearer tok123');
  });

  test('GET failure throws ApiException instead of fake seed data', () async {
    final api = ApiService(
      settings: SettingsStore.memory()..token = 't',
      client: MockClient((req) async => throw http.ClientException('down')),
    );
    expect(api.fetchPlayer(), throwsA(isA<ApiException>()));
  });

  test('401 is flagged as unauthorized', () async {
    final api = ApiService(
      settings: SettingsStore.memory()..token = 't',
      client: MockClient((req) async => http.Response('{"detail":"Missing or invalid token."}', 401)),
    );
    try {
      await api.fetchPlayer();
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.unauthorized, isTrue);
    }
  });

  test('createPlayer stores token and surfaces 409 message', () async {
    final settings = SettingsStore.memory();
    var calls = 0;
    final api = ApiService(
      settings: settings,
      client: MockClient((req) async {
        calls++;
        if (calls == 1) {
          return http.Response(jsonEncode({'player_id': 7, 'token': 'newtok', 'player': _playerJson}), 201);
        }
        return http.Response('{"detail":"That name is taken."}', 409);
      }),
    );
    await api.createPlayer('Ada');
    expect(settings.token, 'newtok');
    expect(() => api.createPlayer('Ada'), throwsA(predicate((e) => e is ApiException && e.message == 'That name is taken.')));
  });
}
