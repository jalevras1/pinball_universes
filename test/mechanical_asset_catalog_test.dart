import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('tool/mechanical_candidates/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('mechanical candidate manifests have valid unique metadata', () {
    const counts = <String, List<int>>{
      '014': [9, 13],
      '015': [12, 40],
      '016': [11, 40],
    };
    final ids = <String>{};
    var frameTotal = 0;
    for (final entry in counts.entries) {
      final assets =
          _read('batch_${entry.key}_manifest.json')['assets'] as List<dynamic>;
      expect(assets.length, entry.value[0]);
      var framesInPack = 0;
      for (final item in assets) {
        final a = item as Map<String, dynamic>;
        final id = a['id'] as String;
        expect(ids.add(id), isTrue, reason: 'duplicate asset id: $id');
        final frames = (a['frames'] as List<dynamic>).cast<String>();
        expect(frames, isNotEmpty);
        for (final frame in frames) {
          expect(frame.startsWith('sprites/'), isTrue, reason: frame);
          expect(frame.endsWith('.png'), isTrue, reason: frame);
          expect(frame.contains('..'), isFalse, reason: frame);
        }
        expect(a.containsKey('collision') || a.containsKey('geometry'),
            isTrue, reason: id);
        framesInPack += frames.length;
      }
      expect(framesInPack, entry.value[1]);
      frameTotal += framesInPack;
    }
    expect(ids.length, 32);
    expect(frameTotal, 93);
  });

  test('twelve mechanically distinct recipes use declared assets', () {
    final knownIds = <String>{};
    for (final pack in ['014', '015', '016']) {
      final manifest = _read('batch_${pack}_manifest.json');
      for (final raw in manifest['assets'] as List<dynamic>) {
        knownIds.add((raw as Map<String, dynamic>)['id'] as String);
      }
    }
    final layouts = <String>{};
    for (final pack in ['015', '016']) {
      final recipes = _read('batch_${pack}_board_recipes.json');
      expect(recipes.length, 6);
      final themes = <String>{};
      for (final row in recipes.entries) {
        final recipe = row.value as Map<String, dynamic>;
        themes.add((recipe['theme'] ?? recipe['universe']) as String);
        final elements =
            (recipe['components'] ?? recipe['obstacles']) as List<dynamic>;
        expect(elements, isNotEmpty);
        final signature = <String>[];
        for (final raw in elements) {
          final item = raw as Map<String, dynamic>;
          final asset = item['asset_id'] as String;
          expect(knownIds.contains(asset), isTrue, reason: row.key);
          expect((item['scale'] as num).toDouble(), greaterThan(0));
          signature.add(asset);
        }
        signature.sort();
        expect(layouts.add('$pack:${signature.join(',')}'), isTrue,
            reason: 'duplicate layout pattern: ${row.key}');
      }
      expect(
        themes,
        containsAll(['cosmic', 'fantasy', 'cyber', 'ancient', 'ocean', 'volcanic']),
      );
    }
    expect(layouts.length, 12);
  });
}
