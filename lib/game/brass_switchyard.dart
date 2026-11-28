import 'dart:math' as math;
import 'dart:ui';

/// A two-lane elevated switchyard, with actual gates and paths on the Brass
/// Labyrinth table. All coordinates match the exported 2D mechanical sprites.
/// Phase 0..3.2: LEFT tunnel open; 3.2..6.4: RIGHT tunnel open.
class BrassSwitchyard {
  const BrassSwitchyard._();

  static const double cycleSeconds = 6.4;
  static const double swapSeconds = 3.2;
  static const double crossingY = 375;
  static const double travelSpeed = 310;
  static const double cooldownSeconds = 0.9;
  static const int closedGatePoints = 125;
  static const int leftExitPoints = 650;
  static const int rightExitPoints = 850;
  static const double entranceHalfWidth = 11.5;
  static const double minimumEntrySpeed = 140;

  static const Offset leftEntrance = Offset(176, 375);
  static const Offset rightEntrance = Offset(226, 375);
  static const Offset leftGateA = Offset(157, 375);
  static const Offset leftGateB = Offset(196, 375);
  static const Offset rightGateA = Offset(207, 375);
  static const Offset rightGateB = Offset(246, 375);
  static const Rect leftGateArtwork = Rect.fromLTWH(146, 355, 60, 40);
  static const Rect rightGateArtwork = Rect.fromLTWH(196, 355, 60, 40);
  static const Offset leftExitVelocity = Offset(-185, 255);
  static const Offset rightExitVelocity = Offset(175, 260);

  static const List<Offset> leftPath = <Offset>[
    Offset(176, 375),
    Offset(175.929, 375.957),
    Offset(175.875, 377.141),
    Offset(175.828, 378.523),
    Offset(175.778, 380.074),
    Offset(175.714, 381.764),
    Offset(175.625, 383.562),
    Offset(175.502, 385.441),
    Offset(175.333, 387.37),
    Offset(175.109, 389.32),
    Offset(174.819, 391.262),
    Offset(174.453, 393.165),
    Offset(174, 395),
    Offset(173.456, 396.834),
    Offset(172.831, 398.741),
    Offset(172.133, 400.703),
    Offset(171.37, 402.704),
    Offset(170.552, 404.725),
    Offset(169.688, 406.75),
    Offset(168.784, 408.761),
    Offset(167.852, 410.741),
    Offset(166.898, 412.672),
    Offset(165.933, 414.537),
    Offset(164.964, 416.319),
    Offset(164, 418),
    Offset(162.987, 419.585),
    Offset(161.88, 421.095),
    Offset(160.703, 422.539),
    Offset(159.482, 423.926),
    Offset(158.239, 425.264),
    Offset(157, 426.562),
    Offset(155.789, 427.83),
    Offset(154.63, 429.074),
    Offset(153.547, 430.305),
    Offset(152.565, 431.53),
    Offset(151.708, 432.759),
    Offset(151, 434),
    Offset(150.493, 435.23),
    Offset(150.192, 436.426),
    Offset(150.055, 437.594),
    Offset(150.037, 438.741),
    Offset(150.096, 439.874),
    Offset(150.188, 441),
    Offset(150.269, 442.126),
    Offset(150.296, 443.259),
    Offset(150.227, 444.406),
    Offset(150.016, 445.574),
    Offset(149.622, 446.77),
    Offset(149, 448),
    Offset(148.17, 449.289),
    Offset(147.19, 450.644),
    Offset(146.078, 452.047),
    Offset(144.852, 453.481),
    Offset(143.528, 454.93),
    Offset(142.125, 456.375),
    Offset(140.659, 457.799),
    Offset(139.148, 459.185),
    Offset(137.609, 460.516),
    Offset(136.06, 461.773),
    Offset(134.518, 462.94),
    Offset(133, 464),
    Offset(131.47, 464.934),
    Offset(129.887, 465.75),
    Offset(128.258, 466.469),
    Offset(126.593, 467.111),
    Offset(124.9, 467.698),
    Offset(123.188, 468.25),
    Offset(121.465, 468.788),
    Offset(119.741, 469.333),
    Offset(118.023, 469.906),
    Offset(116.322, 470.528),
    Offset(114.644, 471.219),
    Offset(113, 472),
    Offset(111.321, 472.898),
    Offset(109.556, 473.907),
    Offset(107.734, 475),
    Offset(105.889, 476.148),
    Offset(104.05, 477.324),
    Offset(102.25, 478.5),
    Offset(100.519, 479.648),
    Offset(98.8889, 480.741),
    Offset(97.3906, 481.75),
    Offset(96.0556, 482.648),
    Offset(94.9149, 483.407),
    Offset(94, 484),
  ];
  static const List<Offset> rightPath = <Offset>[
    Offset(226, 375),
    Offset(226.071, 375.963),
    Offset(226.125, 377.164),
    Offset(226.172, 378.57),
    Offset(226.222, 380.148),
    Offset(226.286, 381.865),
    Offset(226.375, 383.688),
    Offset(226.498, 385.583),
    Offset(226.667, 387.519),
    Offset(226.891, 389.461),
    Offset(227.181, 391.377),
    Offset(227.547, 393.235),
    Offset(228, 395),
    Offset(228.556, 396.731),
    Offset(229.215, 398.5),
    Offset(229.961, 400.297),
    Offset(230.778, 402.111),
    Offset(231.65, 403.932),
    Offset(232.562, 405.75),
    Offset(233.499, 407.554),
    Offset(234.444, 409.333),
    Offset(235.383, 411.078),
    Offset(236.299, 412.778),
    Offset(237.176, 414.422),
    Offset(238, 416),
    Offset(238.807, 417.508),
    Offset(239.639, 418.956),
    Offset(240.484, 420.352),
    Offset(241.333, 421.704),
    Offset(242.175, 423.021),
    Offset(243, 424.312),
    Offset(243.797, 425.587),
    Offset(244.556, 426.852),
    Offset(245.266, 428.117),
    Offset(245.917, 429.391),
    Offset(246.498, 430.683),
    Offset(247, 432),
    Offset(247.364, 433.333),
    Offset(247.565, 434.667),
    Offset(247.641, 436),
    Offset(247.63, 437.333),
    Offset(247.57, 438.667),
    Offset(247.5, 440),
    Offset(247.458, 441.333),
    Offset(247.482, 442.667),
    Offset(247.609, 444),
    Offset(247.88, 445.333),
    Offset(248.33, 446.667),
    Offset(249, 448),
    Offset(249.888, 449.352),
    Offset(250.954, 450.736),
    Offset(252.172, 452.141),
    Offset(253.518, 453.556),
    Offset(254.969, 454.971),
    Offset(256.5, 456.375),
    Offset(258.086, 457.759),
    Offset(259.704, 459.111),
    Offset(261.328, 460.422),
    Offset(262.935, 461.681),
    Offset(264.501, 462.877),
    Offset(266, 464),
    Offset(267.459, 465.043),
    Offset(268.919, 466.014),
    Offset(270.383, 466.922),
    Offset(271.852, 467.778),
    Offset(273.328, 468.592),
    Offset(274.812, 469.375),
    Offset(276.308, 470.137),
    Offset(277.815, 470.889),
    Offset(279.336, 471.641),
    Offset(280.873, 472.403),
    Offset(282.427, 473.186),
    Offset(284, 474),
    Offset(285.66, 474.865),
    Offset(287.449, 475.782),
    Offset(289.328, 476.734),
    Offset(291.259, 477.704),
    Offset(293.204, 478.673),
    Offset(295.125, 479.625),
    Offset(296.983, 480.542),
    Offset(298.741, 481.407),
    Offset(300.359, 482.203),
    Offset(301.801, 482.912),
    Offset(303.027, 483.517),
    Offset(304, 484),
  ];
  static bool leftOpen(double elapsed) => elapsed % cycleSeconds < swapSeconds;
  static int openSide(double elapsed) => leftOpen(elapsed) ? 0 : 1;
  static Offset gateA(int side) => side == 0 ? leftGateA : rightGateA;
  static Offset gateB(int side) => side == 0 ? leftGateB : rightGateB;
  static Offset entrance(int side) => side == 0 ? leftEntrance : rightEntrance;
  static Offset exit(int side) => side == 0 ? leftPath.last : rightPath.last;
  static Offset exitVelocity(int side) =>
      side == 0 ? leftExitVelocity : rightExitVelocity;
  static int exitPoints(int side) =>
      side == 0 ? leftExitPoints : rightExitPoints;
  static List<Offset> path(int side) => side == 0 ? leftPath : rightPath;
  static double length(int side) => _pathLength(path(side));

