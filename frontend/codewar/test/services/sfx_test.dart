import 'package:codewar/main.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:codewar/services/sfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakePlayer implements CuePlayer {
  final played = <String>[];
  @override
  Future<void> play(String asset) async => played.add(asset);
}

void main() {
  late _FakePlayer fake;

  setUp(() {
    fake = _FakePlayer();
    Sfx.player = fake;
    Sfx.soundOn = true;
    Sfx.hapticsOn = false; // no platform channel in unit tests
  });

  tearDown(() {
    Sfx.player = const SilentCuePlayer();
    Sfx.soundOn = true;
    Sfx.hapticsOn = true;
  });

  test('plays the asset for a cue when sound is on', () {
    Sfx.play(Cue.win);
    expect(fake.played, ['sfx/win.wav']);
  });

  test('is silent when sound is off', () {
    Sfx.soundOn = false;
    Sfx.play(Cue.win);
    expect(fake.played, isEmpty);
  });

  test('every cue maps to a bundled asset', () {
    for (final c in Cue.values) {
      Sfx.play(c);
    }
    expect(fake.played.length, Cue.values.length);
    expect(fake.played.toSet().length, Cue.values.length);
  });

  test('settings persist sound and haptics flags (default on)', () {
    final s = SettingsStore.memory();
    expect(s.soundOn, isTrue);
    expect(s.hapticsOn, isTrue);
    s.soundOn = false;
    s.hapticsOn = false;
    expect(s.soundOn, isFalse);
    expect(s.hapticsOn, isFalse);
  });

  testWidgets('settings switches change and store the flags', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = SettingsStore.memory()..token = 'tok';
    final client = MockClient((req) async => http.Response(
        req.url.path == '/api/player'
            ? '{"id":1,"username":"ada","display_name":"Ada","level":1,"xp":0,"xp_to_next":1000,"hp":100,"hp_max":100,"gold":0,"streak":0}'
            : '[]',
        200));
    await tester.pumpWidget(CodeWarApp(api: ApiService(settings: settings, client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings & server'));
    await tester.tap(find.text('Settings & server'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('soundSwitch')));
    await tester.pumpAndSettle();
    expect(settings.soundOn, isFalse);
    expect(Sfx.soundOn, isFalse);
    await tester.tap(find.byKey(const Key('hapticsSwitch')));
    await tester.pumpAndSettle();
    expect(settings.hapticsOn, isFalse);
    expect(Sfx.hapticsOn, isFalse);
  });
}
