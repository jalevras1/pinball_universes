import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/shooter_lane.dart';
import 'package:premium_pinball/game/swept_rail.dart';

// Run 20's preserved additive test candidate, now alongside the Run 21
// shooter-to-playfield handoff tests. These require real Flutter execution.
void main() {
  const lane = ShooterLane();

  test('shooter energy boundary agrees with analytical reachability', () {
    final critical = math.sqrt(2 * lane.gravity * (lane.readyY - lane.exitY));
    final threshold =
        (critical - lane.minimumSpeed) /
        (lane.maximumSpeed - lane.minimumSpeed);
    for (var i = 0; i <= 1000; i++) {
      final power = i / 1000;
      final v = lane.launchVelocityY(power);
      final expectedReach = v.abs() >= critical;
      var y = lane.readyY;
      var velocity = v;
      var phase = ShooterPhase.traveling;
      for (
        var frame = 0;
        frame < 3000 && phase == ShooterPhase.traveling;
        frame++
      ) {
        final step = lane.advance(y: y, velocityY: velocity, dt: 1 / 120);
        y = step.y;
        velocity = step.velocityY;
        phase = step.phase;
      }
      expect(
        phase,
        expectedReach ? ShooterPhase.exited : ShooterPhase.rearmed,
        reason: 'power=$power threshold=$threshold',
      );
    }
  });

  test('shooter travel agrees at 30, 60, 120 and 240 Hz before exit', () {
    for (final power in <double>[0, 0.2, 0.5, 1]) {
      final initialV = lane.launchVelocityY(power);
      const duration = 0.10;
      final expectedY =
          lane.readyY +
          initialV * duration +
          0.5 * lane.gravity * duration * duration;
      final expectedV = initialV + lane.gravity * duration;
      for (final hz in <int>[30, 60, 120, 240]) {
        final dt = duration / (hz ~/ 10);
        var y = lane.readyY;
        var v = initialV;
        for (var i = 0; i < hz ~/ 10; i++) {
          final step = lane.advance(y: y, velocityY: v, dt: dt);
          expect(step.phase, ShooterPhase.traveling);
          y = step.y;
          v = step.velocityY;
        }
        expect(y, closeTo(expectedY, 1e-7), reason: 'power=$power hz=$hz');
        expect(v, closeTo(expectedV, 1e-7), reason: 'power=$power hz=$hz');
      }
    }
  });

  test('swept rail detects crossing at varied speed and directions', () {
    for (final speed in <double>[10, 100, 1000, 10000]) {
      final hit = sweepRail(
        fromX: 31 + 7.5 + speed / 1000,
        fromY: 300,
        toX: 31 - speed,
        toY: 300,
        ax: 31,
        ay: 116,
        bx: 31,
        by: 690,
        radius: 7.5,
      );
      expect(hit, isNotNull, reason: 'speed=$speed');
      expect(hit!.normalX, closeTo(1, 1e-9));
      expect(hit.x, closeTo(38.5, 1e-7));
      expect(hit.fraction, inInclusiveRange(0, 1));
    }
  });

  test('swept rail detects high-speed endpoint contact', () {
    for (final radius in <double>[3, 7.5, 12]) {
      final hit = sweepRail(
        fromX: -50,
        fromY: -50,
        toX: 50,
        toY: 50,
        ax: 0,
        ay: 0,
        bx: 0,
        by: 20,
        radius: radius,
      );
      expect(hit, isNotNull, reason: 'radius=$radius');
      expect(hit!.fraction, inInclusiveRange(0, 1));
      expect(
        math.sqrt(hit.normalX * hit.normalX + hit.normalY * hit.normalY),
        closeTo(1, 1e-8),
      );
    }
  });
}
