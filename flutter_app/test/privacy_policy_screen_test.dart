import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:churntern_play/features/privacy/privacy_policy_screen.dart';

void main() {
  testWidgets('privacy policy shows core disclosures', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyScreen()),
    );

    expect(find.text('Churtern Play'), findsOneWidget);
    expect(find.text('1. Information we collect'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('5. Advertising and analytics'),
      500,
    );
    expect(find.text('5. Advertising and analytics'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('11. Changes and contact'),
      500,
    );
    expect(find.text('11. Changes and contact'), findsOneWidget);
  });
}
