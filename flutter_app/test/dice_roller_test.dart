import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shake_gesture_platform_interface/shake_gesture_platform_interface.dart';

import 'package:churtern_play/features/game_nite/dice_roller_page.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiceRollerPage()));
  }

  Finder diceInArea() => find.descendant(
      of: find.byKey(const ValueKey('dice-area')),
      matching: find.byType(DieFace));

  testWidgets('Roll button is disabled when the pool is empty',
      (tester) async {
    await pumpPage(tester);
    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Roll'));
    expect(button.onPressed, isNull);
  });

  testWidgets('adding dice shows them on screen before rolling',
      (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('add-d6')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-d20')));
    await tester.pump();
    expect(diceInArea(), findsNWidgets(2));
  });

  testWidgets('rolling 2d6 settles on two dice with a total in 2..12',
      (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('add-d6')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-d6')));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
    await tester.pumpAndSettle();

    expect(diceInArea(), findsNWidgets(2));
    final totalText =
        tester.widget<Text>(find.byKey(const ValueKey('total-text')));
    final total = int.parse(totalText.data!);
    expect(total, inInclusiveRange(2, 12));
  });

  testWidgets('a shake gesture rolls the dice', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('add-d6')));
    await tester.pump();

    ShakeGesturePlatform.instance.onShake();
    await tester.pumpAndSettle();

    final totalText =
        tester.widget<Text>(find.byKey(const ValueKey('total-text')));
    expect(int.parse(totalText.data!), inInclusiveRange(1, 6));
  });

  testWidgets('Clear empties the pool and disables Roll', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('add-d10')));
    await tester.pump();
    expect(diceInArea(), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.byKey(const ValueKey('dice-area')), findsNothing);
    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Roll'));
    expect(button.onPressed, isNull);
  });

  testWidgets('DieFace renders every die type without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            DieFace(sides: 4, value: 3),
            DieFace(sides: 6, value: 6),
            DieFace(sides: 8, value: 7),
            DieFace(sides: 10, value: 10),
            DieFace(sides: 20, value: 17),
          ],
        ),
      ),
    ));
    expect(find.byType(DieFace), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });
}
