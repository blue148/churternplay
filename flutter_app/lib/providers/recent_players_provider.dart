import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/recent_players_service.dart';

/// The last set of players used on the First Player board; the default for
/// the Score Calculator and Log a Play. Overridden in tests.
final lastPlayerSetStoreProvider = Provider<LastPlayerSetStore>(
  (ref) => LocalLastPlayerSetStore(),
);

/// The backing store for the Game Nite "First Player" recents list. Overridden
/// in tests with an in-memory implementation.
final recentPlayersStoreProvider = Provider<RecentPlayersStore>(
  (ref) => RecentPlayersService(),
);
