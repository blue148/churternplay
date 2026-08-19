import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/library_entry.dart';

enum GameCardLayout { grid, list }

/// Where a game (as seen on someone *else's* library/shared view) stands
/// relative to the current user's own collection — drives whether "Add to
/// Wishlist" is offered, and what it's replaced with when it can't be.
enum WishlistStatus { addable, inWishlist, inLibrary }

class GameCard extends StatelessWidget {
  final LibraryEntry entry;
  final GameCardLayout layout;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onLogPlay;
  final VoidCallback? onToggleForSale;
  final VoidCallback? onAddToWishlist;
  final WishlistStatus? wishlistStatus;

  const GameCard({
    super.key,
    required this.entry,
    this.layout = GameCardLayout.grid,
    this.onFavorite,
    this.onDelete,
    this.onTap,
    this.onEdit,
    this.onLogPlay,
    this.onToggleForSale,
    this.onAddToWishlist,
    this.wishlistStatus,
  });

  @override
  Widget build(BuildContext context) {
    return layout == GameCardLayout.list
        ? _ListCard(
            entry: entry,
            onFavorite: onFavorite,
            onDelete: onDelete,
            onTap: onTap,
            onEdit: onEdit,
            onLogPlay: onLogPlay,
            onToggleForSale: onToggleForSale,
            onAddToWishlist: onAddToWishlist,
            wishlistStatus: wishlistStatus)
        : _GridCard(
            entry: entry,
            onFavorite: onFavorite,
            onDelete: onDelete,
            onTap: onTap,
            onEdit: onEdit,
            onLogPlay: onLogPlay,
            onToggleForSale: onToggleForSale,
            onAddToWishlist: onAddToWishlist,
            wishlistStatus: wishlistStatus);
  }
}

