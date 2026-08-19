import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/library_entry.dart';
import '../../data/models/library_filter.dart';
import '../../data/services/friends_service.dart';
import '../../providers/library_provider.dart';
import '../../providers/wishlist_provider.dart';
import 'widgets/add_to_wishlist_sheet.dart';
import 'widgets/game_card.dart';
import 'widgets/sort_bottom_sheet.dart';

/// Read-only view of a friend's shared library (PRD §13.1). Deliberately not
/// wired into the app's own `libraryProvider`/filter providers for its *own*
/// list — that's scoped to the current user's library only — this screen
/// owns its own search/sort state and fetches directly via
/// `FriendsService.getSharedLibraryGames`, which already backs the Game
/// Chooser's friend-library toggle (§4.10.1). It does watch
/// `libraryProvider`/`wishlistProvider` read-only, to know which of the
/// friend's games are already in the current user's own collection (Phase 2:
/// the "Add to Wishlist" duplicate guard).
class FriendLibraryScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendUsername;

  const FriendLibraryScreen({
    super.key,
    required this.friendId,
    required this.friendUsername,
  });

  @override
  ConsumerState<FriendLibraryScreen> createState() =>
      _FriendLibraryScreenState();
}

class _FriendLibraryScreenState extends ConsumerState<FriendLibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  LibrarySort _sort = LibrarySort.nameAsc;
  GameCardLayout _layout = GameCardLayout.list;

  late Future<List<LibraryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = FriendsService.getSharedLibraryGames(widget.friendId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    final next = FriendsService.getSharedLibraryGames(widget.friendId);
    setState(() => _future = next);
    return next;
  }

  List<LibraryEntry> _visible(List<LibraryEntry> entries) {
    var result = entries;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((e) =>
              e.game.name.toLowerCase().contains(q) ||
              (e.game.publisher?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    // Facet filters are out of scope for v1 (PRD §13.1) — this is sort-only.
    return LibraryFilter(sort: _sort).apply(result);
  }

  Future<void> _pickSort() async {
    final choice = await showSortBottomSheet<LibrarySort>(
      context: context,
      current: _sort,
      options: [for (final s in LibrarySort.values) SortOption(s, s.label)],
    );
    if (choice != null) setState(() => _sort = choice);
  }

  WishlistStatus _wishlistStatus(String gameId, Set<String> libraryGameIds,
      Set<String> wishlistGameIds) {
    if (libraryGameIds.contains(gameId)) return WishlistStatus.inLibrary;
    if (wishlistGameIds.contains(gameId)) return WishlistStatus.inWishlist;
    return WishlistStatus.addable;
  }

  Future<void> _addToWishlist(LibraryEntry entry) async {
    final added = await showAddToWishlistSheet(
      context,
      game: entry.game,
      prefilledNotes: "Seen in ${widget.friendUsername}'s library",
    );
    if (added != true || !mounted) return;
    // Tell the Wishlist tab what to scroll to, then pop back to My Games —
    // it picks up the tab switch via the same provider (library_screen.dart).
    ref.read(pendingWishlistHighlightProvider.notifier).set(entry.gameId);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final libraryGameIds = (ref.watch(libraryProvider).asData?.value ?? [])
        .map((e) => e.gameId)
        .toSet();
    final wishlistGameIds = (ref.watch(wishlistProvider).asData?.value ?? [])
        .map((e) => e.gameId)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        // Explicit rather than relying on GoRouter/Navigator to infer a back
        // affordance from canPop() — this screen is always reached by
        // pushing from the friends list, so popping back there should never
        // be ambiguous.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Back to friend's games",
          onPressed: () => context.pop(),
        ),
        title: Text("${widget.friendUsername}'s Library"),
        actions: [
          IconButton(
            icon: Icon(
              _layout == GameCardLayout.grid
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              color: AppColors.ink400,
            ),
            onPressed: () => setState(() => _layout =
                _layout == GameCardLayout.grid
                    ? GameCardLayout.list
                    : GameCardLayout.grid),
          ),
        ],
      ),
      body: Column(
        children: [
          // Identifies whose (read-only) library this is — distinct from
          // "My Library", which uses the same GameCard styling.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.plum50,
              border: Border.all(color: AppColors.plum200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 16, color: AppColors.plum400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Viewing ${widget.friendUsername}'s library (read-only)",
                    style:
                        GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink500),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: Text('Back',
                      style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.plum400,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style:
                        GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink500),
                    decoration: InputDecoration(
                      hintText: 'Search games…',
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.ink200),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort, color: AppColors.ink400),
                  onPressed: _pickSort,
                  tooltip: 'Sort',
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LibraryEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.clay400, size: 40),
                        const SizedBox(height: 12),
                        Text('Failed to load library',
                            style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.ink400)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  );
                }

                final all = snapshot.data ?? const [];
                final items = _visible(all);

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.collections_bookmark_outlined,
                            size: 48, color: AppColors.ink100),
                        const SizedBox(height: 16),
                        Text(
                          all.isEmpty
                              ? "${widget.friendUsername}'s library is empty"
                              : 'No results',
                          style: GoogleFonts.literata(
                              fontSize: 22, color: AppColors.ink300),
                        ),
                      ],
                    ),
                  );
                }

                if (_layout == GameCardLayout.list) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => GameCard(
                        key: ValueKey(items[i].id),
                        entry: items[i],
                        layout: _layout,
                        wishlistStatus: _wishlistStatus(items[i].gameId,
                            libraryGameIds, wishlistGameIds),
                        onAddToWishlist: () => _addToWishlist(items[i]),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.55,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => GameCard(
                      key: ValueKey(items[i].id),
                      entry: items[i],
                      layout: _layout,
                      wishlistStatus: _wishlistStatus(
                          items[i].gameId, libraryGameIds, wishlistGameIds),
                      onAddToWishlist: () => _addToWishlist(items[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
