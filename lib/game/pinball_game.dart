import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../audio/pinball_audio.dart';
import 'developer_scenarios.dart';
import 'plunger_model.dart';
import 'shooter_lane.dart';
import 'swept_rail.dart';
import 'table_data.dart';

const double _boardWidth = 400;
const double _boardHeight = 760;
const double _ballRadius = 7.5;
const Offset _leftPivot = Offset(127, 664);
const Offset _rightPivot = Offset(273, 664);

class PinballHud {
  const PinballHud({
    required this.score,
    required this.balls,
    required this.mode,
    required this.isReady,
    required this.isPaused,
    required this.isMultiball,
    required this.awardLabel,
  });

  final int score;
  final int balls;
  final String mode;
  final bool isReady;
  final bool isPaused;
  final bool isMultiball;
  final String awardLabel;
}

class _Ball {
  _Ball(this.position, this.velocity);

  Offset position;
  Offset velocity;
  bool inShooter = false;
  bool inShooterLane = false;
  double portalCooldown = 0;
  final List<Offset> trail = <Offset>[];
  final Map<int, double> lastBumperHit = <int, double>{};
}

class _Segment {
  const _Segment(this.a, this.b);

  final Offset a;
  final Offset b;
  final double bounce = 0.84;
}

class _Bumper {
  const _Bumper(this.center, this.radius, this.value);

  final Offset center;
  final double radius;
  final int value;
}

class _Impact {
  _Impact(this.center, this.color, {this.size = 1});
  final Offset center;
  final Color color;
  final double duration = 0.32;
  final double size;
  double age = 0;
}

/// Early playable interaction prototype. The final physics implementation will
/// use Forge2D bodies and joints after a Codespace compile/playtest pass.
class PinballGame extends FlameGame {
  PinballGame({required this.table, required this.onGameFinished, this.audio})
    : hud = ValueNotifier<PinballHud>(
        PinballHud(
          score: 0,
          balls: 3,
          mode: table.modeNames.first,
          isReady: true,
          isPaused: false,
          isMultiball: false,
          awardLabel: '',
        ),
      );

  final PinballTableInfo table;
  final ValueChanged<int> onGameFinished;
  final PinballAudio? audio;
  final ValueNotifier<PinballHud> hud;
  /// Bounded, event-driven evidence from the real solver, not fake test scores.
  /// The DEV panel observes this without causing a rebuild every physics tick.
  final ValueNotifier<List<String>> developerEvents =
      ValueNotifier<List<String>>(<String>[]);
  final PlungerModel plunger = PlungerModel();
  static const ShooterLane _shooterLane = ShooterLane();

  // Deterministic physics harness: tests can exercise actual gameplay rules
  // without decoding large artwork or launching a browser.
  @visibleForTesting
  void debugInitializePhysics() {
    if (_rails.isNotEmpty || _balls.isNotEmpty) {
      throw StateError('Physics must be initialized only once.');
    }
    _configureTable();
    _prepareBall();
  }

  @visibleForTesting
  void debugStepPhysics(double dt) {
    if (!_paused && !_finished) _simulate(dt);
  }

  @visibleForTesting
  List<Offset> get debugBallPositions =>
      List<Offset>.unmodifiable(_balls.map((ball) => ball.position));

  @visibleForTesting
  List<Offset> get debugBallVelocities =>
      List<Offset>.unmodifiable(_balls.map((ball) => ball.velocity));

  @visibleForTesting
  bool get debugBallInTube => _balls.any((ball) => ball.inShooterLane);

  @visibleForTesting
  void debugPlaceBall(Offset position, Offset velocity) {
    _balls
      ..clear()
      ..add(_Ball(position, velocity));
    _notifyHud();
  }

  /// Repeat real contact scenarios without restarting the app. No points are
  /// injected directly: the physics collision or drain must actually occur.
  bool runDeveloperScenario(PinballDeveloperScenario scenario) {
    if (_rails.isEmpty) return false;
    developerSession = true;
    if (_paused) togglePause();
    if (_finished) restart();
    _logDeveloperEvent('TEST ${scenario.label}');
    switch (scenario) {
      case PinballDeveloperScenario.weakLaunch:
        restart();
        launch(strength: 0.05);
      case PinballDeveloperScenario.skillLaunch:
        restart();
        launch(strength: 0.17);
      case PinballDeveloperScenario.mediumLaunch:
        restart();
        launch(strength: 0.6);
      case PinballDeveloperScenario.fullLaunch:
        restart();
        launch(strength: 1);
      case PinballDeveloperScenario.leftFlipper:
        debugPlaceBall(const Offset(174, 644), const Offset(0, 400));
        leftPressed = true;
        rightPressed = false;
      case PinballDeveloperScenario.rightFlipper:
        debugPlaceBall(const Offset(226, 644), const Offset(0, 400));
        leftPressed = false;
        rightPressed = true;
      case PinballDeveloperScenario.bumperContact:
        final bumper = _bumpers.first;
        // Approach from the open lower face. On Chrono Citadel the upper
        // guide crosses directly above this bumper, so a top-down test ball
        // hits the rail first and never exercises the bumper collider.
        debugPlaceBall(
          Offset(bumper.center.dx, bumper.center.dy + bumper.radius + 30),
          const Offset(0, -450),
        );
        leftPressed = false;
        rightPressed = false;
      case PinballDeveloperScenario.drain:
        debugPlaceBall(const Offset(200, 750), const Offset(0, 400));
        leftPressed = false;
        rightPressed = false;
      case PinballDeveloperScenario.resetRound:
        restart();
    }
    return true;
  }

  /// Move exactly one fixed physics frame while PAUSED. The running game,
  /// sound settings, table, and current ball remain in place.
  bool developerStepPausedPhysics() {
    if (!_paused || _finished || _rails.isEmpty) return false;
    developerSession = true;
    _simulate(1 / 120);
    _logDeveloperEvent('STEP 1/120');
    return true;
  }

  void clearDeveloperEvents() => developerEvents.value = <String>[];