  /// Returns a lane index ONLY when a real moving ball crosses the entrance
  /// from the upper field. Backwards travel, a closed gate, cooldown, or a
  /// nearby miss must never teleport the ball into a raised tunnel.
  static int? detectEntry({
    required Offset previous,
    required Offset current,
    required Offset velocity,
    required double elapsed,
    required double cooldown,
  }) {
    if (cooldown > 0 || velocity.dy < minimumEntrySpeed ||
        previous.dy > crossingY || current.dy < crossingY ||
        current.dy <= previous.dy) {
      return null;
    }
    final fraction = (crossingY - previous.dy) /
        (current.dy - previous.dy);
    if (fraction < 0 || fraction > 1) return null;
    final atGateX = previous.dx +
        (current.dx - previous.dx) * fraction;
    final open = openSide(elapsed);
    return (atGateX - entrance(open).dx).abs() <= entranceHalfWidth
        ? open
        : null;
  }

  /// Deterministic arc-length interpolation so each of the 85 sprite path
  /// waypoints matches the actual ball position at every supported tick rate.
  static SwitchyardStep advance(int side, double oldDistance, double dt) {
    final total = length(side);
    final traveled = math.min(total,
        math.max(0, oldDistance) + math.max(0, dt) * travelSpeed);
    final route = path(side);
    if (traveled >= total) {
      return SwitchyardStep(distance: total, position: route.last, finished: true);
    }
    var traversed = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i], b = route[i + 1];
      final segmentLength = (b - a).distance;
      if (traversed + segmentLength >= traveled) {
        final t = segmentLength < 1e-8 ? 0.0 :
            ((traveled - traversed) / segmentLength).clamp(0.0, 1.0).toDouble();
        return SwitchyardStep(
          distance: traveled,
          position: Offset.lerp(a, b, t)!,
          finished: false,
        );
      }
      traversed += segmentLength;
    }
    return SwitchyardStep(distance: total, position: route.last, finished: true);
  }

  static double _pathLength(List<Offset> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += (route[i] - route[i - 1]).distance;
    }
    return total;
  }
}

class SwitchyardStep {
  const SwitchyardStep({
    required this.distance,
    required this.position,
    required this.finished,
  });
  final double distance;
  final Offset position;
  final bool finished;
}