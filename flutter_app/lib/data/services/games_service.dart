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

  static Future<Game> upsertSharedGame(Map<String, dynamic> game) async {
    final data = await supabase
        .from('shared_games')
        .upsert(game, onConflict: 'barcode')
        .select()
        .single();
    return Game.fromJson(data);
  }

  // ── Edge function calls ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    final response = await supabase.functions
        .invoke('barcode-lookup', body: {'barcode': barcode});
    return response.data as Map<String, dynamic>?;
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
      {String? notes}) async {
    await supabase.from('user_wishlist').insert({
      'user_id': userId,
      'game_id': gameId,
      'priority': priority,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  static Future<void> removeGameFromWishlist(String entryId) async {
    await supabase.from('user_wishlist').delete().eq('id', entryId);
  }

  static Future<void> moveWishlistToLibrary(
      String userId, String gameId) async {
    await supabase
        .from('user_library')
        .insert({'user_id': userId, 'game_id': gameId});
    await supabase
        .from('user_wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('game_id', gameId);
  }
}
