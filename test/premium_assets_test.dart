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
