import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/pinball_audio.dart';
import 'game/pinball_game.dart';
import 'game/table_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const PremiumPinballApp());
}

class PremiumPinballApp extends StatelessWidget {
  const PremiumPinballApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Premium Pinball Collection',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF030710),
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7AE5FF),
        brightness: Brightness.dark,
      ),
    ),
    home: const TableSelectionScreen(),
  );
}

class TableSelectionScreen extends StatefulWidget {
  const TableSelectionScreen({super.key});

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  PinballUniverseId _universe = PinballUniverseId.celestial;
  PinballTableId _selected = PinballTableId.astralOrrery;
  bool _reducedMotion = false;
  bool _soundEnabled = true;
  final Map<PinballTableId, int> _bests = <PinballTableId, int>{};

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reducedMotion = preferences.getBool('pinball_reduced_motion') ?? false;
      _soundEnabled = preferences.getBool('pinball_sfx_enabled') ?? true;
      for (final table in pinballTables) {
        _bests[table.id] = preferences.getInt(table.storageKey) ?? 0;
      }
    });
  }

  Future<void> _launch() async {
    final table = tableById(_selected);
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder:
            (_) => PinballPlayScreen(
              table: table,
              reducedMotion: _reducedMotion,
              soundEnabled: _soundEnabled,
            ),
      ),
    );
    if (!mounted) return;
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _soundEnabled =
          preferences.getBool('pinball_sfx_enabled') ?? _soundEnabled;
    });
    if (result == null) return;
    final prior = _bests[table.id] ?? 0;
    if (result <= prior) return;
    setState(() => _bests[table.id] = result);
    await preferences.setInt(table.storageKey, result);
  }

  @override
  Widget build(BuildContext context) {
    final active = tableById(_selected);
    final availableTables = tablesInUniverse(_universe);
    final universeInfo = pinballUniverses.firstWhere(
      (universe) => universe.id == _universe,
    );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF09152A),
              Color(0xFF050711),
              Color(0xFF180D1E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'EXPLORE THE UNIVERSES',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 5,
                        color: Colors.white.withValues(alpha: 0.54),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'PINBALL',
                            style: TextStyle(
                              fontSize: 42,
                              height: 1.08,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            setState(() => _soundEnabled = !_soundEnabled);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'pinball_sfx_enabled',
                              _soundEnabled,
                            );
                          },
                          icon: Icon(
                            _soundEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                          ),
                          tooltip:
                              _soundEnabled
                                  ? 'Mute sound effects'
                                  : 'Enable sound effects',
                        ),
                        IconButton(
                          onPressed: () async {
                            setState(() => _reducedMotion = !_reducedMotion);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'pinball_reduced_motion',
                              _reducedMotion,
                            );
                          },
                          icon: Icon(
                            _reducedMotion
                                ? Icons.motion_photos_off
                                : Icons.motion_photos_on,
                          ),
                          tooltip:
                              _reducedMotion
                                  ? 'Enable cinematic camera'
                                  : 'Reduce camera motion',
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Choose a universe, then a machine',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.67),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  children: pinballUniverses
                      .map((universe) {
                        final activeUniverse = universe.id == _universe;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 7),
                          child: ChoiceChip(
                            label: Text(
                              universe.id.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: activeUniverse,
                            selectedColor: universe.accent.withValues(
                              alpha: 0.35,
                            ),
                            onSelected:
                                (_) => setState(() {
                                  _universe = universe.id;
                                  _selected =
                                      tablesInUniverse(universe.id).first.id;
                                }),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 0, 19, 11),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            universeInfo.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: universeInfo.accent,
                            ),
                          ),
                          Text(
                            universeInfo.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.56),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${availableTables.length} TABLES',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  itemCount: availableTables.length,
                  itemBuilder: (context, index) {
                    final table = availableTables[index];
                    final selected = table.id == _selected;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: _TableCard(
                        table: table,
                        selected: selected,
                        best: _bests[table.id] ?? 0,
                        onTap: () => setState(() => _selected = table.id),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF050914).withValues(alpha: 0.93),
                  border: Border(
                    top: BorderSide(
                      color: active.accent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _launch,
                    style: FilledButton.styleFrom(
                      backgroundColor: active.accent,
                      foregroundColor: const Color(0xFF07111E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'LAUNCH SELECTED TABLE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.selected,
    required this.best,
    required this.onTap,
  });

  final PinballTableInfo table;
  final bool selected;
  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      height: 158,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              selected
                  ? table.accent.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.16),
          width: selected ? 2 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[table.base, const Color(0xFF090B12)],
        ),
        boxShadow:
            selected
                ? <BoxShadow>[
                  BoxShadow(
                    color: table.accent.withValues(alpha: 0.17),
                    blurRadius: 22,
                  ),
                ]
                : null,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 118,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.asset(
                    table.coverAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: 384,
                    errorBuilder:
                        (_, __, ___) => CustomPaint(
                          painter: _CardPreviewPainter(table),
                          child: const SizedBox.expand(),
                        ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020612).withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'BOARD 0${table.variant + 1}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    table.title,
                    maxLines: 2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    table.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: table.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'BEST  ${_formatScore(best)}',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    selected ? '● SELECTED' : 'TAP TO SELECT',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color:
                          selected
                              ? table.accent
                              : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CardPreviewPainter extends CustomPainter {
  const _CardPreviewPainter(this.table);

  final PinballTableInfo table;

  @override
  void paint(Canvas canvas, Size size) {
    final field = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      field,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[table.base, table.secondary.withValues(alpha: 0.26)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(field),
    );
    final border = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(15),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = table.accent.withValues(alpha: 0.66),
    );

    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.25 + i * 0.25);
      final y = size.height * (i.isEven ? 0.36 : 0.48);
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.11,
        Paint()..color = table.secondary.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.07,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = table.accent,
      );
    }
    final center = Offset(size.width / 2, size.height * 0.20);
    canvas.drawCircle(
      center,
      21,
      Paint()..color = table.secondary.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = table.accent,
    );
    for (final origin in <Offset>[
      Offset(size.width * 0.18, size.height * 0.80),
      Offset(size.width * 0.82, size.height * 0.80),
    ]) {
      final left = origin.dx < size.width / 2;
      canvas.drawLine(
        origin,
        origin.translate(left ? 23 : -23, -7),
        Paint()
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = table.accent,
      );
    }
    if (table.universe == PinballUniverseId.clockwork) {
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final p = center + Offset(math.cos(a) * 24, math.sin(a) * 24);
        canvas.drawCircle(p, 2.3, Paint()..color = table.secondary);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardPreviewPainter oldDelegate) =>
      oldDelegate.table.id != table.id;
}

