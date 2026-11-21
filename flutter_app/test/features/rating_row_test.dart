import 'package:churtern_play/features/library/widgets/rating_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget w) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: w))));

  testWidgets('tapping the Nth icon sets N; tapping it again clears', (t) async {
    var value = 0;
    late StateSetter set;
    await pump(
      t,
      StatefulBuilder(builder: (context, setState) {
        set = setState;
        return RatingRow(
          kind: RatingKind.hearts,
          value: value,
          onChanged: (v) => set(() => value = v),
        );
      }),
    );

    // The 3rd of 5 tappable icons.
    final icons = find.byType(InkResponse);
    expect(icons, findsNWidgets(5));
    await t.tap(icons.at(2));
    await t.pump();
    expect(value, 3);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));

    await t.tap(icons.at(2));
    await t.pump();
    expect(value, 0);
  });

  testWidgets('read-only row has no tap targets and exposes a label', (t) async {
    await pump(t, const RatingRow(kind: RatingKind.fists, value: 2));
    expect(find.byType(InkResponse), findsNothing);
    expect(find.bySemanticsLabel('Punch-worthy, 2 of 5 fists'), findsOneWidget);
  });

  testWidgets('summary hides when unrated and shows set values', (t) async {
    await pump(t, const RatingSummary(hearts: 0, fists: 0));
    expect(find.byType(Icon), findsNothing);
    await pump(t, const RatingSummary(hearts: 4, fists: 1));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
