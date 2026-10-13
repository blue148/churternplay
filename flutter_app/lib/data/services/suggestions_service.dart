import '../../core/supabase_client.dart';
import '../models/game_suggestion.dart';

/// Push: Suggest a Game to a Friend (PRD §13.2). Mirrors `FriendsService`'s
/// static-method style.
abstract class SuggestionsService {
  static Future<void> sendSuggestion(
      String senderId, String recipientId, String gameId,
      {String? note}) async {
    await supabase.from('game_suggestions').insert({
      'sender_id': senderId,
      'recipient_id': recipientId,
      'game_id': gameId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  static Future<List<GameSuggestion>> getPendingSuggestions(
      String recipientId) async {
    final data = await supabase
        .from('game_suggestions')
        .select('*, sender:public_profiles!sender_id(*), game:shared_games(*)')
        .eq('recipient_id', recipientId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return data.map((e) => GameSuggestion.fromJson(e)).toList();
  }

  /// Marks a suggestion accepted. Deliberately does *not* also insert the
  /// wishlist row — that's `WishlistNotifier.addGame` (Phase 2's shared
  /// insert path, which lives behind Riverpod and isn't reachable from a
  /// plain service class). Callers (Phase 4's Accept action) should call
  /// both: the wishlist add, then this, so there's exactly one wishlist
  /// insert path for both Pull and Push (PRD Open Question #8).
  static Future<void> acceptSuggestion(String suggestionId) async {
    await supabase
        .from('game_suggestions')
        .update({'status': 'accepted'}).eq('id', suggestionId);
  }

  /// Marks a suggestion dismissed — no wishlist entry, no notification back
  /// to the sender (PRD §13.2: "Dismissing is silent").
  static Future<void> dismissSuggestion(String suggestionId) async {
    await supabase
        .from('game_suggestions')
        .update({'status': 'dismissed'}).eq('id', suggestionId);
  }
}
