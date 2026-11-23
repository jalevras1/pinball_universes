import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final table in pinballTables) {
    test('${table.id.name}: shooter exit world state is tick-rate stable', () {
      Offset runAt(int hz) {
        final game = PinballGame(table: table, onGameFinished: (_) {});
        game.debugInitializePhysics();
        game.launch(strength: 0.5);
        // Same elapsed time at 30 and 120 Hz, shortly AFTER the first exit
        // and BEFORE a possible upper-guide collision or themed obstacle.
        for (var i = 0; i < (hz * 8) ~/ 15; i++) {
          game.debugStepPhysics(1 / hz);
        }
        expect(game.debugBallInTube, isFalse);
        expect(game.debugBallPositions.length, 1);
        final position = game.debugBallPositions.single;
        // Post-exit playfield rails can cause subpixel lateral movement.
        // The captive shooter phase remains exactly x=352 independently.
        expect(position.dx, closeTo(352, 0.25));
        expect(position.dy, lessThan(198));
        expect(game.hud.value.score, 0);
        game.hud.dispose();
        return position;
      }

      final coarse = runAt(30);
      final fine = runAt(120);
      expect(coarse.dx, closeTo(fine.dx, 0.25));
      expect(coarse.dy, closeTo(fine.dy, 0.75));
    });
  }
}
