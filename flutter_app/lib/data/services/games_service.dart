import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../models/game.dart';
import '../models/library_entry.dart';
import '../models/wishlist_entry.dart';

abstract class GamesService {
  // ── Library ────────────────────────────────────────────────────────────────

  static Future<List<LibraryEntry>> getUserLibrary(String userId) async {
    final data = await supabase
        .from('user_library')
        .select('*, game:shared_games(*)')
        .eq('user_id', userId)
        .order('added_date', ascending: false);
    return data.map((e) => LibraryEntry.fromJson(e)).toList();
  }

  static Future<LibraryEntry> addGameToLibrary(
      String userId, String gameId) async {
    final data = await supabase
        .from('user_library')
        .insert({'user_id': userId, 'game_id': gameId})
        .select('*, game:shared_games(*)')
        .single();
    return LibraryEntry.fromJson(data);
  }

  static Future<void> updateLibraryEntry(
      String entryId, Map<String, dynamic> updates) async {
    await supabase.from('user_library').update(updates).eq('id', entryId);
  }

  static Future<void> removeGameFromLibrary(String entryId) async {
    await supabase.from('user_library').delete().eq('id', entryId);
  }

  // ── Shared games database ──────────────────────────────────────────────────

  static Future<List<Game>> searchSharedGames(String query) async {
    final data = await supabase
        .from('shared_games')
        .select()
        .ilike('name', '%$query%')
        .limit(20);
    return data.map((e) => Game.fromJson(e)).toList();
  }

  static Future<Game?> getGameByBarcode(String barcode) async {
    // Check both UPC-A (12-digit) and EAN-13 (13-digit with 00-prefix) variants
    final variants = [barcode];
    if (barcode.length == 12 && RegExp(r'^\d{12}$').hasMatch(barcode)) {
      variants.add('00$barcode');
    } else if (barcode.length == 13 && barcode.startsWith('00')) {
      variants.add(barcode.substring(2));
    }

    for (final v in variants) {
      final data = await supabase
          .from('shared_games')
          .select()
          .eq('barcode', v)
          .maybeSingle();
      if (data != null) return Game.fromJson(data);
    }
    return null;
  }

  static Future<Game?> getGameByBggId(int bggId) async {
    final data = await supabase
        .from('shared_games')
        .select()
        .eq('bgg_id', bggId)
        .maybeSingle();
    return data == null ? null : Game.fromJson(data);
  }

  // ── Edge function calls ────────────────────────────────────────────────────

  /// Returns null when no lookup service recognises the barcode.
  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    try {
      final response = await supabase.functions
          .invoke('barcode-lookup', body: {'barcode': barcode});
      return response.data as Map<String, dynamic>?;
    } on FunctionException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Adds a game to the signed-in user's library via the
  /// `add-game-to-library` edge function, which creates the shared_games row
  /// server-side (shared_games writes are admin-only).
  ///
  /// Pass [bggId] (plus [barcode] when one was scanned), or — when a barcode
  /// lookup found a name but no BGG match — [barcode] and [name].
  static Future<AddGameResult> addGameToLibraryFromBgg({
    int? bggId,
    String? barcode,
    String? name,
    String? publisher,
    List<String>? designers,
    String target = 'library',
  }) async {
    final response = await supabase.functions.invoke(
      'add-game-to-library',
      body: {
        if (bggId != null) 'bggId': bggId,
        if (barcode != null) 'barcode': barcode,
        if (name != null) 'name': name,
        if (publisher != null) 'publisher': publisher,
        if (designers != null && designers.isNotEmpty) 'designers': designers,
        if (target != 'library') 'target': target,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return AddGameResult(
      game: Game.fromJson(data['game'] as Map<String, dynamic>),
      alreadyInLibrary: data['status'] == 'already_in_library',
      alreadyInWishlist: data['status'] == 'already_in_wishlist',
    );
  }

  static Future<Map<String, dynamic>?> lookupBggById(int bggId) async {
    final response = await supabase.functions
        .invoke('bgg-lookup', body: {'bggId': bggId});
    return response.data as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> searchBgg(String name) async {
    final response = await supabase.functions
        .invoke('bgg-lookup', body: {'searchName': name});
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['results'] as List? ?? []);
  }

  static Future<void> submitBarcodeMapping(
      String barcode, int bggId) async {
    // Fire-and-forget crowdsourced improvement
    supabase.functions.invoke(
      'submit-barcode-mapping',
      body: {'barcode': barcode, 'bggId': bggId},
    );
  }

  // ── Wishlist ───────────────────────────────────────────────────────────────

  static Future<List<WishlistEntry>> getUserWishlist(String userId) async {
    final data = await supabase
        .from('user_wishlist')
        .select('*, game:shared_games(*)')
        .eq('user_id', userId)
        .order('added_date', ascending: false);
    return data.map((e) => WishlistEntry.fromJson(e)).toList();
  }

  static Future<void> addGameToWishlist(
      String userId, String gameId, String priority,
      {String? notes, int heartRating = 0, int punchRating = 0}) async {
    await supabase.from('user_wishlist').insert({
      'user_id': userId,
      'game_id': gameId,
      'priority': priority,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (heartRating > 0) 'heart_rating': heartRating,
      if (punchRating > 0) 'punch_rating': punchRating,
    });
  }

  static Future<void> updateWishlistEntry(
      String entryId, Map<String, dynamic> updates) async {
    await supabase.from('user_wishlist').update(updates).eq('id', entryId);
  }

  static Future<void> removeGameFromWishlist(String entryId) async {
    await supabase.from('user_wishlist').delete().eq('id', entryId);
  }

  /// Atomic (single Postgres function): carries ratings and notes over.
  static Future<void> moveWishlistToLibrary(
      String userId, String gameId) async {
    await supabase.rpc('move_wishlist_to_library', params: {'p_game_id': gameId});
  }

  /// Atomic Library → Wishlist move. Carries ratings and notes over. Throws a
  /// [PostgrestException] with message `game_has_plays` when the game has
  /// logged plays (the UI blocks this up front, so it's a safety net).
  static Future<void> moveLibraryToWishlist(String gameId,
      {String priority = 'medium'}) async {
    await supabase.rpc('move_library_to_wishlist',
        params: {'p_game_id': gameId, 'p_priority': priority});
  }
}

class AddGameResult {
  const AddGameResult({
    required this.game,
    required this.alreadyInLibrary,
    this.alreadyInWishlist = false,
  });

  final Game game;
  final bool alreadyInLibrary;
  final bool alreadyInWishlist;
}
