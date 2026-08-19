import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../data/models/game_suggestion.dart';
import '../data/services/suggestions_service.dart';
import 'wishlist_provider.dart';

/// Push: incoming pending suggestions for the current user (PRD §13.2).
final suggestionsProvider =
    AsyncNotifierProvider<SuggestionsNotifier, List<GameSuggestion>>(
        SuggestionsNotifier.new);

class SuggestionsNotifier extends AsyncNotifier<List<GameSuggestion>> {
  @override
  Future<List<GameSuggestion>> build() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    return SuggestionsService.getPendingSuggestions(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Accept: adds the game to the recipient's own wishlist via the *same*
  /// shared insert path Pull uses (`WishlistNotifier.addGame` — Open
  /// Question #8), carrying the sender's note over, then marks the
  /// suggestion accepted. Two separate writes, not a bypass of
  /// `user_wishlist`'s RLS — this is the recipient's own insert.
  Future<void> accept(GameSuggestion suggestion) async {
    final prev = state.asData?.value ?? [];
    state = AsyncData(prev.where((s) => s.id != suggestion.id).toList());
    try {
      await ref.read(wishlistProvider.notifier).addGame(
            suggestion.gameId,
            notes: suggestion.note,
          );
      await SuggestionsService.acceptSuggestion(suggestion.id);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  /// Dismiss: silent per PRD §13.2 — no notification back to the sender.
  Future<void> dismiss(String suggestionId) async {
    final prev = state.asData?.value ?? [];
    state = AsyncData(prev.where((s) => s.id != suggestionId).toList());
    try {
      await SuggestionsService.dismissSuggestion(suggestionId);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}
