import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/swept_rail.dart';

void main() {
  test('high-speed left-wall collision stays on original playfield side', () {
    final hit = sweepRail(
      fromX: 40,
      fromY: 350,
      toX: 26,
      toY: 350,
      ax: 31,
      ay: 116,
      bx: 31,
      by: 690,
      radius: 7.5,
    );
    expect(hit, isNotNull);
    expect(hit!.x, closeTo(38.5, 1e-8));
    expect(hit.normalX, closeTo(1, 1e-8));
    expect(hit.normalY, closeTo(0, 1e-8));
  });

  test('right-wall inward crossing remains inside', () {
    final hit = sweepRail(
      fromX: 360,
      fromY: 500,
      toX: 381,
      toY: 500,
      ax: 369,
      ay: 109,
      bx: 369,
      by: 695,
      radius: 7.5,
    );
    expect(hit, isNotNull);
    expect(hit!.x, closeTo(361.5, 1e-8));
    expect(hit.normalX, -1);
  });

  test('rounded endpoint prevents fast corner tunneling', () {
    final hit = sweepRail(
      fromX: -12,
      fromY: -12,
      toX: 12,
      toY: 12,
      ax: 0,
      ay: 0,
      bx: 0,
      by: 20,
      radius: 5,
    );
    expect(hit, isNotNull);
    expect(hit!.fraction, inInclusiveRange(0, 1));
    expect(hit.x, lessThan(0));
    expect(hit.y, lessThan(0));
  });

  test('safe pass alongside segment has no false collision', () {
    expect(
      sweepRail(
        fromX: 40,
        fromY: 350,
        toX: 40,
        toY: 100,
        ax: 31,
        ay: 116,
        bx: 31,
        by: 690,
        radius: 7.5,
      ),
      isNull,
    );
  });

  test('zero movement and separated travel produce no hit', () {
    expect(
      sweepRail(
        fromX: 40,
        fromY: 200,
        toX: 40,
        toY: 200,
        ax: 31,
        ay: 116,
        bx: 31,
        by: 690,
        radius: 7.5,
      ),
      isNull,
    );
    expect(
      sweepRail(
        fromX: 60,
        fromY: 200,
        toX: 50,
        toY: 200,
        ax: 31,
        ay: 116,
        bx: 31,
        by: 690,
        radius: 7.5,
      ),
      isNull,
    );
  });
}
