import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final table in pinballTables) {
    group('${table.id.name} runtime physics', () {
      late PinballGame game;
      var gameOvers = 0;

      setUp(() {
        gameOvers = 0;
        game = PinballGame(table: table, onGameFinished: (_) => gameOvers++);
        game.debugInitializePhysics();
      });

      tearDown(() => game.hud.dispose());

      test('weak launch returns ball to plunger without losing a life', () {
        expect(game.hud.value.isReady, isTrue);
        game.launch(strength: 0);
        expect(game.debugBallInTube, isTrue);
        for (var i = 0; i < 500 && !game.hud.value.isReady; i++) {
          game.debugStepPhysics(1 / 120);
          expect(game.debugBallPositions.single.dx, 352);
        }
        expect(game.hud.value.isReady, isTrue);
        expect(game.hud.value.balls, 3);
        expect(game.hud.value.score, 0);
        expect(gameOvers, 0);
      });

      test('medium launch exits tube on centerline and advances remaining time', () {
        game.launch(strength: 0.5);
        for (var i = 0; i < 250 && game.debugBallInTube; i++) {
          game.debugStepPhysics(1 / 120);
          // A step can *cross* the exit and immediately encounter the
          // Moonfall angled upper guide. Require the locked centerline only
          // for frames where the ball is still captive in the tube.
          if (game.debugBallInTube) {
            expect(game.debugBallPositions.single.dx, 352);
            expect(game.debugBallVelocities.single.dx, 0);
          }
        }
        expect(game.debugBallInTube, isFalse);
        // Straight-up launch is exact while captive. Once the ball crosses
        // the exit, the first playfield guide may impart a tiny lateral
        // impulse (Moonfall has a nearby angled guide).
        expect(game.debugBallPositions.single.dx, closeTo(352, 0.25));
        // Exit can happen partway through a physics step; playfield motion
        // must continue for that frame's remaining duration.
        expect(game.debugBallPositions.single.dy, lessThanOrEqualTo(198));
        expect(game.debugBallPositions.single.dy, greaterThan(190));
        expect(game.debugBallVelocities.single.dx, closeTo(0, 1));
        expect(game.debugBallVelocities.single.dy, lessThan(0));
        expect(game.hud.value.score, 0);
        expect(game.hud.value.balls, 3);
      });

      test('barely cleared exit drops back to plunger without drain', () {
        game.launch(strength: 0.18);
        for (var i = 0; i < 520 && !game.hud.value.isReady; i++) {
          game.debugStepPhysics(1 / 120);
        }
        expect(game.hud.value.isReady, isTrue);
        expect(game.hud.value.balls, 3);
        expect(gameOvers, 0);
      });

      test('pause blocks new launches and freezes existing shots', () {
        game.togglePause();
        game.launch(strength: 1);
        expect(game.hud.value.isReady, isTrue);
        game.togglePause();
        game.launch(strength: 1);
        game.debugStepPhysics(1 / 120);
        final current = game.debugBallPositions.single;
        game.togglePause();
        for (var i = 0; i < 30; i++) {
          game.debugStepPhysics(1 / 120);
        }
        expect(game.debugBallPositions.single, current);
        expect(gameOvers, 0);
      });
    });
  }

  test('outlane drain happens once and rearms the next ball', () {
    final game = PinballGame(
      table: pinballTables.first,
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.debugPlaceBall(const Offset(200, 750), const Offset(0, 400));
    game.debugStepPhysics(1 / 120);
    expect(game.hud.value.balls, 2);
    expect(game.hud.value.isReady, isTrue);
    game.debugStepPhysics(1 / 120);
    expect(game.hud.value.balls, 2);
    game.hud.dispose();
  });

  test('left guide bounces incoming steel ball back into play', () {
    final game = PinballGame(
      table: pinballTables.first,
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.debugPlaceBall(const Offset(40, 350), const Offset(-1300, 0));
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallPositions.single.dx, greaterThan(31));
    expect(game.debugBallVelocities.single.dx, greaterThan(0));
    game.hud.dispose();
  });

  for (final left in <bool>[true, false]) {
    test('${left ? 'left' : 'right'} flipper sends descending ball upward', () {
      final game = PinballGame(
        table: pinballTables.first,
        onGameFinished: (_) {},
      );
      game.debugInitializePhysics();
      game.debugPlaceBall(Offset(left ? 174 : 226, 644), const Offset(0, 400));
      game.leftPressed = left;
      game.rightPressed = !left;
      for (var i = 0; i < 12 && game.hud.value.score == 0; i++) {
        game.debugStepPhysics(1 / 120);
      }
      expect(game.debugBallVelocities.single.dy, lessThan(0));
      expect(game.hud.value.score, greaterThanOrEqualTo(10));
      game.hud.dispose();
    });
  }
}
