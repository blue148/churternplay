import 'package:churtern_play/data/models/game.dart';
import 'package:churtern_play/data/services/recent_players_service.dart';
import 'package:churtern_play/features/game_nite/score_calculator_page.dart';
import 'package:churtern_play/features/library/widgets/log_play_sheet.dart';
import 'package:churtern_play/providers/recent_players_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryLastSet implements LastPlayerSetStore {
  _MemoryLastSet(this.names);
  List<String> names;
  @override
  Future<List<String>> load() async => names;
  @override
  Future<void> save(List<String> n) async {
    if (n.isNotEmpty) names = n;
  }
}

class _NoRecents implements RecentPlayersStore {
  @override
  Future<List<String>> load() async => const [];
  @override
  Future<List<String>> add(String name) async => const [];
  @override
  Future<List<String>> remove(String name) async => const [];
}

Widget _app(Widget home, _MemoryLastSet last) => ProviderScope(
      overrides: [
        lastPlayerSetStoreProvider.overrideWithValue(last),
        recentPlayersStoreProvider.overrideWithValue(_NoRecents()),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  testWidgets('Score Calculator starts with the last First Player set',
      (t) async {
    t.view.physicalSize = const Size(400, 850);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        _app(const ScoreCalculatorPage(), _MemoryLastSet(['Ann', 'Bo', 'Cy'])));
    await t.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('Cy'), findsOneWidget);
    // First player in the set is pre-selected.
    expect(find.textContaining('for Ann'), findsOneWidget);
  });

  testWidgets('Score Calculator starts empty when no set was saved',
      (t) async {
    await t.pumpWidget(_app(const ScoreCalculatorPage(), _MemoryLastSet([])));
    await t.pumpAndSettle();
    expect(find.text('Select a player'), findsOneWidget);
  });

  testWidgets('Log a Play pre-fills players from the last set', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = Game(
      id: 'g',
      name: 'Azul',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await t.pumpWidget(_app(
      Scaffold(
        body: LogPlaySheet(game: game, onRecorded: (_) async {}),
      ),
      _MemoryLastSet(['Ann', 'Bo']),
    ));
    await t.pumpAndSettle();
    final fields = t
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((f) => f.initialValue)
        .toList();
    // Three fields per player row (name, score, placement): exactly two rows.
    expect(fields.length, 6);
    expect((fields[0], fields[3]), ('Ann', 'Bo'));
    expect(fields, isNot(contains('Me')));
  });

  testWidgets('Log a Play starts with one blank player row when there is no saved set', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = Game(
      id: 'g',
      name: 'Azul',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await t.pumpWidget(_app(
      Scaffold(body: LogPlaySheet(game: game, onRecorded: (_) async {})),
      _MemoryLastSet([]),
    ));
    await t.pumpAndSettle();
    final fields = t
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((f) => f.initialValue)
        .toList();
    // One blank row (name, score, placement) and no "Me".
    expect(fields.length, 3);
    expect(fields.first, '');
    expect(fields, isNot(contains('Me')));
  });
}
