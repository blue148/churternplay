import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/models/library_entry.dart';
import '../../data/models/victory_stats.dart';
import '../../providers/library_provider.dart';
import 'widgets/log_play_sheet.dart';
import 'widgets/suggest_to_friend_sheet.dart';

/// Full-screen detail view for a single library entry, reachable from any
/// tab (dashboard tiles, library cards). Reads the live entry out of
/// [libraryProvider] so favorite/play-count changes reflect immediately,
/// falling back to [initialEntry] (passed via route `extra`) until the
/// library has loaded.
class GameDetailScreen extends ConsumerWidget {
  final String entryId;
  final LibraryEntry? initialEntry;

  const GameDetailScreen({super.key, required this.entryId, this.initialEntry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(libraryProvider).asData?.value ?? const [];
    LibraryEntry? entry;
    for (final e in entries) {
      if (e.id == entryId) {
        entry = e;
        break;
      }
    }
    entry ??= initialEntry;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('Game not found',
              style: GoogleFonts.literata(
                  fontSize: 22, color: AppColors.ink300)),
        ),
      );
    }

    final liveEntry = entry;
    final game = liveEntry.game;

    return Scaffold(
      backgroundColor: AppColors.parchment50,
      appBar: AppBar(
        title: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              liveEntry.isFavorite ? Icons.star : Icons.star_border,
              color:
                  liveEntry.isFavorite ? AppColors.wheat400 : AppColors.ink400,
            ),
            onPressed: () => ref
                .read(libraryProvider.notifier)
                .toggleFavorite(liveEntry.id, !liveEntry.isFavorite),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.ink400),
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'suggest', child: Text('Suggest to a Friend')),
              PopupMenuItem(
                value: 'sale',
                child: Text(
                    liveEntry.forSale ? 'Remove from sale' : 'Mark for sale'),
              ),
              const PopupMenuItem(
                  value: 'delete', child: Text('Remove from library')),
            ],
            onSelected: (action) {
              switch (action) {
                case 'suggest':
                  showSuggestToFriendSheet(context, game: game);
                case 'sale':
                  ref
                      .read(libraryProvider.notifier)
                      .toggleForSale(liveEntry.id, !liveEntry.forSale);
                case 'delete':
                  _confirmDelete(context, ref, liveEntry);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _CoverHeader(entry: liveEntry),
          const SizedBox(height: 20),
          _TitleBlock(entry: liveEntry),
          const SizedBox(height: 16),
          _StatsRow(entry: liveEntry),
          if (liveEntry.hasVictoryStats) ...[
            const SizedBox(height: 24),
            _VictorySection(stats: liveEntry.victoryStats!),
          ],
          if (game.gameType.isNotEmpty ||
              game.gameCategory.isNotEmpty ||
              game.gameMechanic.isNotEmpty ||
              game.gameFamily.isNotEmpty) ...[
            const SizedBox(height: 24),
            _TagsSection(game: game),
          ],
          if (liveEntry.notes != null && liveEntry.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _NotesSection(notes: liveEntry.notes!),
          ],
          if (liveEntry.playedDates.isNotEmpty) ...[
            const SizedBox(height: 24),
            _PlayHistorySection(dates: liveEntry.playedDates),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showLogPlaySheet(context, liveEntry),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clay400,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                'Log Play',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LibraryEntry entry) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove game?',
            style: GoogleFonts.literata(fontSize: 22)),
        content: Text(
          'Remove "${entry.game.name}" from your library?',
          style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(libraryProvider.notifier).removeGame(entry.id);
              context.pop();
            },
            child: Text('Remove',
                style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.clay500)),
          ),
        ],
      ),
    );
  }
}

// ── Cover header ─────────────────────────────────────────────────────────────

