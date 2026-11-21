import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shake_gesture_platform_interface/shake_gesture_platform_interface.dart';

import 'package:churtern_play/data/services/friend_suggestions_service.dart';
import 'package:churtern_play/data/services/recent_players_service.dart';
import 'package:churtern_play/features/game_nite/game_nite_screen.dart';
import 'package:churtern_play/providers/friend_suggestions_provider.dart';
import 'package:churtern_play/providers/recent_players_provider.dart';

/// In-memory stand-in for the Supabase-backed recents store, mirroring its
/// most-recent-first, case-insensitive-dedupe behaviour.
class InMemoryRecentPlayersStore implements RecentPlayersStore {
  final _names = <String>[];

  @override
  Future<List<String>> load() async => List.unmodifiable(_names);

  @override
  Future<List<String>> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return load();
    _names.removeWhere((n) => n.toLowerCase() == trimmed.toLowerCase());
    _names.insert(0, trimmed);
    return load();
  }

  @override
  Future<List<String>> remove(String name) async {
    _names.removeWhere((n) => n.toLowerCase() == name.trim().toLowerCase());
    return load();
  }
}

/// A fixed stand-in for the friend-suggestions stub, so tests don't need a
/// real Supabase-backed friends connection.
class FakeFriendSuggestionsStore implements FriendSuggestionsStore {
  FakeFriendSuggestionsStore([this._names = const []]);
  final List<String> _names;

  @override
  Future<List<String>> load() async => _names;
}

class _LastSet implements LastPlayerSetStore {
  List<String> names = [];
  @override
  Future<List<String>> load() async => names;
  @override
  Future<void> save(List<String> n) async {
    if (n.isNotEmpty) names = n;
  }
}

void main() {
  // A single store per test so recents survive navigating away and back, the
  // way the real per-user backend would.
  late InMemoryRecentPlayersStore store;
  late FakeFriendSuggestionsStore friendsStore;
  late _LastSet lastSet;
  setUp(() {
    lastSet = _LastSet();
    store = InMemoryRecentPlayersStore();
    friendsStore = FakeFriendSuggestionsStore();
  });

  // The First Player page is reached through go_router, so drive a router that
  // mirrors the real /game-nite/first-player route and override the recents
  // store with the in-memory fake.
  Future<void> openFirstPlayer(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/game-nite',
      routes: [
        GoRoute(
          path: '/game-nite',
          builder: (_, __) => const GameNiteScreen(),
          routes: [
            GoRoute(
              path: 'first-player',
              builder: (_, __) => const FirstPlayerPage(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recentPlayersStoreProvider.overrideWithValue(store),
        friendSuggestionsStoreProvider.overrideWithValue(friendsStore),
        lastPlayerSetStoreProvider.overrideWithValue(lastSet),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.tap(find.text('First Player'));
    await tester.pumpAndSettle();
  }

  // Players are now added by submitting the field (the keyboard's return key).
  Future<void> addPlayer(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('the board is remembered as the last player set', (tester) async {
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Ada');
    await addPlayer(tester, 'Grace');
    expect(lastSet.names, ['Ada', 'Grace']);
  });

  testWidgets('Pick button is disabled until a player is added',
      (tester) async {
    await openFirstPlayer(tester);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Pick First Player'));
    expect(button.onPressed, isNull);

    await addPlayer(tester, 'Ada');
    final enabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Pick First Player'));
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('shuffling surfaces exactly one of the players as winner',
      (tester) async {
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Ada');
    await addPlayer(tester, 'Grace');

    await tester.tap(find.widgetWithText(FilledButton, 'Pick First Player'));
    await tester.pumpAndSettle();

    // Only the winning card ends face-up (losers stay face-down), so exactly
    // one of the names should be present on the board.
    final adaWon = find.text('Ada').evaluate().isNotEmpty;
    final graceWon = find.text('Grace').evaluate().isNotEmpty;
    expect(adaWon ^ graceWon, isTrue,
        reason: 'exactly one player should be revealed as first player');

    // Once a pick is done, the replay and reset controls appear.
    expect(find.widgetWithText(FilledButton, 'Shuffle Again'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reset'), findsOneWidget);
  });

  testWidgets('a shake also runs the shuffle and reveals a winner',
      (tester) async {
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Ada');
    await addPlayer(tester, 'Grace');

    ShakeGesturePlatform.instance.onShake();
    await tester.pumpAndSettle();

    final adaWon = find.text('Ada').evaluate().isNotEmpty;
    final graceWon = find.text('Grace').evaluate().isNotEmpty;
    expect(adaWon ^ graceWon, isTrue);
  });

  testWidgets('Reset returns every card to its name-up state',
      (tester) async {
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Ada');
    await addPlayer(tester, 'Grace');

    await tester.tap(find.widgetWithText(FilledButton, 'Pick First Player'));
    await tester.pumpAndSettle();
    // Mid-result: only the winner is face-up and removal is unavailable.
    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await tester.pumpAndSettle();

    // Both names are face-up again, each with its remove button back, and the
    // controls return to the single pick button.
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Reset'), findsNothing);
    expect(
        find.widgetWithText(FilledButton, 'Pick First Player'), findsOneWidget);
  });

  testWidgets('a removed player no longer appears on the board',
      (tester) async {
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Ada');
    await addPlayer(tester, 'Grace');
    expect(find.text('Ada'), findsOneWidget);

    // Each idle card carries a cancel button; tapping Ada's removes her.
    await tester.tap(find.byIcon(Icons.cancel).first);
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsNothing);
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('recents button re-adds a previously used player',
      (tester) async {
    await openFirstPlayer(tester);

    // No history yet, so the recents button is disabled.
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history))
            .onPressed,
        isNull);

    // Use a name, then remove it from the board — it should be remembered.
    await addPlayer(tester, 'Ada');
    await tester.tap(find.byIcon(Icons.cancel).first);
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsNothing);

    // The recents button is now enabled; opening it lists the remembered name.
    final recentsBtn = tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history))
        .onPressed;
    expect(recentsBtn, isNotNull);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Ada'), findsOneWidget);

    // Tapping it adds the player back and closes the (now empty) sheet.
    await tester.tap(find.widgetWithText(ListTile, 'Ada'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('recent names persist across reopening the page',
      (tester) async {
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Hopper');
    // Leave the page entirely and come back fresh.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First Player'));
    await tester.pumpAndSettle();

    // Hopper isn't on the new board, but is offered from recents.
    expect(find.text('Hopper'), findsNothing);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Hopper'), findsOneWidget);
  });

  testWidgets('friend suggestions appear badged in the quick-select list',
      (tester) async {
    friendsStore = FakeFriendSuggestionsStore(['Ada']);
    await openFirstPlayer(tester);

    // No personal history yet, but a friend suggestion enables the button.
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history))
            .onPressed,
        isNotNull);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('FROM YOUR FRIENDS'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Ada'), findsOneWidget);
    expect(find.text('Friend'), findsOneWidget);

    // Tapping a friend suggestion adds them to the board like any other name.
    await tester.tap(find.widgetWithText(ListTile, 'Ada'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets(
      'a friend already covered by personal recents is not duplicated',
      (tester) async {
    friendsStore = FakeFriendSuggestionsStore(['Hopper']);
    await openFirstPlayer(tester);
    await addPlayer(tester, 'Hopper');
    await tester.tap(find.byIcon(Icons.cancel).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    // Hopper shows once under Recent Players, not again under Friends.
    expect(find.widgetWithText(ListTile, 'Hopper'), findsOneWidget);
    expect(find.text('FROM YOUR FRIENDS'), findsNothing);
  });
}
