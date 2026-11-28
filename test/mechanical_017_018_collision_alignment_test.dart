import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Batch 018 vortex art keeps the original portal hit coordinates', () {
    final game = PinballGame(
      table: tableById(PinballTableId.astralOrrery),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.debugPlaceBall(const Offset(111, 404), Offset.zero);
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallPositions.single.dx, closeTo(289, 2));
    expect(game.debugBallPositions.single.dy, closeTo(156, 2));
    expect(game.hud.value.score, greaterThanOrEqualTo(1200));
    final scoreAfterTeleport = game.hud.value.score;
    game.debugStepPhysics(1 / 120);
    // Cooldown prevents duplicate teleport awards on the next frame.
    expect(game.hud.value.score, scoreAfterTeleport);
    game.hud.dispose();
  });

  test('Batch 017 bumper art retains the existing physical bumper hitbox', () {
    final game = PinballGame(
      table: tableById(PinballTableId.astralOrrery),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    // Physically overlap the first original machine bumper (112, 287), r=22.
    game.debugPlaceBall(const Offset(112, 312), Offset.zero);
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallPositions.single.dy, greaterThanOrEqualTo(316.5));
    expect(game.hud.value.score, greaterThanOrEqualTo(500));
    game.hud.dispose();
  });
}
