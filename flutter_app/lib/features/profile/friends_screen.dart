import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/friend.dart';
import '../../data/models/profile.dart';
import '../../data/services/friends_service.dart';
import '../library/widgets/friend_row.dart';

/// Full friend-management screen: search/add, accept/decline pending
/// requests, and remove existing friends. This is the *only* place friend
/// relationships are managed — My Games → Friends is read-only and just
/// links here when there's something to act on.
class FriendsScreen extends ConsumerStatefulWidget {
  static const routePath = '/profile/friends';

  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  List<UserFriend> _friends = [];
  List<UserFriend> _pending = [];
  List<UserFriend> _sent = [];
  Set<String> _relatedIds = {};
  bool _loading = true;

  final _findCtrl = TextEditingController();
  String _findQuery = '';
  List<AppProfile> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _findCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final results = await (
        FriendsService.getUserFriends(user.id),
        FriendsService.getPendingRequests(user.id),
        FriendsService.getSentPendingRequests(user.id),
        FriendsService.getRelatedUserIds(user.id),
      ).wait;
      if (mounted) {
        setState(() {
          _friends = results.$1;
          _pending = results.$2;
          _sent = results.$3;
          _relatedIds = results.$4;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onFindChanged(String value) {
    setState(() {
      _findQuery = value;
      if (value.length < 2) _searchResults = [];
    });
    _debounce?.cancel();
    if (value.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 400), _searchUsers);
    }
  }

  Future<void> _searchUsers() async {
    if (_findQuery.length < 2) return;
    setState(() => _searching = true);
    try {
      final results = await FriendsService.searchUsers(_findQuery);
      // Exclude self and anyone with an existing relationship row of any
      // status/direction — not just accepted friends. A user with an
      // outstanding pending request (sent or received) or a block would
      // otherwise still show an "Add" button whose insert then fails the
      // table's unique (user_id, friend_id) constraint.
      final excludeIds = {
        ..._relatedIds,
        supabase.auth.currentUser?.id ?? '',
      };
      if (mounted) {
        setState(() {
          _searchResults =
              results.where((u) => !excludeIds.contains(u.id)).toList();
          _searching = false;
        });
      }
    } catch (e) {
      debugPrint('searchUsers failed: $e');
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to search for users')),
        );
      }
    }
  }

  Future<void> _sendRequest(String friendId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await FriendsService.sendFriendRequest(user.id, friendId);
      setState(() {
        _searchResults.removeWhere((u) => u.id == friendId);
        _relatedIds.add(friendId);
      });
    } catch (e) {
      debugPrint('sendFriendRequest failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send friend request')),
        );
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await FriendsService.acceptRequest(requestId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept request')),
        );
      }
    }
  }

  Future<void> _confirmRemoveFriend(UserFriend friendship) async {
    final name = friendship.friend?.username ?? 'this user';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove friend?',
            style: GoogleFonts.literata(fontSize: 22)),
        content: Text('Remove $name as a friend?',
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink400)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Remove',
                style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.clay500)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final user = supabase.auth.currentUser;
      final other = friendship.friend?.id;
      if (user == null || other == null) return;
      // Use the joined other-party id, not the raw friendId column — for a
      // friendship the current user *received*, friendId is the current
      // user's own id, not the other person's.
      await FriendsService.removeFriend(user.id, other);
      await _load();
    }
  }

  Future<void> _confirmCancelRequest(UserFriend request) async {
    final name = request.friend?.username ?? 'this user';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel request?',
            style: GoogleFonts.literata(fontSize: 22)),
        content: Text('Cancel your friend request to $name?',
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink400)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Cancel request',
                style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.clay500)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final user = supabase.auth.currentUser;
      final other = request.friend?.id;
      if (user == null || other == null) return;
      await FriendsService.removeFriend(user.id, other);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = _findQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _findCtrl,
                    onChanged: _onFindChanged,
                    style:
                        GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink500),
                    decoration: InputDecoration(
                      hintText: 'Find friends by username…',
                      prefixIcon: const Icon(Icons.person_search,
                          size: 20, color: AppColors.ink200),
                      suffixIcon: _findQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _findCtrl.clear();
                                setState(() {
                                  _findQuery = '';
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: showSearch
                        ? _buildSearchResults()
                        : _buildFriendsList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchResults() {
    if (_findQuery.length < 2) {
      return Center(
        child: Text('Type at least 2 characters',
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink300)),
      );
    }

    // Existing friends matching the query are surfaced separately from the
    // system-wide search — they're already friends, so there's nothing to
    // "add"; the system section only ever contains addable strangers since
    // _relatedIds already excludes friends from _searchResults.
    final q = _findQuery.toLowerCase();
    final currentMatches = _friends
        .where((f) => (f.friend?.username ?? '').toLowerCase().contains(q))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (currentMatches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('CURRENT',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.ink300)),
          ),
          ...currentMatches.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FriendRow(
                  username: f.friend?.username ?? 'Unknown',
                  avatarUrl: f.friend?.avatarUrl,
                  totalGames: f.friend?.totalGames ?? 0,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz,
                        size: 18, color: AppColors.ink300),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          const Icon(Icons.person_remove_outlined,
                              size: 16, color: AppColors.clay500),
                          const SizedBox(width: 10),
                          Text('Remove friend',
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 13, color: AppColors.clay500)),
                        ]),
                      ),
                    ],
                    onSelected: (_) => _confirmRemoveFriend(f),
                  ),
                ),
              )),
          const SizedBox(height: 8),
        ],
        // Always shown, even with zero matches — an empty result here means
        // the search genuinely found no one, and the user needs to see that
        // to know their search term (not the feature) is what to adjust.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('ADD FRIENDS',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.plum400)),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off,
                      size: 40, color: AppColors.ink100),
                  const SizedBox(height: 10),
                  Text('No matches for "$_findQuery"',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 13, color: AppColors.ink300)),
                ],
              ),
            ),
          )
        else
          ..._searchResults.map((user) => Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: FriendRow(
                  username: user.username,
                  avatarUrl: user.avatarUrl,
                  totalGames: user.totalGames,
                  trailing: FilledButton(
                    onPressed: () => _sendRequest(user.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.plum400,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Add',
                        style:
                            GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: Colors.white)),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildFriendsList() {
    final hasContent =
        _pending.isNotEmpty || _sent.isNotEmpty || _friends.isNotEmpty;
    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: AppColors.ink100),
            const SizedBox(height: 16),
            Text('No friends yet',
                style: GoogleFonts.literata(
                    fontSize: 22, color: AppColors.ink300)),
            const SizedBox(height: 8),
            Text('Search above to find and add friends',
                style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink200)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Pending requests section
        if (_pending.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text('REQUESTS (${_pending.length})',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.clay400)),
          ),
          ..._pending.map((req) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FriendRow(
                  username: req.friend?.username ?? 'Unknown',
                  avatarUrl: req.friend?.avatarUrl,
                  totalGames: req.friend?.totalGames ?? 0,
                  subtitle: 'Wants to be friends',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            color: AppColors.forest500, size: 22),
                        onPressed: () => _acceptRequest(req.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
        ],

        // Sent (outgoing, still-pending) requests section
        if (_sent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text('SENT (${_sent.length})',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.ink300)),
          ),
          ..._sent.map((req) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FriendRow(
                  username: req.friend?.username ?? 'Unknown',
                  avatarUrl: req.friend?.avatarUrl,
                  totalGames: req.friend?.totalGames ?? 0,
                  subtitle: 'Pending',
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz,
                        size: 18, color: AppColors.ink300),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'cancel',
                        child: Row(children: [
                          const Icon(Icons.cancel_outlined,
                              size: 16, color: AppColors.clay500),
                          const SizedBox(width: 10),
                          Text('Cancel request',
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 13, color: AppColors.clay500)),
                        ]),
                      ),
                    ],
                    onSelected: (_) => _confirmCancelRequest(req),
                  ),
                ),
              )),
          const SizedBox(height: 8),
        ],

        // Friends section
        if (_friends.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text('FRIENDS (${_friends.length})',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.ink300)),
          ),
          ..._friends.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FriendRow(
                  username: f.friend?.username ?? 'Unknown',
                  avatarUrl: f.friend?.avatarUrl,
                  totalGames: f.friend?.totalGames ?? 0,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz,
                        size: 18, color: AppColors.ink300),
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          const Icon(Icons.person_remove_outlined,
                              size: 16, color: AppColors.clay500),
                          const SizedBox(width: 10),
                          Text('Remove friend',
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 13, color: AppColors.clay500)),
                        ]),
                      ),
                    ],
                    onSelected: (_) => _confirmRemoveFriend(f),
                  ),
                ),
              )),
        ],
      ],
    );
  }
}
