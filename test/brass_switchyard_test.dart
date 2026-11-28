import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/brass_switchyard.dart';
import 'package:premium_pinball/game/developer_scenarios.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the open shutter alternates at strict 3.2-second boundaries', () {
    expect(BrassSwitchyard.leftOpen(0), isTrue);
    expect(BrassSwitchyard.leftOpen(3.199), isTrue);
    expect(BrassSwitchyard.leftOpen(3.2), isFalse);
    expect(BrassSwitchyard.leftOpen(6.399), isFalse);
    expect(BrassSwitchyard.leftOpen(6.4), isTrue);
    expect(BrassSwitchyard.leftEntrance, const Offset(176, 375));
    expect(BrassSwitchyard.rightEntrance, const Offset(226, 375));
  });

  test('both geometry routes precisely follow the exported sprite coordinates', () {
    final manifest = jsonDecode(File(
      'tool/mechanical_candidates/batch_023_manifest.json',
    ).readAsStringSync()) as Map<String, dynamic>;
    final map = manifest['paths_world'] as Map<String, dynamic>;
    for (final side in <int>[0, 1]) {
      final label = side == 0 ? 'left' : 'right';
      final points = map[label] as List<dynamic>;
      final route = BrassSwitchyard.path(side);
      expect(route.length, 85);
      expect(points.length, route.length);
      for (var i = 0; i < route.length; i++) {
        final p = (points[i] as List<dynamic>).cast<num>();
        expect(route[i].dx, closeTo(p[0].toDouble(), .00011));
        expect(route[i].dy, closeTo(p[1].toDouble(), .00011));
      }
      expect(BrassSwitchyard.length(side), closeTo(
        (manifest['path_lengths'] as Map<String, dynamic>)[label] as num, .001));
      expect(BrassSwitchyard.exit(side), route.last);
    }
  });

  test('PNG sprites are transparent, correctly sized and bundled', () async {
    for (final name in <String>[
      'brass_switchyard_track.png',
      'brass_switchyard_left_active.png',
      'brass_switchyard_right_active.png',
      'brass_switchyard_gate_closed.png',
      'brass_switchyard_gate_open.png',
    ]) {
      final data = await rootBundle.load('assets/gameplay/mechanical/$name');
      expect(data.lengthInBytes, greaterThan(4000), reason: name);
      expect(data.getUint32(0), 0x89504e47);
      expect(data.getUint32(16), name.contains('gate_') ? 180 : 800);
      expect(data.getUint32(20), name.contains('gate_') ? 120 : 1520);
      expect(data.getUint8(25), 6, reason: 'Must be RGBA: $name');
    }
  });

  test('actual sweep crossing is required; closed lanes cannot capture', () {
    int? enter(Offset previous, Offset current, Offset v, double time,
        {double cooldown = 0}) => BrassSwitchyard.detectEntry(
          previous: previous, current: current, velocity: v,
          elapsed: time, cooldown: cooldown,
        );
    expect(enter(const Offset(176, 370), const Offset(176, 382),
        const Offset(0, 700), 0.8), 0);
    expect(enter(const Offset(226, 370), const Offset(226, 382),
        const Offset(0, 700), 4.0), 1);
    expect(enter(const Offset(226, 370), const Offset(226, 382),
        const Offset(0, 700), 0.8), isNull); // closed RIGHT gate
    expect(enter(const Offset(176, 370), const Offset(176, 382),
        const Offset(0, 700), 4.0), isNull); // closed LEFT gate
    expect(enter(const Offset(176, 382), const Offset(176, 370),
        const Offset(0, -700), 0.8), isNull);
    expect(enter(const Offset(160, 370), const Offset(160, 382),
        const Offset(0, 700), 0.8), isNull);
    expect(enter(const Offset(176, 370), const Offset(176, 382),
        const Offset(0, 70), 0.8), isNull);
    expect(enter(const Offset(176, 370), const Offset(176, 382),
        const Offset(0, 700), 0.8, cooldown: 0.3), isNull);
  });

  test('both raised routes have deterministic fixed-step travel and exit', () {
    for (final side in <int>[0,1]) {
      final targetDuration = BrassSwitchyard.length(side) /
          BrassSwitchyard.travelSpeed;
      for (final fps in <int>[30,60,120,240]) {
        var distance = 0.0;
        SwitchyardStep? last;
        for (var i=0; i<fps; i++) {
          last = BrassSwitchyard.advance(side, distance, 1/fps);
          distance = last.distance;
          if (i / fps < targetDuration - 1/fps) {
            expect(last.finished, isFalse);
          }
        }
        expect(last!.finished, isTrue);
        expect(last.position, BrassSwitchyard.exit(side));
        expect(distance, closeTo(BrassSwitchyard.length(side), .00001));
      }
    }
  });

  for (final side in <int>[0,1]) {
    test('real ball enters and exits ${side == 0 ? 'LEFT' : 'RIGHT'} tunnel', () {
      final game = PinballGame(
        table: tableById(PinballTableId.brassLabyrinth),
        onGameFinished: (_) {},
      );
      game.debugInitializePhysics();
      expect(game.runDeveloperScenario(
        side == 0 ? PinballDeveloperScenario.brassLeftRoute :
          PinballDeveloperScenario.brassRightRoute,
      ), isTrue);
      expect(game.hud.value.score, 0);
      for (var i=0; i<6 && !game.debugBallInSwitchyard; i++) {
        game.debugStepPhysics(1/120);
      }
      expect(game.debugBallInSwitchyard, isTrue);
      expect(game.hud.value.score, 0);
      for (var i=0; i<150 && game.debugBallInSwitchyard; i++) {
        game.debugStepPhysics(1/120);
        if (game.debugBallInSwitchyard) expect(game.hud.value.score, 0);
      }
      expect(game.debugBallInSwitchyard, isFalse);
      expect(game.debugSwitchyardLastExitSide, side);
      expect(game.debugBallPositions.single, BrassSwitchyard.exit(side));
      expect(game.debugBallVelocities.single, BrassSwitchyard.exitVelocity(side));
      expect(game.hud.value.score, BrassSwitchyard.exitPoints(side));
      game.debugStepPhysics(1/120);
      expect(game.hud.value.score, BrassSwitchyard.exitPoints(side));
      game.hud.dispose();
      game.developerEvents.dispose();
    });
  }

  test('closed right gate rebounds a real ball; no teleport or free score', () {
    final game = PinballGame(
      table: tableById(PinballTableId.brassLabyrinth),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    expect(game.runDeveloperScenario(PinballDeveloperScenario.brassLeftRoute),
        isTrue);
    // RIGHT gate is closed during the left phase. Its actual collision segment
    // rather than the sprite must reject this descending ball.
    game.debugPlaceBall(const Offset(226, 360), const Offset(0, 740));
    for (var i=0; i<10 && game.hud.value.score==0;i++) {
      game.debugStepPhysics(1/120);
    }
    expect(game.debugBallInSwitchyard, isFalse);
    expect(game.debugBallVelocities.single.dy, lessThan(0));
    expect(game.hud.value.score, BrassSwitchyard.closedGatePoints);
    game.hud.dispose(); game.developerEvents.dispose();
  });

  test('the switchyard remains disabled on all other nine-table variants', () {
    for (final table in pinballTables.where(
      (t) => t.id != PinballTableId.brassLabyrinth,
    )) {
      final game = PinballGame(table: table,onGameFinished: (_) {});
      game.debugInitializePhysics();
      expect(game.runDeveloperScenario(PinballDeveloperScenario.brassLeftRoute),
          isFalse);
      expect(game.debugBallInSwitchyard, isFalse);
      game.hud.dispose(); game.developerEvents.dispose();
    }
  });
}