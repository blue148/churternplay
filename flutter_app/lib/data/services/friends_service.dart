import '../../core/supabase_client.dart';
import '../models/friend.dart';
import '../models/library_entry.dart';
import '../models/profile.dart';

abstract class FriendsService {
  // ── Friends ────────────────────────────────────────────────────────────────

  static Future<List<UserFriend>> getUserFriends(String userId) async {
    // A friendship row's user_id/friend_id reflect who sent the original
    // request, not who owns the query — an accepted request the current
    // user *received* has userId sitting in friend_id, not user_id. Fetch
    // both directions and join the *other* profile in each so `.friend` is
    // always the other party, regardless of who sent the original request.
    final sent = await supabase
        .from('user_friends')
        .select('*, friend:public_profiles!friend_id(*)')
        .eq('user_id', userId)
        .eq('status', 'accepted');
    final received = await supabase
        .from('user_friends')
        .select('*, friend:public_profiles!user_id(*)')
        .eq('friend_id', userId)
        .eq('status', 'accepted');
    return [
      ...sent.map((e) => UserFriend.fromJson(e)),
      ...received.map((e) => UserFriend.fromJson(e)),
    ];
  }

  /// All other-user ids the current user has *any* `user_friends` row with
  /// (pending, accepted, or blocked; either direction) — used to keep
  /// already-requested/blocked users out of "find friends" search results,
  /// since a duplicate INSERT on an existing (user_id, friend_id) pair
  /// fails the table's unique constraint.
  static Future<Set<String>> getRelatedUserIds(String userId) async {
    final data = await supabase
        .from('user_friends')
        .select('user_id, friend_id')
        .or('user_id.eq.$userId,friend_id.eq.$userId');
    return {
      for (final row in data)
        row['user_id'] == userId
            ? row['friend_id'] as String
            : row['user_id'] as String,
    };
  }

  /// Requests the current user has *received* and not yet responded to.
  static Future<List<UserFriend>> getPendingRequests(String userId) async {
    final data = await supabase
        .from('user_friends')
        .select('*, friend:public_profiles!user_id(*)')
        .eq('friend_id', userId)
        .eq('status', 'pending');
    return data.map((e) => UserFriend.fromJson(e)).toList();
  }

  /// Requests the current user has *sent* that the other party hasn't
  /// accepted yet — surfaced as a "Pending" row so the sender can see the
  /// request is still outstanding.
  static Future<List<UserFriend>> getSentPendingRequests(
      String userId) async {
    final data = await supabase
        .from('user_friends')
        .select('*, friend:public_profiles!friend_id(*)')
        .eq('user_id', userId)
        .eq('status', 'pending');
    return data.map((e) => UserFriend.fromJson(e)).toList();
  }

  static Future<void> sendFriendRequest(
      String userId, String friendId) async {
    await supabase.from('user_friends').insert({
      'user_id': userId,
      'friend_id': friendId,
      'status': 'pending',
    });
  }

  static Future<void> acceptRequest(String requestId) async {
    await supabase
        .from('user_friends')
        .update({'status': 'accepted'}).eq('id', requestId);
  }

  static Future<void> removeFriend(String userId, String friendId) async {
    // The row's user_id/friend_id reflect who sent the original request, not
    // who's removing it now — match either direction or this silently
    // deletes nothing when the caller was the recipient.
    await supabase.from('user_friends').delete().or(
        'and(user_id.eq.$userId,friend_id.eq.$friendId),'
        'and(user_id.eq.$friendId,friend_id.eq.$userId)');
  }

  static Future<void> blockUser(String userId, String blockId) async {
    // Same directional issue as removeFriend: match either direction, since
    // the row's user_id/friend_id reflect who sent the original request, not
    // who's blocking now.
    await supabase.from('user_friends').update({'status': 'blocked'}).or(
        'and(user_id.eq.$userId,friend_id.eq.$blockId),'
        'and(user_id.eq.$blockId,friend_id.eq.$userId)');
  }

  static Future<List<AppProfile>> searchUsers(String query) async {
    // Match on username *or* display name — a real-world display name
    // ("Jason Sonderman") often doesn't resemble the account's @handle
    // ("user-tester"), so username-only matching left plausible searches
    // returning nothing.
    //
    // PostgREST's or() filter parses its value as a comma-separated list, so
    // it reserves `%` for percent-encoding and expects `*` as the ilike
    // wildcard instead — passing literal `%` here (as you would to a
    // standalone .ilike() call) silently breaks the match instead of erroring.
    final q = query.replaceAll(',', '');
    final data = await supabase
        .from('public_profiles')
        .select()
        .or('username.ilike.*$q*,full_name.ilike.*$q*')
        .limit(20);
    return data.map((e) => AppProfile.fromJson(e)).toList();
  }

  // ── Library sharing ────────────────────────────────────────────────────────

  static Future<List<SharedLibraryAccess>> getSharedLibraries(
      String userId) async {
    final data = await supabase
        .from('shared_library_access')
        .select('*, owner:public_profiles!owner_id(*)')
        .eq('viewer_id', userId);
    return data.map((e) => SharedLibraryAccess.fromJson(e)).toList();
  }

  static Future<void> shareLibraryWith(
      String ownerId, String viewerId, String accessLevel) async {
    await supabase.from('shared_library_access').upsert({
      'owner_id': ownerId,
      'viewer_id': viewerId,
      'access_level': accessLevel,
    });
  }

  static Future<void> revokeLibraryAccess(
      String ownerId, String viewerId) async {
    await supabase
        .from('shared_library_access')
        .delete()
        .eq('owner_id', ownerId)
        .eq('viewer_id', viewerId);
  }

  static Future<List<LibraryEntry>> getSharedLibraryGames(
      String ownerId) async {
    final data = await supabase
        .from('user_library')
        .select('*, game:shared_games(*)')
        .eq('user_id', ownerId)
        .order('added_date', ascending: false);
    return data.map((e) => LibraryEntry.fromJson(e)).toList();
  }

  // ── Player name suggestions ────────────────────────────────────────────────

  /// Usernames of friends who've shared a library with [userId] — a stub
  /// source of quick-select names (e.g. for the Game Nite "First Player"
  /// picker) until a dedicated "who I play with" concept exists.
  static Future<List<String>> getConnectedFriendNames(String userId) async {
    final shared = await getSharedLibraries(userId);
    return [
      for (final access in shared)
        if (access.owner != null) access.owner!.username,
    ];
  }
}
