import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premium_pinball/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the pinball collection opens at universe selection', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const PremiumPinballApp());
    expect(find.text('PINBALL'), findsOneWidget);
    expect(find.text('THE ASTRAL ORRERY'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
  });

  testWidgets('sound mute setting is saved for future launches', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const PremiumPinballApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mute sound effects'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Enable sound effects'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('pinball_sfx_enabled'), isFalse);
  });
}