class PinballPlayScreen extends StatefulWidget {
  const PinballPlayScreen({
    super.key,
    required this.table,
    required this.reducedMotion,
    required this.soundEnabled,
  });

  final PinballTableInfo table;
  final bool reducedMotion;
  final bool soundEnabled;

  @override
  State<PinballPlayScreen> createState() => _PinballPlayScreenState();
}

class _PinballPlayScreenState extends State<PinballPlayScreen> {
  late final PinballGame _game;
  late final PinballAudio _audio;
  final Map<int, bool> _pointers = <int, bool>{};
  int _peakScore = 0;
  bool _resultDialogShown = false;
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.soundEnabled;
    _audio = PinballAudio(enabled: _soundEnabled);
    _game = PinballGame(
      table: widget.table,
      onGameFinished: _onGameFinished,
      audio: _audio,
    )..reducedMotion = widget.reducedMotion;
    unawaited(_audio.preload());
  }

  void _toggleAudio() {
    setState(() => _soundEnabled = !_soundEnabled);
    _audio.enabled = _soundEnabled;
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool('pinball_sfx_enabled', _soundEnabled),
      ),
    );
    if (_soundEnabled) _audio.play(PinballSound.award);
  }

  void _toggleCollisionDebug() {
    setState(() => _game.showCollisionDebug = !_game.showCollisionDebug);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_game.showCollisionDebug
            ? 'Collider calibration ON — orange walls, green targets'
            : 'Collider calibration OFF'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onGameFinished(int score) {
    _peakScore = math.max(_peakScore, score);
    if (_resultDialogShown) return;
    _resultDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF111928),
              title: const Text('GAME OVER'),
              content: Text('Final score: ${_formatScore(score)}'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop(_peakScore);
                  },
                  child: const Text('CHOOSE TABLE'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _resultDialogShown = false;
                    _game.restart();
                  },
                  child: const Text('PLAY AGAIN'),
                ),
              ],
            ),
      );
    });
  }

  void _handleDown(PointerDownEvent event, double width, double height) {
    if (event.localPosition.dy < height * 0.43) return;
    final left = event.localPosition.dx < width / 2;
    _pointers[event.pointer] = left;
    _syncFlippers();
  }

  void _handleUp(int pointer) {
    _pointers.remove(pointer);
    _syncFlippers();
  }

  void _syncFlippers() {
    final wasLeft = _game.leftPressed;
    final wasRight = _game.rightPressed;
    _game.leftPressed = _pointers.values.any((left) => left);
    _game.rightPressed = _pointers.values.any((left) => !left);
    if ((!wasLeft && _game.leftPressed) || (!wasRight && _game.rightPressed)) {
      _audio.play(PinballSound.flipper);
    }
  }

  void _exitToTables() {
    _peakScore = math.max(_peakScore, _game.hud.value.score);
    Navigator.of(context).pop(_peakScore);
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _game.releaseSprites();
    _game.hud.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown:
                  (event) => _handleDown(event, screen.width, screen.height),
              onPointerUp: (event) => _handleUp(event.pointer),
              onPointerCancel: (event) => _handleUp(event.pointer),
              child: GameWidget(game: _game),
            ),
          ),
          SafeArea(
            child: ValueListenableBuilder<PinballHud>(
              valueListenable: _game.hud,
              builder:
                  (context, state, _) => Column(
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.fromLTRB(9, 5, 9, 0),
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF020612,
                          ).withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.table.accent.withValues(alpha: 0.40),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: _exitToTables,
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                              ),
                              tooltip: 'Choose another table',
                              visualDensity: VisualDensity.compact,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onLongPress: _toggleCollisionDebug,
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _formatScore(state.score),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    Text(
                                      state.mode.toUpperCase(),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: widget.table.accent,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              'BALL ${state.balls}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 3),
                            IconButton(
                              onPressed: _toggleAudio,
                              icon: Icon(
                                _soundEnabled
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                              ),
                              tooltip:
                                  _soundEnabled
                                      ? 'Mute pinball sounds'
                                      : 'Enable pinball sounds',
                            ),
                            IconButton(
                              onPressed: _game.togglePause,
                              icon: Icon(
                                state.isPaused ? Icons.play_arrow : Icons.pause,
                              ),
                              tooltip: state.isPaused ? 'Resume' : 'Pause',
                            ),
                          ],
                        ),
                      ),
                      if (state.isMultiball)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'MULTIBALL!',
                            style: TextStyle(
                              color: widget.table.secondary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      if (state.awardLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF030711,
                              ).withValues(alpha: 0.88),
                              border: Border.all(
                                color: widget.table.accent.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              child: Text(
                                state.awardLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: widget.table.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (state.isReady)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 90),
                          child: FilledButton.icon(
                            onPressed: _game.launch,
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.table.accent,
                              foregroundColor: const Color(0xFF050712),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('LAUNCH BALL'),
                          ),
                        )
                      else
                        const SizedBox(height: 100),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _FlipperHint(
                              color: widget.table.accent,
                              label: 'LEFT',
                            ),
                            _FlipperHint(
                              color: widget.table.accent,
                              label: 'RIGHT',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlipperHint extends StatelessWidget {
  const _FlipperHint({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFF010409).withValues(alpha: 0.55),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Text(
        'TAP $label',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    ),
  );
}

String _formatScore(int score) {
  final raw = score.toString();
  return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
