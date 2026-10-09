import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/leaderboard.dart';
import '../providers/game_state.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';

/// Rank: the live leaderboard from the server (global, weekly, friends), by
/// XP or by online rating. Nothing here is hardcoded.
class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  String _scope = 'global';
  String _metric = 'xp';
  Leaderboard? _board;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<GameState>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await api.fetchLeaderboard(scope: _scope, metric: _metric);
      if (!mounted) return;
      setState(() => _board = b);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addFriend() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
          key: const Key('friendNameField'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Their warrior name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final api = context.read<GameState>().api;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.addFriend(name.trim());
      messenger.showSnackBar(SnackBar(content: Text('${name.trim()} added!')));
      if (_scope == 'friends') _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String get _unit => _scope == 'weekly' ? 'XP' : (_metric == 'rating' ? 'RP' : 'XP');

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return AppShell(
      title: 'Rank',
      navIndex: 3,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'global', label: Text('Global')),
                      ButtonSegment(value: 'weekly', label: Text('Weekly')),
                      ButtonSegment(value: 'friends', label: Text('Friends')),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (s) {
                      setState(() => _scope = s.first);
                      _load();
                    },
                  ),
                ),
                IconButton(
                  key: const Key('addFriendButton'),
                  tooltip: 'Add friend',
                  icon: const Icon(Icons.person_add_alt_1),
                  onPressed: _addFriend,
                ),
              ],
            ),
          ),
          if (_scope != 'weekly')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Total XP'),
                    selected: _metric == 'xp',
                    onSelected: (_) {
                      setState(() => _metric = 'xp');
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Online rating'),
                    selected: _metric == 'rating',
                    onSelected: (_) {
                      setState(() => _metric = 'rating');
                      _load();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(board),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Leaderboard? board) {
    if (_loading && board == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && board == null) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      ]);
    }
    if (board == null) return const SizedBox.shrink();
    final entries = board.entries;
    return ListView.builder(
      key: const Key('leaderboardList'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length + (board.meOutsideList ? 2 : 0) + (entries.length <= 1 && _scope == 'friends' ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < entries.length) return _row(entries[i]);
        final extra = i - entries.length;
        if (board.meOutsideList) {
          if (extra == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(child: Text('...', style: TextStyle(color: AppColors.outline))),
            );
          }
          if (extra == 1) return _row(board.me);
        }
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No friends yet. Add one with the button above, or play a room together.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceVariant)),
        );
      },
    );
  }

  Widget _row(LeaderboardEntry e) {
    final medalColor = e.rank == 1
        ? AppColors.tertiary
        : e.rank == 2
            ? AppColors.onSurfaceVariant
            : e.rank == 3
                ? const Color(0xFFCD7F32)
                : AppColors.outline;
    return Container(
      key: Key('rank_${e.playerId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: e.isMe ? AppColors.surfaceContainerHigh : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: e.isMe ? AppColors.primary : AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: e.rank <= 3
                ? Icon(Icons.emoji_events, color: medalColor, size: 22)
                : Text('#${e.rank}', style: TextStyle(fontWeight: FontWeight.w800, color: medalColor, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              e.name + (e.isMe ? ' (You)' : ''),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 13),
            ),
          ),
          Text('Lv.${e.level}', style: AppTheme.mono(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 12),
          Text('${e.value} $_unit',
              style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary)),
        ],
      ),
    );
  }
}
