import 'dart:ui';

import 'table_data.dart';

/// The three illustrated arcade machines have 1024x1536 reference art.
///
/// All physical landmarks below are traced in ORIGINAL ART PIXELS. Rendering
/// and physics share this one transform, so moving a collider cannot silently
/// break the visible alignment. The machine is fitted without distortion into
/// a 400x600 rectangle, centred vertically in the 400x760 simulation viewport.
const Rect machineArtworkRect = Rect.fromLTWH(0, 80, 400, 600);
const Size machineSourceSize = Size(1024, 1536);

Offset machinePoint(Offset sourcePoint) => Offset(
  machineArtworkRect.left + sourcePoint.dx * machineArtworkRect.width / machineSourceSize.width,
  machineArtworkRect.top + sourcePoint.dy * machineArtworkRect.height / machineSourceSize.height,
);

class MachineTarget {
  const MachineTarget(this.center, this.radius, this.score);

  /// Center and radius in 1024x1536 source-art pixel coordinates.
  final Offset center;
  final double radius;
  final int score;

  Offset get worldCenter => machinePoint(center);
  double get worldRadius => radius * machineArtworkRect.width / machineSourceSize.width;
}

class MachineBlueprint {
  const MachineBlueprint({
    required this.artAsset,
    required this.leftPivot,
    required this.rightPivot,
    required this.flipperLength,
    required this.shooterBall,
    required this.drainY,
    required this.wallPaths,
    required this.targets,
    required this.signatureCenter,
  });

  final String artAsset;
  final Offset leftPivot;
  final Offset rightPivot;
  final double flipperLength;
  final Offset shooterBall;
  final double drainY;

  /// Painted guard edges, ramp rims, and slingshot faces, in reference pixels.
  /// A path is a series of connected collision segments, not an opaque polygon.
  final List<List<Offset>> wallPaths;
  final List<MachineTarget> targets;
  final Offset signatureCenter;

  Offset get leftFlipperWorld => machinePoint(leftPivot);
  Offset get rightFlipperWorld => machinePoint(rightPivot);
  Offset get shooterWorld => machinePoint(shooterBall);
  Offset get signatureWorld => machinePoint(signatureCenter);
  double get drainWorldY => machinePoint(Offset(0, drainY)).dy;

  Iterable<(Offset, Offset)> get worldWallSegments sync* {
    for (final path in wallPaths) {
      for (var i = 0; i + 1 < path.length; i++) {
        yield (machinePoint(path[i]), machinePoint(path[i + 1]));
      }
    }
  }
}

/// Flagship machine references. The other six tables retain their existing
/// independent gameplay layouts until bespoke, QA-tested artwork is available.
/// This avoids claiming those layouts have already been matched to art.
MachineBlueprint? flagshipMachineBlueprint(PinballTableId table) =>
    switch (table) {
      PinballTableId.astralOrrery => celestialMachine,
      PinballTableId.circuitVelocity => neonMachine,
      PinballTableId.grandMechanism => clockworkMachine,
      _ => null,
    };

const celestialMachine = MachineBlueprint(
  artAsset: 'assets/machines/celestial_orrery.png',
  leftPivot: Offset(256, 1310), rightPivot: Offset(746, 1310),
  flipperLength: 65,
  shooterBall: Offset(955, 1325), drainY: 1515,
  signatureCenter: Offset(510, 236),
  targets: <MachineTarget>[
    MachineTarget(Offset(400, 475), 54, 500),
    MachineTarget(Offset(603, 480), 54, 500),
    MachineTarget(Offset(504, 585), 57, 850),
  ],
  wallPaths: <List<Offset>>[
    // Painted outer cabinet and the independent right shooter channel.
    <Offset>[Offset(45, 1130), Offset(39, 790), Offset(46, 347), Offset(60, 178), Offset(145, 64)],
    <Offset>[Offset(145, 64), Offset(510, 27), Offset(870, 65), Offset(906, 175)],
    <Offset>[Offset(906, 175), Offset(910, 750), Offset(900, 1115), Offset(843, 1230)],
    <Offset>[Offset(913, 560), Offset(913, 1445)],
    <Offset>[Offset(987, 140), Offset(987, 1450)],
    // Left and right outer return lanes and the sweep toward the drain.
    <Offset>[Offset(48, 1120), Offset(104, 1226), Offset(188, 1277), Offset(214, 1355)],
    <Offset>[Offset(900, 1120), Offset(846, 1228), Offset(808, 1317)],
    <Offset>[Offset(72, 1310), Offset(205, 1453), Offset(418, 1508)],
    <Offset>[Offset(834, 1310), Offset(803, 1453), Offset(608, 1508)],
    // The two painted crescent-shaped upper ramp guard edges.
    <Offset>[Offset(92, 268), Offset(130, 185), Offset(223, 129), Offset(306, 139), Offset(316, 232)],
    <Offset>[Offset(109, 446), Offset(183, 380), Offset(260, 319), Offset(297, 250)],
    <Offset>[Offset(760, 191), Offset(839, 136), Offset(921, 173), Offset(938, 289)],
    <Offset>[Offset(772, 444), Offset(838, 402), Offset(874, 350)],
    // Orbital platform braces and V-shaped slingshots visible on the art.
    <Offset>[Offset(358, 369), Offset(510, 416), Offset(676, 373)],
    <Offset>[Offset(147, 981), Offset(169, 1094), Offset(306, 1168)],
    <Offset>[Offset(843, 981), Offset(820, 1094), Offset(694, 1168)],
  ],
);

