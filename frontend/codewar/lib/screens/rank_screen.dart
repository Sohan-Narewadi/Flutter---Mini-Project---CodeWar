import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/leaderboard.dart';
import '../models/profile_models.dart';
import '../models/tier.dart';
import '../providers/game_state.dart';
import '../services/api_service.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/avatar.dart';
import '../ui/neon_button.dart';
import '../ui/segmented_tabs.dart';
import '../ui/skeleton.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';

/// Rank: the live leaderboard from the server (global, weekly, friends), by
/// XP or by online rating. It re-fetches every [_refreshEvery] while visible.
/// Nothing here is hardcoded.
class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

const _refreshEvery = Duration(seconds: 15);

class _RankScreenState extends State<RankScreen> {
  String _scope = 'global';
  String _metric = 'xp';
  Leaderboard? _board;
  String? _error;
  bool _loading = true;
  DateTime? _updatedAt;
  Timer? _timer;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final api = context.read<GameState>().api;
    final id = ++_requestId;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final b = await api.fetchLeaderboard(scope: _scope, metric: _metric);
      if (!mounted || id != _requestId) return; // a newer request superseded this one
      setState(() {
        _board = b;
        _error = null;
        _updatedAt = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      if (!silent || _board == null) setState(() => _error = e.message);
    }
    if (mounted && id == _requestId) setState(() => _loading = false);
  }

  void _change({String? scope, String? metric}) {
    setState(() {
      _scope = scope ?? _scope;
      _metric = metric ?? _metric;
      _board = null;
    });
    _load();
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Add')),
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

  void _openProfile(LeaderboardEntry e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileSheet(entry: e, api: context.read<GameState>().api),
    );
  }

  String get _unit => (_scope == 'weekly' || _metric == 'xp') ? 'XP' : 'RP';

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return AppShell(
      title: 'Rank',
      navIndex: 3,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: _load,
        child: ListView(
          key: const Key('leaderboardList'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageHeader(
              title: 'Leaderboard',
              subtitle: 'Real players, updated live.',
              trailing: IconButton.filledTonal(
                key: const Key('addFriendButton'),
                tooltip: 'Add friend',
                icon: const Icon(Icons.person_add_alt_1_rounded),
                onPressed: _addFriend,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedTabs<String>(
                    options: const {'global': 'Global', 'weekly': 'Weekly', 'friends': 'Friends'},
                    value: _scope,
                    onChanged: (v) => _change(scope: v),
                  ),
                  if (_scope != 'weekly') ...[
                    const SizedBox(height: 10),
                    SegmentedTabs<String>(
                      height: 38,
                      options: const {'xp': 'Total XP', 'rating': 'Online rating'},
                      value: _metric,
                      onChanged: (v) => _change(metric: v),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _LiveRow(updatedAt: _updatedAt, error: _error != null && board != null),
                  const SizedBox(height: 14),
                  ..._content(board),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(Leaderboard? board) {
    if (_loading && board == null) return const [SkeletonList(rows: 6, rowHeight: 64)];
    if (_error != null && board == null) {
      return [
        AppCard(
          accent: AppColors.danger,
          child: Column(
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.text), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              NeonButton(label: 'Retry', compact: true, expanded: false, onPressed: _load),
            ],
          ),
        ),
      ];
    }
    if (board == null) return const [];
    final entries = board.entries;
    final podium = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    return [
      if (entries.isEmpty)
        const AppCard(child: Text('Nobody here yet.', style: TextStyle(color: AppColors.textDim)))
      else
        _Podium(entries: podium, unit: _unit, onTap: _openProfile),
      if (_scope == 'friends' && entries.length <= 1) ...[
        const SizedBox(height: 14),
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.group_add_rounded, color: AppColors.accent),
              SizedBox(width: 12),
              Expanded(
                child: Text('No friends yet. Add one with the button above, or play a room together.',
                    style: TextStyle(color: AppColors.textDim, height: 1.35)),
              ),
            ],
          ),
        ),
      ],
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 18),
        for (final e in rest) _RankRow(entry: e, unit: _unit, onTap: () => _openProfile(e)),
      ],
      if (board.meOutsideList) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Center(child: Text('•  •  •', style: TextStyle(color: AppColors.textFaint, letterSpacing: 4))),
        ),
        _RankRow(entry: board.me, unit: _unit, onTap: () => _openProfile(board.me)),
      ],
    ];
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.updatedAt, required this.error});
  final DateTime? updatedAt;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.danger : AppColors.success;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8)]),
        ),
        const SizedBox(width: 8),
        Text(
          error ? 'RECONNECTING' : 'LIVE',
          style: AppTheme.overline(color: color),
        ),
        const SizedBox(width: 8),
        Text(
          error ? 'showing last known data' : 'refreshes every ${_refreshEvery.inSeconds}s',
          style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
        ),
      ],
    );
  }
}

