import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/room_state.dart';
import '../utils/theme.dart';

/// Entry point for online play: create a room (Race or Duel) or join one
/// with a 6-character code a friend shared.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Online'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Create a room',
            icon: Icons.add_circle_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mode', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  key: const Key('modeSelector'),
                  segments: const [
                    ButtonSegment(value: 'race', label: Text('Race (2-8)'), icon: Icon(Icons.flag)),
                    ButtonSegment(value: 'duel', label: Text('Duel (1v1)'), icon: Icon(Icons.sports_mma)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 14),
                const Text('Difficulty', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'easy', label: Text('Easy')),
                    ButtonSegment(value: 'medium', label: Text('Medium')),
                    ButtonSegment(value: 'hard', label: Text('Hard')),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (s) => setState(() => _difficulty = s.first),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in Language.values)
                      ChoiceChip(
                        label: Text(l.label),
                        selected: rooms.language == l,
                        onSelected: (_) => rooms.setLanguage(l),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('createRoomButton'),
                    onPressed: _busy ? null : () => _go((r) => r.create(mode: _mode, difficulty: _difficulty)),
                    child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create room'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Join with a code',
            icon: Icons.login,
            child: Column(
              children: [
                TextField(
                  key: const Key('roomCodeField'),
                  controller: _code,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))],
                  style: AppTheme.mono(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
                  onSubmitted: (_) => _busy ? null : _go((r) => r.join(_code.text)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    key: const Key('joinRoomButton'),
                    onPressed: _busy ? null : () => _go((r) => r.join(_code.text)),
                    child: const Text('Join room'),
                  ),
                ),
              ],
            ),
          ),
          if (rooms.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(rooms.error!, key: const Key('onlineError'), style: const TextStyle(color: AppColors.error)),
            ),
          const SizedBox(height: 16),
          const Text(
            'Friends must be able to reach the same server address (see Settings). Share the room code and the server URL with them.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
