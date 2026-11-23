import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/machine_blueprints.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  test('exact 2:3 illustrated artwork is fitted without crop or distortion', () {
    expect(machineArtworkRect.width / machineArtworkRect.height,
        closeTo(machineSourceSize.width / machineSourceSize.height, 1e-9));
    expect(machinePoint(const Offset(0, 0)), machineArtworkRect.topLeft);
    expect(machinePoint(const Offset(1024, 1536)), machineArtworkRect.bottomRight);
  });

  test('each flagship has individual art-aligned physical target and wall map', () {
    final selected = <PinballTableId>[
      PinballTableId.astralOrrery,
      PinballTableId.circuitVelocity,
      PinballTableId.grandMechanism,
    ];
    final expectedTargets = <int>[3, 6, 8];
    for (var i = 0; i < selected.length; i++) {
      final machine = flagshipMachineBlueprint(selected[i]);
      expect(machine, isNotNull);
      final blueprint = machine!;
      expect(blueprint.targets.length, expectedTargets[i]);
      expect(blueprint.worldWallSegments.length, greaterThan(20));
      expect(blueprint.shooterWorld.dx, greaterThan(360));
      expect(blueprint.leftFlipperWorld.dx, lessThan(160));
      expect(blueprint.rightFlipperWorld.dx, greaterThan(260));
      expect(blueprint.drainWorldY, greaterThan(650));
      for (final target in blueprint.targets) {
        expect(target.worldRadius, greaterThan(5));
        expect(machineArtworkRect.contains(target.worldCenter), true);
      }
      for (final (a, b) in blueprint.worldWallSegments) {
        expect(machineArtworkRect.inflate(1).contains(a), true);
        expect(machineArtworkRect.inflate(1).contains(b), true);
        expect((a - b).distance, greaterThan(0.01));
        expect((a - b).distance.isFinite, true);
      }
      expect(blueprint.flipperLength.isFinite, true);
      expect(blueprint.flipperLength, greaterThan(50));
      expect(blueprint.flipperLength, lessThan(90));
    }
    expect(flagshipMachineBlueprint(PinballTableId.moonfallSanctuary), isNull);
    expect(flagshipMachineBlueprint(PinballTableId.quantumGrid), isNull);
    expect(flagshipMachineBlueprint(PinballTableId.chronoCitadel), isNull);
  });

  test('source illustrated targets match key measured physical landmarks', () {
    final celestialBumper = celestialMachine.targets[2].worldCenter;
    final neonReactor = neonMachine.targets.last.worldCenter;
    final clock = clockworkMachine.targets[3].worldCenter;
    expect(celestialBumper.dx, closeTo(197, 1));
    expect(neonReactor.dx, closeTo(200, 1));
    expect(clock.dx, closeTo(201, 1));
    expect(celestialBumper.dy, lessThan(neonReactor.dy));
    expect(clock.dy, lessThan(neonReactor.dy));
    // Machine landmarks are finite and remain in the simulation viewport.
    for (final landmark in [celestialBumper, neonReactor, clock]) {
      expect(landmark.dx.isFinite && landmark.dy.isFinite, true);
      expect(math.max(landmark.dx, landmark.dy), lessThan(760));
    }
  });
}
