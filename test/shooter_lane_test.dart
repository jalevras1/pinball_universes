import 'dart:math' as math;

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

  test('captures an exit hidden between two frame endpoints', () {
    // The apex is just above exitY, but the next coarse frame endpoint is
    // below the exit again. An endpoint-only test wrongly reports traveling.
    final step = lane.advance(y: 198.05, velocityY: -12, dt: 0.05);
    expect(step.phase, ShooterPhase.exited);
    expect(step.y, lane.exitY);
    expect(step.velocityY, closeTo(-math.sqrt(77), 1e-10));
  });

  test('exit speed uses crossing time, not the frame endpoint', () {
    final step = lane.advance(y: 198.05, velocityY: -12, dt: 0.01);
    expect(step.phase, ShooterPhase.exited);
    expect(step.velocityY, closeTo(-math.sqrt(77), 1e-10));
    expect(step.velocityY, isNot(closeTo(-5.3, 0.01)));
  });

  test('exit transfers only unconsumed frame time to playfield', () {
    const dt = 0.2;
    const y = 300.0;
    const velocity = -1000.0;
    final step = lane.advance(y: y, velocityY: velocity, dt: dt);
    final exitSpeed = math.sqrt(
      velocity * velocity - 2 * lane.gravity * (y - lane.exitY),
    );
    final crossingTime = (-velocity - exitSpeed) / lane.gravity;
    expect(step.phase, ShooterPhase.exited);
    expect(step.remainingDt, closeTo(dt - crossingTime, 1e-12));
    expect(step.remainingDt, greaterThan(0));

    final noExit = lane.advance(y: y, velocityY: velocity, dt: 0.01);
    expect(noExit.phase, ShooterPhase.traveling);
    expect(noExit.remainingDt, 0);
  });

  test('near-clear weak and strong shots agree across frame rates', () {
    final critical = math.sqrt(2 * lane.gravity * (lane.readyY - lane.exitY));
    final powerAtExit =
        (critical - lane.minimumSpeed) /
        (lane.maximumSpeed - lane.minimumSpeed);
    for (final dt in <double>[1 / 20, 1 / 30, 1 / 60, 1 / 120]) {
      for (final extraPower in <double>[-0.0005, 0.0005]) {
        var y = lane.readyY;
        var velocity = lane.launchVelocityY(powerAtExit + extraPower);
        var phase = ShooterPhase.traveling;
        for (var i = 0; i < 900 && phase == ShooterPhase.traveling; i++) {
          final step = lane.advance(y: y, velocityY: velocity, dt: dt);
          y = step.y;
          velocity = step.velocityY;
          phase = step.phase;
        }
        expect(
          phase,
          extraPower < 0 ? ShooterPhase.rearmed : ShooterPhase.exited,
          reason: 'dt=$dt offset=$extraPower',
        );
      }
    }
  });

  test('invalid state is rejected, not allowed to corrupt gameplay', () {
    expect(() => lane.launchVelocityY(double.nan), throwsArgumentError);
    expect(
      () => lane.advance(y: 653, velocityY: -900, dt: -1),
      throwsArgumentError,
    );
  });
}
