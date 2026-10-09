import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../services/api_service.dart';
import '../ui/app_scaffold.dart';
import '../ui/neon_button.dart';
import '../utils/theme.dart';

/// First launch: pick a display name (and optionally the server address
/// your host shared). Registers a device-bound account; there is no password.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server.text = context.read<GameState>().api.settings.apiUrl ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 2 || name.length > 16) {
      setState(() => _error = 'Pick a name between 2 and 16 characters.');
      return;
    }
    final state = context.read<GameState>();
    state.api.settings.apiUrl = _server.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.register(name);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      maxWidth: 440,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page + 4,
            24,
            AppSpace.page + 4,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Logo()),
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (r) => AppColors.accentGradient.createShader(r),
                child: Text(
                  'CODEWAR',
                  textAlign: TextAlign.center,
                  style: AppTheme.display(
                    fontSize: 40,
                    letterSpacing: 6,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Code to fight. Climb the ranks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDim, fontSize: 15),
              ),
              const SizedBox(height: 28),
              const _Feature(
                icon: Icons.all_inclusive_rounded,
                text: 'Endless fresh problems, verified by a real judge',
              ),
              const _Feature(
                icon: Icons.groups_rounded,
                text: 'Race or duel friends live with a room code',
              ),
              const _Feature(
                icon: Icons.leaderboard_rounded,
                text: 'Real leaderboard, tiers and badges',
              ),
              const SizedBox(height: 28),
              TextField(
                key: const Key('nameField'),
                controller: _name,
                maxLength: 16,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _submit(),
                style: AppTheme.display(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Choose your warrior name',
                  counterText: '',
                ),
              ),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text(
                    'Advanced: server address',
                    style: TextStyle(color: AppColors.textDim, fontSize: 14),
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  iconColor: AppColors.textDim,
                  collapsedIconColor: AppColors.textDim,
                  children: [
                    TextField(
                      key: const Key('serverField'),
                      controller: _server,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://your-tunnel.trycloudflare.com',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          key: const Key('onboardingError'),
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              NeonButton(
                key: const Key('startButton'),
                label: 'Enter the Arena',
                icon: Icons.bolt_rounded,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 14),
              const Text(
                'No password or email. Your warrior lives on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppColors.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.45),
            blurRadius: 36,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.code_rounded,
        size: 46,
        color: AppColors.onAccent,
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
