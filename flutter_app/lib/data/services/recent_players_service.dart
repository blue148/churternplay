import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_client.dart';

/// Storage for the Game Nite "First Player" recents list. Abstracted so the UI
/// can depend on the behaviour while tests swap in an in-memory implementation.
abstract interface class RecentPlayersStore {
  /// Recent names, most-recent first.
  Future<List<String>> load();

  /// Records [name] as just used and returns the updated list.
  Future<List<String>> add(String name);

  /// Forgets [name] and returns the updated list.
  Future<List<String>> remove(String name);
}

/// Persists the names of players used in the Game Nite "First Player" picker so
/// they can be re-added from a recents list, most-recent first.
///
/// Backed by the per-user `recent_players` table (RLS-scoped), so the list
/// follows the signed-in account across sessions and devices. When no user is
/// signed in every call is a no-op returning an empty list.
class RecentPlayersService implements RecentPlayersStore {
  static const _table = 'recent_players';
  static const _max = 30;
  // "Recent" means used within the last 30 days — older names still exist in
  // the table but age out of the picker on their own.
  static const _recentWindow = Duration(days: 30);

  String? get _userId => supabase.auth.currentUser?.id;

  @override
  Future<List<String>> load() async {
    final userId = _userId;
    if (userId == null) return const [];
    final cutoff = DateTime.now().toUtc().subtract(_recentWindow);
    final rows = await supabase
        .from(_table)
        .select('player_name')
        .eq('user_id', userId)
        .gte('used_at', cutoff.toIso8601String())
        .order('used_at', ascending: false)
        .limit(_max);
    return [for (final r in rows) r['player_name'] as String];
  }

  /// Promotes [name] to the front, de-duplicating case-insensitively and
  /// capping the history at [_max], then returns the updated list.
  @override
  Future<List<String>> add(String name) async {
    final userId = _userId;
    final trimmed = name.trim();
    if (userId == null || trimmed.isEmpty) return load();

    // Pull the current rows so we can drop any case-insensitive duplicate of
    // the incoming name and any overflow beyond the cap in a single delete.
    // The new entry claims slot 0, leaving _max-1 slots for existing rows.
    final rows = await supabase
        .from(_table)
        .select('id, player_name')
        .eq('user_id', userId)
        .order('used_at', ascending: false);

    final lower = trimmed.toLowerCase();
    final toDelete = <String>[];
    var kept = 0;
    for (final r in rows) {
      final isDupe = (r['player_name'] as String).toLowerCase() == lower;
      if (isDupe || kept >= _max - 1) {
        toDelete.add(r['id'] as String);
      } else {
        kept++;
      }
    }
    if (toDelete.isNotEmpty) {
      await supabase.from(_table).delete().inFilter('id', toDelete);
    }
    await supabase
        .from(_table)
        .insert({'user_id': userId, 'player_name': trimmed});
    return load();
  }

  /// Forgets [name] from the recents history and returns the updated list.
  @override
  Future<List<String>> remove(String name) async {
    final userId = _userId;
    if (userId == null) return const [];
    final lower = name.trim().toLowerCase();
    final rows = await supabase
        .from(_table)
        .select('id, player_name')
        .eq('user_id', userId);
    final toDelete = [
      for (final r in rows)
        if ((r['player_name'] as String).toLowerCase() == lower)
          r['id'] as String,
    ];
    if (toDelete.isNotEmpty) {
      await supabase.from(_table).delete().inFilter('id', toDelete);
    }
    return load();
  }
}

/// The most recent set of players used on the Game Nite "First Player" board,
/// in board order. Score Calculator and Log a Play start from this set.
abstract interface class LastPlayerSetStore {
  /// The saved set, or empty when none has been saved.
  Future<List<String>> load();

  /// Saves [names] as the current set. An empty list is ignored so clearing
  /// the board doesn't wipe the default.
  Future<void> save(List<String> names);
}

/// Device-local [LastPlayerSetStore] backed by shared preferences.
class LocalLastPlayerSetStore implements LastPlayerSetStore {
  static const _key = 'game_nite.last_player_set';

  @override
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  @override
  Future<void> save(List<String> names) async {
    if (names.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, names);
  }
}
