import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

// Real PinballGame solver regression, not a Python reimplementation or art test.
// These must run in a Flutter SDK before the Run23 candidate can be promoted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final table in pinballTables) {
    group('${table.id.name} full-table shooter route', () {
      late PinballGame game;
      setUp(() {
        game = PinballGame(table: table, onGameFinished: (_) {});
        game.debugInitializePhysics();
      });
      tearDown(() {
        game.hud.dispose();
        game.developerEvents.dispose();
      });

      test('100% shot exits guide into the actual playable left side', () {
        game.launch(strength: 1);
        var enteredField = false;
        // The fixed lane divider occupies x=336 from y=205 down. A legal
        // upper exit must cross left of the ball-radius-inflated divider
        // while still above its y=205 endpoint.
        for (var i = 0; i < 720; i++) {
          game.debugStepPhysics(1 / 120);
          for (final position in game.debugBallPositions) {
            if (position.dx < 328.5 && position.dy < 205) {
              enteredField = true;
            }
          }
          if (enteredField || game.hud.value.isReady) break;
        }
        expect(
          enteredField,
          isTrue,
          reason:
              '${table.id.name}: full-strength ball never cleared the '
              'upper shooter divider; inspect exit guide/outer wall.',
        );
      });

      test('long play stays finite at three launch powers', () {
        for (final strength in <double>[0.17, 0.6, 1]) {
          game.restart();
          game.launch(strength: strength);
          for (var frame = 0; frame < 1200; frame++) {
            game.debugStepPhysics(1 / 120);
            for (final position in game.debugBallPositions) {
              expect(
                position.dx.isFinite && position.dy.isFinite,
                isTrue,
                reason: '${table.id.name}, power=$strength, frame=$frame',
              );
            }
            for (final velocity in game.debugBallVelocities) {
              expect(
                velocity.dx.isFinite && velocity.dy.isFinite,
                isTrue,
                reason: '${table.id.name}, power=$strength, frame=$frame',
              );
            }
            expect(game.hud.value.balls, inInclusiveRange(0, 4));
          }
        }
      });
    });
  }
}