  void _logDeveloperEvent(String detail) {
    if (!developerSession) return;
    final entry = '${_time.toStringAsFixed(2)}s  $detail';
    final recent = developerEvents.value;
    developerEvents.value = <String>[
      ...recent.skip(recent.length > 9 ? recent.length - 9 : 0),
      entry,
    ];
  }

  /// Diagnostic layer uses real solver coordinates; never final playfield art.
  bool developerCollisionOverlay = false;

  /// Diagnostic injections must never enter the player's high-score record.
  bool developerSession = false;

  final List<_Ball> _balls = <_Ball>[];
  final List<_Segment> _rails = <_Segment>[];
  final List<_Bumper> _bumpers = <_Bumper>[];
  final List<_Impact> _impacts = <_Impact>[];
  final Map<int, double> _bumperLastGlow = <int, double>{};
  ui.Image? _ballSprite;
  ui.Image? _bumperSprite;
  ui.Image? _backplateSprite;
  ui.Image? _hazardSprite;
  bool _spritesReleased = false;

  bool leftPressed = false;
  bool rightPressed = false;
  bool _paused = false;
  bool _finished = false;
  bool _multiballAwarded = false;
  int _score = 0;
  int _ballsToPlay = 3;
  int _hits = 0;
  double _time = 0;
  double _accumulator = 0;
  double _leftLift = 0;
  double _rightLift = 0;
  double _cinematicTime = -1;
  double _shake = 0;
  double _scoreBoostUntil = 0;
  double _ballSaverUntil = 0;
  double _awardTextUntil = 0;
  double _lastRailImpact = -100;
  String _awardText = '';
  bool reducedMotion = false;

