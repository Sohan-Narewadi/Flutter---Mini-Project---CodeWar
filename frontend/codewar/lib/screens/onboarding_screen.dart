import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../services/api_service.dart';
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield, size: 64, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text('CODEWAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 4)),
                  const SizedBox(height: 4),
                  const Text('Code to fight. Climb the ranks.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  TextField(
                    key: const Key('nameField'),
                    controller: _name,
                    maxLength: 16,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: const InputDecoration(labelText: 'Choose your warrior name'),
                  ),
                  ExpansionTile(
                    title: const Text('Advanced: server address'),
                    tilePadding: EdgeInsets.zero,
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, key: const Key('onboardingError'), style: const TextStyle(color: AppColors.error)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('startButton'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Enter the Arena'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
