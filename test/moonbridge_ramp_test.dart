import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/moonbridge_ramp.dart';
import 'package:premium_pinball/game/developer_scenarios.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PNG overlays are actually bundled at mobile resolution', () async {
    for (final state in <String>['idle', 'active']) {
      final bytes = await rootBundle.load(
        'assets/gameplay/mechanical/moonbridge_ramp_$state.png',
      );
      expect(bytes.lengthInBytes, greaterThan(10000));
      expect(bytes.getUint32(0), 0x89504e47);
      expect(bytes.getUint32(16), 600);
      expect(bytes.getUint32(20), 1140);
    }
  });

  test('Artwork manifest and simulated spline share every measured waypoint', () {
    final raw = File('tool/mechanical_candidates/batch_021_manifest.json')
        .readAsStringSync();
    final manifest = jsonDecode(raw) as Map<String, dynamic>;
    final artworkPath = manifest['curve_world'] as List<dynamic>;
    expect(artworkPath.length, MoonbridgeRamp.centerline.length);
    for (var i = 0; i < artworkPath.length; i++) {
      final coords = artworkPath[i] as List<dynamic>;
      final physics = MoonbridgeRamp.centerline[i];
      expect(physics.dx, closeTo((coords[0] as num).toDouble(), 0.0011),
          reason: 'x at waypoint $i');
      expect(physics.dy, closeTo((coords[1] as num).toDouble(), 0.0011),
          reason: 'y at waypoint $i');
    }
  });

  test('Ramp path exactly spans the authored sprite endpoints', () {
    expect(MoonbridgeRamp.centerline.length, 97);
    expect(MoonbridgeRamp.entrance, const Offset(290, 518));
    expect(MoonbridgeRamp.exit, const Offset(78, 332));
    expect(MoonbridgeRamp.length, closeTo(401.4, 0.2));
    for (final p in MoonbridgeRamp.centerline) {
      expect(p.dx, inInclusiveRange(45, 325));
      expect(p.dy, inInclusiveRange(255, 545));
    }
  });

  test('Capture requires an upward hit and respects recapture cooldown', () {
    expect(MoonbridgeRamp.canEnter(
      const Offset(290, 530), const Offset(0, -420)), isTrue);
    expect(MoonbridgeRamp.canEnter(
      const Offset(290, 530), const Offset(0, 420)), isFalse);
    expect(MoonbridgeRamp.canEnter(
      const Offset(290, 530), const Offset(0, -50)), isFalse);
    expect(MoonbridgeRamp.canEnter(
      const Offset(260, 530), const Offset(0, -420)), isFalse);
    expect(MoonbridgeRamp.canEnter(
      const Offset(290, 530), const Offset(0, -420), cooldown: 0.5), isFalse);
  });

  test('Elevated movement is time-step invariant and exits only at end', () {
    final elapsed = MoonbridgeRamp.length / MoonbridgeRamp.travelSpeed;
    for (final hz in <int>[30, 60, 120, 240]) {
      var traveled = 0.0;
      RampMovement? step;
      for (var i = 0; i < hz; i++) {
        step = MoonbridgeRamp.advance(traveled, 1 / hz);
        traveled = step.distance;
        if (i / hz < elapsed - 1 / hz) {
          expect(step.finished, isFalse, reason: '$hz Hz at frame $i');
        }
      }
      expect(step!.finished, isTrue);
      expect(step.position, MoonbridgeRamp.exit);
      expect(traveled, MoonbridgeRamp.length);
    }
  });

  test('Moonfall ball travels the real overpass without ghost collisions', () {
    final game = PinballGame(
      table: tableById(PinballTableId.moonfallSanctuary),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.debugPlaceBall(const Offset(290, 529), const Offset(0, -480));
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallInMoonbridge, isTrue);
    expect(game.hud.value.score, 0);
    var crossings = 0;
    while (game.debugBallInMoonbridge && crossings < 160) {
      game.debugStepPhysics(1 / 120);
      crossings++;
      // Underpass rails and bumpers cannot impact a ball currently above them.
      if (game.debugBallInMoonbridge) expect(game.hud.value.score, 0);
    }
    expect(crossings, greaterThan(80));
    expect(game.debugBallInMoonbridge, isFalse);
    expect(game.debugBallPositions.single, MoonbridgeRamp.exit);
    expect(game.debugBallVelocities.single, MoonbridgeRamp.exitVelocity);
    expect(game.hud.value.score, MoonbridgeRamp.exitBonus);
    game.debugStepPhysics(1 / 120);
    expect(game.hud.value.score, MoonbridgeRamp.exitBonus);
    game.hud.dispose();
  });

  test('developer shortcut enters the real ramp and awards only on exit', () {
    final game = PinballGame(
      table: tableById(PinballTableId.moonfallSanctuary),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    expect(game.runDeveloperScenario(PinballDeveloperScenario.moonbridgeRamp),
        isTrue);
    expect(game.hud.value.score, 0);
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallInMoonbridge, isTrue);
    expect(game.developerEvents.value.any((e) => e.contains('CAPTURE')), isTrue);
    for (var i = 0; i < 160 && game.debugBallInMoonbridge; i++) {
      game.debugStepPhysics(1 / 120);
    }
    expect(game.debugBallInMoonbridge, isFalse);
    expect(game.hud.value.score, MoonbridgeRamp.exitBonus);
    expect(game.developerEvents.value.any((e) => e.contains('RAMP')), isTrue);
    game.hud.dispose();
    game.developerEvents.dispose();
  });

  test('Downward ball is not sucked into the elevated ramp entrance', () {
    final game = PinballGame(
      table: tableById(PinballTableId.moonfallSanctuary),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.debugPlaceBall(const Offset(290, 518), const Offset(0, 350));
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallInMoonbridge, isFalse);
    game.hud.dispose();
  });

  test('Other boards retain their original collision routes', () {
    for (final id in <PinballTableId>[
      PinballTableId.astralOrrery,
      PinballTableId.circuitVelocity,
    ]) {
      final game = PinballGame(table: tableById(id), onGameFinished: (_) {});
      game.debugInitializePhysics();
      game.debugPlaceBall(const Offset(290, 529), const Offset(0, -480));
      game.debugStepPhysics(1 / 120);
      expect(game.debugBallInMoonbridge, isFalse);
      game.hud.dispose();
    }
  });
}