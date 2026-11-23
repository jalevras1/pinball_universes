import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/game/plunger_model.dart';

void main() {
  test('downward pull clamps and upward drag does not charge', () {
    final plunger = PlungerModel(fullPullPixels: 100);
    plunger.pull(-50);
    expect(plunger.charge, 0);
    plunger.pull(50);
    expect(plunger.charge, 0.5);
    plunger.pull(400);
    expect(plunger.charge, 1);
  });

  test('accidental tap cannot launch, deliberate pull resets on release', () {
    final plunger = PlungerModel(fullPullPixels: 100);
    expect(plunger.release(), isNull);
    plunger.pull(7);
    expect(plunger.release(), isNull);
    plunger.pull(45);
    expect(plunger.release(), 0.45);
    expect(plunger.charge, 0);
    expect(plunger.release(), isNull);
  });

  test('cancel clears charge and never fires', () {
    final plunger = PlungerModel();
    plunger.pull(108);
    plunger.cancel();
    expect(plunger.charge, 0);
    expect(plunger.release(), isNull);
  });

  test('nonfinite drag cannot arm the shooter', () {
    final plunger = PlungerModel();
    plunger.pull(double.nan);
    expect(plunger.release(), isNull);
  });
}
