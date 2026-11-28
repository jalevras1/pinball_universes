import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/citadel_ball_lock.dart';
import 'package:premium_pinball/game/developer_scenarios.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('artwork landmarks, timings, and physical gate agree with manifest', () {
    final manifest = jsonDecode(
      File('tool/mechanical_candidates/batch_022_manifest.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final m = manifest['state_machine'] as Map<String, dynamic>;
    expect(m['capture_trigger'], <int>[198, 505]);
    expect(CitadelBallLock.mouth, const Offset(198, 505));
    expect(CitadelBallLock.lockVisualRect, const Rect.fromLTWH(152, 477, 92, 92));
    expect(CitadelBallLock.gateVisualRect, const Rect.fromLTWH(116, 438, 168, 40));
    expect(CitadelBallLock.gateA, const Offset(127, 457));
    expect(CitadelBallLock.gateB, const Offset(273, 457));
    expect(CitadelBallLock.period, 4.8);
    expect(CitadelBallLock.closedSeconds, 2.8);
    expect(CitadelBallLock.isGateClosed(0), isTrue);
    expect(CitadelBallLock.isGateClosed(2.79), isTrue);
    expect(CitadelBallLock.isGateClosed(3), isFalse);
    expect(CitadelBallLock.isGateClosed(4.81), isTrue);
  });

  test('two-ball lock refuses the wrong direction or an occupied vault', () {
    bool accepts(Offset p, Offset v, double t, int held, {bool released = false}) =>
        CitadelBallLock.canCapture(
          position: p, velocity: v, elapsed: t,
          lockedBalls: held, alreadyReleased: released,
        );
    expect(accepts(const Offset(198, 505), const Offset(0, 350), 3, 0), isTrue);
    expect(accepts(const Offset(198, 505), const Offset(0, 350), 3, 1), isTrue);
    expect(accepts(const Offset(198, 505), const Offset(0, 350), 3, 2), isFalse);
    expect(accepts(const Offset(198, 505), const Offset(0, 350), 0, 0), isFalse);
    expect(accepts(const Offset(198, 505), const Offset(0, -350), 3, 0), isFalse);
    expect(accepts(const Offset(198, 505), const Offset(0, 80), 3, 0), isFalse);
    expect(accepts(const Offset(240, 505), const Offset(0, 350), 3, 0), isFalse);
    expect(accepts(const Offset(198, 505), const Offset(0, 350), 3, 0,
        released: true), isFalse);
    expect(CitadelBallLock.canRelease(
        actualGateContact: true, elapsed: 0, lockedBalls: 2,
        alreadyReleased: false), isTrue);
    expect(CitadelBallLock.canRelease(
        actualGateContact: false, elapsed: 0, lockedBalls: 2,
        alreadyReleased: false), isFalse);
    expect(CitadelBallLock.canRelease(
        actualGateContact: true, elapsed: 3, lockedBalls: 2,
        alreadyReleased: false), isFalse);
    expect(CitadelBallLock.canRelease(
        actualGateContact: true, elapsed: 0, lockedBalls: 1,
        alreadyReleased: false), isFalse);
    expect(CitadelBallLock.canRelease(
        actualGateContact: true, elapsed: 0, lockedBalls: 2,
        alreadyReleased: true), isFalse);
  });

  test('all five real RGBA assets are bundled and sized for machine geometry', () async {
    for (final name in <String>[
      'citadel_lock_0.png', 'citadel_lock_1.png', 'citadel_lock_2.png',
      'citadel_gate_closed.png', 'citadel_gate_open.png',
    ]) {
      final bytes = await rootBundle.load('assets/gameplay/mechanical/$name');
      expect(bytes.lengthInBytes, greaterThan(2000), reason: name);
      expect(bytes.getUint32(0), 0x89504e47, reason: name);
      expect(bytes.getUint32(16), name.contains('gate') ? 336 : 184);
      expect(bytes.getUint32(20), name.contains('gate') ? 80 : 184);
      expect(bytes.getUint8(25), 6, reason: 'Expected RGBA color type: $name');
    }
  });

  test('real physics holds first two balls without consuming lives', () {
    final game = PinballGame(
      table: tableById(PinballTableId.chronoCitadel),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    for (var held = 1; held <= 2; held++) {
      expect(game.runDeveloperScenario(PinballDeveloperScenario.citadelLock), isTrue);
      game.debugStepPhysics(1 / 120);
      expect(game.debugCitadelLockedBalls, held);
      expect(game.hud.value.balls, 3); // A vault capture is NOT a drain.
      expect(game.hud.value.isReady, isTrue); // Shooter rearms a real third ball.
      expect(game.debugBallPositions.length, 1);
      expect(game.hud.value.isMultiball, isFalse);
    }
    expect(game.hud.value.score, 600);
    game.hud.dispose();
    game.developerEvents.dispose();
  });

  test('real gate contact releases precisely two trapped balls for multiball', () {
    final game = PinballGame(
      table: tableById(PinballTableId.chronoCitadel),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    for (var i = 0; i < 2; i++) {
      game.runDeveloperScenario(PinballDeveloperScenario.citadelLock);
      game.debugStepPhysics(1 / 120);
    }
    expect(game.debugCitadelLockedBalls, 2);
    expect(game.hud.value.score, 600);
    expect(game.runDeveloperScenario(PinballDeveloperScenario.citadelRelease), isTrue);
    // The developer button only injects a moving ball. The next frame must
    // actually collide with the existing gate segment for the vault to open.
    expect(game.debugBallPositions.length, 1);
    expect(game.hud.value.score, 600);
    for (var i = 0; i < 12 && !game.hud.value.isMultiball; i++) {
      game.debugStepPhysics(1 / 120);
    }
    expect(game.debugCitadelLockedBalls, 0);
    expect(game.debugCitadelReleased, isTrue);
    expect(game.hud.value.isMultiball, isTrue);
    expect(game.debugBallPositions.length, 3);
    expect(game.hud.value.balls, 3);
    expect(game.hud.value.score, 2550); // 300 + 300 + 450 + 1500.
    for (var i = 0; i < 5; i++) {
      game.debugStepPhysics(1 / 120);
    }
    expect(game.debugBallPositions.length, greaterThanOrEqualTo(1));
    game.hud.dispose();
    game.developerEvents.dispose();
  });

  test('vault does not operate on other tables and restart clears held balls', () {
    final game = PinballGame(
      table: tableById(PinballTableId.chronoCitadel),
      onGameFinished: (_) {},
    );
    game.debugInitializePhysics();
    game.runDeveloperScenario(PinballDeveloperScenario.citadelLock);
    game.debugStepPhysics(1 / 120);
    expect(game.debugCitadelLockedBalls, 1);
    game.restart();
    expect(game.debugCitadelLockedBalls, 0);
    expect(game.debugCitadelReleased, isFalse);
    game.hud.dispose();
    game.developerEvents.dispose();
    final other = PinballGame(
      table: tableById(PinballTableId.astralOrrery),
      onGameFinished: (_) {},
    );
    other.debugInitializePhysics();
    expect(other.runDeveloperScenario(PinballDeveloperScenario.citadelLock), isFalse);
    expect(other.runDeveloperScenario(PinballDeveloperScenario.citadelRelease), isFalse);
    other.hud.dispose();
    other.developerEvents.dispose();
  });
}