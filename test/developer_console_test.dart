import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/developer_console.dart';
import 'package:premium_pinball/game/developer_scenarios.dart';
import 'package:premium_pinball/game/pinball_game.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  testWidgets('developer controls expose every scenario without app restart', (
    tester,
  ) async {
    PinballDeveloperScenario? requested;
    var overlayVisible = false;
    var closed = false;
    var stepCalls = 0;
    var clearCalls = 0;
    final events = ValueNotifier<List<String>>(<String>[]);
    PinballTableId? chosenTable;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 330,
            height: 440,
            child: PinballDeveloperConsole(
              accent: Colors.cyan,
              currentTable: PinballTableId.astralOrrery,
              collisionOverlayVisible: false,
              scoreNotSaved: false,
              eventFeed: events,
              onScenario: (scenario) => requested = scenario,
              onStepFrame: () => stepCalls++,
              onClearEvents: () => clearCalls++,
              onOverlayChanged: (visible) => overlayVisible = visible,
              onTableSelected: (table) => chosenTable = table,
              onClose: () => closed = true,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PinballDeveloperConsole), findsOneWidget);
    expect(find.text('DEVELOPER • LIVE TEST'), findsOneWidget);
    for (final scenario in PinballDeveloperScenario.values) {
      expect(find.text(scenario.label),
          scenario == PinballDeveloperScenario.moonbridgeRamp ||
                  scenario == PinballDeveloperScenario.citadelLock ||
                  scenario == PinballDeveloperScenario.citadelRelease ||
                  scenario == PinballDeveloperScenario.brassLeftRoute ||
                  scenario == PinballDeveloperScenario.brassRightRoute
              ? findsNothing : findsOneWidget);
    }
    await tester.tap(find.text(PinballDeveloperScenario.weakLaunch.label));
    expect(requested, PinballDeveloperScenario.weakLaunch);
    events.value = <String>['3.12s  BUMPER 1 +700 @(211,250)'];
    await tester.pump();
    expect(find.textContaining('BUMPER 1 +700'), findsOneWidget);
    await tester.ensureVisible(find.text('STEP PAUSED FRAME'));
    await tester.tap(find.text('STEP PAUSED FRAME'));
    expect(stepCalls, 1);
    await tester.tap(find.text('CLEAR LOG'));
    expect(clearCalls, 1);
    await tester.ensureVisible(find.text('Show wall / bumper / flipper hitboxes'));
    await tester.tap(find.text('Show wall / bumper / flipper hitboxes'));
    expect(overlayVisible, isTrue);
    await tester.ensureVisible(find.byType(DropdownButton<PinballTableId>));
    await tester.tap(find.byType(DropdownButton<PinballTableId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QUANTUM GRID').last);
    expect(chosenTable, PinballTableId.quantumGrid);
    await tester.ensureVisible(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
    events.dispose();
  });

  testWidgets('Moonfall developer panel exposes the active elevated ramp test',
      (tester) async {
    PinballDeveloperScenario? requested;
    final events = ValueNotifier<List<String>>(<String>[]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 330, height: 440,
          child: PinballDeveloperConsole(
            accent: Colors.cyan,
            currentTable: PinballTableId.moonfallSanctuary,
            collisionOverlayVisible: false,
            scoreNotSaved: false,
            eventFeed: events,
            onScenario: (scenario) => requested = scenario,
            onStepFrame: () {},
            onClearEvents: () {},
            onOverlayChanged: (_) {},
            onTableSelected: (_) {},
            onClose: () {},
          ),
        ),
      ),
    ));
    final button = find.text('MOONBRIDGE RAMP');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(requested, PinballDeveloperScenario.moonbridgeRamp);
    events.dispose();
  });

  testWidgets('Chrono Citadel exposes real capture and release developer scenarios',
      (tester) async {
    PinballDeveloperScenario? requested;
    final events = ValueNotifier<List<String>>(<String>[]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 330, height: 440,
          child: PinballDeveloperConsole(
            accent: Colors.orange,
            currentTable: PinballTableId.chronoCitadel,
            collisionOverlayVisible: false,
            scoreNotSaved: false,
            eventFeed: events,
            onScenario: (scenario) => requested = scenario,
            onStepFrame: () {},
            onClearEvents: () {},
            onOverlayChanged: (_) {},
            onTableSelected: (_) {},
            onClose: () {},
          ),
        ),
      ),
    ));
    expect(find.text('MOONBRIDGE RAMP'), findsNothing);
    final capture = find.text('CITADEL CAPTURE');
    final release = find.text('CITADEL RELEASE');
    expect(capture, findsOneWidget);
    expect(release, findsOneWidget);
    await tester.ensureVisible(capture);
    await tester.tap(capture);
    expect(requested, PinballDeveloperScenario.citadelLock);
    await tester.ensureVisible(release);
    await tester.tap(release);
    expect(requested, PinballDeveloperScenario.citadelRelease);
    events.dispose();
  });

  testWidgets('Brass Labyrinth exposes only its dual tunnel test buttons',
      (tester) async {
    PinballDeveloperScenario? requested;
    final events = ValueNotifier<List<String>>(<String>[]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 330, height: 440,
          child: PinballDeveloperConsole(
            accent: Colors.amber,
            currentTable: PinballTableId.brassLabyrinth,
            collisionOverlayVisible: false,
            scoreNotSaved: false,
            eventFeed: events,
            onScenario: (scenario) => requested = scenario,
            onStepFrame: () {},
            onClearEvents: () {},
            onOverlayChanged: (_) {},
            onTableSelected: (_) {},
            onClose: () {},
          ),
        ),
      ),
    ));
    expect(find.text('MOONBRIDGE RAMP'), findsNothing);
    expect(find.text('CITADEL CAPTURE'), findsNothing);
    final left = find.text('BRASS LEFT TUNNEL');
    final right = find.text('BRASS RIGHT TUNNEL');
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    await tester.ensureVisible(left);
    await tester.pumpAndSettle();
    await tester.tap(left);
    expect(requested, PinballDeveloperScenario.brassLeftRoute);
    await tester.ensureVisible(right);
    await tester.pumpAndSettle();
    await tester.tap(right);
    expect(requested, PinballDeveloperScenario.brassRightRoute);
    events.dispose();
  });

  for (final table in pinballTables) {
    test('${table.id.name}: developer shots use actual game rules', () {
      final game = PinballGame(table: table, onGameFinished: (_) {});
      game.debugInitializePhysics();
      expect(game.developerSession, isFalse);

      expect(game.runDeveloperScenario(PinballDeveloperScenario.weakLaunch), isTrue);
      expect(game.developerSession, isTrue);
      expect(game.developerEvents.value.last, contains('PLUNGER 5%'));
      expect(game.debugBallInTube, isTrue);
      expect(game.debugBallPositions.single.dx, 352);
      expect(game.hud.value.score, 0);
      for (var i = 0; i < 500 && !game.hud.value.isReady; i++) {
        game.debugStepPhysics(1 / 120);
      }
      expect(game.hud.value.isReady, isTrue);
      expect(game.hud.value.balls, 3);
      expect(
        game.developerEvents.value.any((event) => event.contains('SHOOTER REARMED')),
        isTrue,
      );

      expect(game.runDeveloperScenario(PinballDeveloperScenario.skillLaunch), isTrue);
      expect(game.debugBallVelocities.single.dy, lessThan(0));
      expect(game.developerEvents.value.last, contains('PLUNGER 17%'));

      expect(game.runDeveloperScenario(PinballDeveloperScenario.bumperContact), isTrue);
      expect(game.hud.value.score, 0);
      for (var i = 0; i < 80 && game.hud.value.score == 0; i++) {
        game.debugStepPhysics(1 / 120);
      }
      expect(game.hud.value.score, greaterThan(0));
      expect(
        game.developerEvents.value.any((event) => event.contains('BUMPER 1 +')),
        isTrue,
      );

      for (final flipper in <PinballDeveloperScenario>[
        PinballDeveloperScenario.leftFlipper,
        PinballDeveloperScenario.rightFlipper,
      ]) {
        final scoreBefore = game.hud.value.score;
        expect(game.runDeveloperScenario(flipper), isTrue);
        for (var i = 0; i < 15 && game.hud.value.score == scoreBefore; i++) {
          game.debugStepPhysics(1 / 120);
        }
        expect(
          game.hud.value.score,
          greaterThan(scoreBefore),
          reason: '${table.id.name}: $flipper did not strike the ball',
        );
        expect(
          game.developerEvents.value.any((event) => event.contains('FLIPPER HIT')),
          isTrue,
        );
      }

      expect(game.runDeveloperScenario(PinballDeveloperScenario.drain), isTrue);
      game.debugStepPhysics(1 / 120);
      expect(game.hud.value.balls, 2);
      expect(game.hud.value.isReady, isTrue);
      expect(game.developerEvents.value.last, contains('BALL LOST'));

      expect(game.runDeveloperScenario(PinballDeveloperScenario.resetRound), isTrue);
      expect(game.hud.value.balls, 3);
      expect(game.hud.value.score, 0);
      expect(game.developerSession, isTrue);
      expect(game.developerEvents.value.length, lessThanOrEqualTo(10));
      game.clearDeveloperEvents();
      expect(game.developerEvents.value, isEmpty);

      game.developerCollisionOverlay = true;
      expect(game.developerCollisionOverlay, isTrue);
      game.hud.dispose();
      game.developerEvents.dispose();
    });
  }

  test('developer scenario refuses an unloaded board', () {
    final game = PinballGame(
      table: pinballTables.first,
      onGameFinished: (_) {},
    );
    expect(game.runDeveloperScenario(PinballDeveloperScenario.drain), isFalse);
    expect(game.debugBallPositions, isEmpty);
    game.hud.dispose();
    game.developerEvents.dispose();
  });

  test('paused developer frame step advances exactly once', () {
    final game = PinballGame(table: pinballTables.first, onGameFinished: (_) {});
    game.debugInitializePhysics();
    expect(game.developerStepPausedPhysics(), isFalse);
    game.runDeveloperScenario(PinballDeveloperScenario.fullLaunch);
    game.togglePause();
    final before = game.debugBallPositions.single;
    game.debugStepPhysics(1 / 120);
    expect(game.debugBallPositions.single, before);
    expect(game.developerStepPausedPhysics(), isTrue);
    final after = game.debugBallPositions.single;
    expect(after, isNot(before));
    expect(game.hud.value.isPaused, isTrue);
    expect(game.developerEvents.value.last, contains('STEP 1/120'));
    game.hud.dispose();
    game.developerEvents.dispose();
  });
}
