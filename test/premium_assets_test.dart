import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nine machines have shipped universe artwork', () async {
    expect(pinballTables.length, 9);
    for (final universe in PinballUniverseId.values) {
      expect(tablesInUniverse(universe).length, 3);
      for (final path in <String>[
        'assets/universe_covers/${universe.name}.png',
        'assets/backplates/${universe.name}.png',
        'assets/gameplay/bumper_${universe.name}.png',
      ]) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(2000), reason: path);
      }
    }
    expect(
      (await rootBundle.load('assets/gameplay/steel_ball.png')).lengthInBytes,
      greaterThan(2000),
    );
    for (final path in <String>[
      'portal_celestial.png',
      'reactor_neon.png',
      'gear_clockwork.png',
    ]) {
      expect(
        (await rootBundle.load('assets/gameplay/$path')).lengthInBytes,
        greaterThan(2000),
        reason: path,
      );
    }
  });

  test('Astral Orrery premium bumper is bundled and correctly sized', () async {
    final art = await rootBundle.load(
      'assets/gameplay/mechanical/pop_bumper_blue_idle.png',
    );
    expect(art.lengthInBytes, greaterThan(1500));
    expect(art.getUint32(16), 80); // PNG IHDR pixel width
    expect(art.getUint32(20), 80); // PNG IHDR pixel height
    expect(art.getUint32(0), 0x89504e47); // PNG signature
    final vortex = await rootBundle.load(
      'assets/gameplay/mechanical/capture_hole_violet.png',
    );
    expect(vortex.lengthInBytes, greaterThan(1500));
    expect(vortex.getUint32(16), 80);
    expect(vortex.getUint32(20), 80);
    expect(vortex.getUint32(0), 0x89504e47);
    // The premium impact art is separate and retains the exact bumper size.
    final hit = await rootBundle.load(
      'assets/gameplay/mechanical/pop_bumper_blue_hit.png',
    );
    expect(hit.lengthInBytes, greaterThan(1500));
    expect(hit.getUint32(0), 0x89504e47);
    expect(hit.getUint32(16), 80);
    expect(hit.getUint32(20), 80);
    expect(hit.lengthInBytes, isNot(art.lengthInBytes));
  });

  test('the complete sound set is bundled', () async {
    for (final name in <String>[
      'launch',
      'flipper',
      'rail',
      'bumper_celestial',
      'bumper_neon',
      'bumper_clockwork',
      'portal',
      'gravity',
      'gate',
      'gear',
      'boost',
      'award',
      'jackpot',
      'multiball',
      'drain',
      'extra_ball',
    ]) {
      final data = await rootBundle.load('assets/audio/$name.wav');
      expect(data.lengthInBytes, greaterThan(4000), reason: name);
    }
  });
}
