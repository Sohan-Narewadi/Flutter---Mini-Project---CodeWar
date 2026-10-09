import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../services/sfx.dart';
import '../ui/app_card.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../utils/theme.dart';

/// Sound and haptics, the server address (the tunnel URL a host shares) and
/// account switching.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _server;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(
      text: context.read<GameState>().api.settings.apiUrl ?? '',
    );
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<GameState>();
    state.api.settings.apiUrl = _server.text;
    setState(() => _saving = true);
    await state.load();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.offline
              ? 'Saved, but the server is still unreachable.'
              : 'Connected.',
        ),
      ),
    );
  }

  void _setSound(bool v) {
    final settings = context.read<GameState>().api.settings;
    setState(() {
      settings.soundOn = v;
      Sfx.soundOn = v;
    });
    if (v) Sfx.play(Cue.success);
  }

  void _setHaptics(bool v) {
    final settings = context.read<GameState>().api.settings;
    setState(() {
      settings.hapticsOn = v;
      Sfx.hapticsOn = v;
    });
    if (v) Sfx.play(Cue.tap);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final settings = state.api.settings;
    return AppScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, AppSpace.page, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
                Text('Settings', style: AppTheme.display(fontSize: 26)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const SectionTitle('Feedback'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('soundSwitch'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Sound effects',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Clicks, wins and countdown beeps',
                            style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                          value: settings.soundOn,
                          onChanged: _setSound,
                        ),
                        const Divider(),
                        SwitchListTile(
                          key: const Key('hapticsSwitch'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Haptics',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Vibration on supported devices',
                            style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                          value: settings.hapticsOn,
                          onChanged: _setHaptics,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Server'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('settingsServerField'),
                        controller: _server,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          helperText:
                              'Leave empty for the default (${state.api.baseUrl}).',
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      NeonButton(
                        label: 'Save & reconnect',
                        icon: Icons.sync_rounded,
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Account'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in as ${settings.playerName ?? state.player.displayName}',
                        style: const TextStyle(color: AppColors.textDim),
                      ),
                      const SizedBox(height: 14),
                      NeonButton(
                        label: 'Switch player (sign out)',
                        icon: Icons.logout_rounded,
                        variant: NeonVariant.danger,
                        onPressed: state.signOut,
                      ),
                    ],
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
