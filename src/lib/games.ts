import { supabase, Game, UserLibraryEntry, UserWishlistEntry, UserLibraryEntryWithStats, UserFriend, SharedLibraryAccess, SharedLibrary, Profile } from './supabase';
import { getUserGameVictoryStats } from './sessions';

export async function getUserLibrary(userId: string) {
  const { data, error } = await supabase
    .from('user_library')
    .select(`
      *,
      game:shared_games(*)
    `)
    .eq('user_id', userId)
    .order('added_date', { ascending: false });

  if (error) throw error;
  return data as (UserLibraryEntry & { game: Game })[];
}

export async function getUserLibraryWithVictoryStats(userId: string) {
  const library = await getUserLibrary(userId);

  // Add victory stats for each game
  const libraryWithStats = await Promise.all(
    library.map(async (entry) => {
      try {
        const victoryStats = await getUserGameVictoryStats(userId, entry.game_id);
        return {
          ...entry,
          victory_stats: {
            total_sessions: victoryStats.total_sessions,
            total_wins: victoryStats.total_wins,
            win_rate: victoryStats.win_rate,
            best_score: victoryStats.best_score,
            last_played: victoryStats.last_played,
          }
        } as UserLibraryEntryWithStats & { game: Game };
      } catch (error) {
        // If victory stats fail, just return the entry without stats
        return entry as UserLibraryEntryWithStats & { game: Game };
      }
    })
  );

  return libraryWithStats;
}

export async function getLibraryEntry(entryId: string) {
  const { data, error } = await supabase
    .from('user_library')
    .select(`
      *,
      game:shared_games(*)
    `)
    .eq('id', entryId)
    .single();

  if (error) throw error;
  return data as UserLibraryEntry & { game: Game };
}

export async function searchSharedGames(query: string) {
  const { data, error } = await supabase
    .from('shared_games')
    .select('*')
    .ilike('name', `%${query}%`)
    .limit(20);

  if (error) throw error;
  return data as Game[];
}

export async function getGameByBarcode(barcode: string) {
  // Generate barcode variations to support UPC-A (12-digit) and EAN-13 (13-digit) formats
  const variations = [barcode]; // Original barcode first (priority)

  if (barcode.length === 12 && /^\d{12}$/.test(barcode)) {
    // 12-digit UPC-A: also check EAN-13 with 00 prefix
    variations.push(`00${barcode}`);
  } else if (barcode.length === 13 && barcode.startsWith('00')) {
    // 13-digit EAN starting with 00: also check UPC-A (remove prefix)
    variations.push(barcode.slice(2));
  }

  const { data, error } = await supabase
    .from('shared_games')
    .select('*')
    .in('barcode', variations)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data as Game | null;
}

export async function getGameByBggId(bggId: number) {
  const { data, error } = await supabase
    .from('shared_games')
    .select('*')
    .eq('bgg_id', bggId)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data as Game | null;
}

export async function createSharedGame(game: Omit<Game, 'id' | 'created_at' | 'updated_at'>) {
  const { data, error } = await supabase
    .from('shared_games')
    .insert(game)
    .select()
    .single();

  if (error) throw error;
  return data as Game;
}

export async function addGameToLibrary(userId: string, gameId: string) {
  const { data, error } = await supabase
    .from('user_library')
    .insert({
      user_id: userId,
      game_id: gameId,
    })
    .select()
    .single();

  if (error) throw error;
  return data as UserLibraryEntry;
}

export async function updateLibraryEntry(
  entryId: string,
  updates: Partial<Pick<UserLibraryEntry, 'is_favorite' | 'for_sale' | 'personal_ranking' | 'played_dates' | 'notes'>>
) {
  const { data, error } = await supabase
    .from('user_library')
    .update(updates)
    .eq('id', entryId)
    .select()
    .single();

  if (error) throw error;
  return data as UserLibraryEntry;
}