class _CoverHeader extends StatelessWidget {
  final LibraryEntry entry;
  const _CoverHeader({required this.entry});

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            game.coverImage != null
                ? CachedNetworkImage(
                    imageUrl: game.coverImage!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.parchment100),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.parchment100,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.ink100, size: 40),
                    ),
                  )
                : Container(
                    color: AppColors.parchment100,
                    child: const Icon(Icons.menu_book_outlined,
                        size: 48, color: AppColors.ink100),
                  ),
            if (entry.forSale)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: AppColors.forest600,
                  child: Text('FOR SALE',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 10, color: Colors.white, letterSpacing: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Title block ───────────────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  final LibraryEntry entry;
  const _TitleBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    final subtitleParts = [
      if (game.publisher != null && game.publisher!.isNotEmpty) game.publisher!,
      if (game.year != null && game.year!.isNotEmpty) game.year!,
      if (game.edition != null && game.edition!.isNotEmpty) game.edition!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                game.name,
                style: GoogleFonts.literata(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink600),
              ),
            ),
            if (game.isExpansion)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.parchment300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('EXPANSION',
                    style:
                        GoogleFonts.atkinsonHyperlegibleNext(fontSize: 9, color: AppColors.ink300)),
              ),
          ],
        ),
        if (subtitleParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitleParts.join(' · '),
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink300),
          ),
        ],
      ],
    );
  }
}

// ── Quick stats row ──────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final LibraryEntry entry;
  const _StatsRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    final items = <(IconData, String)>[
      if (game.playerCountLabel.isNotEmpty)
        (Icons.people_outline, game.playerCountLabel),
      if (game.playtimeMinutes != null)
        (Icons.timer_outlined, '${game.playtimeMinutes} min'),
      (
        Icons.replay,
        '${entry.playCount} play${entry.playCount == 1 ? '' : 's'}'
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final (icon, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.ink300),
              const SizedBox(width: 5),
              Text(label,
                  style:
                      GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink400)),
            ],
          ),
      ],
    );
  }
}

// ── Victory stats ─────────────────────────────────────────────────────────────

class _VictorySection extends StatelessWidget {
  final VictoryStats stats;
  const _VictorySection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final lastPlayed = stats.lastPlayed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Victory Stats'),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatTile(
                value: '${stats.winRate.toStringAsFixed(0)}%',
                label: 'WIN RATE'),
            const SizedBox(width: 10),
            _StatTile(value: '${stats.totalWins}', label: 'WINS'),
            const SizedBox(width: 10),
            _StatTile(
                value: stats.bestScore != null ? '${stats.bestScore}' : '—',
                label: 'BEST SCORE'),
          ],
        ),
        if (lastPlayed != null) ...[
          const SizedBox(height: 10),
          Text(
            'Last played ${DateFormat('MMM d, yyyy').format(lastPlayed)}',
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink300),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.parchment200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.literata(
                    fontSize: 24, color: AppColors.ink600)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 9, letterSpacing: 1.0, color: AppColors.ink300)),
          ],
        ),
      ),
    );
  }
}

// ── Tags ──────────────────────────────────────────────────────────────────────

class _TagsSection extends StatelessWidget {
  final Game game;
  const _TagsSection({required this.game});

  @override
  Widget build(BuildContext context) {
    final tags = [
      ...game.gameType,
      ...game.gameCategory,
      ...game.gameMechanic,
      ...game.gameFamily,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Details'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.parchment200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tag,
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 11, color: AppColors.ink400)),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Notes ─────────────────────────────────────────────────────────────────────

class _NotesSection extends StatelessWidget {
  final String notes;
  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Notes'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.parchment200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(notes,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 13, color: AppColors.ink500, height: 1.4)),
        ),
      ],
    );
  }
}

// ── Play history ──────────────────────────────────────────────────────────────

class _PlayHistorySection extends StatelessWidget {
  final List<DateTime> dates;
  const _PlayHistorySection({required this.dates});

  @override
  Widget build(BuildContext context) {
    final sorted = [...dates]..sort((a, b) => b.compareTo(a));
    final recent = sorted.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Play History (${dates.length})'),
        const SizedBox(height: 10),
        ...recent.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.clay400),
                  const SizedBox(width: 10),
                  Text(DateFormat('EEEE, MMM d, yyyy').format(d),
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 13, color: AppColors.ink400)),
                ],
              ),
            )),
        if (sorted.length > recent.length)
          Text('+ ${sorted.length - recent.length} more',
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink200)),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.atkinsonHyperlegibleNext(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.ink300),
      );
}
