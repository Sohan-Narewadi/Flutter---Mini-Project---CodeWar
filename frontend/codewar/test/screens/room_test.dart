import 'dart:async';
import 'dart:convert';

import 'package:codewar/main.dart';
import 'package:codewar/providers/room_state.dart';
import 'package:codewar/services/api_service.dart';
import 'package:codewar/services/room_channel.dart';
import 'package:codewar/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _me = 7;

const _player = {
  'id': _me, 'username': 'ada', 'display_name': 'Ada', 'level': 3, 'xp': 10,
  'xp_to_next': 1000, 'hp': 100, 'hp_max': 100, 'gold': 0, 'streak': 0,
};

Map<String, dynamic> _p(int id, String name, {bool host = false, int pct = 0, bool forfeited = false, int subs = 0}) => {
      'player_id': id, 'name': name, 'connected': true, 'is_host': host, 'passed': 0, 'total': 0,
      'best_pct': pct, 'submissions': subs, 'forfeited': forfeited, 'rank': null,
    };

Map<String, dynamic> _room(String status, List<Map<String, dynamic>> players, {
  String mode = 'race', int? secondsLeft, double? countdown, bool preparing = false, List<Map<String, dynamic>>? standings, String? reason,
}) =>
    {
      'code': 'ABC234', 'mode': mode, 'difficulty': 'easy', 'language': 'python', 'status': status,
      'host_id': _me, 'max_players': mode == 'duel' ? 2 : 8, 'time_limit_s': 300,
      'seconds_left': secondsLeft, 'countdown_left': countdown, 'reason': reason, 'preparing': preparing,
      'players': players, 'standings': standings,
    };

const _question = {
  'id': 'g_1', 'title': 'Digit Sum Dash', 'difficulty': 'Easy', 'tags': ['Math'],
  'prompt': 'Return the sum of digits of n.', 'example_input': 'n = 123', 'example_output': '6',
  'starter_code': {'python': 'def digit_sum(n):\n    pass\n', 'typescript': 'function digitSum(n: any): any {}\n'},
  'test_cases': [],
};

class FakeChannel implements RoomChannel {
  FakeChannel(this.uri);
  final Uri uri;
  final _controller = StreamController<Map<String, dynamic>>();
  final sent = <Map<String, dynamic>>[];
  @override
  int? closeCode;
  bool closed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  void send(Map<String, dynamic> message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
  }

  void push(Map<String, dynamic> m) => _controller.add(m);
  void snapshot(Map<String, dynamic> room) => push({'type': 'snapshot', 'room': room});
  void dropWith(int? code) {
    closeCode = code;
    _controller.close();
  }
}

class Harness {
  final channels = <FakeChannel>[];
  FakeChannel get channel => channels.last;
  Map<String, dynamic> createResponse = _room('lobby', [_p(_me, 'Ada', host: true)]);
  int joinStatus = 200;
  final calls = <String>[];

  MockClient get client => MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        http.Response json(Object o, [int code = 200]) => http.Response(jsonEncode(o), code);
        switch (req.url.path) {
          case '/api/player':
            return json(_player);
          case '/api/worlds':
            return json([
              {'id': 'w2', 'name': 'Array Ruins', 'order': 2, 'description': 'd', 'cleared_percent': 0}
            ]);
          case '/api/rooms':
            return json(createResponse, 201);
          case '/api/rooms/ABC234/join':
            return joinStatus == 200 ? json(createResponse) : json({'detail': 'That room is full.'}, joinStatus);
        }
        return http.Response('[]', 200);
      });
}

Future<Harness> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final h = Harness();
  final settings = SettingsStore.memory()..token = 'tok';
  await tester.pumpWidget(CodeWarApp(
    api: ApiService(settings: settings, client: h.client),
    channelFactory: (uri) {
      final c = FakeChannel(uri);
      h.channels.add(c);
      return c;
    },
  ));
  await tester.pumpAndSettle();
  return h;
}