export async function removeGameFromLibrary(entryId: string) {
  const { error } = await supabase
    .from('user_library')
    .delete()
    .eq('id', entryId);

  if (error) throw error;
}

export async function lookupBarcode(barcode: string): Promise<Partial<Game>> {
  try {
    const response = await fetch(`https://api.gameupc.com/test/upc/${barcode}`, {
      headers: {
        'x-api-key': 'test_test_test_test_test'
      }
    });

    if (!response.ok) {
      throw new Error('Barcode lookup failed');
    }

    const result = await response.json();

    // GameUPC returns bgg_info array with game matches
    if (result.bgg_info && result.bgg_info.length > 0) {
      const game = result.bgg_info[0];
      return {
        barcode,
        name: game.name || 'Unknown Game',
        bgg_id: game.id,
        // GameUPC primarily provides BGG mapping - additional metadata like
        // publisher, year, and cover_image would need to be fetched from BGG API
      };
    }

    return {
      barcode,
      name: 'Unknown Game',
    };
  } catch (error) {
    console.error('Barcode lookup error:', error);
    return {
      barcode,
      name: 'Unknown Game',
    };
  }
}

export async function enrichSharedGameWithBggId(barcode: string): Promise<Game | null> {
  // First, get the existing game by barcode
  const existingGame = await getGameByBarcode(barcode);

  if (!existingGame) {
    return null;
  }

  // If bgg_id is already set, return the game as-is
  if (existingGame.bgg_id) {
    return existingGame;
  }

  // Look up the barcode using GameUPC API
  const gameData = await lookupBarcode(barcode);

  // If we got a bgg_id from the API, update the shared_games record
  if (gameData.bgg_id) {
    const { data, error } = await supabase
      .from('shared_games')
      .update({ bgg_id: gameData.bgg_id })
      .eq('id', existingGame.id)
      .select()
      .single();

    if (error) throw error;
    return data as Game;
  }

  // No bgg_id found, return the existing game
  return existingGame;
}

// Wishlist functions
export async function getUserWishlist(userId: string) {
  const { data, error } = await supabase
    .from('user_wishlist')
    .select(`
      *,
      game:shared_games(*)
    `)
    .eq('user_id', userId)
    .order('added_date', { ascending: false });

  if (error) throw error;
  return data as (UserWishlistEntry & { game: Game })[];
}

export async function getWishlistEntry(entryId: string) {
  const { data, error } = await supabase
    .from('user_wishlist')
    .select(`
      *,
      game:shared_games(*)
    `)
    .eq('id', entryId)
    .single();

  if (error) throw error;
  return data as UserWishlistEntry & { game: Game };
}

export async function addGameToWishlist(userId: string, gameId: string, priority: 'high' | 'medium' | 'low' = 'medium', notes?: string) {
  const { data, error } = await supabase
    .from('user_wishlist')
    .insert({
      user_id: userId,
      game_id: gameId,
      priority,
      notes,
    })
    .select()
    .single();

  if (error) throw error;
  return data as UserWishlistEntry;
}

export async function updateWishlistEntry(
  entryId: string,
  updates: Partial<Pick<UserWishlistEntry, 'priority' | 'notes'>>
) {
  const { data, error } = await supabase
    .from('user_wishlist')
    .update(updates)
    .eq('id', entryId)
    .select()
    .single();

  if (error) throw error;
  return data as UserWishlistEntry;
}

export async function removeGameFromWishlist(entryId: string) {
  const { error } = await supabase
    .from('user_wishlist')
    .delete()
    .eq('id', entryId);

  if (error) throw error;
}

export async function moveGameFromWishlistToLibrary(userId: string, wishlistEntryId: string) {
  // Get the wishlist entry
  const wishlistEntry = await getWishlistEntry(wishlistEntryId);

  // Add to library
  const libraryEntry = await addGameToLibrary(userId, wishlistEntry.game_id);

  // Remove from wishlist
  await removeGameFromWishlist(wishlistEntryId);

  return libraryEntry;
}

