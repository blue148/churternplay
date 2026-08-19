import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../data/models/wishlist_entry.dart';
import '../data/services/games_service.dart';
import 'library_provider.dart';

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<WishlistEntry>>(
        WishlistNotifier.new);

/// Set right before navigating to the Wishlist tab after adding a game from
/// elsewhere (e.g. a friend's library) — holds the added game's id. The
/// Wishlist tab watches this to scroll the new entry into view, then clears
/// it back to null so it doesn't re-trigger on the next rebuild.
class PendingWishlistHighlightNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final pendingWishlistHighlightProvider =
    NotifierProvider<PendingWishlistHighlightNotifier, String?>(
        PendingWishlistHighlightNotifier.new);

class WishlistNotifier extends AsyncNotifier<List<WishlistEntry>> {
  @override
  Future<List<WishlistEntry>> build() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    return GamesService.getUserWishlist(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Inserts a wishlist entry and refreshes from the server rather than
  /// constructing one locally — `WishlistEntry` needs the server-assigned
  /// `id`/`addedDate`, and the game's own record isn't loaded here to embed.
  /// Shared by both Pull (this screen) and, later, Push's Accept action, so
  /// there's exactly one wishlist-insert code path (PRD Open Question #8).
  Future<void> addGame(String gameId,
      {String priority = 'medium', String? notes}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await GamesService.addGameToWishlist(user.id, gameId, priority,
        notes: notes);
    await refresh();
  }

  Future<void> removeEntry(String entryId) async {
    final prev = state.asData?.value ?? [];
    state = AsyncData(prev.where((e) => e.id != entryId).toList());
    try {
      await GamesService.removeGameFromWishlist(entryId);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> moveToLibrary(String entryId, String gameId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final prev = state.asData?.value ?? [];
    state = AsyncData(prev.where((e) => e.id != entryId).toList());
    try {
      await GamesService.moveWishlistToLibrary(user.id, gameId);
      ref.invalidate(libraryProvider);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}
