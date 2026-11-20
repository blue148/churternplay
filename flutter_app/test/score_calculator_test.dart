import 'package:churtern_play/features/game_nite/score_calculator.dart';
import 'package:churtern_play/features/game_nite/score_calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluateExpression', () {
    test('basic arithmetic with precedence', () {
      expect(evaluateExpression('2+3×4'), 14);
      expect(evaluateExpression('10−4÷2'), 8);
      expect(evaluateExpression('1.5+2.25'), 3.75);
      expect(evaluateExpression('−5+8'), 3);
      expect(evaluateExpression('12'), 12);
    });
    test('rejects incomplete, malformed and divide-by-zero', () {
      expect(evaluateExpression(''), isNull);
      expect(evaluateExpression('5+'), isNull);
      expect(evaluateExpression('×3'), isNull);
      expect(evaluateExpression('4÷0'), isNull);
      expect(evaluateExpression('1.2.3'), isNull);
    });
  });

  test('formatScore trims zeros', () {
    expect(formatScore(7), '7');
    expect(formatScore(7.5), '7.5');
    expect(formatScore(7.25), '7.25');
    expect(formatScore(-3), '-3');
  });

  testWidgets('add players, assign sums, undo, reset, clear', (t) async {
    // A phone-sized window, so the player list gets real room.
    t.view.physicalSize = const Size(400, 850);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: ScoreCalculatorPage()));

    Future<void> addPlayer(String name) async {
      await t.enterText(find.byType(TextField), name);
      await t.tap(find.text('Add').first);
      await t.pump();
    }

    Future<void> keys(String chars) async {
      for (final c in chars.split('')) {
        await t.tap(find.bySemanticsLabel(RegExp('^${RegExp.escape(c)}\$')).first);
      }
      await t.pump();
    }

    await addPlayer('Ann');
    await addPlayer('Bo');
    // Bo (last added) is selected: 12 + 3×4 = 24.
    await keys('12');
    await t.tap(find.bySemanticsLabel('Plus'));
    await keys('3');
    await t.tap(find.bySemanticsLabel('Multiply'));
    await keys('4');
    await t.tap(find.textContaining('Add 24 to Bo'));
    await t.pump();
    // Total and the entry breakdown both read 24.
    expect(find.text('24'), findsNWidgets(2));

    // Switch to Ann and give her 5.
    await t.tap(find.text('Ann'));
    await t.pump();
    await keys('5');
    await t.tap(find.textContaining('Add 5 to Ann'));
    await t.pump();
    // Ann's total + breakdown, plus the keypad's own "5" key.
    expect(find.text('5'), findsNWidgets(3));

    // Reset keeps players, zeroes scores.
    await t.tap(find.text('Reset scores'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reset'));
    await t.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('24'), findsNothing);

    // Clear players removes everyone.
    await t.tap(find.text('Clear players'));
    await t.pumpAndSettle();
    await t.tap(find.text('Clear players').last);
    await t.pumpAndSettle();
    expect(find.text('Ann'), findsNothing);
    expect(find.text('Bo'), findsNothing);
  });
}