export async function checkGameInUserCollections(userId: string, gameId: string) {
  const [libraryCheck, wishlistCheck] = await Promise.all([
    supabase
      .from('user_library')
      .select('id')
      .eq('user_id', userId)
      .eq('game_id', gameId)
      .maybeSingle(),
    supabase
      .from('user_wishlist')
      .select('id')
      .eq('user_id', userId)
      .eq('game_id', gameId)
      .maybeSingle()
  ]);

  if (libraryCheck.error) throw libraryCheck.error;
  if (wishlistCheck.error) throw wishlistCheck.error;

  return {
    inLibrary: !!libraryCheck.data,
    inWishlist: !!wishlistCheck.data,
    libraryEntryId: libraryCheck.data?.id,
    wishlistEntryId: wishlistCheck.data?.id,
  };
}

// ===========================================
// SHARED LIBRARY & FRIENDS FUNCTIONS
// ===========================================

// Friend Management
export async function sendFriendRequest(userId: string, friendId: string) {
  const { data, error } = await supabase
    .from('user_friends')
    .insert({
      user_id: userId,
      friend_id: friendId,
      status: 'pending'
    })
    .select(`
      *,
      friend:public_profiles!friend_id(*)
    `)
    .single();

  if (error) throw error;
  return data as UserFriend & { friend: Profile };
}

export async function acceptFriendRequest(requestId: string) {
  const { data, error } = await supabase
    .from('user_friends')
    .update({ status: 'accepted' })
    .eq('id', requestId)
    .select(`
      *,
      friend:public_profiles!friend_id(*)
    `)
    .single();

  if (error) throw error;
  return data as UserFriend & { friend: Profile };
}

export async function getUserFriends(userId: string) {
  const { data, error } = await supabase
    .from('user_friends')
    .select(`
      *,
      friend:public_profiles!friend_id(*)
    `)
    .or(`and(user_id.eq.${userId},status.eq.accepted),and(friend_id.eq.${userId},status.eq.accepted)`)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data as (UserFriend & { friend: Profile })[];
}

export async function getPendingFriendRequests(userId: string) {
  const { data, error } = await supabase
    .from('user_friends')
    .select(`
      *,
      friend:public_profiles!user_id(*)
    `)
    .eq('friend_id', userId)
    .eq('status', 'pending')
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data as (UserFriend & { friend: Profile })[];
}

