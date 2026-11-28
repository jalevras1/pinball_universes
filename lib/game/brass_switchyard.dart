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
    Offset(176.0000, 375.0000),
    Offset(175.9288, 375.9569),
    Offset(175.8750, 377.1412),
    Offset(175.8281, 378.5234),
    Offset(175.7778, 380.0741),
    Offset(175.7135, 381.7636),
    Offset(175.6250, 383.5625),
    Offset(175.5017, 385.4413),
    Offset(175.3333, 387.3704),
    Offset(175.1094, 389.3203),
    Offset(174.8194, 391.2616),
    Offset(174.4531, 393.1646),
    Offset(174.0000, 395.0000),
    Offset(173.4563, 396.8339),
    Offset(172.8310, 398.7407),
    Offset(172.1328, 400.7031),
    Offset(171.3704, 402.7037),
    Offset(170.5524, 404.7251),
    Offset(169.6875, 406.7500),
    Offset(168.7844, 408.7610),
    Offset(167.8519, 410.7407),
    Offset(166.8984, 412.6719),
    Offset(165.9329, 414.5370),
    Offset(164.9638, 416.3189),
    Offset(164.0000, 418.0000),
    Offset(162.9867, 419.5848),
    Offset(161.8796, 421.0949),
    Offset(160.7031, 422.5391),
    Offset(159.4815, 423.9259),
    Offset(158.2390, 425.2642),
    Offset(157.0000, 426.5625),
    Offset(155.7888, 427.8296),
    Offset(154.6296, 429.0741),
    Offset(153.5469, 430.3047),
    Offset(152.5648, 431.5301),
    Offset(151.7078, 432.7590),
    Offset(151.0000, 434.0000),
    Offset(150.4928, 435.2303),
    Offset(150.1921, 436.4259),
    Offset(150.0547, 437.5938),
    Offset(150.0370, 438.7407),
    Offset(150.0958, 439.8738),
    Offset(150.1875, 441.0000),
    Offset(150.2688, 442.1262),
    Offset(150.2963, 443.2593),
    Offset(150.2266, 444.4062),
    Offset(150.0162, 445.5741),
    Offset(149.6218, 446.7697),
    Offset(149.0000, 448.0000),
    Offset(148.1696, 449.2888),
    Offset(147.1898, 450.6435),
    Offset(146.0781, 452.0469),
    Offset(144.8519, 453.4815),
    Offset(143.5284, 454.9300),
    Offset(142.1250, 456.3750),
    Offset(140.6591, 457.7992),
    Offset(139.1481, 459.1852),
    Offset(137.6094, 460.5156),
    Offset(136.0602, 461.7731),
    Offset(134.5179, 462.9404),
    Offset(133.0000, 464.0000),
    Offset(131.4702, 464.9340),
    Offset(129.8866, 465.7500),
    Offset(128.2578, 466.4688),
    Offset(126.5926, 467.1111),
    Offset(124.8996, 467.6979),
    Offset(123.1875, 468.2500),
    Offset(121.4650, 468.7882),
    Offset(119.7407, 469.3333),
    Offset(118.0234, 469.9062),
    Offset(116.3218, 470.5278),
    Offset(114.6444, 471.2188),
    Offset(113.0000, 472.0000),
    Offset(111.3212, 472.8981),
    Offset(109.5556, 473.9074),
    Offset(107.7344, 475.0000),
    Offset(105.8889, 476.1481),
    Offset(104.0503, 477.3241),
    Offset(102.2500, 478.5000),
    Offset(100.5191, 479.6481),
    Offset(98.8889, 480.7407),
    Offset(97.3906, 481.7500),
    Offset(96.0556, 482.6481),
    Offset(94.9149, 483.4074),
    Offset(94.0000, 484.0000),
  ];
  static const List<Offset> rightPath = <Offset>[
    Offset(226.0000, 375.0000),
    Offset(226.0712, 375.9633),
    Offset(226.1250, 377.1644),
    Offset(226.1719, 378.5703),
    Offset(226.2222, 380.1481),
    Offset(226.2865, 381.8649),
    Offset(226.3750, 383.6875),
    Offset(226.4983, 385.5830),
    Offset(226.6667, 387.5185),
    Offset(226.8906, 389.4609),
    Offset(227.1806, 391.3773),
    Offset(227.5469, 393.2347),
    Offset(228.0000, 395.0000),
    Offset(228.5564, 396.7309),
    Offset(229.2153, 398.5000),
    Offset(229.9609, 400.2969),
    Offset(230.7778, 402.1111),
    Offset(231.6502, 403.9323),
    Offset(232.5625, 405.7500),
    Offset(233.4991, 407.5538),
    Offset(234.4444, 409.3333),
    Offset(235.3828, 411.0781),
    Offset(236.2986, 412.7778),
    Offset(237.1762, 414.4219),
    Offset(238.0000, 416.0000),
    Offset(238.8073, 417.5084),
    Offset(239.6389, 418.9560),
    Offset(240.4844, 420.3516),
    Offset(241.3333, 421.7037),
    Offset(242.1753, 423.0211),
    Offset(243.0000, 424.3125),
    Offset(243.7969, 425.5865),
    Offset(244.5556, 426.8519),
    Offset(245.2656, 428.1172),
    Offset(245.9167, 429.3912),
    Offset(246.4983, 430.6826),
    Offset(247.0000, 432.0000),
    Offset(247.3640, 433.3333),
    Offset(247.5648, 434.6667),
    Offset(247.6406, 436.0000),
    Offset(247.6296, 437.3333),
    Offset(247.5700, 438.6667),
    Offset(247.5000, 440.0000),
    Offset(247.4578, 441.3333),
    Offset(247.4815, 442.6667),
    Offset(247.6094, 444.0000),
    Offset(247.8796, 445.3333),
    Offset(248.3304, 446.6667),
    Offset(249.0000, 448.0000),
    Offset(249.8883, 449.3524),
    Offset(250.9537, 450.7361),
    Offset(252.1719, 452.1406),
    Offset(253.5185, 453.5556),
    Offset(254.9693, 454.9705),
    Offset(256.5000, 456.3750),
    Offset(258.0862, 457.7587),
    Offset(259.7037, 459.1111),
    Offset(261.3281, 460.4219),
    Offset(262.9352, 461.6806),
    Offset(264.5006, 462.8767),
    Offset(266.0000, 464.0000),
    Offset(267.4586, 465.0434),
    Offset(268.9190, 466.0139),
    Offset(270.3828, 466.9219),
    Offset(271.8519, 467.7778),
    Offset(273.3278, 468.5920),
    Offset(274.8125, 469.3750),
    Offset(276.3076, 470.1372),
    Offset(277.8148, 470.8889),
    Offset(279.3359, 471.6406),
    Offset(280.8727, 472.4028),
    Offset(282.4268, 473.1858),
    Offset(284.0000, 474.0000),
    Offset(285.6603, 474.8652),
    Offset(287.4491, 475.7824),
    Offset(289.3281, 476.7344),
    Offset(291.2593, 477.7037),
    Offset(293.2043, 478.6730),
    Offset(295.1250, 479.6250),
    Offset(296.9832, 480.5422),
    Offset(298.7407, 481.4074),
    Offset(300.3594, 482.2031),
    Offset(301.8009, 482.9120),
    Offset(303.0272, 483.5168),
    Offset(304.0000, 484.0000),
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