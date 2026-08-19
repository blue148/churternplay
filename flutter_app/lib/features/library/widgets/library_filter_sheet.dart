import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/library_entry.dart';
import '../../../data/models/library_filter.dart';
import '../../../providers/library_provider.dart';
import 'filter_chip_group.dart';

/// Opens the full faceted filter sheet for the catalogue. Edits are made on a
/// local draft and only committed to [libraryFilterProvider] when the user taps
/// "Show N games" (batched apply).
Future<void> showLibraryFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LibraryFilterSheet(),
  );
}

class _LibraryFilterSheet extends ConsumerStatefulWidget {
  const _LibraryFilterSheet();

  @override
  ConsumerState<_LibraryFilterSheet> createState() =>
      _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends ConsumerState<_LibraryFilterSheet> {
  late LibraryFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(libraryFilterProvider);
  }

  void _update(LibraryFilter next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final facets = ref.watch(availableFacetsProvider);
    final entries = ref.watch(libraryProvider).asData?.value ?? const [];
    final query = ref.watch(librarySearchProvider);
    final matchCount = countMatching(entries, _draft, query);
    final maxPlays = _maxPlayCount(entries);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.parchment50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _playerCounts(),
                    if (maxPlays > 0) ...[
                      const SizedBox(height: 20),
                      _plays(maxPlays),
                    ],
                    _section(FilterChipGroup(
                      title: 'Ranking',
                      options: const ['high', 'medium', 'low'],
                      selected: _draft.rankings,
                      capitalize: true,
                      onToggle: (v) =>
                          _update(_draft.toggleString(_draft.rankings, v)),
                    )),
                    _section(FilterChipGroup(
                      title: 'Publisher',
                      options: facets.publishers,
                      selected: _draft.publishers,
                      onToggle: (v) =>
                          _update(_draft.toggleString(_draft.publishers, v)),
                    )),
                    _section(FilterChipGroup(
                      title: 'Game Type',
                      options: facets.gameTypes,
                      selected: _draft.gameTypes,
                      onToggle: (v) =>
                          _update(_draft.toggleString(_draft.gameTypes, v)),
                    )),
                    _section(FilterChipGroup(
                      title: 'Category',
                      options: facets.categories,
                      selected: _draft.categories,
                      onToggle: (v) =>
                          _update(_draft.toggleString(_draft.categories, v)),
                    )),
                    _section(FilterChipGroup(
                      title: 'Year',
                      options: facets.years,
                      selected: _draft.years,
                      onToggle: (v) =>
                          _update(_draft.toggleString(_draft.years, v)),
                    )),
                  ],
                ),
              ),
              _footer(matchCount),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink100,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Filters',
                  style: GoogleFonts.literata(
                      fontSize: 24, color: AppColors.ink500)),
              const Spacer(),
              if (_draft.hasActiveFilters)
                TextButton(
                  onPressed: () => _update(_draft.cleared()),
                  child: Text('Clear all',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 13, color: AppColors.clay400)),
                ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.ink300),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.parchment200),
        ],
      ),
    );
  }

  Widget _section(Widget child) {
    if (child is FilterChipGroup && child.options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: child,
    );
  }

  Widget _playerCounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NUMBER OF PLAYERS',
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.ink300)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final count in [1, 2, 3, 4, 5, 6])
              FilterChip(
                label: Text(
                  count == 6 ? '6+' : '$count',
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 12,
                    color: _draft.playerCounts.contains(count)
                        ? Colors.white
                        : AppColors.ink400,
                  ),
                ),
                selected: _draft.playerCounts.contains(count),
                onSelected: (_) => _update(_draft.togglePlayerCount(count)),
                selectedColor: AppColors.clay400,
                backgroundColor: Colors.white,
                showCheckmark: false,
                side: BorderSide(
                  color: _draft.playerCounts.contains(count)
                      ? AppColors.clay400
                      : AppColors.parchment200,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }

  Widget _plays(int maxPlays) {
    final start = _draft.minPlays.toDouble();
    final end = (_draft.maxPlays ?? maxPlays).toDouble().clamp(0, maxPlays);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('NUMBER OF PLAYS',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.ink300)),
            const Spacer(),
            Text(
              _draft.minPlays == 0 && _draft.maxPlays == null
                  ? 'Any'
                  : '${_draft.minPlays} – ${_draft.maxPlays ?? '$maxPlays+'}',
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink400),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(start, end.toDouble()),
          min: 0,
          max: maxPlays.toDouble(),
          divisions: maxPlays,
          activeColor: AppColors.clay400,
          inactiveColor: AppColors.parchment200,
          labels: RangeLabels('${start.round()}', '${end.round()}'),
          onChanged: (values) {
            final lo = values.start.round();
            final hi = values.end.round();
            _update(_draft.copyWith(
              minPlays: lo,
              // Treat the top of the range as "no upper limit".
              maxPlays: hi >= maxPlays ? null : hi,
            ));
          },
        ),
      ],
    );
  }

  Widget _footer(int matchCount) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.parchment50,
          border: Border(
            top: BorderSide(color: AppColors.parchment200),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              ref.read(libraryFilterProvider.notifier).set(_draft);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.clay400,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              matchCount == 1 ? 'Show 1 game' : 'Show $matchCount games',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  int _maxPlayCount(List<LibraryEntry> entries) {
    var max = 0;
    for (final e in entries) {
      if (e.playCount > max) max = e.playCount;
    }
    return max;
  }
}
