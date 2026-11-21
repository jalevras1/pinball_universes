import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Original effects, deliberately short to keep the first web download small.
enum PinballSound {
  launch,
  flipper,
  rail,
  bumperCelestial,
  bumperNeon,
  bumperClockwork,
  portal,
  gravity,
  gate,
  gear,
  boost,
  award,
  jackpot,
  multiball,
  drain,
  extraBall,
}

extension on PinballSound {
  String get fileName => switch (this) {
    PinballSound.bumperCelestial => 'bumper_celestial',
    PinballSound.bumperNeon => 'bumper_neon',
    PinballSound.bumperClockwork => 'bumper_clockwork',
    PinballSound.extraBall => 'extra_ball',
    _ => name,
  };

  int get cooldownMs => switch (this) {
    PinballSound.flipper => 52,
    PinballSound.rail => 115,
    PinballSound.gravity => 1500,
    PinballSound.bumperCelestial ||
    PinballSound.bumperNeon ||
    PinballSound.bumperClockwork => 80,
    _ => 125,
  };

  double get gain => switch (this) {
    PinballSound.rail => 0.23,
    PinballSound.flipper => 0.43,
    PinballSound.gravity => 0.28,
    PinballSound.drain => 0.40,
    PinballSound.launch => 0.62,
    PinballSound.jackpot => 0.62,
    _ => 0.48,
  };
}

/// Short effect pools let multiple collisions overlap without restarting a
/// single player. Web audio begins only after a user's tap/launch interaction.
class PinballAudio {
  PinballAudio({bool enabled = true}) : enabled = enabled;

  bool enabled;
  bool _disposed = false;
  final Map<PinballSound, AudioPool> _pools = {};
  final Map<PinballSound, Future<AudioPool?>> _loading = {};
  final Map<PinballSound, int> _playedAt = {};

  Future<AudioPool?> _load(PinballSound sound) {
    if (_disposed) return Future<AudioPool?>.value(null);
    if (_pools[sound] case final existing?) {
      return Future<AudioPool?>.value(existing);
    }
    return _loading.putIfAbsent(sound, () async {
      try {
        final pool = await AudioPool.create(
          source: AssetSource('audio/${sound.fileName}.wav'),
          minPlayers: 1,
          maxPlayers: sound == PinballSound.rail ? 3 : 4,
        );
        if (_disposed) {
          await pool.dispose();
          return null;
        }
        _pools[sound] = pool;
        return pool;
      } catch (_) {
        // Unsupported audio/browser policies never block the physics loop.
        return null;
      } finally {
        _loading.remove(sound);
      }
    });
  }

  Future<void> preload() async {
    await Future.wait(PinballSound.values.map(_load));
  }

  void play(PinballSound sound) {
    if (!enabled || _disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_playedAt[sound] ?? -100000) < sound.cooldownMs) return;
    _playedAt[sound] = now;
    final pool = _pools[sound];
    if (pool != null) {
      unawaited(
        pool
            .start(volume: sound.gain)
            .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
      );
    } else {
      // Prewarm during loading; never await in the game's frame callback.
      unawaited(
        _load(
          sound,
        ).then<void>((ready) {}, onError: (Object error, StackTrace stack) {}),
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    final pools = _pools.values.toList(growable: false);
    _pools.clear();
    await Future.wait(pools.map((pool) => pool.dispose()));
  }
}