export async function blockUser(userId: string, friendId: string) {
  // First, try to update existing relationship
  const { data: existing } = await supabase
    .from('user_friends')
    .update({ status: 'blocked' })
    .or(`and(user_id.eq.${userId},friend_id.eq.${friendId}),and(user_id.eq.${friendId},friend_id.eq.${userId})`)
    .select()
    .maybeSingle();

  if (!existing) {
    // Create new blocked relationship
    const { data, error } = await supabase
      .from('user_friends')
      .insert({
        user_id: userId,
        friend_id: friendId,
        status: 'blocked'
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  return existing;
}

export async function removeFriend(userId: string, friendId: string) {
  const { error } = await supabase
    .from('user_friends')
    .delete()
    .or(`and(user_id.eq.${userId},friend_id.eq.${friendId}),and(user_id.eq.${friendId},friend_id.eq.${userId})`);

  if (error) throw error;

  // Also remove any library access
  await revokeLibraryAccess(userId, friendId);
}

// Library Sharing
export async function shareLibraryWith(ownerId: string, viewerId: string, accessLevel: 'view' | 'suggest' = 'view') {
  const { data, error } = await supabase
    .from('shared_library_access')
    .insert({
      owner_id: ownerId,
      viewer_id: viewerId,
      access_level: accessLevel,
      granted_at: new Date().toISOString()
    })
    .select(`
      *,
      owner:public_profiles!owner_id(*),
      viewer:public_profiles!viewer_id(*)
    `)
    .single();

  if (error) throw error;
  return data as SharedLibraryAccess & { owner: Profile; viewer: Profile };
}

export async function revokeLibraryAccess(ownerId: string, viewerId: string) {
  const { error } = await supabase
    .from('shared_library_access')
    .delete()
    .eq('owner_id', ownerId)
    .eq('viewer_id', viewerId);

  if (error) throw error;
}

export async function getSharedLibraries(userId: string): Promise<SharedLibrary[]> {
  const { data, error } = await supabase
    .from('shared_library_access')
    .select(`
      *,
      owner:public_profiles!owner_id(*)
    `)
    .eq('viewer_id', userId)
    .order('granted_at', { ascending: false });

  if (error) throw error;

  // Get library metadata for each shared library
  const libraries = await Promise.all(
    data.map(async (access) => {
      const { count } = await supabase
        .from('user_library')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', access.owner_id);

      const { data: latestEntry } = await supabase
        .from('user_library')
        .select('updated_at')
        .eq('user_id', access.owner_id)
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      return {
        owner: access.owner,
        game_count: count || 0,
        last_updated: latestEntry?.updated_at || access.granted_at,
        access_level: access.access_level
      } as SharedLibrary;
    })
  );

  return libraries;
}

export async function getSharedLibraryGames(ownerId: string, viewerId: string, limit: number = 50, offset: number = 0) {
  // First check if viewer has access
  const { data: access } = await supabase
    .from('shared_library_access')
    .select('access_level')
    .eq('owner_id', ownerId)
    .eq('viewer_id', viewerId)
    .single();

  if (!access) {
    throw new Error('Access denied to this library');
  }

  const { data, error } = await supabase
    .from('user_library')
    .select(`
      *,
      game:shared_games(*)
    `)
    .eq('user_id', ownerId)
    .order('added_date', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return data as (UserLibraryEntry & { game: Game })[];
}

export async function searchSharedLibrary(ownerId: string, viewerId: string, query: string, limit: number = 20) {
  // First check if viewer has access
  const { data: access } = await supabase
    .from('shared_library_access')
    .select('access_level')
    .eq('owner_id', ownerId)
    .eq('viewer_id', viewerId)
    .single();

  if (!access) {
    throw new Error('Access denied to this library');
  }

  const { data, error } = await supabase
    .from('user_library')
    .select(`
      *,
      game:shared_games(*)
    `)
    .eq('user_id', ownerId)
    .or(`game.name.ilike.%${query}%,game.publisher.ilike.%${query}%`)
    .order('added_date', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data as (UserLibraryEntry & { game: Game })[];
}

export async function getFriendsWithLibraryAccess(userId: string) {
  const { data, error } = await supabase
    .from('shared_library_access')
    .select(`
      *,
      viewer:public_profiles!viewer_id(*)
    `)
    .eq('owner_id', userId)
    .order('granted_at', { ascending: false });

  if (error) throw error;
  return data as (SharedLibraryAccess & { viewer: Profile })[];
}

export async function searchUsers(query: string, excludeUserId: string, limit: number = 10) {
  const { data, error } = await supabase
    .from('public_profiles')
    .select('id, username, full_name, avatar_url, total_games')
    .or(`username.ilike.*${query.replace(/,/g, '')}*,full_name.ilike.*${query.replace(/,/g, '')}*`)
    .neq('id', excludeUserId)
    .order('total_games', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data as Profile[];
}

export async function getGameOwnership(gameId: string, friendIds: string[]) {
  if (friendIds.length === 0) return [];

  const { data, error } = await supabase
    .from('user_library')
    .select(`
      user_id,
      game_id,
      owner:public_profiles!user_id(id, username, avatar_url)
    `)
    .eq('game_id', gameId)
    .in('user_id', friendIds);

  if (error) throw error;
  return data.map(entry => ({
    user_id: entry.user_id,
    game_id: entry.game_id,
    owner: entry.owner
  }));
}
