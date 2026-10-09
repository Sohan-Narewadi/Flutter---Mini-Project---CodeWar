import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// The sound/haptic cues the UI can fire.
enum Cue { tap, select, success, error, countdown, go, levelUp, win, lose }

/// Plays one audio asset. Replaceable in tests.
abstract class CuePlayer {
  Future<void> play(String asset);
}

/// No sound at all (the default, so tests and unsupported platforms stay silent).
class SilentCuePlayer implements CuePlayer {
  const SilentCuePlayer();
  @override
  Future<void> play(String asset) async {}
}

/// Real playback through `audioplayers`, with a tiny player pool so rapid
/// cues overlap instead of cutting each other off. Never throws: if audio is
/// unavailable (autoplay policy, missing plugin) the cue is simply skipped.
class AudioCuePlayer implements CuePlayer {
  final List<AudioPlayer> _pool = [];
  int _next = 0;

  @override
  Future<void> play(String asset) async {
    try {
      if (_pool.length < 4) _pool.add(AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
      final p = _pool[_next++ % _pool.length];
      await p.stop();
      await p.play(AssetSource(asset), volume: 0.7);
    } catch (_) {}
  }
}

/// App-wide UI feedback: short sounds and haptic taps, each with its own
/// on/off switch (persisted via Settings).
class Sfx {
  Sfx._();

  static CuePlayer player = const SilentCuePlayer();
  static bool soundOn = true;
  static bool hapticsOn = true;

  static const _assets = {
    Cue.tap: 'sfx/tap.wav',
    Cue.select: 'sfx/select.wav',
    Cue.success: 'sfx/success.wav',
    Cue.error: 'sfx/error.wav',
    Cue.countdown: 'sfx/countdown.wav',
    Cue.go: 'sfx/go.wav',
    Cue.levelUp: 'sfx/levelup.wav',
    Cue.win: 'sfx/win.wav',
    Cue.lose: 'sfx/lose.wav',
  };

  /// Fires the sound (if enabled) and the matching haptic (if enabled).
  static void play(Cue cue) {
    if (soundOn) {
      player.play(_assets[cue]!);
    }
    if (hapticsOn) _haptic(cue);
  }

  static void _haptic(Cue cue) {
    try {
      switch (cue) {
        case Cue.tap:
        case Cue.select:
          HapticFeedback.selectionClick();
        case Cue.countdown:
          HapticFeedback.lightImpact();
        case Cue.success:
        case Cue.go:
          HapticFeedback.mediumImpact();
        case Cue.levelUp:
        case Cue.win:
          HapticFeedback.heavyImpact();
        case Cue.error:
        case Cue.lose:
          HapticFeedback.vibrate();
      }
    } catch (_) {}
  }
}