const neonMachine = MachineBlueprint(
  artAsset: 'assets/machines/neon_velocity.png',
  leftPivot: Offset(255, 1296), rightPivot: Offset(762, 1296),
  flipperLength: 75,
  shooterBall: Offset(952, 1345), drainY: 1500,
  signatureCenter: Offset(512, 762),
  targets: <MachineTarget>[
    MachineTarget(Offset(392, 219), 57, 550),
    MachineTarget(Offset(631, 219), 57, 550),
    MachineTarget(Offset(316, 347), 57, 500),
    MachineTarget(Offset(511, 378), 60, 750),
    MachineTarget(Offset(704, 347), 57, 500),
    MachineTarget(Offset(512, 761), 87, 1200),
  ],
  wallPaths: <List<Offset>>[
    <Offset>[Offset(34, 94), Offset(20, 390), Offset(24, 780), Offset(30, 1236), Offset(80, 1376)],
    <Offset>[Offset(34, 94), Offset(175, 25), Offset(510, 34), Offset(865, 25), Offset(988, 94)],
    <Offset>[Offset(985, 95), Offset(990, 1260), Offset(984, 1481)],
    <Offset>[Offset(914, 443), Offset(914, 1420)],
    // Cyan and magenta elevated S-loop ramp rims.
    <Offset>[Offset(63, 263), Offset(88, 154), Offset(193, 75), Offset(305, 90), Offset(341, 154)],
    <Offset>[Offset(89, 327), Offset(169, 418), Offset(247, 468), Offset(283, 535)],
    <Offset>[Offset(665, 136), Offset(707, 76), Offset(841, 68), Offset(936, 148)],
    <Offset>[Offset(738, 532), Offset(826, 464), Offset(913, 342)],
    // Four painted target bank frames and lower slingshot faces.
    <Offset>[Offset(147, 605), Offset(173, 819), Offset(244, 807)],
    <Offset>[Offset(878, 605), Offset(853, 819), Offset(781, 807)],
    <Offset>[Offset(194, 1013), Offset(168, 1160), Offset(284, 1194)],
    <Offset>[Offset(825, 1013), Offset(853, 1160), Offset(738, 1194)],
    <Offset>[Offset(37, 1250), Offset(182, 1398), Offset(402, 1480)],
    <Offset>[Offset(886, 1250), Offset(824, 1398), Offset(621, 1480)],
  ],
);

const clockworkMachine = MachineBlueprint(
  artAsset: 'assets/machines/clockwork_mechanism.png',
  leftPivot: Offset(300, 1305), rightPivot: Offset(730, 1305),
  flipperLength: 66,
  shooterBall: Offset(943, 1305), drainY: 1510,
  signatureCenter: Offset(515, 407),
  targets: <MachineTarget>[
    MachineTarget(Offset(359, 206), 64, 700),
    MachineTarget(Offset(514, 129), 62, 800),
    MachineTarget(Offset(668, 205), 64, 700),
    MachineTarget(Offset(515, 408), 149, 1100),
    MachineTarget(Offset(350, 809), 37, 400),
    MachineTarget(Offset(515, 762), 38, 500),
    MachineTarget(Offset(677, 809), 37, 400),
    MachineTarget(Offset(514, 994), 67, 1000),
  ],
  wallPaths: <List<Offset>>[
    <Offset>[Offset(34, 83), Offset(24, 436), Offset(24, 1000), Offset(29, 1340), Offset(117, 1434)],
    <Offset>[Offset(34, 83), Offset(194, 35), Offset(512, 19), Offset(846, 35), Offset(988, 83)],
    <Offset>[Offset(988, 83), Offset(988, 1450)],
    <Offset>[Offset(905, 539), Offset(905, 1446)],
    // Visible giant brass C-ramp, top-left sweep and matching top-right loop.
    <Offset>[Offset(273, 48), Offset(118, 83), Offset(81, 178), Offset(128, 332), Offset(260, 407)],
    <Offset>[Offset(270, 315), Offset(169, 224), Offset(177, 136), Offset(274, 115)],
    <Offset>[Offset(747, 80), Offset(874, 95), Offset(939, 191), Offset(871, 315)],
    <Offset>[Offset(744, 337), Offset(819, 416), Offset(810, 558)],
    // Side lanes and gear-chamber shaped lower sling guards.
    <Offset>[Offset(62, 692), Offset(116, 859), Offset(208, 1029)],
    <Offset>[Offset(872, 692), Offset(820, 859), Offset(730, 1029)],
    <Offset>[Offset(236, 955), Offset(223, 1081), Offset(358, 1166)],
    <Offset>[Offset(791, 955), Offset(804, 1081), Offset(667, 1166)],
    <Offset>[Offset(80, 1300), Offset(185, 1390), Offset(399, 1469)],
    <Offset>[Offset(885, 1300), Offset(840, 1390), Offset(623, 1469)],
  ],
);