// ── Grid card ────────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onLogPlay;
  final VoidCallback? onToggleForSale;
  final VoidCallback? onAddToWishlist;
  final WishlistStatus? wishlistStatus;

  const _GridCard({
    required this.entry,
    this.onFavorite,
    this.onDelete,
    this.onTap,
    this.onEdit,
    this.onLogPlay,
    this.onToggleForSale,
    this.onAddToWishlist,
    this.wishlistStatus,
  });

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.parchment200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image — fills available height, info row takes what it needs
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CoverImage(url: game.coverImage, name: game.name),
                    // Favorite star — top left
                    if (entry.isFavorite)
                      const Positioned(
                        top: 6,
                        left: 6,
                        child: Icon(Icons.star,
                            size: 14, color: AppColors.wheat400),
                      ),
                    // For sale badge — top right
                    if (entry.forSale)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          color: AppColors.forest600,
                          child: Text(
                            'SALE',
                            style: GoogleFonts.atkinsonHyperlegibleNext(
                                fontSize: 8,
                                color: Colors.white,
                                letterSpacing: 1),
                          ),
                        ),
                      ),
                    // Play count — bottom right
                    if (entry.playCount > 0)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.playCount}×',
                            style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Info row
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (game.playerCountLabel.isNotEmpty) ...[
                                const Icon(Icons.people_outline,
                                    size: 10, color: AppColors.ink200),
                                const SizedBox(width: 2),
                                Text(game.playerCountLabel,
                                    style: GoogleFonts.atkinsonHyperlegibleNext(
                                        fontSize: 9, color: AppColors.ink200)),
                                const SizedBox(width: 6),
                              ],
                              if (game.playtimeMinutes != null) ...[
                                const Icon(Icons.timer_outlined,
                                    size: 10, color: AppColors.ink200),
                                const SizedBox(width: 2),
                                Text('${game.playtimeMinutes}m',
                                    style: GoogleFonts.atkinsonHyperlegibleNext(
                                        fontSize: 9, color: AppColors.ink200)),
                              ],
                              if (entry.hasVictoryStats)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.emoji_events_outlined,
                                      size: 10, color: AppColors.wheat400),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _MenuButton(
                        entry: entry,
                        onFavorite: onFavorite,
                        onDelete: onDelete,
                        onEdit: onEdit,
                        onLogPlay: onLogPlay,
                        onToggleForSale: onToggleForSale,
                        onAddToWishlist: onAddToWishlist,
                        wishlistStatus: wishlistStatus),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── List card ─────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onLogPlay;
  final VoidCallback? onToggleForSale;
  final VoidCallback? onAddToWishlist;
  final WishlistStatus? wishlistStatus;

  const _ListCard({
    required this.entry,
    this.onFavorite,
    this.onDelete,
    this.onTap,
    this.onEdit,
    this.onLogPlay,
    this.onToggleForSale,
    this.onAddToWishlist,
    this.wishlistStatus,
  });

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.parchment200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Thumbnail
              SizedBox(
                width: 72,
                height: 72,
                child: _CoverImage(url: game.coverImage, name: game.name),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              game.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink600,
                              ),
                            ),
                          ),
                          if (game.isExpansion)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: AppColors.parchment300),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text('EXP',
                                  style: GoogleFonts.atkinsonHyperlegibleNext(
                                      fontSize: 9, color: AppColors.ink300)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (game.playerCountLabel.isNotEmpty) ...[
                            const Icon(Icons.people_outline,
                                size: 12, color: AppColors.ink200),
                            const SizedBox(width: 3),
                            Text(game.playerCountLabel,
                                style: GoogleFonts.atkinsonHyperlegibleNext(
                                    fontSize: 11, color: AppColors.ink300)),
                            const SizedBox(width: 10),
                          ],
                          if (game.playtimeMinutes != null) ...[
                            const Icon(Icons.timer_outlined,
                                size: 12, color: AppColors.ink200),
                            const SizedBox(width: 3),
                            Text('${game.playtimeMinutes} min',
                                style: GoogleFonts.atkinsonHyperlegibleNext(
                                    fontSize: 11, color: AppColors.ink300)),
                          ],
                        ],
                      ),
                      if (entry.hasVictoryStats) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_outlined,
                                size: 12, color: AppColors.wheat400),
                            const SizedBox(width: 3),
                            Text(
                              '${entry.victoryStats!.winRate.toStringAsFixed(0)}% win rate',
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 11, color: AppColors.wheat500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // A disabled (onFavorite: null) star button would still
                  // render greyed-out but tappable-looking — a dead control
                  // on read-only views (e.g. a friend's library). Fall back
                  // to a plain, non-interactive badge instead, matching how
                  // the grid card already surfaces favorite status.
                  if (onFavorite != null)
                    IconButton(
                      icon: Icon(
                        entry.isFavorite ? Icons.star : Icons.star_border,
                        size: 18,
                        color: entry.isFavorite
                            ? AppColors.wheat400
                            : AppColors.ink200,
                      ),
                      onPressed: onFavorite,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    )
                  else if (entry.isFavorite)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.star,
                          size: 18, color: AppColors.wheat400),
                    ),
                  _MenuButton(
                    entry: entry,
                    onFavorite: onFavorite,
                    onDelete: onDelete,
                    onEdit: onEdit,
                    onLogPlay: onLogPlay,
                    onToggleForSale: onToggleForSale,
                    onAddToWishlist: onAddToWishlist,
                    wishlistStatus: wishlistStatus,
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  final String? url;
  final String name;

  const _CoverImage({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        color: AppColors.parchment100,
        child: const Center(
          child:
              Icon(Icons.menu_book_outlined, size: 28, color: AppColors.ink100),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.parchment100),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.parchment100,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.ink100),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onLogPlay;
  final VoidCallback? onToggleForSale;
  final VoidCallback? onAddToWishlist;
  final WishlistStatus? wishlistStatus;

  const _MenuButton({
    required this.entry,
    this.onFavorite,
    this.onDelete,
    this.onEdit,
    this.onLogPlay,
    this.onToggleForSale,
    this.onAddToWishlist,
    this.wishlistStatus,
  });

  @override
  Widget build(BuildContext context) {
    // No visible actions means no menu button at all — a button that opens
    // an empty menu is a dead control (App Store Guideline 2.1).
    final hasAnyAction = onFavorite != null ||
        onDelete != null ||
        onEdit != null ||
        onLogPlay != null ||
        onToggleForSale != null ||
        wishlistStatus != null;
    if (!hasAnyAction) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.ink200),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        if (wishlistStatus != null)
          PopupMenuItem(
            value: 'wishlist',
            // Visible-but-disabled rather than hidden when it's already on
            // the wishlist/in the library — makes the state legible instead
            // of letting a second insert fail on the unique constraint.
            enabled: wishlistStatus == WishlistStatus.addable,
            child: _menuItem(
              switch (wishlistStatus!) {
                WishlistStatus.addable => Icons.playlist_add,
                WishlistStatus.inWishlist => Icons.playlist_add_check,
                WishlistStatus.inLibrary => Icons.collections_bookmark,
              },
              switch (wishlistStatus!) {
                WishlistStatus.addable => 'Add to Wishlist',
                WishlistStatus.inWishlist => 'Already on Your Wishlist',
                WishlistStatus.inLibrary => 'Already in Your Library',
              },
              color: wishlistStatus == WishlistStatus.addable
                  ? null
                  : AppColors.ink300,
            ),
          ),
        if (onEdit != null)
          PopupMenuItem(
              value: 'edit', child: _menuItem(Icons.edit_outlined, 'Edit')),
        if (onFavorite != null)
          PopupMenuItem(
            value: 'favorite',
            child: _menuItem(
              entry.isFavorite ? Icons.star : Icons.star_border,
              entry.isFavorite ? 'Unstar' : 'Star',
            ),
          ),
        if (onLogPlay != null)
          PopupMenuItem(
            value: 'log',
            child: _menuItem(
                Icons.add_circle_outline, 'Log Play (${entry.playCount})'),
          ),
        if (onToggleForSale != null)
          PopupMenuItem(
            value: 'sale',
            child: _menuItem(
              Icons.sell_outlined,
              entry.forSale ? 'Remove Sale' : 'For Sale',
            ),
          ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: _menuItem(Icons.delete_outline, 'Remove',
                color: AppColors.clay500),
          ),
        ],
      ],
      onSelected: (action) {
        switch (action) {
          case 'edit':
            onEdit?.call();
          case 'favorite':
            onFavorite?.call();
          case 'log':
            onLogPlay?.call();
          case 'sale':
            onToggleForSale?.call();
          case 'delete':
            onDelete?.call();
          case 'wishlist':
            onAddToWishlist?.call();
        }
      },
    );
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) => Row(
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.ink400),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 13, color: color ?? AppColors.ink500),
          ),
        ],
      );
}
