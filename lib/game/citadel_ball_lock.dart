import 'dart:ui';

/// The physical ball-lock geometry for Chrono Citadel. All measurements use
/// the game's 400 x 760 top-down world coordinates, not raster image pixels.
/// Runtime collision and visible housing share these fixed landmarks.
class CitadelBallLock {
  const CitadelBallLock._();

  static const Offset mouth = Offset(198, 505);
  static const double mouthRadius = 21;
  static const double minimumCaptureVelocityY = 90;
  static const int capacity = 2;
  static const int lockPoints = 300;
  static const int releasePoints = 1500;

  static const double period = 4.8;
  static const double closedSeconds = 2.8;
  static const Offset gateA = Offset(127, 457);
  static const Offset gateB = Offset(273, 457);

  static const Rect lockVisualRect = Rect.fromLTWH(152, 477, 92, 92);
  static const Rect gateVisualRect = Rect.fromLTWH(116, 438, 168, 40);

  static const List<Offset> releasedPositions = <Offset>[
    Offset(162, 524), Offset(234, 524),
  ];
  static const List<Offset> releasedVelocities = <Offset>[
    Offset(-470, -485), Offset(470, -485),
  ];

  /// The gate collider exists only during the closed portion of its cycle.
  static bool isGateClosed(double elapsed) =>
      elapsed % period < closedSeconds;

  /// Only a genuine descending ball in the unobstructed mouth can lock.
  /// An already-released vault must not generate free replacement balls.
  static bool canCapture({
    required Offset position,
    required Offset velocity,
    required double elapsed,
    required int lockedBalls,
    required bool alreadyReleased,
  }) =>
      !alreadyReleased &&
      lockedBalls >= 0 &&
      lockedBalls < capacity &&
      !isGateClosed(elapsed) &&
      velocity.dy > minimumCaptureVelocityY &&
      (position - mouth).distance <= mouthRadius;

  /// Release requires the *same physical gate collider* to have been hit by
  /// the third ball; neither a score threshold nor a fake timer triggers it.
  static bool canRelease({
    required bool actualGateContact,
    required double elapsed,
    required int lockedBalls,
    required bool alreadyReleased,
  }) =>
      actualGateContact &&
      isGateClosed(elapsed) &&
      lockedBalls == capacity &&
      !alreadyReleased;
}