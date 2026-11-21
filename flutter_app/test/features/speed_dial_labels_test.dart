import 'package:churtern_play/features/shell/widgets/quick_actions_speed_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('speed dial shows a visible label beside every action',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: QuickActionsSpeedDial()),
    ));

    await t.tap(find.byIcon(Icons.bolt));
    await t.pumpAndSettle();

    for (final label in [
      'Game Picker',
      'First Player',
      'Turn Timer',
      'Add Game',
      'Add to Wishlist',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
