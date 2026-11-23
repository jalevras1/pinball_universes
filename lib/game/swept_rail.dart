import 'dart:math' as math;

/// Earliest point at which a moving ball touches a stationary capsule rail.
/// All coordinates share the engine's logical 400x760 table space.
class SweptRailHit {
  const SweptRailHit(this.fraction, this.x, this.y, this.normalX, this.normalY);

  final double fraction;
  final double x;
  final double y;
  final double normalX;
  final double normalY;
}

/// Continuous circle-versus-segment contact: straight wall faces plus rounded
/// endpoints. An initial overlap is left to the engine's penetration solver.
SweptRailHit? sweepRail({
  required double fromX,
  required double fromY,
  required double toX,
  required double toY,
  required double ax,
  required double ay,
  required double bx,
  required double by,
  required double radius,
}) {
  final dx = toX - fromX;
  final dy = toY - fromY;
  final movementSq = dx * dx + dy * dy;
  if (movementSq < 1e-12 || radius <= 0) return null;

  SweptRailHit? earliest;
  void accept(double t, double x, double y, double nx, double ny) {
    if (!t.isFinite || t < 0 || t > 1) return;
    if (earliest != null && t >= earliest!.fraction) return;
    earliest = SweptRailHit(t, x, y, nx, ny);
  }

  final sx = bx - ax;
  final sy = by - ay;
  final length = math.sqrt(sx * sx + sy * sy);
  if (length > 1e-9) {
    final tx = sx / length;
    final ty = sy / length;
    final nx = -ty;
    final ny = tx;
    final d0 = (fromX - ax) * nx + (fromY - ay) * ny;
    final d1 = (toX - ax) * nx + (toY - ay) * ny;
    for (final side in <double>[-1, 1]) {
      // Starting inside a rail needs overlap recovery, not a fictitious TOI.
      if (side * d0 < radius || side * d1 >= side * d0) continue;
      final denominator = d1 - d0;
      if (denominator.abs() < 1e-12) continue;
      final t = (side * radius - d0) / denominator;
      if (t < 0 || t > 1) continue;
      final px = fromX + t * dx;
      final py = fromY + t * dy;
      final along = (px - ax) * tx + (py - ay) * ty;
      if (along >= 0 && along <= length) {
        accept(t, px, py, side * nx, side * ny);
      }
    }
  }

  // Rounded endpoints must also block corner tunneling.
  for (final endpoint in <(double, double)>[(ax, ay), (bx, by)]) {
    final ox = fromX - endpoint.$1;
    final oy = fromY - endpoint.$2;
    final c = ox * ox + oy * oy - radius * radius;
    if (c < 0) continue; // already overlapping at the start
    final b = 2 * (ox * dx + oy * dy);
    final discriminant = b * b - 4 * movementSq * c;
    if (b >= 0 || discriminant < 0) continue;
    final t = (-b - math.sqrt(discriminant)) / (2 * movementSq);
    if (t < 0 || t > 1) continue;
    final px = fromX + t * dx;
    final py = fromY + t * dy;
    final nx = (px - endpoint.$1) / radius;
    final ny = (py - endpoint.$2) / radius;
    accept(t, px, py, nx, ny);
  }
  return earliest;
}