Color _medal(int rank) => switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.textFaint,
    };

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.unit, required this.onTap});
  final List<LeaderboardEntry> entries;
  final String unit;
  final ValueChanged<LeaderboardEntry> onTap;

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd, 1st, 3rd.
    LeaderboardEntry? at(int rank) => entries.where((e) => e.rank == rank).firstOrNull;
    final slots = [at(2), at(1), at(3)];
    const heights = [92.0, 124.0, 74.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: slots[i] == null
                ? const SizedBox.shrink()
                : _PodiumSlot(entry: slots[i]!, unit: unit, pillarHeight: heights[i], onTap: () => onTap(slots[i]!)),
          ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.entry, required this.unit, required this.pillarHeight, required this.onTap});
  final LeaderboardEntry entry;
  final String unit;
  final double pillarHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _medal(entry.rank);
    final first = entry.rank == 1;
    return GestureDetector(
      key: Key('rank_${entry.playerId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (first) const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 26),
            PlayerAvatar(name: entry.name, tier: Tier.fromKey(entry.tier, rating: entry.rating), size: first ? 68 : 56, glow: first || entry.isMe),
            const SizedBox(height: 8),
            Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppTheme.display(fontSize: 14)),
            if (entry.isMe) Text('YOU', style: AppTheme.overline(color: AppColors.accent)),
            const SizedBox(height: 4),
            Container(
              height: pillarHeight,
              width: double.infinity,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.04)],
                ),
                border: Border(top: BorderSide(color: color, width: 2)),
              ),
              child: Column(
                children: [
                  Text('${entry.rank}', style: AppTheme.display(fontSize: 26, color: color)),
                  const SizedBox(height: 2),
                  Text('${entry.value} $unit', style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.unit, required this.onTap});
  final LeaderboardEntry entry;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final tier = Tier.fromKey(e.tier, rating: e.rating);
    return Padding(
      key: Key('rank_${e.playerId}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        accent: e.isMe ? AppColors.accent : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 34, child: Text('${e.rank}', style: AppTheme.display(fontSize: 18, color: _medal(e.rank)))),
            PlayerAvatar(name: e.name, tier: tier, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(fontSize: 15))),
                      if (e.isMe) ...[
                        const SizedBox(width: 6),
                        Text('YOU', style: AppTheme.overline(color: AppColors.accent)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Level ${e.level}  ·  ${tier.label}', style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            Text('${e.value} $unit', style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a player's public profile (what any signed-in player may see).
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.entry, required this.api});
  final LeaderboardEntry entry;
  final ApiService api;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  PublicProfile? _profile;
  List<BadgeInfo> _catalogue = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final results = await Future.wait([widget.api.fetchPublicProfile(widget.entry.playerId), widget.api.fetchBadges()]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as PublicProfile;
        _catalogue = results[1] as List<BadgeInfo>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final p = _profile;
    final tier = Tier.fromKey(p?.tier ?? e.tier, rating: p?.rating ?? e.rating);
    final earned = p == null ? <BadgeInfo>[] : _catalogue.where((b) => p.badges.contains(b.key)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(name: e.name, tier: tier, size: 72, glow: true),
            const SizedBox(height: 12),
            Text(e.name, style: AppTheme.display(fontSize: 24)),
            const SizedBox(height: 6),
            TierBadge(tier: tier),
            const SizedBox(height: 18),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger))
            else if (p == null)
              const SkeletonBox(height: 70, radius: AppRadius.xl)
            else ...[
              Row(
                children: [
                  _Mini(label: 'Level', value: '${p.level}'),
                  const SizedBox(width: 10),
                  _Mini(label: 'Rating', value: '${p.rating}'),
                  const SizedBox(width: 10),
                  _Mini(label: 'W / L', value: '${p.wins} / ${p.losses}'),
                ],
              ),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: Text('BADGES', style: AppTheme.overline())),
              const SizedBox(height: 8),
              if (earned.isEmpty)
                const Align(alignment: Alignment.centerLeft, child: Text('No badges yet.', style: TextStyle(color: AppColors.textDim)))
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in earned)
                        Tooltip(
                          message: '${b.name}: ${b.description}',
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: 0.6))),
                            child: Icon(b.iconData, color: AppColors.gold, size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        flat: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value, style: AppTheme.display(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: AppTheme.overline()),
          ],
        ),
      ),
    );
  }
}
