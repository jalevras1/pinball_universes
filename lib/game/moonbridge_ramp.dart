import 'dart:math' as math;
import 'dart:ui';

/// Deterministic, measurable elevated ramp on Moonfall Sanctuary.
///
/// The matching transparent sprite is rendered on the entire 400x760 board
/// at 3x resolution. Its centerline is sampled with this exact spline.
/// No underlying table rail, bumper or well contacts are simulated while a
/// ball is on this raised track.
class MoonbridgeRamp {
  MoonbridgeRamp._();

  static const double entranceRadius = 16;
  static const double minimumUpwardSpeed = 100;
  static const double travelSpeed = 470;
  static const double cooldownSeconds = 1.1;
  static const int exitBonus = 700;
  static const Offset exitVelocity = Offset(-145, 260);

  // Centers authored in game coordinates, NOT screen pixel coordinates.
  // Correspond exactly to build_moonbridge.py and manifest.json.
  static const List<Offset> controlPoints = <Offset>[
    Offset(290, 518),
    Offset(282, 493),
    Offset(274, 468),
    Offset(261, 434),
    Offset(251, 397),
    Offset(242, 357),
    Offset(221, 318),
    Offset(193, 290),
    Offset(160, 275),
    Offset(128, 275),
    Offset(100, 291),
    Offset(81, 318),
    Offset(78, 332),
  ];

  static final List<Offset> centerline = _sampleControlPoints();
  static final List<double> _cumulative = _cumulativeDistances(centerline);
  static double get length => _cumulative.last;
  static Offset get entrance => centerline.first;
  static Offset get exit => centerline.last;

  static bool canEnter(
    Offset position,
    Offset velocity, {
    double cooldown = 0,
  }) =>
      cooldown <= 0 &&
      velocity.dy <= -minimumUpwardSpeed &&
      (position - entrance).distance <= entranceRadius;

  static RampMovement advance(double previousDistance, double dt) {
    assert(previousDistance >= 0);
    assert(dt >= 0);
    final nextDistance = math.min(length, previousDistance + dt * travelSpeed);
    if (nextDistance >= length) {
      return RampMovement(exit, length, true);
    }
    var high = 1;
    while (high < _cumulative.length && _cumulative[high] < nextDistance) {
      high++;
    }
    final low = high - 1;
    final edge = _cumulative[high] - _cumulative[low];
    final fraction = edge <= 0 ? 0.0 : (nextDistance - _cumulative[low]) / edge;
    return RampMovement(
      Offset.lerp(centerline[low], centerline[high], fraction)!,
      nextDistance,
      false,
    );
  }

  static List<Offset> _sampleControlPoints() {
    final result = <Offset>[];
    for (var i = 0; i < controlPoints.length - 1; i++) {
      final p0 = controlPoints[math.max(0, i - 1)];
      final p1 = controlPoints[i];
      final p2 = controlPoints[i + 1];
      final p3 = controlPoints[math.min(controlPoints.length - 1, i + 2)];
      for (var j = 0; j < 8; j++) {
        final t = j / 8;
        final t2 = t * t;
        final t3 = t2 * t;
        double coordinate(double a, double b, double c, double d) =>
            0.5 * (2 * b + (-a + c) * t +
                (2 * a - 5 * b + 4 * c - d) * t2 +
                (-a + 3 * b - 3 * c + d) * t3);
        double round3(double v) => (v * 1000).round() / 1000;
        result.add(Offset(
          round3(coordinate(p0.dx, p1.dx, p2.dx, p3.dx)),
          round3(coordinate(p0.dy, p1.dy, p2.dy, p3.dy)),
        ));
      }
    }
    result.add(controlPoints.last);
    return List<Offset>.unmodifiable(result);
  }

  static List<double> _cumulativeDistances(List<Offset> path) {
    final result = <double>[0];
    for (var i = 1; i < path.length; i++) {
      result.add(result.last + (path[i] - path[i - 1]).distance);
    }
    return List<double>.unmodifiable(result);
  }
}

class RampMovement {
  const RampMovement(this.position, this.distance, this.finished);

  final Offset position;
  final double distance;
  final bool finished;
}