  @override
  Color backgroundColor() => const Color(0xFF02040C);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _configureTable();
    _ballSprite = await _loadSprite('assets/gameplay/steel_ball.png', 128);
    _bumperSprite = await _loadSprite(
      'assets/gameplay/bumper_${table.universe.name}.png',
      192,
    );
    _backplateSprite = await _loadSprite(
      'assets/backplates/${table.universe.name}.png',
      512,
    );
    final hazardAsset = switch (table.universe) {
      PinballUniverseId.celestial when table.variant == 0 =>
        'assets/gameplay/portal_celestial.png',
      PinballUniverseId.neon when table.variant == 2 =>
        'assets/gameplay/reactor_neon.png',
      PinballUniverseId.clockwork when table.variant != 1 =>
        'assets/gameplay/gear_clockwork.png',
      _ => null,
    };
    if (hazardAsset != null)
      _hazardSprite = await _loadSprite(hazardAsset, 192);
    if (_spritesReleased) return;
    _prepareBall();
  }

  Future<ui.Image?> _loadSprite(String asset, int targetWidth) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (_spritesReleased) {
        frame.image.dispose();
        return null;
      }
      return frame.image;
    } catch (error) {
      // Keep playable fallbacks, but surface missing asset declarations in logs.
      debugPrint('PINBALL ASSET FAILED: $asset ($error)');
      return null;
    }
  }

  void releaseSprites() {
    _spritesReleased = true;
    _ballSprite?.dispose();
    _bumperSprite?.dispose();
    _backplateSprite?.dispose();
    _hazardSprite?.dispose();
    _ballSprite = null;
    _bumperSprite = null;
    _backplateSprite = null;
    _hazardSprite = null;
  }

  void _configureTable() {
    // Outer wall, sloping inlanes, shooter divider, and drain guides.
    _rails.addAll(const <_Segment>[
      _Segment(Offset(31, 690), Offset(31, 116)),
      _Segment(Offset(31, 116), Offset(63, 57)),
      _Segment(Offset(63, 57), Offset(330, 57)),
      _Segment(Offset(330, 57), Offset(369, 109)),
      _Segment(Offset(369, 109), Offset(369, 695)),
      _Segment(Offset(336, 205), Offset(336, 695)),
      _Segment(Offset(369, 105), Offset(315, 145)),
      _Segment(Offset(35, 559), Offset(105, 631)),
      _Segment(Offset(365, 559), Offset(295, 631)),
      _Segment(Offset(31, 689), Offset(88, 716)),
      _Segment(Offset(369, 689), Offset(312, 716)),
      _Segment(Offset(76, 612), Offset(105, 652)),
      _Segment(Offset(324, 612), Offset(295, 652)),
    ]);

    switch (table.universe) {
      case PinballUniverseId.celestial:
        switch (table.variant) {
          case 0: // Orrery: central constellation-triangle layout.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(112, 287), 22, 500),
              _Bumper(Offset(211, 250), 24, 700),
              _Bumper(Offset(289, 319), 21, 500),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(62, 181), Offset(147, 116)),
              _Segment(Offset(255, 117), Offset(320, 197)),
              _Segment(Offset(87, 439), Offset(160, 481)),
              _Segment(Offset(310, 439), Offset(242, 481)),
            ]);
          case 1: // Moonfall: asymmetrical lunar well field.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(99, 214), 20, 500),
              _Bumper(Offset(296, 270), 22, 800),
              _Bumper(Offset(191, 422), 27, 1000),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(77, 181), Offset(124, 148)),
              _Segment(Offset(284, 154), Offset(325, 206)),
              _Segment(Offset(75, 358), Offset(123, 393)),
              _Segment(Offset(258, 479), Offset(309, 435)),
            ]);
          default: // Nebula: dense storm gates and four-way bumpers.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(110, 210), 20, 450),
              _Bumper(Offset(281, 205), 20, 450),
              _Bumper(Offset(172, 329), 19, 650),
              _Bumper(Offset(276, 422), 19, 650),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(76, 137), Offset(165, 172)),
              _Segment(Offset(231, 176), Offset(313, 134)),
              _Segment(Offset(62, 454), Offset(128, 497)),
              _Segment(Offset(248, 503), Offset(324, 463)),
            ]);
        }
      case PinballUniverseId.neon:
        switch (table.variant) {
          case 0: // Velocity: center acceleration rail.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(112, 218), 20, 600),
              _Bumper(Offset(285, 219), 20, 600),
              _Bumper(Offset(199, 339), 24, 850),
              _Bumper(Offset(106, 433), 16, 300),
              _Bumper(Offset(293, 433), 16, 300),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(77, 125), Offset(148, 186)),
              _Segment(Offset(322, 125), Offset(249, 186)),
              _Segment(Offset(87, 476), Offset(167, 517)),
              _Segment(Offset(312, 476), Offset(234, 517)),
            ]);
          case 1: // Quantum: diagonally offset phase-relay obstacles.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(89, 245), 21, 600),
              _Bumper(Offset(287, 310), 23, 750),
              _Bumper(Offset(196, 472), 19, 500),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(87, 135), Offset(149, 194)),
              _Segment(Offset(257, 181), Offset(317, 119)),
              _Segment(Offset(66, 395), Offset(129, 435)),
              _Segment(Offset(273, 496), Offset(320, 453)),
            ]);
          default: // Reactor: perimeter targets around a core.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(199, 275), 30, 1200),
              _Bumper(Offset(100, 371), 20, 500),
              _Bumper(Offset(301, 371), 20, 500),
              _Bumper(Offset(198, 494), 18, 650),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(85, 159), Offset(145, 140)),
              _Segment(Offset(254, 140), Offset(314, 159)),
              _Segment(Offset(80, 443), Offset(125, 465)),
              _Segment(Offset(275, 465), Offset(318, 443)),
            ]);
        }
      case PinballUniverseId.clockwork:
        switch (table.variant) {
          case 0: // Mechanism: classic trilateral gears.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(197, 216), 28, 900),
              _Bumper(Offset(105, 332), 20, 500),
              _Bumper(Offset(293, 332), 20, 500),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(76, 164), Offset(152, 127)),
              _Segment(Offset(246, 127), Offset(319, 164)),
              _Segment(Offset(81, 462), Offset(150, 504)),
              _Segment(Offset(313, 462), Offset(248, 504)),
            ]);
          case 1: // Citadel: split upper lane, lower timed gate.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(115, 208), 22, 500),
              _Bumper(Offset(286, 208), 22, 500),
              _Bumper(Offset(198, 365), 23, 850),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(77, 150), Offset(160, 198)),
              _Segment(Offset(240, 198), Offset(318, 150)),
              _Segment(Offset(83, 484), Offset(145, 528)),
              _Segment(Offset(251, 527), Offset(319, 483)),
            ]);
          default: // Labyrinth: offset passage walls and four targets.
            _bumpers.addAll(const <_Bumper>[
              _Bumper(Offset(112, 242), 19, 400),
              _Bumper(Offset(288, 241), 19, 400),
              _Bumper(Offset(110, 433), 19, 500),
              _Bumper(Offset(288, 430), 19, 500),
            ]);
            _rails.addAll(const <_Segment>[
              _Segment(Offset(65, 320), Offset(162, 347)),
              _Segment(Offset(242, 349), Offset(329, 320)),
              _Segment(Offset(62, 514), Offset(140, 536)),
              _Segment(Offset(268, 532), Offset(331, 509)),
            ]);
        }
    }
  }

  void _prepareBall() {
    if (_finished) return;
    final ball = _Ball(
      Offset(_shooterLane.centerX, _shooterLane.readyY),
      Offset.zero,
    )..inShooter = true;
    _balls.add(ball);
    _notifyHud();
  }

  /// Power is the ONLY shot variable. The ball remains on the shooter centerline
  /// until it reaches the real exit guide at the top of the tube.
  void launch({double strength = 1}) {
    if (_paused || _finished) return;
    var didLaunch = false;
    for (final ball in _balls) {
      if (!ball.inShooter) continue;
      ball.inShooter = false;
      ball.inShooterLane = true;
      ball.position = Offset(_shooterLane.centerX, _shooterLane.readyY);
      ball.velocity = Offset(0, _shooterLane.launchVelocityY(strength));
      didLaunch = true;
    }
    if (didLaunch && !reducedMotion) _cinematicTime = 0;
    if (didLaunch) _pulse(const Offset(352, 651), table.accent, size: 1.8);
    if (didLaunch) audio?.play(PinballSound.launch);
    if (didLaunch) _logDeveloperEvent('PLUNGER ${(strength * 100).round()}%');
    _notifyHud();
  }

  void togglePause() {
    if (_finished) return;
    _paused = !_paused;
    _notifyHud();
  }

  void restart() {
    _balls.clear();
    _score = 0;
    _hits = 0;
    _ballsToPlay = 3;
    _finished = false;
    _paused = false;
    _multiballAwarded = false;
    _impacts.clear();
    _bumperLastGlow.clear();
    _cinematicTime = -1;
    _scoreBoostUntil = 0;
    _ballSaverUntil = 0;
    _awardTextUntil = 0;
    _awardText = '';
    _shake = 0;
    leftPressed = false;
    rightPressed = false;
    plunger.cancel();
    _prepareBall();
  }

  void _notifyHud() {
    if (_finished && hud.value.balls == 0) return;
    final modeIndex = _hits < 4
        ? 0
        : _hits < 10
        ? 1
        : _hits < 18
        ? 2
        : 3;
    hud.value = PinballHud(
      score: _score,
      balls: _ballsToPlay,
      mode: table.modeNames[modeIndex],
      isReady: _balls.any((ball) => ball.inShooter),
      isPaused: _paused,
      isMultiball: _balls.length > 1,
      awardLabel: _awardTextUntil > _time ? _awardText : '',
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_paused || _finished) return;
    _accumulator += math.min(dt, 0.05);
    const step = 1 / 120;
    var steps = 0;
    while (_accumulator >= step && steps < 6) {
      _simulate(step);
      _accumulator -= step;
      steps++;
    }
  }

  void _simulate(double dt) {
    _time += dt;
    if (_awardText.isNotEmpty && _time >= _awardTextUntil) {
      _awardText = '';
      _notifyHud();
    }
    if (_cinematicTime >= 0) {
      _cinematicTime += dt;
      if (_cinematicTime > 1.35) _cinematicTime = -1;
    }
    _shake = math.max(0.0, _shake - dt * 6);
    for (final impact in List<_Impact>.of(_impacts)) {
      impact.age += dt;
      if (impact.age >= impact.duration) _impacts.remove(impact);
    }
    _leftLift = _approach(_leftLift, leftPressed ? 1 : 0, dt * 16);
    _rightLift = _approach(_rightLift, rightPressed ? 1 : 0, dt * 16);

    for (final ball in List<_Ball>.of(_balls)) {
      if (ball.inShooter) continue;
      var flightDt = dt;
      // A very soft shot can barely clear the divider and fall back into the
      // tube. Recapture instead of draining a ball that never reached play.
      if (!ball.inShooterLane &&
          ball.velocity.dy > 0 &&
          (ball.position.dx - _shooterLane.centerX).abs() < 8 &&
          ball.position.dy >= _shooterLane.exitY &&
          ball.position.dy < _shooterLane.readyY) {
        ball.inShooterLane = true;
        ball.velocity = Offset(0, ball.velocity.dy);
      }
      if (ball.inShooterLane) {
        // The captive lane is a separate physical state: no random sideways
        // impulse, generic rail collisions, scoring, portal or drain here.
        final shot = _shooterLane.advance(
          y: ball.position.dy,
          velocityY: ball.velocity.dy,
          dt: dt,
        );
        ball.position = Offset(_shooterLane.centerX, shot.y);
        ball.velocity = Offset(0, shot.velocityY);
        if (shot.phase == ShooterPhase.rearmed) {
          ball.inShooter = true;
          ball.inShooterLane = false;
          ball.velocity = Offset.zero;
          ball.trail.clear();
          _logDeveloperEvent('SHOOTER REARMED');
          _notifyHud();
          continue;
        } else if (shot.phase == ShooterPhase.exited) {
          // Hand unused frame time directly to the playfield. Without this,
          // near-identical launches diverge at different physics tick rates.
          ball.inShooterLane = false;
          _logDeveloperEvent(
            'SHOOTER EXIT vY=${shot.velocityY.toStringAsFixed(0)}',
          );
          flightDt = shot.remainingDt;
          if (flightDt <= 0) continue;
        } else {
          ball.trail.add(ball.position);
          if (ball.trail.length > 7) ball.trail.removeAt(0);
          continue;
        }
      }
      ball.portalCooldown = math.max(0.0, ball.portalCooldown - flightDt);
      ball.velocity = Offset(
        ball.velocity.dx * 0.9994,
        ball.velocity.dy + 670 * flightDt,
      );
      final speed = ball.velocity.distance;
      if (speed > 1600) ball.velocity = ball.velocity * (1600 / speed);
      var previousPosition = ball.position;
      ball.position += ball.velocity * flightDt;

      for (final rail in _rails) {
        if (_collideSegment(
          ball,
          rail.a,
          rail.b,
          rail.bounce,
          previousPosition: previousPosition,
        )) {
          previousPosition = ball.position;
        }
      }
      _collideFlipper(ball, left: true);
      _collideFlipper(ball, left: false);

      for (var i = 0; i < _bumpers.length; i++) {
        final bumper = _bumpers[i];
        final delta = ball.position - bumper.center;
        final limit = bumper.radius + _ballRadius;
        if (delta.distance >= limit) continue;
        final normal = delta.distance < 0.001
            ? const Offset(0, -1)
            : delta / delta.distance;
        ball.position = bumper.center + normal * limit;
        final dot = _dot(ball.velocity, normal);
        ball.velocity -= normal * (2.0 * math.min(0.0, dot));
        ball.velocity += normal * 270;
        if (_time - (ball.lastBumperHit[i] ?? -100) > 0.12) {
          ball.lastBumperHit[i] = _time;
          _bumperLastGlow[i] = _time;
          _pulse(bumper.center, table.secondary, size: 1.6);
          _shake = reducedMotion ? 0.0 : math.max(_shake, 0.16);
          audio?.play(switch (table.universe) {
            PinballUniverseId.celestial => PinballSound.bumperCelestial,
            PinballUniverseId.neon => PinballSound.bumperNeon,
            PinballUniverseId.clockwork => PinballSound.bumperClockwork,
          });
          final oldScore = _score;
          _registerHit(bumper.value);
          _logDeveloperEvent(
            'BUMPER ${i + 1} +${_score - oldScore}'
            ' @(${bumper.center.dx.round()},${bumper.center.dy.round()})',
          );
        }
      }
      _specialBehavior(ball);

      if (ball.position.dy > 745 ||
          ball.position.dx < -50 ||
          ball.position.dx > 450) {
        _logDeveloperEvent(
          'DRAIN @(${ball.position.dx.round()},${ball.position.dy.round()})',
        );
        _balls.remove(ball);
        audio?.play(PinballSound.drain);
      }

      ball.trail.add(ball.position);
      if (ball.trail.length > 7) ball.trail.removeAt(0);
    }

    if (_balls.isEmpty && !_finished) {
      if (_ballSaverUntil > _time) {
        _ballSaverUntil = 0;
        _announce('BALL SAVED', seconds: 1.8);
        _logDeveloperEvent('BALL SAVED');
        audio?.play(PinballSound.award);
        _pulse(const Offset(200, 678), table.accent, size: 2.8);
        _prepareBall();
        return;
      }
      _ballsToPlay--;
      _logDeveloperEvent('BALL LOST • $_ballsToPlay LEFT');
      if (_ballsToPlay <= 0) {
        _finished = true;
        hud.value = PinballHud(
          score: _score,
          balls: 0,
          mode: table.modeNames.last,
          isReady: false,
          isPaused: false,
          isMultiball: false,
          awardLabel: '',
        );
        onGameFinished(_score);
      } else {
        _prepareBall();
      }
    }
  }

  void _specialBehavior(_Ball ball) {
    switch (table.universe) {
      case PinballUniverseId.celestial:
        if (table.variant == 0) {
          _portal(ball, const Offset(111, 404), const Offset(289, 156));
        } else if (table.variant == 1) {
          _gravityWell(ball, const Offset(114, 359), radius: 115, pull: 255);
          _gravityWell(ball, const Offset(285, 187), radius: 80, pull: 160);
        } else {
          final x = 200.0 + 52 * math.sin(_time * 1.6);
          _movingBarrier(ball, Offset(x - 34, 438), Offset(x + 34, 438));
        }
      case PinballUniverseId.neon:
        if (table.variant == 0) {
          if (ball.position.dy > 390 &&
              ball.position.dy < 402 &&
              ball.position.dx > 150 &&
              ball.position.dx < 250 &&
              ball.velocity.dy > 30) {
            ball.velocity = Offset(ball.velocity.dx * 1.15, -740);
            if (ball.portalCooldown == 0) {
              ball.portalCooldown = 0.55;
              _pulse(const Offset(200, 391), table.accent, size: 2);
              audio?.play(PinballSound.boost);
              _registerHit(350);
            }
          }
        } else if (table.variant == 1) {
          _portal(ball, const Offset(100, 392), const Offset(280, 147));
        } else {
          _gravityWell(ball, const Offset(200, 297), radius: 110, pull: 190);
          final x = 200.0 + 46 * math.sin(_time * 1.9);
          _movingBarrier(ball, Offset(x - 22, 474), Offset(x + 22, 474));
        }
      case PinballUniverseId.clockwork:
        if (table.variant == 0) {
          _movingGear(ball, Offset(200 + 36 * math.sin(_time * 1.5), 433));
        } else if (table.variant == 1) {
          if (_time % 4.8 < 2.8) {
            _movingBarrier(
              ball,
              const Offset(127, 457),
              const Offset(273, 457),
            );
          }
        } else {
          final shift = 38 * math.sin(_time * 1.22);
          _movingBarrier(
            ball,
            Offset(86 + shift, 375),
            Offset(170 + shift, 375),
          );
          _movingGear(ball, Offset(255 - shift * 0.6, 471));
        }
    }
  }

  void _portal(_Ball ball, Offset entrance, Offset exit) {
    if (ball.portalCooldown > 0 || (ball.position - entrance).distance > 23)
      return;
    ball.position = exit;
    ball.velocity = const Offset(-120, -500);
    ball.portalCooldown = 1.1;
    _pulse(entrance, table.secondary, size: 2.3);
    _pulse(exit, table.accent, size: 2.3);
    audio?.play(PinballSound.portal);
    _registerHit(1200);
  }

  void _gravityWell(
    _Ball ball,
    Offset center, {
    required double radius,
    required double pull,
  }) {
    final delta = center - ball.position;
    final distance = delta.distance;
    if (distance < 18 || distance > radius) return;
    final factor = 1 - distance / radius;
    ball.velocity += delta / distance * (pull * factor / 120);
    if (distance < radius * 0.35) audio?.play(PinballSound.gravity);
  }

  void _movingBarrier(_Ball ball, Offset a, Offset b) {
    if (!_collideSegment(ball, a, b, 0.95, width: 5)) return;
    if (ball.portalCooldown > 0) return;
    ball.portalCooldown = 0.45;
    _pulse((a + b) / 2, table.secondary, size: 1.4);
    audio?.play(PinballSound.gate);
    _registerHit(450);
  }

  void _movingGear(_Ball ball, Offset center) {
    final delta = ball.position - center;
    final distance = delta.distance;
    if (distance > 21 + _ballRadius || distance < 0.1) return;
    final normal = delta / distance;
    ball.position = center + normal * (21 + _ballRadius);
    ball.velocity = normal * 550;
    if (ball.portalCooldown > 0) return;
    ball.portalCooldown = 0.4;
    _pulse(center, table.secondary, size: 1.6);
    audio?.play(PinballSound.gear);
    _registerHit(400);
  }

  void _registerHit(int points) {
    _score += _scoreBoostUntil > _time ? points * 2 : points;
    _hits++;
    if (_hits == 5) {
      _scoreBoostUntil = _time + 13;
      _announce('2X SCORE • 13 SEC', seconds: 3);
      audio?.play(PinballSound.boost);
      _pulse(const Offset(200, 375), table.accent, size: 3);
    } else if (_hits == 9) {
      _ballSaverUntil = _time + 17;
      _announce('BALL SAVE ACTIVATED', seconds: 3);
      audio?.play(PinballSound.award);
      _pulse(const Offset(200, 663), table.secondary, size: 2.8);
    } else if (_hits == 17) {
      _ballsToPlay++;
      _announce('EXTRA BALL AWARDED', seconds: 3);
      audio?.play(PinballSound.extraBall);
      _pulse(const Offset(200, 385), table.accent, size: 4);
    } else if (_hits == 24) {
      _score += 10000;
      _announce('SUPER JACKPOT +10,000', seconds: 3.5);
      audio?.play(PinballSound.jackpot);
      _pulse(const Offset(200, 300), table.secondary, size: 5);
      _shake = reducedMotion ? 0 : 0.45;
    }
    if (!_multiballAwarded && _hits >= 12) {
      _multiballAwarded = true;
      _balls.add(_Ball(const Offset(182, 182), const Offset(-190, 320)));
      _balls.add(_Ball(const Offset(222, 182), const Offset(190, 320)));
      _announce('3-BALL MULTIBALL', seconds: 3);
      audio?.play(PinballSound.multiball);
      _pulse(const Offset(200, 220), table.accent, size: 4.8);
    }
    _notifyHud();
  }

  void _announce(String text, {double seconds = 2}) {
    _awardText = text;
    _awardTextUntil = _time + seconds;
  }

  void _pulse(Offset point, Color color, {double size = 1}) {
    // Restrained and bounded: never flood the screen during multiball.
    if (_impacts.length >= 28) _impacts.removeAt(0);
    _impacts.add(_Impact(point, color, size: size));
  }

  void _collideFlipper(_Ball ball, {required bool left}) {
    final a = left ? _leftPivot : _rightPivot;
    final lift = left ? _leftLift : _rightLift;
    final radians = left ? -0.19 - lift * 0.67 : math.pi + 0.19 + lift * 0.67;
    final b = a + Offset(math.cos(radians) * 78, math.sin(radians) * 78);
    if (!_collideSegment(ball, a, b, 0.78, width: 11)) return;
    final pressed = left ? leftPressed : rightPressed;
    if (pressed && ball.position.dy < a.dy + 18) {
      ball.velocity = Offset(
        ball.velocity.dx + (left ? 100 : -100),
        -math.max(630.0, ball.velocity.dy.abs() * 0.95 + 350),
      );
      if (_time - (ball.lastBumperHit[-1] ?? -100) > 0.10) {
        ball.lastBumperHit[-1] = _time;
        _score += 10;
        _logDeveloperEvent(
          '${left ? 'LEFT' : 'RIGHT'} FLIPPER HIT vY=${ball.velocity.dy.toStringAsFixed(0)}',
        );
        audio?.play(PinballSound.flipper);
        _notifyHud();
      }
    }
  }

  bool _collideSegment(
    _Ball ball,
    Offset a,
    Offset b,
    double bounce, {
    double width = 0,
    Offset? previousPosition,
  }) {
    if (previousPosition != null) {
      final hit = sweepRail(
        fromX: previousPosition.dx,
        fromY: previousPosition.dy,
        toX: ball.position.dx,
        toY: ball.position.dy,
        ax: a.dx,
        ay: a.dy,
        bx: b.dx,
        by: b.dy,
        radius: _ballRadius + width,
      );
      if (hit != null) {
        final normal = Offset(hit.normalX, hit.normalY);
        ball.position = Offset(
          hit.x + hit.normalX * 0.02,
          hit.y + hit.normalY * 0.02,
        );
        final incoming = _dot(ball.velocity, normal);
        if (incoming < 0) ball.velocity -= normal * ((1 + bounce) * incoming);
        _railImpactSound(ball.position, incoming);
        return true;
      }
    }
    final v = b - a;
    final sq = _dot(v, v);
    final projection = sq < 0.001
        ? 0.0
        : (_dot(ball.position - a, v) / sq).clamp(0.0, 1.0).toDouble();
    final closest = a + v * projection;
    final delta = ball.position - closest;
    final distance = delta.distance;
    final minDistance = _ballRadius + width;
    if (distance >= minDistance) return false;
    final normal = distance < 0.0001 ? const Offset(0, -1) : delta / distance;
    ball.position = closest + normal * minDistance;
    final incoming = _dot(ball.velocity, normal);
    if (incoming < 0) ball.velocity -= normal * ((1 + bounce) * incoming);
    _railImpactSound(closest, incoming);
    return true;
  }

  void _railImpactSound(Offset contact, double incoming) {
    if (incoming >= -260 || _time - _lastRailImpact <= 0.10) return;
    _lastRailImpact = _time;
    _logDeveloperEvent(
      'RAIL @(${contact.dx.round()},${contact.dy.round()}) '
      'impact=${incoming.abs().round()}',
    );
    _pulse(contact, table.accent, size: 0.75);
    audio?.play(PinballSound.rail);
  }

  double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  double _approach(double current, double target, double maxDelta) =>
      current + (target - current).clamp(-maxDelta, maxDelta).toDouble();

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final viewWidth = size.x;
    final viewHeight = size.y;
    if (viewWidth <= 0 || viewHeight <= 0) return;
    final scale = math.min(viewWidth / _boardWidth, viewHeight / _boardHeight);
    var zoom = 1.0;
    var focus = const Offset(200, 380);
    // Cinematic plunger close-up -> short ball follow -> full-field reveal.
    // The shot never pauses physics or prevents two-finger flipper input.
    if (_cinematicTime >= 0 && !reducedMotion) {
      final blend = _cinematicTime < 0.35
          ? 1.0
          : (1 - (_cinematicTime - 0.35) / 1.0).clamp(0.0, 1.0).toDouble();
      zoom = 1 + 0.34 * blend * blend;
      if (_balls.isNotEmpty) {
        focus = Offset.lerp(focus, _balls.first.position, 0.82 * blend)!;
      }
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, viewWidth, viewHeight));
    canvas.translate(viewWidth / 2, viewHeight / 2);
    canvas.scale(scale * zoom);
    canvas.translate(-focus.dx, -focus.dy);
    if (_shake > 0 && !reducedMotion) {
      canvas.translate(
        math.sin(_time * 63) * _shake * 2.2,
        math.cos(_time * 71) * _shake * 2.2,
      );
    }
    _renderBoard(canvas);
    if (developerCollisionOverlay) _renderDeveloperCollisionOverlay(canvas);
    canvas.restore();
  }

  void _renderDeveloperCollisionOverlay(Canvas c) {
    final envelope = Paint()
      ..color = const Color(0x6637F2BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ballRadius * 2;
    final outline = Paint()
      ..color = const Color(0xEE37F2BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final rail in _rails) {
      c.drawLine(rail.a, rail.b, envelope);
      c.drawLine(rail.a, rail.b, outline);
    }
    final bumperPaint = Paint()
      ..color = const Color(0xDDFF8AC9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (final bumper in _bumpers) {
      c.drawCircle(
        bumper.center,
        bumper.radius + _ballRadius,
        bumperPaint,
      );
    }
    for (final left in <bool>[true, false]) {
      final pivot = left ? _leftPivot : _rightPivot;
      final lift = left ? _leftLift : _rightLift;
      final angle = left ? -0.19 - lift * 0.67 : math.pi + 0.19 + lift * 0.67;
      final tip = pivot + Offset(math.cos(angle) * 78, math.sin(angle) * 78);
      c.drawLine(
        pivot,
        tip,
        Paint()
          ..color = const Color(0x55FFD378)
          ..strokeWidth = 2 * (_ballRadius + 11)
          ..strokeCap = StrokeCap.round,
      );
      c.drawLine(
        pivot,
        tip,
        Paint()
          ..color = const Color(0xFFFFD378)
          ..strokeWidth = 1.5,
      );
    }
    c.drawLine(
      Offset(_shooterLane.centerX, _shooterLane.readyY),
      Offset(_shooterLane.centerX, _shooterLane.exitY),
      Paint()
        ..color = const Color(0xCCFFFF70)
        ..strokeWidth = 1.5,
    );
    c.drawCircle(
      Offset(_shooterLane.centerX, _shooterLane.exitY),
      _ballRadius,
      Paint()
        ..color = const Color(0xFFFFFF70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _renderBoard(Canvas c) {
    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 12, 376, 736),
      const Radius.circular(26),
    );
    c.drawRRect(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[table.base, const Color(0xFF04050A), table.base],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 760)),
    );
    final backplate = _backplateSprite;
    if (backplate != null) {
      // Original high-detail 2D scene, deliberately *without* physical parts.
      // Real colliders and animated targets are rendered above this layer.
      const dest = Rect.fromLTWH(12, 12, 376, 736);
      final sourceAspect = backplate.width / backplate.height;
      final destAspect = dest.width / dest.height;
      final Rect source;
      if (sourceAspect > destAspect) {
        final visibleWidth = backplate.height * destAspect;
        source = Rect.fromLTWH(
          (backplate.width - visibleWidth) / 2,
          0,
          visibleWidth,
          backplate.height.toDouble(),
        );
      } else {
        final visibleHeight = backplate.width / destAspect;
        source = Rect.fromLTWH(
          0,
          (backplate.height - visibleHeight) / 2,
          backplate.width.toDouble(),
          visibleHeight,
        );
      }
      c.save();
      c.clipRRect(board);
      c.drawImageRect(
        backplate,
        source,
        dest,
        Paint()..filterQuality = FilterQuality.medium,
      );
      // Recesses the surface beneath bright collision rails, ball and lamps.
      c.drawRect(
        dest,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x7000030A),
              Color(0x26000108),
              Color(0x66000209),
            ],
          ).createShader(dest),
      );
      c.restore();
    }
    c.drawRRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = table.accent.withValues(alpha: 0.5),
    );
    c.drawRRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    _drawTableDecor(c);

    for (final rail in _rails) {
      _glowLine(c, rail.a, rail.b, table.accent, 2.5);
    }
    for (var i = 0; i < _bumpers.length; i++) {
      final bumper = _bumpers[i];
      final sprite = _bumperSprite;
      if (sprite != null) {
        _drawCenteredSprite(c, sprite, bumper.center, bumper.radius * 1.35);
        _drawRing(c, bumper.center, bumper.radius + 3, table.secondary, 1.5);
      } else {
        _glowCircle(c, bumper.center, bumper.radius, table.secondary);
        _glowCircle(c, bumper.center, bumper.radius * 0.48, table.accent);
      }
      final sinceHit = _time - (_bumperLastGlow[i] ?? -100);
      if (sinceHit < 0.30) {
        final strength = (1 - sinceHit / 0.30).clamp(0.0, 1.0).toDouble();
        _drawRing(
          c,
          bumper.center,
          bumper.radius + 7 + sinceHit * 45,
          table.accent.withValues(alpha: strength * 0.8),
          4,
        );
      }
    }

    _drawImpacts(c);

    _drawFlipper(c, _leftPivot, true, _leftLift);
    _drawFlipper(c, _rightPivot, false, _rightLift);

    // Right-side shooter lane and plunger, kept separate from the HUD.
    _glowLine(
      c,
      const Offset(351, 697),
      const Offset(351, 714),
      table.secondary,
      6,
    );

    for (final ball in _balls) {
      for (var i = 0; i < ball.trail.length; i++) {
        final alpha = (i + 1) / (ball.trail.length + 1) * 0.22;
        c.drawCircle(
          ball.trail[i],
          3 + alpha * 14,
          Paint()..color = table.accent.withValues(alpha: alpha),
        );
      }
      c.drawCircle(
        ball.position + const Offset(2, 3),
        _ballRadius + 2,
        Paint()..color = Colors.black.withValues(alpha: 0.70),
      );
      final sprite = _ballSprite;
      if (sprite != null) {
        _drawCenteredSprite(c, sprite, ball.position, _ballRadius * 1.35);
      } else {
        c.drawCircle(
          ball.position,
          _ballRadius,
          Paint()
            ..shader =
                const RadialGradient(
                  center: Alignment(-0.5, -0.6),
                  colors: <Color>[
                    Colors.white,
                    Color(0xFFA8C8E0),
                    Color(0xFF26344B),
                  ],
                ).createShader(
                  Rect.fromCircle(center: ball.position, radius: _ballRadius),
                ),
        );
        c.drawCircle(
          ball.position + const Offset(-2, -3),
          2.2,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawCenteredSprite(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double radius,
  ) {
    // Keeps circular bumpers round even when a source canvas is widescreen.
    final side = math.min(image.width, image.height).toDouble();
    final source = Rect.fromLTWH(
      (image.width - side) / 2,
      (image.height - side) / 2,
      side,
      side,
    );
    canvas.drawImageRect(
      image,
      source,
      Rect.fromCircle(center: center, radius: radius),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _drawRotatingSprite(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double radius,
    double angle,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    _drawCenteredSprite(canvas, image, Offset.zero, radius);
    canvas.restore();
  }

  void _drawImpacts(Canvas c) {
    for (final impact in _impacts) {
      final progress = impact.age / impact.duration;
      final fading = (1 - progress).clamp(0.0, 1.0).toDouble();
      final radius = (7 + 30 * progress) * impact.size;
      c.drawCircle(
        impact.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * fading
          ..color = impact.color.withValues(alpha: 0.58 * fading),
      );
      // Sparse radial spark lines: readable even during multiball.
      for (var i = 0; i < 7; i++) {
        final angle = i * (math.pi * 2 / 7);
        final inner =
            impact.center +
            Offset(
              math.cos(angle) * radius * 0.52,
              math.sin(angle) * radius * 0.52,
            );
        final outer =
            impact.center +
            Offset(
              math.cos(angle) * radius * 0.82,
              math.sin(angle) * radius * 0.82,
            );
        c.drawLine(
          inner,
          outer,
          Paint()
            ..strokeWidth = fading * 2
            ..strokeCap = StrokeCap.round
            ..color = impact.color.withValues(alpha: fading * 0.72),
        );
      }
    }
  }

  void _drawTableDecor(Canvas c) {
    switch (table.universe) {
      case PinballUniverseId.celestial:
        for (var i = 0; i < 24; i++) {
          final x = 43.0 + (i * 79 % 310);
          final y = 72.0 + (i * 137 % 555);
          c.drawCircle(
            Offset(x, y),
            1.2,
            Paint()..color = Colors.white.withValues(alpha: 0.6),
          );
        }
        _drawRing(c, const Offset(200, 163), 49, table.accent, 1.4);
        _drawRing(c, const Offset(200, 163), 38, table.secondary, 2);
        _drawRing(c, const Offset(200, 531), 52, table.accent, 1);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4 + _time * 0.17;
          final a =
              const Offset(200, 163) +
              Offset(math.cos(angle) * 32, math.sin(angle) * 32);
          final b =
              const Offset(200, 163) +
              Offset(math.cos(angle) * 48, math.sin(angle) * 48);
          _glowLine(c, a, b, table.secondary, 1.2);
        }
        if (table.variant == 0) {
          final sprite = _hazardSprite;
          if (sprite != null) {
            _drawRotatingSprite(
              c,
              sprite,
              const Offset(111, 404),
              28,
              _time * 0.32,
            );
            _drawRotatingSprite(
              c,
              sprite,
              const Offset(289, 156),
              28,
              -_time * 0.28,
            );
          } else {
            _drawRing(c, const Offset(111, 404), 22, table.secondary, 3);
            _drawRing(c, const Offset(289, 156), 22, table.accent, 3);
          }
        } else if (table.variant == 1) {
          _drawRing(c, const Offset(114, 359), 72, table.secondary, 1.5);
          _drawRing(c, const Offset(285, 187), 41, table.accent, 2);
        } else if (table.variant == 2) {
          final x = 200.0 + 52 * math.sin(_time * 1.6);
          _glowLine(
            c,
            Offset(x - 34, 438),
            Offset(x + 34, 438),
            table.secondary,
            7,
          );
        }
      case PinballUniverseId.neon:
        for (var i = 0; i < 14; i++) {
          final y = 99.0 + i * 39;
          _glowLine(
            c,
            Offset(53, y),
            Offset(324, y),
            table.accent.withValues(alpha: 0.16),
            0.6,
          );
        }
        for (var i = 0; i < 7; i++) {
          final x = 63.0 + i * 42;
          _glowLine(
            c,
            Offset(x, 84),
            Offset(x, 621),
            table.secondary.withValues(alpha: 0.13),
            0.6,
          );
        }
        _drawRing(c, const Offset(200, 391), 46, table.secondary, 3);
        _drawRing(c, const Offset(200, 391), 28, table.accent, 2);
        _glowLine(
          c,
          const Offset(144, 390),
          const Offset(256, 390),
          table.secondary,
          5,
        );
        if (table.variant == 1) {
          _drawRing(c, const Offset(100, 392), 24, table.secondary, 3);
          _drawRing(c, const Offset(280, 147), 24, table.accent, 3);
        } else if (table.variant == 2) {
          if (_hazardSprite case final reactor?) {
            _drawCenteredSprite(c, reactor, const Offset(200, 297), 47);
          }
          _drawRing(c, const Offset(200, 297), 74, table.accent, 2);
          final x = 200.0 + 46 * math.sin(_time * 1.9);
          _glowLine(
            c,
            Offset(x - 22, 474),
            Offset(x + 22, 474),
            table.secondary,
            6,
          );
        }
      case PinballUniverseId.clockwork:
        for (final center in <Offset>[
          const Offset(200, 154),
          const Offset(97, 474),
          const Offset(298, 475),
        ]) {
          final radius = center.dx == 200 ? 48.0 : 32.0;
          _drawRing(c, center, radius, table.accent, 2.5);
          _drawRing(c, center, radius - 13, table.secondary, 1.2);
          for (var i = 0; i < 12; i++) {
            final angle = i * math.pi / 6 + _time * 0.14;
            _glowLine(
              c,
              center +
                  Offset(
                    math.cos(angle) * (radius - 3),
                    math.sin(angle) * (radius - 3),
                  ),
              center +
                  Offset(
                    math.cos(angle) * (radius + 6),
                    math.sin(angle) * (radius + 6),
                  ),
              table.accent,
              3,
            );
          }
        }
        if (table.variant == 0) {
          final center = Offset(200 + 36 * math.sin(_time * 1.5), 433);
          if (_hazardSprite case final gear?) {
            _drawRotatingSprite(c, gear, center, 23, _time * 1.9);
          } else {
            _drawRing(c, center, 21, table.secondary, 6);
          }
        } else if (table.variant == 1) {
          if (_time % 4.8 < 2.8) {
            _glowLine(
              c,
              const Offset(127, 457),
              const Offset(273, 457),
              table.accent,
              7,
            );
          }
        } else if (table.variant == 2) {
          final shift = 38 * math.sin(_time * 1.22);
          _glowLine(
            c,
            Offset(86 + shift, 375),
            Offset(170 + shift, 375),
            table.secondary,
            7,
          );
          final center = Offset(255 - shift * 0.6, 471);
          if (_hazardSprite case final gear?) {
            _drawRotatingSprite(c, gear, center, 23, -_time * 1.4);
          } else {
            _drawRing(c, center, 21, table.accent, 3);
          }
        }
    }
  }

  void _drawRing(
    Canvas c,
    Offset center,
    double radius,
    Color color,
    double width,
  ) {
    c.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 3
        ..color = color.withValues(alpha: 0.08),
    );
    c.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: 0.77),
    );
  }

  void _glowCircle(Canvas c, Offset center, double radius, Color color) {
    c.drawCircle(
      center,
      radius + 9,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[color.withValues(alpha: 0.45), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 11)),
    );
    c.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    c.drawCircle(
      center,
      radius - 5,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  void _glowLine(Canvas c, Offset a, Offset b, Color color, double width) {
    c.drawLine(
      a,
      b,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 4
        ..color = color.withValues(alpha: 0.10),
    );
    c.drawLine(
      a,
      b,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color.withValues(alpha: 0.88),
    );
  }

  void _drawFlipper(Canvas c, Offset pivot, bool left, double lift) {
    final angle = left ? -0.19 - lift * 0.67 : math.pi + 0.19 + lift * 0.67;
    final tip = pivot + Offset(math.cos(angle) * 78, math.sin(angle) * 78);
    _glowLine(c, pivot, tip, table.secondary, 18);
    c.drawLine(
      pivot,
      tip,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10
        ..color = const Color(0xFFF7F3E8),
    );
    _glowCircle(c, pivot, 7, table.accent);
  }
}
