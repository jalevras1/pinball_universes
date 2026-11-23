import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/shooter_lane.dart';

void main() {
  const lane = ShooterLane();

  test('power changes speed only, never the centerline or angle', () {
    expect(lane.centerX, 352);
    expect(lane.launchVelocityY(0), -650);
    expect(lane.launchVelocityY(0.5), -1050);
    expect(lane.launchVelocityY(1), -1450);
    expect(lane.launchVelocityY(-9), -650);
    expect(lane.launchVelocityY(9), -1450);
  });

  test('weak plunge rolls back and rearms instead of draining', () {
    var y = lane.readyY;
    var velocity = lane.launchVelocityY(0);
    ShooterPhase? phase;
    for (var i = 0; i < 800; i++) {
      final result = lane.advance(y: y, velocityY: velocity, dt: 1 / 120);
      y = result.y;
      velocity = result.velocityY;
      phase = result.phase;
      if (phase != ShooterPhase.traveling) break;
    }
    expect(phase, ShooterPhase.rearmed);
    expect(y, lane.readyY);
    expect(velocity, 0);
  });

  test('medium and full launch exit tube at fixed endpoint', () {
    for (final power in [0.5, 1.0]) {
      var y = lane.readyY;
      var velocity = lane.launchVelocityY(power);
      var exits = 0;
      for (var i = 0; i < 600; i++) {
        final step = lane.advance(y: y, velocityY: velocity, dt: 1 / 120);
        y = step.y;
        velocity = step.velocityY;
        if (step.phase == ShooterPhase.exited) {
          exits++;
          break;
        }
        expect(step.phase, ShooterPhase.traveling);
        expect(y, greaterThan(lane.exitY));
      }
      expect(exits, 1);
      expect(y, lane.exitY);
      expect(velocity, lessThan(0));
    }
  });

  test('identical power repeats identical trajectory', () {
    ShooterStep run() {
      var step = ShooterStep(
        lane.readyY,
        lane.launchVelocityY(0.67),
        ShooterPhase.traveling,
      );
      for (var i = 0; i < 20; i++) {
        step = lane.advance(y: step.y, velocityY: step.velocityY, dt: 1 / 120);
      }
      return step;
    }

    final first = run();
    final second = run();
    expect(first.y, second.y);
    expect(first.velocityY, second.velocityY);
    expect(first.phase, second.phase);
  });

  test('zero dt and no hidden horizontal evolution', () {
    final step = lane.advance(y: 400, velocityY: -900, dt: 0);
    expect(step.y, 400);
    expect(step.velocityY, -900);
    expect(step.phase, ShooterPhase.traveling);
  });

  test('invalid state is rejected, not allowed to corrupt gameplay', () {
    expect(() => lane.launchVelocityY(double.nan), throwsArgumentError);
    expect(
      () => lane.advance(y: 653, velocityY: -900, dt: -1),
      throwsArgumentError,
    );
  });
}
