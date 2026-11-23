// Zero-network, pure-Dart model probe. It does NOT replace flutter test or an
// actual rendered/mobile game playtest.
import 'dart:math' as math;

import '../lib/game/plunger_model.dart';
import '../lib/game/shooter_lane.dart';
import '../lib/game/swept_rail.dart';

int _checks = 0;

void check(bool condition, String label) {
  _checks++;
  if (!condition) throw StateError('FAIL $_checks: $label');
}

void main() {
  final plunger = PlungerModel(fullPullPixels: 100);
  check(plunger.release() == null, 'tap never launches');
  plunger.pull(7);
  check(plunger.release() == null, 'tiny accidental drag never launches');
  plunger.pull(50);
  check(plunger.release() == 0.5, 'mid pull maps to exact power');
  plunger.pull(1000);
  check(plunger.release() == 1, 'power caps at 100%');
  plunger.pull(100);
  plunger.cancel();
  check(plunger.release() == null, 'cancel never fires');

  const lane = ShooterLane();
  check(lane.launchVelocityY(0) == -650, 'minimum power speed');
  check(lane.launchVelocityY(0.5) == -1050, 'medium power speed');
  check(lane.launchVelocityY(1) == -1450, 'maximum power speed');
  check(lane.centerX == 352, 'fixed centerline');
  var weakReturns = 0;
  var successfulExits = 0;
  for (var i = 0; i <= 100; i++) {
    final power = i / 100;
    var y = lane.readyY;
    var velocityY = lane.launchVelocityY(power);
    var outcome = ShooterPhase.traveling;
    for (var tick = 0; tick < 900; tick++) {
      final step = lane.advance(y: y, velocityY: velocityY, dt: 1 / 120);
      y = step.y;
      velocityY = step.velocityY;
      outcome = step.phase;
      check(y.isFinite && velocityY.isFinite, 'finite state @ $power');
      check(y >= lane.exitY && y <= lane.readyY, 'tube bounds @ $power');
      if (outcome != ShooterPhase.traveling) break;
    }
    check(
      outcome != ShooterPhase.traveling,
      'shot eventually resolves @ $power',
    );
    if (outcome == ShooterPhase.rearmed) {
      weakReturns++;
      check(y == lane.readyY && velocityY == 0, 'weak shot rearms');
    } else {
      successfulExits++;
      check(y == lane.exitY && velocityY < 0, 'exit is deterministic');
    }
  }
  check(weakReturns > 0, 'supports rollback');
  check(successfulExits > 0, 'supports complete launches');

  // A crossing can happen between two frame endpoints, even when the ball
  // turns around and the frame ends below the exit again.
  for (final dt in <double>[0.01, 0.05]) {
    final hiddenExit = lane.advance(y: 198.05, velocityY: -12, dt: dt);
    check(hiddenExit.phase == ShooterPhase.exited, 'subframe exit at $dt');
    check(hiddenExit.y == lane.exitY, 'exact exit position at $dt');
    check(
      (hiddenExit.velocityY + math.sqrt(77)).abs() < 1e-10,
      'exact ascending exit velocity at $dt',
    );
  }

  final criticalSpeed =
      math.sqrt(2 * lane.gravity * (lane.readyY - lane.exitY));
  final criticalPower =
      (criticalSpeed - lane.minimumSpeed) /
      (lane.maximumSpeed - lane.minimumSpeed);
  for (final dt in <double>[1 / 20, 1 / 30, 1 / 60, 1 / 120]) {
    for (final delta in <double>[-0.0005, 0.0005]) {
      var y = lane.readyY;
      var vy = lane.launchVelocityY(criticalPower + delta);
      var phase = ShooterPhase.traveling;
      for (var i = 0; i < 900 && phase == ShooterPhase.traveling; i++) {
        final step = lane.advance(y: y, velocityY: vy, dt: dt);
        y = step.y;
        vy = step.velocityY;
        phase = step.phase;
      }
      check(
        phase == (delta < 0 ? ShooterPhase.rearmed : ShooterPhase.exited),
        'near-threshold launch at dt=$dt delta=$delta',
      );
    }
  }

  final left = sweepRail(
    fromX: 40,
    fromY: 350,
    toX: 26,
    toY: 350,
    ax: 31,
    ay: 116,
    bx: 31,
    by: 690,
    radius: 7.5,
  );
  check(left != null, 'fast ball hits left rail');
  check((left!.x - 38.5).abs() < 1e-8, 'left impact point correct');
  check((left.normalX - 1).abs() < 1e-8, 'left normal points inward');

  final right = sweepRail(
    fromX: 360,
    fromY: 500,
    toX: 381,
    toY: 500,
    ax: 369,
    ay: 109,
    bx: 369,
    by: 695,
    radius: 7.5,
  );
  check(right != null, 'fast ball hits right rail');
  check((right!.x - 361.5).abs() < 1e-8, 'right impact point correct');
  check((right.normalX + 1).abs() < 1e-8, 'right normal points inward');

  final corner = sweepRail(
    fromX: -12,
    fromY: -12,
    toX: 12,
    toY: 12,
    ax: 0,
    ay: 0,
    bx: 0,
    by: 20,
    radius: 5,
  );
  check(corner != null, 'rounded endpoint blocks corner tunneling');
  check(corner!.fraction >= 0 && corner.fraction <= 1, 'valid contact time');
  check(
    sweepRail(
          fromX: 60,
          fromY: 200,
          toX: 50,
          toY: 200,
          ax: 31,
          ay: 116,
          bx: 31,
          by: 690,
          radius: 7.5,
        ) ==
        null,
    'nearby clear path has no false hit',
  );

  print('PASS: $_checks pure Dart model assertions');
  print('101 launch powers: $weakReturns weak rearms; $successfulExits exits.');
  print(
    'NOT TESTED: Flutter integration, live controls, rendered frames or Android.',
  );
}
