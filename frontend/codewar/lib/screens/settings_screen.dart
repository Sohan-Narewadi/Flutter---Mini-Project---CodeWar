import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';

/// Server address (the tunnel URL your host shares) and account switching.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _server;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: context.read<GameState>().api.settings.apiUrl ?? '');
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<GameState>();
    state.api.settings.apiUrl = _server.text;
    await state.load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.offline ? 'Saved, but the server is still unreachable.' : 'Connected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Signed in as ${state.api.settings.playerName ?? state.player.displayName}',
              style: const TextStyle(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('settingsServerField'),
            controller: _server,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Server URL',
              helperText: 'Leave empty for the default (${state.api.baseUrl}).',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save & reconnect')),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Switch player (sign out)'),
            onPressed: state.signOut,
          ),
        ],
      ),
    );
  }
}
