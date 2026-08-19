import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/library_entry.dart';
import '../data/models/library_filter.dart';
import '../data/services/games_service.dart';
import 'auth_provider.dart';

/// Set right before navigating to `/library` (e.g. from the bottom nav's
/// long-press section menu) to land on a specific tab — 0: My Library,
/// 1: Wishlist, 2: Friend's Games. The library screen watches this to jump
/// tabs, then clears it back to null so it doesn't re-trigger later.
class PendingLibraryTabNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? value) => state = value;
}

final pendingLibraryTabProvider =
    NotifierProvider<PendingLibraryTabNotifier, int?>(
        PendingLibraryTabNotifier.new);

class LibraryNotifier extends AsyncNotifier<List<LibraryEntry>> {
  @override
  Future<List<LibraryEntry>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    return GamesService.getUserLibrary(user.id);
  }

  Future<void> toggleFavorite(String entryId, bool isFavorite) async {
    final current = state.asData?.value ?? [];
    state = AsyncData(
      current
          .map((e) => e.id == entryId ? e.copyWith(isFavorite: isFavorite) : e)
          .toList(),
    );
    try {
      await GamesService.updateLibraryEntry(entryId, {'is_favorite': isFavorite});
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> toggleForSale(String entryId, bool forSale) async {
    final current = state.asData?.value ?? [];
    state = AsyncData(
      current
          .map((e) => e.id == entryId ? e.copyWith(forSale: forSale) : e)
          .toList(),
    );
    try {
      await GamesService.updateLibraryEntry(entryId, {'for_sale': forSale});
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Appends [playedAt] to the entry's play history. Called after a play is
  /// logged so the catalogue's play count badge reflects it immediately.
  Future<void> recordPlayedDate(String entryId, DateTime playedAt) async {
    final current = state.asData?.value ?? [];
    final index = current.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    final entry = current[index];
    final updatedDates = [...entry.playedDates, playedAt];
    state = AsyncData([
      for (final e in current)
        e.id == entryId ? e.copyWith(playedDates: updatedDates) : e,
    ]);
    try {
      await GamesService.updateLibraryEntry(entryId, {
        'played_dates':
            updatedDates.map((d) => d.toIso8601String().split('T').first).toList(),
      });
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> removeGame(String entryId) async {
    final current = state.asData?.value ?? [];
    state = AsyncData(current.where((e) => e.id != entryId).toList());
    try {
      await GamesService.removeGameFromLibrary(entryId);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final libraryProvider =
    AsyncNotifierProvider<LibraryNotifier, List<LibraryEntry>>(
  LibraryNotifier.new,
);

/// Free-text search applied to the catalogue (name / publisher / barcode).
class LibrarySearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final librarySearchProvider =
    NotifierProvider<LibrarySearchNotifier, String>(LibrarySearchNotifier.new);

/// The active filter + sort selection for the catalogue list.
class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();
  void set(LibraryFilter value) => state = value;
  void update(LibraryFilter Function(LibraryFilter current) fn) =>
      state = fn(state);
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
        LibraryFilterNotifier.new);

/// The distinct facet values available to filter by, derived from the loaded
/// library. Mirrors the web `availableFilters` memo in `Library.tsx`.
class LibraryFacets {
  final List<String> publishers;
  final List<String> gameTypes;
  final List<String> categories;
  final List<String> years;

  const LibraryFacets({
    this.publishers = const [],
    this.gameTypes = const [],
    this.categories = const [],
    this.years = const [],
  });
}

final availableFacetsProvider = Provider<LibraryFacets>((ref) {
  final entries = ref.watch(libraryProvider).asData?.value ?? const [];
  final publishers = <String>{};
  final gameTypes = <String>{};
  final categories = <String>{};
  final years = <String>{};

  for (final e in entries) {
    final p = e.game.publisher;
    if (p != null && p.isNotEmpty) publishers.add(p);
    final y = e.game.year;
    if (y != null && y.isNotEmpty) years.add(y);
    gameTypes.addAll(e.game.gameType);
    categories.addAll(e.game.gameCategory);
  }

  List<String> sorted(Set<String> s) => s.toList()..sort();

  return LibraryFacets(
    publishers: sorted(publishers),
    gameTypes: sorted(gameTypes),
    categories: sorted(categories),
    years: sorted(years),
  );
});

/// The catalogue list after search + filter + sort have been applied,
/// preserving the underlying [AsyncValue] loading/error state.
final filteredLibraryProvider = Provider<AsyncValue<List<LibraryEntry>>>((ref) {
  final async = ref.watch(libraryProvider);
  final query = ref.watch(librarySearchProvider).trim().toLowerCase();
  final filter = ref.watch(libraryFilterProvider);

  return async.whenData((entries) {
    var result = entries;
    if (query.isNotEmpty) {
      result = result
          .where((e) =>
              e.game.name.toLowerCase().contains(query) ||
              (e.game.publisher?.toLowerCase().contains(query) ?? false) ||
              (e.game.barcode?.toLowerCase().contains(query) ?? false))
          .toList();
    }
    return filter.apply(result);
  });
});

/// Live count of entries matching the *pending* filter (used by the filter
/// sheet's "Show N games" button before the user commits).
int countMatching(List<LibraryEntry> entries, LibraryFilter filter,
    String query) {
  final q = query.trim().toLowerCase();
  var result = entries;
  if (q.isNotEmpty) {
    result = result
        .where((e) =>
            e.game.name.toLowerCase().contains(q) ||
            (e.game.publisher?.toLowerCase().contains(q) ?? false) ||
            (e.game.barcode?.toLowerCase().contains(q) ?? false))
        .toList();
  }
  return filter.apply(result).length;
}
