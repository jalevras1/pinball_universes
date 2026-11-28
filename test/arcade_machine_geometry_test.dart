import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PinballGame game;
  setUp(() {
    game = PinballGame(table: tableById(PinballTableId.astralOrrery), onGameFinished: (_) {});
    game.debugInitializePhysics();
  });
  tearDown(() => game.hud.dispose());
  test('resting flippers leave genuine center drain', () {
    game.debugPlaceBall(const Offset(200,650), const Offset(0,400));
    for(var i=0;i<60&&!game.hud.value.isReady;i++) {game.debugStepPhysics(1/120);}
    expect(game.hud.value.isReady,true); expect(game.hud.value.balls,2);
  });
  test('left outlane drains independently', () {
    game.debugPlaceBall(const Offset(52,678), const Offset(0,380));
    for(var i=0;i<30&&!game.hud.value.isReady;i++) {game.debugStepPhysics(1/120);}
    expect(game.hud.value.isReady,true); expect(game.hud.value.balls,2);
  });
  test('slingshot contact delivers rebound and score', () {
    game.debugPlaceBall(const Offset(170,550), const Offset(-450,0));
    for(var i=0;i<24&&game.hud.value.score==0;i++) {game.debugStepPhysics(1/120);}
    expect(game.hud.value.score,greaterThanOrEqualTo(100));
    expect(game.debugBallVelocities.single.dx,greaterThan(0));
  });
  test('rollover lane crossing scores', () {
    game.debugPlaceBall(const Offset(200,84), const Offset(0,400));
    for(var i=0;i<12&&game.hud.value.score==0;i++) {game.debugStepPhysics(1/120);}
    expect(game.hud.value.score,greaterThanOrEqualTo(150));
  });
}
