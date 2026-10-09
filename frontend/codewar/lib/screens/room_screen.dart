import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../models/room.dart';
import '../providers/game_state.dart';
import '../providers/room_state.dart';
import '../services/sfx.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/avatar.dart';
import '../ui/neon_button.dart';
import '../ui/segmented_tabs.dart';
import '../utils/theme.dart';
import '../widgets/code_editor_panel.dart';
import '../widgets/test_case_tile.dart';

/// One screen for the whole life of a room: lobby, countdown, live match and
/// results. It switches on the room status the server reports.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Timer? _ticker;
  String? _lastStatus;
  int? _lastCount;

  @override
  void initState() {
    super.initState();
    // Re-render a few times a second so the countdown and timer move
    // smoothly between server snapshots.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Fires each sound cue once, when the status or countdown number changes.
  void _cues(RoomState rooms, RoomSnapshot room, int myId) {
    if (room.status == 'countdown') {
      final n = rooms.countdownNumber;
      if (_lastCount != n) {
        _lastCount = n;
        Sfx.play(n > 0 ? Cue.countdown : Cue.go);
      }
    }
    if (_lastStatus != room.status) {
      final first = _lastStatus == null;
      _lastStatus = room.status;
      if (room.status == 'finished' && !first) {
        final standings = room.standings ?? const <Standing>[];
        final mine = standings.where((s) => s.playerId == myId).firstOrNull;
        final won =
            mine != null &&
            mine.rank == 1 &&
            standings.where((s) => s.rank == 1).length < standings.length;
        Sfx.play(won ? Cue.win : Cue.lose);
      }
    }
  }

  Future<void> _leave({bool confirm = false}) async {
    final rooms = context.read<RoomState>();
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Leave this match?'),
          content: const Text(
            'You will forfeit if the match is running.',
            style: TextStyle(color: AppColors.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await rooms.leave();
    if (mounted) context.go('/online');
  }

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<RoomState>();
    final room = rooms.room;
    if (room == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/online');
      });
      return const AppScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final myId = int.tryParse(context.read<GameState>().player.id) ?? -1;
    _cues(rooms, room, myId);

    final Widget body;
    switch (room.status) {
      case 'lobby':
        body = _Lobby(room: room, rooms: rooms, myId: myId);
      case 'countdown':
        body = _Countdown(rooms: rooms);
      case 'running':
        body = _Match(room: room, rooms: rooms, myId: myId);
      default:
        body = _Results(
          room: room,
          rooms: rooms,
          myId: myId,
          onDone: () => _leave(),
        );
    }

    return AppScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, AppSpace.page, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('leaveRoom'),
                  tooltip: 'Leave room',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _leave(confirm: room.status == 'running'),
                ),
                Text('ROOM ', style: AppTheme.overline()),
                Text(
                  room.code,
                  style: AppTheme.display(fontSize: 18, letterSpacing: 3),
                ),
                const Spacer(),
                if (rooms.connection == RoomConnection.reconnecting)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reconnecting...',
                        style: AppTheme.overline(color: AppColors.gold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (rooms.connection == RoomConnection.closed &&
              room.status != 'finished')
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                8,
                AppSpace.page,
                0,
              ),
              child: AppCard(
                accent: AppColors.danger,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rooms.error ?? 'Disconnected from the room.',
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _leave(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

String _modeLabel(RoomSnapshot r) => r.isDuel ? 'Duel' : 'Race';

// ---------------------------------------------------------------- lobby

class _Lobby extends StatelessWidget {
  const _Lobby({required this.room, required this.rooms, required this.myId});
  final RoomSnapshot room;
  final RoomState rooms;
  final int myId;

  Future<void> _copy(BuildContext context, String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toast)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = room.hostId == myId;
    final canStart = isHost && room.players.length >= 2 && !room.preparing;
    final server = rooms.serverUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 24),
      children: [
        AppCard(
          accent: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            children: [
              Text(
                '${_modeLabel(room).toUpperCase()}  ·  ${room.difficulty.toUpperCase()}',
                style: AppTheme.overline(color: AppColors.accent),
              ),
              const SizedBox(height: 10),
              SelectableText(
                room.code,
                key: const Key('roomCode'),
                style: AppTheme.display(
                  fontSize: 52,
                  letterSpacing: 8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Share this code with your friends',
                style: TextStyle(color: AppColors.textDim, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      label: 'Copy code',
                      icon: Icons.copy_rounded,
                      variant: NeonVariant.secondary,
                      compact: true,
                      onPressed: () =>
                          _copy(context, room.code, 'Room code copied'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeonButton(
                      key: const Key('shareInvite'),
                      label: 'Copy invite',
                      icon: Icons.share_rounded,
                      compact: true,
                      onPressed: () => _copy(
                        context,
                        'Join my CodeWar room ${room.code}. Server: $server',
                        'Invite copied',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.public_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Friends join at $server',
                  style: AppTheme.mono(
                    fontSize: 11.5,
                    color: AppColors.textDim,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy server address',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () =>
                    _copy(context, server, 'Server address copied'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle(
          'Players',
          trailing: Text(
            '${room.players.length}/${room.maxPlayers}',
            style: AppTheme.mono(fontSize: 12, color: AppColors.textDim),
          ),
        ),
        for (final p in room.players)
          Padding(
            key: Key('lobbyPlayer_${p.playerId}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              accent: p.playerId == myId ? AppColors.accent : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  PlayerAvatar(name: p.name, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.display(fontSize: 16),
                          ),
                        ),
                        if (p.playerId == myId) ...[
                          const SizedBox(width: 6),
                          Text(
                            'YOU',
                            style: AppTheme.overline(color: AppColors.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (p.isHost)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Tooltip(
                        message: 'Host',
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.gold,
                          size: 22,
                        ),
                      ),
                    ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.connected
                          ? AppColors.success
                          : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (rooms.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              rooms.error!,
              key: const Key('roomError'),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        if (isHost)
          NeonButton(
            key: const Key('startMatch'),
            label: room.preparing
                ? 'Preparing a fresh problem...'
                : (room.players.length < 2
                      ? 'Waiting for a second player...'
                      : 'Start match'),
            icon: canStart ? Icons.play_arrow_rounded : null,
            loading: room.preparing,
            onPressed: canStart ? rooms.start : null,
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Waiting for the host to start...',
                style: TextStyle(color: AppColors.textDim),
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ countdown

class _Countdown extends StatelessWidget {
  const _Countdown({required this.rooms});
  final RoomState rooms;

  @override
  Widget build(BuildContext context) {
    final n = rooms.countdownNumber;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GET READY',
            style: AppTheme.overline(
              color: AppColors.textDim,
            ).copyWith(fontSize: 14, letterSpacing: 6),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            key: ValueKey(n),
            tween: Tween(begin: 1.6, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              n > 0 ? '$n' : 'GO!',
              key: const Key('countdownNumber'),
              style:
                  AppTheme.display(
                    fontSize: 120,
                    color: n > 0 ? AppColors.accent : AppColors.success,
                  ).copyWith(
                    shadows: [
                      Shadow(
                        color: (n > 0 ? AppColors.accent : AppColors.success)
                            .withValues(alpha: 0.7),
                        blurRadius: 40,
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- match

class _Match extends StatelessWidget {
  const _Match({required this.room, required this.rooms, required this.myId});
  final RoomSnapshot room;
  final RoomState rooms;
  final int myId;

  String _clock(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final q = rooms.question;
    final me = room.playerById(myId);
    final forfeited = me?.forfeited ?? false;
    final secs = rooms.secondsLeft;
    final low = secs < 30;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              8,
              AppSpace.page,
              20,
            ),
            children: [
              Row(
                children: [
                  Text(
                    _modeLabel(room).toUpperCase(),
                    style: AppTheme.overline(color: AppColors.accent),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (low ? AppColors.danger : AppColors.gold)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: (low ? AppColors.danger : AppColors.gold)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          size: 16,
                          color: low ? AppColors.danger : AppColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _clock(secs),
                          key: const Key('matchClock'),
                          style: AppTheme.display(
                            fontSize: 16,
                            color: low ? AppColors.danger : AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              room.isDuel
                  ? _DuelBars(room: room, myId: myId)
                  : _RaceBars(room: room, myId: myId),
              const SizedBox(height: 18),
              if (q == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Text(
                  q.title,
                  style: AppTheme.display(fontSize: 24, height: 1.1),
                ),
                const SizedBox(height: 10),
                Text(
                  q.prompt,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input   ${q.exampleInput}',
                        style: AppTheme.mono(
                          fontSize: 12.5,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Output  ${q.exampleOutput}',
                        style: AppTheme.mono(
                          fontSize: 12.5,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedTabs<Language>(
                  height: 40,
                  options: {for (final l in Language.values) l: l.label},
                  value: rooms.language,
                  onChanged: rooms.setLanguage,
                ),
                const SizedBox(height: 12),
                CodeEditorPanel(
                  key: ValueKey('${q.id}_${rooms.language.id}'),
                  filename: 'solution.${rooms.language.ext}',
                  initialCode: rooms.code,
                  onChanged: rooms.updateCode,
                ),
                if (rooms.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      rooms.error!,
                      key: const Key('roomError'),
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (rooms.lastRun != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${rooms.lastRunKind == 'submit' ? 'Submitted' : 'Preview'}: ${rooms.lastRun!.passedTests}/${rooms.lastRun!.totalTests} tests passed',
                    key: const Key('roomRunSummary'),
                    style: AppTheme.display(
                      fontSize: 14,
                      color:
                          rooms.lastRun!.passedTests ==
                              rooms.lastRun!.totalTests
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < rooms.lastRun!.results.length; i++)
                    TestCaseTile(index: i, result: rooms.lastRun!.results[i]),
                ],
              ],
            ],
          ),
        ),
        if (q != null)
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              12,
              AppSpace.page,
              12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLow,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: forfeited
                  ? const Center(
                      child: Text(
                        'You left this match.',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            key: const Key('roomRun'),
                            label: 'Run',
                            icon: Icons.play_arrow_rounded,
                            variant: NeonVariant.secondary,
                            onPressed: rooms.judging ? null : rooms.run,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: NeonButton(
                            key: const Key('roomSubmit'),
                            label: 'Submit',
                            icon: Icons.bolt_rounded,
                            loading: rooms.judging,
                            onPressed: rooms.judging ? null : rooms.submit,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

class _RaceBars extends StatelessWidget {
  const _RaceBars({required this.room, required this.myId});
  final RoomSnapshot room;
  final int myId;

  @override
  Widget build(BuildContext context) {
    final players = [...room.players]
      ..sort((a, b) => b.bestPct.compareTo(a.bestPct));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        children: [
          for (final p in players)
            Padding(
              key: Key('bar_${p.playerId}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  PlayerAvatar(name: p.name, size: 28),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 84,
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: p.playerId == myId
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: p.forfeited
                            ? AppColors.textFaint
                            : AppColors.text,
                        decoration: p.forfeited
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: p.bestPct / 100),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          backgroundColor: AppColors.line,
                          color: p.playerId == myId
                              ? AppColors.accent
                              : AppColors.accentDeep,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${p.bestPct}%',
                      textAlign: TextAlign.right,
                      style: AppTheme.mono(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DuelBars extends StatelessWidget {
  const _DuelBars({required this.room, required this.myId});
  final RoomSnapshot room;
  final int myId;

  @override
  Widget build(BuildContext context) {
    final me = room.playerById(myId);
    final foe = room.players.where((p) => p.playerId != myId).firstOrNull;
    // Your best score drains the opponent's HP, and theirs drains yours.
    final myHp = 100 - (foe?.bestPct ?? 0);
    final foeHp = 100 - (me?.bestPct ?? 0);

    Widget bar(String name, int hp, Color color, {required Key key}) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(fontSize: 15),
              ),
            ),
            Text(
              '$hp HP',
              style: AppTheme.mono(fontSize: 12, color: AppColors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: hp / 100),
            duration: const Duration(milliseconds: 600),
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 14,
              backgroundColor: AppColors.line,
              color: color,
            ),
          ),
        ),
      ],
    );

    return AppCard(
      child: Column(
        children: [
          bar(
            foe?.name ?? 'Opponent',
            foeHp,
            AppColors.danger,
            key: const Key('foeHp'),
          ),
          const SizedBox(height: 14),
          bar(
            me?.name ?? 'You',
            myHp,
            AppColors.accent,
            key: const Key('myHp'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Passing more tests drains your opponent\'s HP.',
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- results

class _Results extends StatefulWidget {
  const _Results({
    required this.room,
    required this.rooms,
    required this.myId,
    required this.onDone,
  });
  final RoomSnapshot room;
  final RoomState rooms;
  final int myId;
  final VoidCallback onDone;

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  bool _rematching = false;

  Future<void> _rematch() async {
    final room = widget.room;
    final rooms = widget.rooms;
    setState(() => _rematching = true);
    final mode = room.isDuel ? 'duel' : 'race';
    final difficulty = room.difficulty;
    // The old room is finished, so there is nothing to forfeit: creating the
    // new room tears the old socket down and this screen simply shows the
    // new lobby (calling leave() first would bounce us to /online).
    final ok = await rooms.create(mode: mode, difficulty: difficulty);
    if (!mounted) return;
    setState(() => _rematching = false);
    if (!ok) {
      context.go('/online');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New room created. Share its code so your opponent can join.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final myId = widget.myId;
    final standings = room.standings ?? const <Standing>[];
    Standing? mine;
    for (final s in standings) {
      if (s.playerId == myId) mine = s;
    }
    final won =
        mine != null &&
        mine.rank == 1 &&
        standings.where((s) => s.rank == 1).length < standings.length;
    final title = standings.isEmpty
        ? 'Match over'
        : (won ? 'Victory!' : (mine?.rank == 1 ? 'Draw' : 'Match over'));
    final color = won ? AppColors.gold : AppColors.accent;
    final why = switch (room.reason) {
      'solved' => 'A perfect solution ended the match.',
      'timeout' => "Time's up.",
      'forfeit' => 'The opponent left the match.',
      _ => '',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 24),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 34),
              ],
            ),
            child: Icon(
              won ? Icons.emoji_events_rounded : Icons.flag_rounded,
              size: 46,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          key: const Key('resultTitle'),
          textAlign: TextAlign.center,
          style: AppTheme.display(fontSize: 34, color: color),
        ),
        if (why.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              why,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim),
            ),
          ),
        const SizedBox(height: 22),
        for (final s in standings)
          Padding(
            key: Key('standing_${s.playerId}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              accent: s.playerId == myId ? AppColors.accent : null,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: s.rank == 1
                        ? const Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.gold,
                          )
                        : Text(
                            '#${s.rank}',
                            style: AppTheme.display(
                              fontSize: 18,
                              color: AppColors.textFaint,
                            ),
                          ),
                  ),
                  PlayerAvatar(name: s.name, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.display(fontSize: 16),
                              ),
                            ),
                            if (s.playerId == myId) ...[
                              const SizedBox(width: 6),
                              Text(
                                'YOU',
                                style: AppTheme.overline(
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          s.forfeited
                              ? 'Left the match'
                              : '${s.bestPct}% passed${s.timeS != null ? ' in ${s.timeS}s' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.hasRewards)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${s.ratingDelta! >= 0 ? '+' : ''}${s.ratingDelta} RP',
                          key: Key('delta_${s.playerId}'),
                          style: AppTheme.display(
                            fontSize: 16,
                            color: s.ratingDelta! >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                        if ((s.xp ?? 0) > 0)
                          Text(
                            '+${s.xp} XP',
                            style: AppTheme.mono(
                              fontSize: 11,
                              color: AppColors.gold,
                            ),
                          ),
                      ],
                    )
                  else
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        NeonButton(
          key: const Key('rematch'),
          label: 'New room, same settings',
          icon: Icons.replay_rounded,
          loading: _rematching,
          onPressed: _rematching ? null : _rematch,
        ),
        const SizedBox(height: 10),
        NeonButton(
          key: const Key('backToOnline'),
          label: 'Back to lobby',
          variant: NeonVariant.secondary,
          onPressed: widget.onDone,
        ),
        const SizedBox(height: 10),
        NeonButton(
          label: 'Home',
          variant: NeonVariant.ghost,
          onPressed: () async {
            await widget.rooms.leave();
            if (context.mounted) context.go('/home');
          },
        ),
      ],
    );
  }
}
