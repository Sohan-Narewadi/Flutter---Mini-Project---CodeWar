import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/room_state.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../ui/segmented_tabs.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_bar.dart' show kPlayTab;

/// Online hub (a main tab): create a Race or Duel room, or join one with the
/// 6-character code a friend shared.
class PlayOnlineScreen extends StatefulWidget {
  const PlayOnlineScreen({super.key});

  @override
  State<PlayOnlineScreen> createState() => _PlayOnlineScreenState();
}

class _PlayOnlineScreenState extends State<PlayOnlineScreen> {
  String _mode = 'race';
  String _difficulty = 'easy';
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _go(Future<bool> Function(RoomState) action) async {
    final rooms = context.read<RoomState>();
    setState(() => _busy = true);
    final ok = await action(rooms);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.go('/room');
  }

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<RoomState>();
    final codeReady = _code.text.trim().length == 6;
    return AppShell(
      title: 'Play',
      navIndex: kPlayTab,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const PageHeader(title: 'Play Online', subtitle: 'Race your friends in real time. Same problem, first to solve wins.'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  accent: AppColors.accent,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CREATE A ROOM', style: AppTheme.overline(color: AppColors.accent)),
                      const SizedBox(height: 14),
                      SegmentedTabs<String>(
                        key: const Key('modeSelector'),
                        options: const {'race': 'Race · 2-8', 'duel': 'Duel · 1v1'},
                        value: _mode,
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mode == 'race'
                            ? 'Everyone solves the same problem. Ranked by who solves it first and how many tests pass.'
                            : 'A head-to-head match. The winner takes rating from the loser.',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      Text('DIFFICULTY', style: AppTheme.overline()),
                      const SizedBox(height: 8),
                      SegmentedTabs<String>(
                        options: const {'easy': 'Easy', 'medium': 'Medium', 'hard': 'Hard'},
                        value: _difficulty,
                        onChanged: (v) => setState(() => _difficulty = v),
                      ),
                      const SizedBox(height: 16),
                      Text('LANGUAGE', style: AppTheme.overline()),
                      const SizedBox(height: 8),
                      SegmentedTabs<Language>(
                        options: {for (final l in Language.values) l: l.label},
                        value: rooms.language,
                        onChanged: rooms.setLanguage,
                      ),
                      const SizedBox(height: 20),
                      NeonButton(
                        key: const Key('createRoomButton'),
                        label: 'Create room',
                        icon: Icons.add_rounded,
                        loading: _busy,
                        onPressed: _busy ? null : () => _go((r) => r.create(mode: _mode, difficulty: _difficulty)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JOIN WITH A CODE', style: AppTheme.overline()),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('roomCodeField'),
                        controller: _code,
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                          _UpperCaseFormatter(),
                        ],
                        style: AppTheme.display(fontSize: 28, letterSpacing: 8, color: AppColors.text),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'ABC123',
                          hintStyle: AppTheme.display(fontSize: 28, letterSpacing: 8, color: AppColors.textFaint.withValues(alpha: 0.5)),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onSubmitted: (_) => _busy || !codeReady ? null : _go((r) => r.join(_code.text)),
                      ),
                      const SizedBox(height: 14),
                      NeonButton(
                        key: const Key('joinRoomButton'),
                        label: 'Join room',
                        icon: Icons.login_rounded,
                        variant: NeonVariant.secondary,
                        onPressed: _busy ? null : () => _go((r) => r.join(_code.text)),
                      ),
                    ],
                  ),
                ),
                if (rooms.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(rooms.error!, key: const Key('onlineError'), style: const TextStyle(color: AppColors.danger, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Friends must reach the same server (${rooms.serverUrl}). Share the room code and, if needed, the server address from Settings.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textFaint, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