/// Stream events from the fake socket arrive a microtask after pump(), so a
/// second pump is needed for the UI to reflect them.
Future<void> pump2(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> openOnline(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('navPlay')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create a room opens the lobby with the code and the socket URL', (tester) async {
    final h = await boot(tester);
    await openOnline(tester);
    await tester.tap(find.byKey(const Key('createRoomButton')));
    await tester.pumpAndSettle();
    expect(h.channels, hasLength(1));
    expect(h.channel.uri.scheme, 'ws');
    expect(h.channel.uri.path, '/ws/rooms/ABC234');
    expect(h.channel.uri.queryParameters['token'], 'tok');
    h.channel.snapshot(_room('lobby', [_p(_me, 'Ada', host: true)]));
    await pump2(tester);
    expect(find.byKey(const Key('roomCode')), findsOneWidget);
    expect(find.text('ABC234'), findsWidgets);
    // host with one player cannot start yet
    final start = tester.widget<FilledButton>(find.byKey(const Key('startMatch')));
    expect(start.onPressed, isNull);
  });

  testWidgets('host starts once a friend joins and sees the countdown then the match', (tester) async {
    final h = await boot(tester);
    await openOnline(tester);
    await tester.tap(find.byKey(const Key('createRoomButton')));
    await tester.pumpAndSettle();
    h.channel.snapshot(_room('lobby', [_p(_me, 'Ada', host: true), _p(9, 'Bob')]));
    await pump2(tester);
    expect(find.byKey(const Key('lobbyPlayer_9')), findsOneWidget);

    await tester.tap(find.byKey(const Key('startMatch')));
    await pump2(tester);
    expect(h.channel.sent, contains(equals({'type': 'start'})));

    h.channel.snapshot(_room('countdown', [_p(_me, 'Ada', host: true), _p(9, 'Bob')], countdown: 2.4));
    await pump2(tester);
    expect(find.byKey(const Key('countdownNumber')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    h.channel.push({'type': 'question', 'question': _question});
    h.channel.snapshot(_room('running', [_p(_me, 'Ada', host: true), _p(9, 'Bob', pct: 50)], secondsLeft: 280));
    await pump2(tester);
    expect(find.text('Digit Sum Dash'), findsOneWidget);
    expect(find.byKey(const Key('bar_9')), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byKey(const Key('matchClock')), findsOneWidget);
  });

  testWidgets('submitting sends the code, shows the result, and finished shows rating changes', (tester) async {
    final h = await boot(tester);
    await openOnline(tester);
    await tester.tap(find.byKey(const Key('createRoomButton')));
    await tester.pumpAndSettle();
    h.channel.push({'type': 'question', 'question': _question});
    h.channel.snapshot(_room('running', [_p(_me, 'Ada', host: true), _p(9, 'Bob')], secondsLeft: 200));
    await pump2(tester);

    await tester.ensureVisible(find.byKey(const Key('roomSubmit')));
    await tester.tap(find.byKey(const Key('roomSubmit')));
    await pump2(tester);
    final submit = h.channel.sent.last;
    expect(submit['type'], 'submit');
    expect(submit['language'], 'python');
    expect(submit['code'], contains('def digit_sum'));

    h.channel.push({
      'type': 'run_result', 'kind': 'submit', 'passed_tests': 3, 'total_tests': 3, 'correctness_percent': 100, 'results': [],
    });
    await pump2(tester);
    expect(find.text('Submitted: 3/3 tests passed'), findsOneWidget);

    h.channel.snapshot(_room('finished', [_p(_me, 'Ada', host: true, pct: 100), _p(9, 'Bob')], reason: 'solved', standings: [
      {'player_id': _me, 'name': 'Ada', 'rank': 1, 'best_pct': 100, 'passed': 3, 'total': 3, 'forfeited': false, 'time_s': 42.5,
       'rating_delta': 16, 'xp': 30, 'gold': 7, 'rating': 1016},
      {'player_id': 9, 'name': 'Bob', 'rank': 2, 'best_pct': 0, 'passed': 0, 'total': 0, 'forfeited': false, 'time_s': null,
       'rating_delta': -16, 'xp': 0, 'gold': 0, 'rating': 984},
    ]));
    await pump2(tester);
    expect(find.byKey(const Key('resultTitle')), findsOneWidget);
    expect(find.text('Victory!'), findsOneWidget);
    expect(find.text('+16 RP'), findsOneWidget);
    expect(find.text('-16 RP'), findsOneWidget);
  });

  testWidgets('duel shows HP bars derived from the opponent best score', (tester) async {
    final h = await boot(tester);
    h.createResponse = _room('lobby', [_p(_me, 'Ada', host: true)], mode: 'duel');
    await openOnline(tester);
    await tester.tap(find.byKey(const Key('createRoomButton')));
    await tester.pumpAndSettle();
    h.channel.push({'type': 'question', 'question': _question});
    h.channel.snapshot(_room('running', [_p(_me, 'Ada', host: true, pct: 25), _p(9, 'Bob', pct: 60)], mode: 'duel', secondsLeft: 100));
    await pump2(tester);
    expect(find.text('40 HP'), findsOneWidget); // me: 100 - Bob 60
    expect(find.text('75 HP'), findsOneWidget); // Bob: 100 - my 25
  });

  testWidgets('joining a full room shows the server message and stays on the join screen', (tester) async {
    final h = await boot(tester);
    h.joinStatus = 409;
    await openOnline(tester);
    await tester.enterText(find.byKey(const Key('roomCodeField')), 'abc234');
    await tester.tap(find.byKey(const Key('joinRoomButton')));
    await tester.pumpAndSettle();
    expect(find.text('That room is full.'), findsOneWidget);
    expect(h.channels, isEmpty);
  });

  testWidgets('a short code is rejected before any request', (tester) async {
    final h = await boot(tester);
    await openOnline(tester);
    await tester.enterText(find.byKey(const Key('roomCodeField')), 'AB');
    await tester.tap(find.byKey(const Key('joinRoomButton')));
    await tester.pumpAndSettle();
    expect(find.text('Room codes have 6 characters.'), findsOneWidget);
    expect(h.calls.where((c) => c.contains('/join')), isEmpty);
  });

  test('RoomState reconnects after an unexpected drop and stops on terminal codes', () async {
    final channels = <FakeChannel>[];
    final settings = SettingsStore.memory()..token = 'tok';
    final api = ApiService(
      settings: settings,
      client: MockClient((req) async => http.Response(jsonEncode(_room('running', [_p(_me, 'Ada', host: true)], secondsLeft: 100)), 201)),
    );
    final rooms = RoomState(api, channelFactory: (u) {
      final c = FakeChannel(u);
      channels.add(c);
      return c;
    }, backoff: const [Duration(milliseconds: 10), Duration(milliseconds: 10)]);

    expect(await rooms.create(), isTrue);
    channels.last.snapshot(_room('running', [_p(_me, 'Ada', host: true)], secondsLeft: 100));
    await Future<void>.delayed(Duration.zero);
    expect(rooms.connection, RoomConnection.connected);

    channels.last.dropWith(1006); // network blip
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(channels, hasLength(2)); // reconnected
    expect(rooms.connection, RoomConnection.reconnecting);

    channels.last.snapshot(_room('running', [_p(_me, 'Ada', host: true)], secondsLeft: 90));
    await Future<void>.delayed(Duration.zero);
    expect(rooms.connection, RoomConnection.connected);

    channels.last.dropWith(4404); // room gone: do not retry
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(channels, hasLength(2));
    expect(rooms.connection, RoomConnection.closed);
    expect(rooms.error, 'That room no longer exists.');
    rooms.dispose();
  });
}
