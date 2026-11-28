import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final side in <String>['left', 'right']) {
    for (final state in <String>['idle', 'hit']) {
      test('Batch 019 $side slingshot $state is a valid transparent 96x112 sprite', () async {
        final bytes = await rootBundle.load(
          'assets/gameplay/mechanical/slingshot_${side}_${state}_aligned.png',
        );
        expect(bytes.lengthInBytes, greaterThan(2000));
        expect(bytes.getUint32(0), 0x89504e47);
        expect(bytes.getUint32(16), 96);
        expect(bytes.getUint32(20), 112);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 96);
        expect(frame.image.height, 112);
        final decoded = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(decoded, isNotNull);
        // Transparent corner means the sprite cannot occlude neighboring rails.
        expect(decoded!.getUint8(3), 0);
        frame.image.dispose();
        codec.dispose();
      });
    }
  }

  test('left slingshot visual replacement preserves bounce and scoring', () {
    final game = PinballGame(
      table: tableById(PinballTableId.astralOrrery),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.debugPlaceBall(const ui.Offset(170, 550), const ui.Offset(-450, 0));
    for (var i = 0; i < 24 && game.hud.value.score == 0; i++) {
      game.debugStepPhysics(1 / 120);
    }
    expect(game.hud.value.score, greaterThanOrEqualTo(100));
    expect(game.debugBallVelocities.single.dx, greaterThan(0));
    game.hud.dispose();
  });
}
