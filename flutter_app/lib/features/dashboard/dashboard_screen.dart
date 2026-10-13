import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/library_entry.dart';
import '../../providers/library_provider.dart';
import '../library/widgets/add_game_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load data')),
        data: (entries) => RefreshIndicator(
          onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _QuickActions(context),
              const SizedBox(height: 24),
              _MostPlayed(entries: entries),
              const SizedBox(height: 24),
              _CollectionStats(entries: entries),
              const SizedBox(height: 24),
              _RecentlyAdded(entries: entries),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.literata(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: AppColors.ink400,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Divider(
                color: AppColors.parchment300,
                thickness: 1,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

// ── Quick Actions ──────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final BuildContext ctx;
  const _QuickActions(this.ctx);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Quick Actions'),
        Row(
          children: [
            _ActionCard(
              icon: Icons.shuffle,
              label: 'Game Picker',
              onTap: () => context.go('/game-nite/chooser'),
            ),
            const SizedBox(width: 6),
            _ActionCard(
              icon: Icons.people_outline,
              label: 'First Player',
              onTap: () => context.go('/game-nite/first-player'),
            ),
            const SizedBox(width: 6),
            _ActionCard(
              icon: Icons.timer_outlined,
              label: 'Turn Timer',
              onTap: () => context.go('/game-nite/turn-timer'),
            ),
            const SizedBox(width: 6),
            _ActionCard(
              icon: Icons.add_circle_outline,
              label: 'Add Game',
              onTap: () => showAddGameSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.parchment100,
            border: Border.all(color: AppColors.parchment300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.clay400, size: 18),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink400,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Most Played ────────────────────────────────────────────────────────────────

class _MostPlayed extends StatelessWidget {
  final List<LibraryEntry> entries;
  const _MostPlayed({required this.entries});

  @override
  Widget build(BuildContext context) {
    final played = entries.where((e) => e.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    if (played.isEmpty) return const SizedBox.shrink();

    final top = played.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Most Played'),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final entry = top[i];
              return GestureDetector(
                onTap: () => context.push('/game/${entry.id}', extra: entry),
                child: SizedBox(
                  width: 76,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: entry.game.coverImage != null
                            ? CachedNetworkImage(
                                imageUrl: entry.game.coverImage!,
                                width: 76,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 76,
                                height: 100,
                                color: AppColors.parchment100,
                                child: const Icon(Icons.menu_book_outlined,
                                    color: AppColors.ink100),
                              ),
                      ),
                      Positioned(
                        bottom: 14,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.clay400,
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
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Text(
                          entry.game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 9, color: AppColors.ink400),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Collection Stats ───────────────────────────────────────────────────────────

class _CollectionStats extends StatelessWidget {
  final List<LibraryEntry> entries;
  const _CollectionStats({required this.entries});

  @override
  Widget build(BuildContext context) {
    final games = entries.length;
    final starred = entries.where((e) => e.isFavorite).length;
    final played = entries.where((e) => e.playCount > 0).length;
    final unplayed = games - played;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Your Collection'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _StatTile(value: '$games', label: 'GAMES'),
            _StatTile(value: '$starred', label: 'STARRED'),
            _StatTile(value: '$played', label: 'PLAYED'),
            _StatTile(value: '$unplayed', label: 'UNPLAYED'),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.parchment200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.literata(
              fontSize: 32,
              color: AppColors.ink600,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.atkinsonHyperlegibleNext(
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppColors.ink300,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recently Added ─────────────────────────────────────────────────────────────

class _RecentlyAdded extends StatelessWidget {
  final List<LibraryEntry> entries;
  const _RecentlyAdded({required this.entries});

  @override
  Widget build(BuildContext context) {
    final recent = entries.take(8).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Recently Added'),
        ...recent.map((e) => _RecentRow(entry: e)),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final LibraryEntry entry;
  const _RecentRow({required this.entry});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return '$y year${y == 1 ? '' : 's'} ago';
    } else if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return '$m month${m == 1 ? '' : 's'} ago';
    } else if (diff.inDays >= 7) {
      final w = (diff.inDays / 7).floor();
      return '$w week${w == 1 ? '' : 's'} ago';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return 'Today';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => context.push('/game/${entry.id}', extra: entry),
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.parchment200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(4)),
                child: entry.game.coverImage != null
                    ? CachedNetworkImage(
                        imageUrl: entry.game.coverImage!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: AppColors.parchment100,
                        child: const Icon(Icons.menu_book_outlined,
                            size: 20, color: AppColors.ink100),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink600),
                    ),
                    Text(
                      _timeAgo(entry.addedDate),
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 12, color: AppColors.ink200),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.ink100, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
