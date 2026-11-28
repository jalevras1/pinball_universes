import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../audio/pinball_audio.dart';
import 'developer_scenarios.dart';
import 'citadel_ball_lock.dart';
import 'brass_switchyard.dart';
import 'plunger_model.dart';
import 'moonbridge_ramp.dart';
import 'shooter_lane.dart';
import 'swept_rail.dart';
import 'table_data.dart';

const double _boardWidth = 400;
const double _boardHeight = 760;
const double _ballRadius = 7.5;
const double _flipperLength = 56;
const double _flipperRadius = 7;
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
  // Raised Moonbridge travel is a distinct, collider-free flight state.
  double moonbridgeDistance = -1;
  double moonbridgeCooldown = 0;
  // Independent elevated travel state for Brass Labyrinth's two tunnel routes.
  int switchyardLane = -1;
  double switchyardDistance = 0;
  double switchyardCooldown = 0;
  final List<Offset> trail = <Offset>[];
  final Map<int, double> lastBumperHit = <int, double>{};
}

class _Segment {
  const _Segment(this.a, this.b, {this.width = 1.5, this.kicker = false});

  final Offset a;
  final Offset b;
  final double bounce = 0.84;
  final double width;
  final bool kicker;
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
  bool get _arcadeLayout => table.id == PinballTableId.astralOrrery;
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
  bool get debugBallInMoonbridge =>
      _balls.any((ball) => ball.moonbridgeDistance >= 0);

  @visibleForTesting
  bool get debugBallInSwitchyard =>
      _balls.any((ball) => ball.switchyardLane >= 0);

  @visibleForTesting
  int get debugSwitchyardLastExitSide => _switchyardLastExitSide;

  @visibleForTesting
  bool get debugSwitchyardOpenLeft => BrassSwitchyard.leftOpen(_time);

  @visibleForTesting
  int get debugCitadelLockedBalls => _citadelLockedBalls;

  @visibleForTesting
  bool get debugCitadelReleased => _citadelReleased;


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
      case PinballDeveloperScenario.moonbridgeRamp:
        if (table.id != PinballTableId.moonfallSanctuary) return false;
        // Enter through the real ramp sensor on the following physics frame.
        debugPlaceBall(const Offset(290, 529), const Offset(0, -480));
        leftPressed = false;
        rightPressed = false;
      case PinballDeveloperScenario.citadelLock:
        if (table.id != PinballTableId.chronoCitadel) return false;
        // Advance into the next naturally OPEN gate phase. The ball must
        // physically enter the vault; the button never gives free points.
        _advanceDeveloperGatePhase(3.0);
        debugPlaceBall(const Offset(198, 496), const Offset(0, 330));
        leftPressed = false;
        rightPressed = false;
      case PinballDeveloperScenario.citadelRelease:
        if (table.id != PinballTableId.chronoCitadel) return false;
        // Aim a moving test ball at the real CLOSED gate collision segment.
        _advanceDeveloperGatePhase(0.1);
        debugPlaceBall(const Offset(200, 445), const Offset(0, 550));
        leftPressed = false;
        rightPressed = false;
      case PinballDeveloperScenario.brassLeftRoute:
      case PinballDeveloperScenario.brassRightRoute:
        if (table.id != PinballTableId.brassLabyrinth) return false;
        final left = scenario == PinballDeveloperScenario.brassLeftRoute;
        _advanceDeveloperSwitchyardPhase(left ? 0.6 : 3.8);
        debugPlaceBall(Offset(left ? 176 : 226, 366), const Offset(0, 820));
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

  void _advanceDeveloperGatePhase(double phase) {
    final cycle = (_time / CitadelBallLock.period).floor();
    var target = cycle * CitadelBallLock.period + phase;
    if (target <= _time) target += CitadelBallLock.period;
    _time = target;
  }

