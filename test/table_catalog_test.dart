import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/table_data.dart';

void main() {
  test('three universes contain nine independently identified boards', () {
    expect(pinballUniverses.length, 3);
    expect(pinballTables.length, 9);
    expect(pinballTables.map((table) => table.id).toSet().length, 9);
    expect(pinballTables.map((table) => table.storageKey).toSet().length, 9);
    for (final universe in pinballUniverses) {
      final boards = tablesInUniverse(universe.id);
      expect(boards.length, 3);
      expect(boards.map((table) => table.variant).toSet(), <int>{0, 1, 2});
    }
  });

  test('every table has its own full mission sequence', () {
    for (final table in pinballTables) {
      expect(table.title.isNotEmpty, true);
      expect(table.modeNames.length, 4);
      expect(table.modeNames.toSet().length, 4);
    }
  });
}
