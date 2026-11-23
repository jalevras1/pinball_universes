import 'dart:math' as math;

/// Deterministic shooter-tube motion in the game's fixed playfield coordinates.
///
/// This intentionally has no horizontal impulse. The real upper guide rail
/// redirects the ball only after [ShooterPhase.exited] has been reported.
enum ShooterPhase { traveling, exited, rearmed }

class ShooterStep {
  const ShooterStep(
    this.y,
    this.velocityY,
    this.phase, {
    this.remainingDt = 0,
  });

  final double y;
  final double velocityY;
  final ShooterPhase phase;

  /// Unspent time after the first upward tube-exit crossing. The playfield
  /// must simulate this remainder in the SAME tick to avoid frame-rate drift.
  final double remainingDt;
}

class ShooterLane {
  const ShooterLane({
    this.centerX = 352,
    this.readyY = 653,
    this.exitY = 198,
    this.gravity = 670,
    this.minimumSpeed = 650,
    this.maximumSpeed = 1450,
  }) : assert(readyY > exitY),
       assert(gravity > 0),
       assert(minimumSpeed > 0),
       assert(maximumSpeed >= minimumSpeed);

  /// Fixed centerline; input changes speed but NEVER x or aim angle.
  final double centerX;
  final double readyY;
  final double exitY;
  final double gravity;
  final double minimumSpeed;
  final double maximumSpeed;

  double launchVelocityY(double power) {
    if (!power.isFinite) throw ArgumentError.value(power, 'power');
    final normalized = power.clamp(0.0, 1.0).toDouble();
    return -(minimumSpeed + (maximumSpeed - minimumSpeed) * normalized);
  }

  /// Integrates travel inside the tube analytically, avoiding frame-rate drift.
  /// A weak plunge is recaptured at the plunger without consuming a ball.
  ShooterStep advance({
    required double y,
    required double velocityY,
    required double dt,
  }) {
    if (!y.isFinite || !velocityY.isFinite || !dt.isFinite || dt < 0) {
      throw ArgumentError('Shooter requires finite state and nonnegative dt.');
    }
    // Solve the FIRST ascending crossing inside the frame. Checking only the
    // frame endpoint misses near-threshold shots that clear the exit and turn
    // around before the next frame. It also gives the wrong exit speed when
    // a ball is clamped to exitY after crossing early in the frame.
    if (velocityY < 0 && y >= exitY && dt > 0) {
      final distanceToExit = y - exitY;
      final discriminant =
          velocityY * velocityY - 2 * gravity * distanceToExit;
      if (discriminant >= 0) {
        final exitSpeed = math.sqrt(discriminant);
        final timeToExit = (-velocityY - exitSpeed) / gravity;
        if (timeToExit >= 0 && timeToExit <= dt) {
          return ShooterStep(
            exitY,
            -exitSpeed,
            ShooterPhase.exited,
            remainingDt: math.max(0, dt - timeToExit),
          );
        }
      }
    }
    final nextY = y + velocityY * dt + 0.5 * gravity * dt * dt;
    final nextVelocity = velocityY + gravity * dt;
    if (nextVelocity >= 0 && nextY >= readyY) {
      return ShooterStep(readyY, 0, ShooterPhase.rearmed);
    }
    return ShooterStep(nextY, nextVelocity, ShooterPhase.traveling);
  }
}