  void _advanceDeveloperSwitchyardPhase(double phase) {
    final cycle = (_time / BrassSwitchyard.cycleSeconds).floor();
    var target = cycle * BrassSwitchyard.cycleSeconds + phase;
    if (target <= _time) target += BrassSwitchyard.cycleSeconds;
    _time = target;
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
  // Batch 014: top-down artwork shares the existing circular bumper collider.
  ui.Image? _astralBumperSprite;
  ui.Image? _astralBumperHitSprite;
  ui.Image? _moonbridgeIdleSprite;
  ui.Image? _moonbridgeActiveSprite;
  final List<ui.Image?> _citadelLockSprites = List<ui.Image?>.filled(3, null);
  ui.Image? _citadelGateClosedSprite;
  ui.Image? _citadelGateOpenSprite;
  ui.Image? _brassTrackSprite;
  ui.Image? _brassLeftActiveSprite;
  ui.Image? _brassRightActiveSprite;
  ui.Image? _brassGateOpenSprite;
  ui.Image? _brassGateClosedSprite;
  // Batch 019: sprites warped into the exact existing slingshot rail triangles.
  ui.Image? _slingLeftIdle;
  ui.Image? _slingLeftHit;
  ui.Image? _slingRightIdle;
  ui.Image? _slingRightHit;
  double _slingLeftFlashUntil = -1;
  double _slingRightFlashUntil = -1;
  ui.Image? _backplateSprite;
  ui.Image? _hazardSprite;
  bool _spritesReleased = false;

  bool leftPressed = false;
  bool rightPressed = false;
  bool _paused = false;
  bool _finished = false;
  bool _multiballAwarded = false;
  int _citadelLockedBalls = 0;
  bool _citadelReleased = false;
  int _switchyardLastExitSide = -1;
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
    if (_arcadeLayout) {
      _astralBumperSprite = await _loadSprite(
        'assets/gameplay/mechanical/pop_bumper_blue_idle.png',
        128,
      );
      _astralBumperHitSprite = await _loadSprite(
        'assets/gameplay/mechanical/pop_bumper_blue_hit.png',
        128,
      );
      _slingLeftIdle = await _loadSprite(
        'assets/gameplay/mechanical/slingshot_left_idle_aligned.png', 96,
      );
      _slingLeftHit = await _loadSprite(
        'assets/gameplay/mechanical/slingshot_left_hit_aligned.png', 96,
      );
      _slingRightIdle = await _loadSprite(
        'assets/gameplay/mechanical/slingshot_right_idle_aligned.png', 96,
      );
      _slingRightHit = await _loadSprite(
        'assets/gameplay/mechanical/slingshot_right_hit_aligned.png', 96,
      );
    }
    if (table.id == PinballTableId.moonfallSanctuary) {
      _moonbridgeIdleSprite = await _loadSprite(
        'assets/gameplay/mechanical/moonbridge_ramp_idle.png', 600,
      );
      _moonbridgeActiveSprite = await _loadSprite(
        'assets/gameplay/mechanical/moonbridge_ramp_active.png', 600,
      );
    }
    if (table.id == PinballTableId.chronoCitadel) {
      for (var i = 0; i < _citadelLockSprites.length; i++) {
        _citadelLockSprites[i] = await _loadSprite(
          'assets/gameplay/mechanical/citadel_lock_$i.png', 184,
        );
      }
      _citadelGateClosedSprite = await _loadSprite(
        'assets/gameplay/mechanical/citadel_gate_closed.png', 336,
      );
      _citadelGateOpenSprite = await _loadSprite(
        'assets/gameplay/mechanical/citadel_gate_open.png', 336,
      );
    }
    if (table.id == PinballTableId.brassLabyrinth) {
      _brassTrackSprite = await _loadSprite(
        'assets/gameplay/mechanical/brass_switchyard_track.png', 600,
      );
      _brassLeftActiveSprite = await _loadSprite(
        'assets/gameplay/mechanical/brass_switchyard_left_active.png', 600,
      );
      _brassRightActiveSprite = await _loadSprite(
        'assets/gameplay/mechanical/brass_switchyard_right_active.png', 600,
      );
      _brassGateOpenSprite = await _loadSprite(
        'assets/gameplay/mechanical/brass_switchyard_gate_open.png', 180,
      );
      _brassGateClosedSprite = await _loadSprite(
        'assets/gameplay/mechanical/brass_switchyard_gate_closed.png', 180,
      );
    }
    _backplateSprite = await _loadSprite(
      'assets/backplates/${table.universe.name}.png',
      512,
    );
    final hazardAsset = switch (table.universe) {
      PinballUniverseId.celestial when table.variant == 0 =>
        'assets/gameplay/mechanical/capture_hole_violet.png',
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
    _astralBumperSprite?.dispose();
    _astralBumperHitSprite?.dispose();
    _moonbridgeIdleSprite?.dispose();
    _moonbridgeActiveSprite?.dispose();
    for (final image in _citadelLockSprites) { image?.dispose(); }
    _citadelGateClosedSprite?.dispose();
    _citadelGateOpenSprite?.dispose();
    _brassTrackSprite?.dispose();
    _brassLeftActiveSprite?.dispose();
    _brassRightActiveSprite?.dispose();
    _brassGateOpenSprite?.dispose();
    _brassGateClosedSprite?.dispose();
    _slingLeftIdle?.dispose();
    _slingLeftHit?.dispose();
    _slingRightIdle?.dispose();
    _slingRightHit?.dispose();
    _backplateSprite?.dispose();
    _hazardSprite?.dispose();
    _ballSprite = null;
    _bumperSprite = null;
    _astralBumperSprite = null;
    _astralBumperHitSprite = null;
    _moonbridgeIdleSprite = null;
    _moonbridgeActiveSprite = null;
    for (var i = 0; i < _citadelLockSprites.length; i++) {
      _citadelLockSprites[i] = null;
    }
    _citadelGateClosedSprite = null;
    _citadelGateOpenSprite = null;
    _brassTrackSprite = null;
    _brassLeftActiveSprite = null;
    _brassRightActiveSprite = null;
    _brassGateOpenSprite = null;
    _brassGateClosedSprite = null;
    _slingLeftIdle = null;
    _slingLeftHit = null;
    _slingRightIdle = null;
    _slingRightHit = null;
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
    ]);
    if (_arcadeLayout) {
      _rails.addAll(const <_Segment>[
        _Segment(Offset(74, 480), Offset(74, 579), width: 3),
        _Segment(Offset(74, 579), Offset(114, 654), width: 3),
        _Segment(Offset(294, 480), Offset(294, 579), width: 3),
        _Segment(Offset(294, 579), Offset(286, 654), width: 3),
        _Segment(Offset(108, 518), Offset(158, 574), width: 4, kicker: true),
        _Segment(Offset(158, 574), Offset(128, 604), width: 4),
        _Segment(Offset(128, 604), Offset(108, 518), width: 4),
        _Segment(Offset(258, 518), Offset(223, 574), width: 4, kicker: true),
        _Segment(Offset(223, 574), Offset(252, 604), width: 4),
        _Segment(Offset(252, 604), Offset(258, 518), width: 4),
        _Segment(Offset(171, 78), Offset(171, 111), width: 3),
        _Segment(Offset(229, 78), Offset(229, 111), width: 3),
      ]);
    } else {
      _rails.addAll(const <_Segment>[
      _Segment(Offset(35, 559), Offset(105, 631)),
      _Segment(Offset(365, 559), Offset(295, 631)),
      _Segment(Offset(31, 689), Offset(88, 716)),
      _Segment(Offset(369, 689), Offset(312, 716)),
      _Segment(Offset(76, 612), Offset(105, 652)),
      _Segment(Offset(324, 612), Offset(295, 652)),
    ]);
    }

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
    _citadelLockedBalls = 0;
    _citadelReleased = false;
    _switchyardLastExitSide = -1;
    _impacts.clear();
    _bumperLastGlow.clear();
    _slingLeftFlashUntil = -1;
    _slingRightFlashUntil = -1;
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
      // A raised switchyard ball must never collide with rails/bumpers below.
      // The actual 85-point artwork curves are the physics source of truth.
      if (table.id == PinballTableId.brassLabyrinth &&
          ball.switchyardLane >= 0) {
        final side = ball.switchyardLane;
        final travel = BrassSwitchyard.advance(
          side, ball.switchyardDistance, dt,
        );
        ball.switchyardDistance = travel.distance;
        ball.position = travel.position;
        ball.velocity = Offset.zero;
        if (travel.finished) {
          ball.switchyardLane = -1;
          ball.switchyardCooldown = BrassSwitchyard.cooldownSeconds;
          ball.velocity = BrassSwitchyard.exitVelocity(side);
          _switchyardLastExitSide = side;
          _registerHit(BrassSwitchyard.exitPoints(side));
          _announce(side == 0 ? 'LEFT TUNNEL +650' : 'RIGHT TUNNEL +850',
              seconds: 1.8);
          _pulse(ball.position, table.accent, size: 2.0);
          _logDeveloperEvent('SWITCHYARD EXIT ${side == 0 ? "LEFT" : "RIGHT"}');
          audio?.play(PinballSound.award);
        }
        ball.trail.add(ball.position);
        if (ball.trail.length > 7) ball.trail.removeAt(0);
        continue;
      }
      ball.switchyardCooldown =
          math.max(0.0, ball.switchyardCooldown - dt);
      // An elevated ramp must not hit the physical rails and bumpers below it.
      // Use exactly the same centerline as the 2D artwork and return the ball
      // to the lower deck with a distinct exit impulse only after traversal.
      if (table.id == PinballTableId.moonfallSanctuary &&
          ball.moonbridgeDistance >= 0) {
        final step = MoonbridgeRamp.advance(ball.moonbridgeDistance, dt);
        ball.moonbridgeDistance = step.distance;
        ball.position = step.position;
        ball.velocity = Offset.zero;
        if (step.finished) {
          ball.moonbridgeDistance = -1;
          ball.moonbridgeCooldown = MoonbridgeRamp.cooldownSeconds;
          ball.velocity = MoonbridgeRamp.exitVelocity;
          _registerHit(MoonbridgeRamp.exitBonus);
          _announce('MOONBRIDGE +700', seconds: 1.5);
          _pulse(MoonbridgeRamp.exit, table.accent, size: 1.8);
          _logDeveloperEvent('MOONBRIDGE EXIT +700');
          audio?.play(PinballSound.award);
        }
        ball.trail.add(ball.position);
        if (ball.trail.length > 7) ball.trail.removeAt(0);
        continue;
      }
      ball.moonbridgeCooldown =
          math.max(0.0, ball.moonbridgeCooldown - dt);
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
      if (table.id == PinballTableId.moonfallSanctuary &&
          MoonbridgeRamp.canEnter(
            ball.position, ball.velocity, cooldown: ball.moonbridgeCooldown,
          )) {
        ball.position = MoonbridgeRamp.entrance;
        ball.velocity = Offset.zero;
        ball.moonbridgeDistance = 0;
        ball.trail.clear();
        _pulse(MoonbridgeRamp.entrance, table.secondary, size: 1.4);
        _logDeveloperEvent('MOONBRIDGE CAPTURE');
        // No under-track or lower-deck contacts on this fixed step.
        continue;
      }
      if (_arcadeLayout && (previousPosition.dy-95)*(ball.position.dy-95)<0) {
        for(var lane=0;lane<3;lane++) {
          final center=142.0+lane*58;
          final key=-2000-lane;
          if ((ball.position.dx-center).abs()<=10 && _time-(ball.lastBumperHit[key]??-100)>0.4) {
            ball.lastBumperHit[key]=_time;
            _pulse(Offset(center,95),table.accent);
            _registerHit(150);
          }
        }
      }

      for (var ri = 0; ri < _rails.length; ri++) {
        final rail = _rails[ri];
        if (_collideSegment(
          ball,
          rail.a,
          rail.b,
          rail.bounce,
          width: rail.width,
          previousPosition: previousPosition,
        )) {
          if (rail.kicker && _time - (ball.lastBumperHit[-1000-ri] ?? -100) > 0.18) {
            final axis = rail.b - rail.a;
            final u = (_dot(ball.position-rail.a, axis)/_dot(axis,axis)).clamp(0.0,1.0).toDouble();
            final delta = ball.position - (rail.a + axis*u);
            if (delta.distance > 0.001) {
              final normal = delta/delta.distance;
              if (_dot(ball.velocity,normal) > 60) {
                ball.lastBumperHit[-1000-ri] = _time;
                if (rail.a.dx < _boardWidth / 2) {
                  _slingLeftFlashUntil = _time + 0.16;
                } else {
                  _slingRightFlashUntil = _time + 0.16;
                }
                ball.velocity += normal*220;
                _pulse(ball.position, table.secondary, size: 1.2);
                audio?.play(PinballSound.rail);
                _registerHit(100);
                _logDeveloperEvent('SLINGSHOT +100');
              }
            }
          }
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
      if (_captureCitadelBall(ball)) continue;
      if (_resolveBrassSwitchyard(ball, previousPosition)) continue;
      _specialBehavior(ball);

      final outlaneDrain = _arcadeLayout && ball.position.dy > 690 && (ball.position.dx < 75 || (ball.position.dx > 294 && ball.position.dx < 336));
      if (outlaneDrain || ball.position.dy > 745 ||
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

  bool _captureCitadelBall(_Ball ball) {
    if (table.id != PinballTableId.chronoCitadel ||
        !CitadelBallLock.canCapture(
          position: ball.position,
          velocity: ball.velocity,
          elapsed: _time,
          lockedBalls: _citadelLockedBalls,
          alreadyReleased: _citadelReleased,
        )) return false;
    // Store the actual playfield ball, not a fake visual counter. A lock is
    // never charged as a drain, and the shooter rearms the replacement ball.
    _balls.remove(ball);
    _citadelLockedBalls++;
    _registerHit(CitadelBallLock.lockPoints);
    _announce('VAULT ${_citadelLockedBalls}/2 LOCKED', seconds: 2.3);
    _pulse(CitadelBallLock.mouth, table.secondary, size: 2.0);
    _logDeveloperEvent('CITADEL LOCK ${_citadelLockedBalls}/2');
    audio?.play(PinballSound.gate);
    _prepareBall();
    return true;
  }

  void _releaseCitadelBalls() {
    if (_citadelReleased || _citadelLockedBalls != CitadelBallLock.capacity) return;
    _citadelLockedBalls = 0;
    _citadelReleased = true;
    _multiballAwarded = true;
    for (var i = 0; i < CitadelBallLock.capacity; i++) {
      _balls.add(_Ball(
        CitadelBallLock.releasedPositions[i],
        CitadelBallLock.releasedVelocities[i],
      ));
    }
    _registerHit(CitadelBallLock.releasePoints);
    _announce('CITADEL 3-BALL RELEASE +1500', seconds: 3);
    _pulse(CitadelBallLock.mouth, table.accent, size: 4);
    _logDeveloperEvent('CITADEL MULTIBALL 3 BALLS');
    _shake = reducedMotion ? 0 : math.max(_shake, 0.32);
    audio?.play(PinballSound.multiball);
    _notifyHud();
  }

  bool _resolveBrassSwitchyard(_Ball ball, Offset previousPosition) {
    if (table.id != PinballTableId.brassLabyrinth) return false;
    // Match the physical sliding gate collision segment. The old moving
    // placeholder barrier is removed from this table, not merely hidden.
    final closedSide = BrassSwitchyard.leftOpen(_time) ? 1 : 0;
    final gateHit = _collideSegment(
      ball,
      BrassSwitchyard.gateA(closedSide),
      BrassSwitchyard.gateB(closedSide),
      0.90,
      width: 3,
      previousPosition: previousPosition,
    );
    if (gateHit) {
      if (_time - (ball.lastBumperHit[-4200] ?? -100) >= 0.20) {
        ball.lastBumperHit[-4200] = _time;
        _registerHit(BrassSwitchyard.closedGatePoints);
        _pulse(ball.position, table.secondary, size: 1.25);
        audio?.play(PinballSound.gate);
        _logDeveloperEvent('SWITCHYARD CLOSED GATE +125');
      }
      return false;
    }
    final lane = BrassSwitchyard.detectEntry(
      previous: previousPosition,
      current: ball.position,
      velocity: ball.velocity,
      elapsed: _time,
      cooldown: ball.switchyardCooldown,
    );
    if (lane == null) return false;
    ball.switchyardLane = lane;
    ball.switchyardDistance = 0;
    ball.position = BrassSwitchyard.entrance(lane);
    ball.velocity = Offset.zero;
    ball.trail.clear();
    _pulse(ball.position, table.accent, size: 1.4);
    _logDeveloperEvent('SWITCHYARD ENTER ${lane == 0 ? "LEFT" : "RIGHT"}');
    // No lower-deck trigger, drain or bumper contacts this frame.
    return true;
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
          if (CitadelBallLock.isGateClosed(_time)) {
            final gateContact = _movingBarrier(
              ball, CitadelBallLock.gateA, CitadelBallLock.gateB,
            );
            if (CitadelBallLock.canRelease(
              actualGateContact: gateContact,
              elapsed: _time,
              lockedBalls: _citadelLockedBalls,
              alreadyReleased: _citadelReleased,
            )) {
              _releaseCitadelBalls();
            }
          }
        } else {
          // Brass Labyrinth now uses two real elevated passage gates.
          // Keep the gear obstacle; remove the conflicting phantom barrier.
          final shift = 38 * math.sin(_time * 1.22);
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

  bool _movingBarrier(_Ball ball, Offset a, Offset b) {
    if (!_collideSegment(ball, a, b, 0.95, width: 5)) return false;
    if (ball.portalCooldown > 0) return false;
    ball.portalCooldown = 0.45;
    _pulse((a + b) / 2, table.secondary, size: 1.4);
    audio?.play(PinballSound.gate);
    _registerHit(450);
    return true;
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
    // Chrono Citadel requires two physically trapped balls and an actual
    // gate strike; it must never gain fake balls from the global hit counter.
    if (table.id != PinballTableId.chronoCitadel &&
        !_multiballAwarded && _hits >= 12) {
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
    final b = _flipperTip(a,left,lift);
    if (!_collideSegment(ball, a, b, 0.78, width: _flipperRadius)) return;
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
      envelope.strokeWidth = (_ballRadius+rail.width)*2;
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
      final tip = _flipperTip(pivot,left,lift);
      c.drawLine(
        pivot,
        tip,
        Paint()
          ..color = const Color(0x55FFD378)
          ..strokeWidth = 2 * (_ballRadius + _flipperRadius)
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

    _drawMachineDeck(c);
    _drawAlignedSlingshots(c);
    _drawTableDecor(c);

    for (final rail in _rails) {
      _drawMachineRail(c,rail);
    }
    if (table.id == PinballTableId.moonfallSanctuary) {
      final rampImage = (debugBallInMoonbridge
              ? _moonbridgeActiveSprite : null) ?? _moonbridgeIdleSprite;
      if (rampImage != null) {
        c.drawImageRect(
          rampImage,
          Rect.fromLTWH(0, 0, rampImage.width.toDouble(),
              rampImage.height.toDouble()),
          const Rect.fromLTWH(0, 0, _boardWidth, _boardHeight),
          Paint()..filterQuality = FilterQuality.high,
        );
      }
    }
    _drawCitadelVaultHardware(c);
    _drawBrassSwitchyardHardware(c);
    for (var i = 0; i < _bumpers.length; i++) {
      final bumper = _bumpers[i];
      final sinceHit = _time - (_bumperLastGlow[i] ?? -100);
      // A real solver contact triggers the bright impact state; the
      // three existing bumper colliders remain the source of truth.
      final sprite = (_arcadeLayout && sinceHit < 0.15
              ? _astralBumperHitSprite : null) ??
          _astralBumperSprite ?? _bumperSprite;
      _drawBumperHousing(c,bumper);
      if (sprite != null) {
        // The 014 master has transparent padding, so its metal rim fills the
        // same radius as the real circle collider. Do not move the collider.
        _drawCenteredSprite(
          c,
          sprite,
          bumper.center,
          bumper.radius * (_astralBumperSprite != null ? 1.10 : 0.86),
        );
      } else {
        _glowCircle(c, bumper.center, bumper.radius, table.secondary);
        _glowCircle(c, bumper.center, bumper.radius * 0.48, table.accent);
      }
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
    _drawPlunger(c);

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
        _drawCenteredSprite(c, sprite, ball.position, _ballRadius);
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
        if (!_arcadeLayout) _drawRing(c, const Offset(200, 531), 52, table.accent, 1);
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
          // Fallback only: the premium gate sprites share this collider.
          if (_citadelGateClosedSprite == null &&
              CitadelBallLock.isGateClosed(_time)) {
            _glowLine(c, CitadelBallLock.gateA,
                CitadelBallLock.gateB, table.accent, 7);
          }
        } else if (table.variant == 2) {
          final shift = 38 * math.sin(_time * 1.22);
          final center = Offset(255 - shift * 0.6, 471);
          if (_hazardSprite case final gear?) {
            _drawRotatingSprite(c, gear, center, 23, -_time * 1.4);
          } else {
            _drawRing(c, center, 21, table.accent, 3);
          }
        }
    }
  }

  void _drawBrassSwitchyardHardware(Canvas c) {
    if (table.id != PinballTableId.brassLabyrinth) return;
    void drawSprite(ui.Image? sprite, Rect rect) {
      if (sprite == null) return;
      c.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(),
            sprite.height.toDouble()),
        rect,
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    const boardRect = Rect.fromLTWH(0, 0, _boardWidth, _boardHeight);
    drawSprite(_brassTrackSprite, boardRect);
    final leftRaised = _balls.any((b) => b.switchyardLane == 0);
    final rightRaised = _balls.any((b) => b.switchyardLane == 1);
    if (BrassSwitchyard.leftOpen(_time) || leftRaised) {
      drawSprite(_brassLeftActiveSprite, boardRect);
    }
    if (!BrassSwitchyard.leftOpen(_time) || rightRaised) {
      drawSprite(_brassRightActiveSprite, boardRect);
    }
    for (final side in <int>[0, 1]) {
      final open = side == BrassSwitchyard.openSide(_time);
      final sprite = open ? _brassGateOpenSprite : _brassGateClosedSprite;
      drawSprite(sprite, side == 0
          ? BrassSwitchyard.leftGateArtwork : BrassSwitchyard.rightGateArtwork);
      if (sprite == null && !open) {
        _glowLine(c, BrassSwitchyard.gateA(side),
            BrassSwitchyard.gateB(side), table.accent, 6);
      }
    }
  }

  void _drawCitadelVaultHardware(Canvas c) {
    if (table.id != PinballTableId.chronoCitadel) return;
    void drawAsset(ui.Image? sprite, Rect rect) {
      if (sprite == null) return;
      c.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(),
            sprite.height.toDouble()),
        rect,
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    final vault = _citadelLockSprites[_citadelLockedBalls];
    if (vault != null) {
      drawAsset(vault, CitadelBallLock.lockVisualRect);
    } else {
      _drawRing(c, CitadelBallLock.mouth, 21, table.accent, 4);
    }
    drawAsset(
      CitadelBallLock.isGateClosed(_time)
          ? _citadelGateClosedSprite : _citadelGateOpenSprite,
      CitadelBallLock.gateVisualRect,
    );
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

  Offset _flipperTip(Offset pivot, bool left, double lift) {
    final angle=left ? 0.20-lift*0.94 : math.pi-0.20+lift*0.94;
    return pivot+Offset(math.cos(angle),math.sin(angle))*_flipperLength;
  }
  Color get _hardwareMetal => switch(table.universe) {
    PinballUniverseId.celestial => const Color(0xFFC8A56B),
    PinballUniverseId.neon => const Color(0xFFAAC2CC),
    PinballUniverseId.clockwork => const Color(0xFFC78E49),
  };
  void _drawMachineRail(Canvas c,_Segment rail) {
    final a=rail.a,b=rail.b,w=rail.width*2;
    c.drawLine(a+const Offset(2,3),b+const Offset(2,3),Paint()..strokeCap=StrokeCap.round..strokeWidth=w+4..color=const Color(0xA9000000));
    c.drawLine(a,b,Paint()..strokeCap=StrokeCap.round..strokeWidth=w..color=rail.kicker?const Color(0xFF34333D):_hardwareMetal);
    c.drawLine(a-const Offset(0.7,0.7),b-const Offset(0.7,0.7),Paint()..strokeCap=StrokeCap.round..strokeWidth=math.max(1.0,w*0.24)..color=rail.kicker?table.secondary:const Color(0xFFF8E8CE));
  }
  void _drawBumperHousing(Canvas c,_Bumper bumper) {
    final p=bumper.center,r=bumper.radius;
    c.drawCircle(p+const Offset(2,4),r+2,Paint()..color=const Color(0xA9000000));
    c.drawCircle(p,r,Paint()..color=const Color(0xFF20252D));
    c.drawCircle(p,r-2,Paint()..shader=RadialGradient(center:const Alignment(-0.4,-0.5),colors:[const Color(0xFFF9EBD2),_hardwareMetal,const Color(0xFF584736)],stops:const [0.1,0.65,1]).createShader(Rect.fromCircle(center:p,radius:r)));
  }
  void _drawMachineDeck(Canvas c) {
    final trough=RRect.fromRectAndRadius(const Rect.fromLTRB(337.5,205,367.5,695),const Radius.circular(4));
    c.drawRRect(trough,Paint()..shader=const LinearGradient(colors:[Color(0xFF11151E),Color(0xFF4A4C50),Color(0xFF141922)],stops:[0,0.48,1]).createShader(trough.outerRect));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(100,700,300,740),const Radius.circular(5)),Paint()..color=const Color(0xDD111419));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(179,687,221,747),const Radius.circular(6)),Paint()..color=const Color(0xFF030407));
    if (!_arcadeLayout) return;
    for(final points in <List<Offset>>[
      const [Offset(108,518),Offset(158,574),Offset(128,604)],
      const [Offset(258,518),Offset(223,574),Offset(252,604)],
    ]) {
      final path=Path()..addPolygon(points,true);
      c.drawPath(path.shift(const Offset(2,4)),Paint()..color=const Color(0xBB000000));
      c.drawPath(path,Paint()..shader=LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[table.base,_hardwareMetal,const Color(0xFF23232C)]).createShader(path.getBounds()));
      for(final p in points) {
        c.drawCircle(p,3,Paint()..color=const Color(0xFF201D25));
        c.drawCircle(p,1.6,Paint()..color=const Color(0xFFF6E8D1));
      }
    }
    for(final x in [142.0,200.0,258.0]) {
      final lamp=RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(x,95),width:20,height:9),const Radius.circular(4));
      c.drawRRect(lamp,Paint()..color=const Color(0xFF171C29));
      c.drawRRect(lamp.deflate(2),Paint()..color=table.secondary.withValues(alpha:0.75));
    }
  }
  void _drawAlignedSlingshots(Canvas c) {
    if (!_arcadeLayout) return;
    // Pre-aligned transparent PNGs occupy the original physical rail
    // triangle envelopes, with unchanged flippers, colliders and bounce.
    void drawSling(ui.Image? image, Rect destination) {
      if (image == null) return; // Existing metal triangles stay as fallback.
      c.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        destination,
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    drawSling(
      _time < _slingLeftFlashUntil ? _slingLeftHit ?? _slingLeftIdle
          : _slingLeftIdle,
      const Rect.fromLTWH(98, 508, 96, 112),
    );
    drawSling(
      _time < _slingRightFlashUntil ? _slingRightHit ?? _slingRightIdle
          : _slingRightIdle,
      const Rect.fromLTWH(210, 508, 96, 112),
    );
  }

  void _drawPlunger(Canvas c) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(342,660,362,713),const Radius.circular(4)),Paint()..color=const Color(0xFF1E2229));
    c.drawRect(const Rect.fromLTRB(349,664,355,712),Paint()..color=_hardwareMetal);
    for(var i=0;i<7;i++) {
      final y=668.0+i*5;
      c.drawLine(Offset(344,y),Offset(360,y+3),Paint()..strokeWidth=2..color=const Color(0xFFD7D8D8));
    }
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(342,707,362,719),const Radius.circular(4)),Paint()..color=_hardwareMetal);
  }
  void _drawFlipper(Canvas c,Offset pivot,bool left,double lift) {
    final tip=_flipperTip(pivot,left,lift);
    c.drawLine(pivot+const Offset(2,4),tip+const Offset(2,4),Paint()..strokeCap=StrokeCap.round..strokeWidth=18..color=const Color(0xB9000000));
    c.drawLine(pivot,tip,Paint()..strokeCap=StrokeCap.round..strokeWidth=_flipperRadius*2..color=const Color(0xFF24232B));
    c.drawLine(pivot,tip,Paint()..strokeCap=StrokeCap.round..strokeWidth=10..color=_hardwareMetal);
    c.drawLine(pivot-const Offset(0,1),tip-const Offset(0,1),Paint()..strokeCap=StrokeCap.round..strokeWidth=3..color=const Color(0xFFF9EBD2));
    c.drawCircle(pivot,4.5,Paint()..color=const Color(0xFF363B44));
    c.drawCircle(pivot,2.5,Paint()..color=const Color(0xFFEDE9E3));
  }
}

