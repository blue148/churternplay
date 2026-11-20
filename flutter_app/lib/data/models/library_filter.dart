import 'library_entry.dart';

/// Sort options for a library/collection list. Mirrors the web app's
/// `SortOption` union in `src/components/Library.tsx`.
enum LibrarySort {
  nameAsc,
  nameDesc,
  dateAddedDesc,
  dateAddedAsc,
  playsDesc,
  playsAsc,
  designerAsc,
  designerDesc,
  publisherAsc,
  publisherDesc,
  heartsDesc,
  punchDesc;

  /// Section heading used by the sort sheet.
  String get group {
    switch (this) {
      case LibrarySort.nameAsc:
      case LibrarySort.nameDesc:
        return 'Name';
      case LibrarySort.dateAddedDesc:
      case LibrarySort.dateAddedAsc:
        return 'Date';
      case LibrarySort.playsDesc:
      case LibrarySort.playsAsc:
        return 'Plays';
      case LibrarySort.designerAsc:
      case LibrarySort.designerDesc:
      case LibrarySort.publisherAsc:
      case LibrarySort.publisherDesc:
        return 'Creator';
      case LibrarySort.heartsDesc:
      case LibrarySort.punchDesc:
        return 'Rating';
    }
  }

  String get label {
    switch (this) {
      case LibrarySort.nameAsc:
        return 'Name (A–Z)';
      case LibrarySort.nameDesc:
        return 'Name (Z–A)';
      case LibrarySort.dateAddedDesc:
        return 'Recently Added';
      case LibrarySort.dateAddedAsc:
        return 'Oldest First';
      case LibrarySort.playsDesc:
        return 'Most Played';
      case LibrarySort.playsAsc:
        return 'Least Played';
      case LibrarySort.designerAsc:
        return 'Designer (A–Z)';
      case LibrarySort.designerDesc:
        return 'Designer (Z–A)';
      case LibrarySort.publisherAsc:
        return 'Publisher (A–Z)';
      case LibrarySort.publisherDesc:
        return 'Publisher (Z–A)';
      case LibrarySort.heartsDesc:
        return 'Most Liked (hearts)';
      case LibrarySort.punchDesc:
        return 'Most Punch-worthy (fists)';
    }
  }
}

/// The multi-select text facets of a [LibraryFilter].
enum StringFacet { publishers, designers, gameTypes, categories, years, rankings }

/// Immutable description of the active filters + sort for the library list.
///
/// Ports the filter state from the web `Library.tsx` component. Multi-select
/// facets are kept as ordered [Set]s; play-count bounds are inclusive, with a
/// null [maxPlays] meaning "no upper limit".
/// Case-insensitive text compare where empty/null values always sort last,
/// in both ascending and [descending] order.
int compareOptionalText(String? a, String? b, {bool descending = false}) {
  final aEmpty = a == null || a.trim().isEmpty;
  final bEmpty = b == null || b.trim().isEmpty;
  if (aEmpty && bEmpty) return 0;
  if (aEmpty) return 1;
  if (bEmpty) return -1;
  final c = a.toLowerCase().compareTo(b.toLowerCase());
  return descending ? -c : c;
}

class LibraryFilter {
  final Set<String> publishers;
  final Set<String> designers;
  final Set<String> gameTypes;
  final Set<String> categories;
  final Set<String> years;
  final Set<String> rankings; // legacy 'high' | 'medium' | 'low'
  final Set<int> playerCounts; // 1..6, where 6 means "6+"
  final int minHearts; // 0 = any
  final int minPunch; // 0 = any
  final int minPlays;
  final int? maxPlays;
  final bool favoritesOnly;
  final bool forSaleOnly;
  final LibrarySort sort;

  const LibraryFilter({
    this.publishers = const {},
    this.designers = const {},
    this.gameTypes = const {},
    this.categories = const {},
    this.years = const {},
    this.rankings = const {},
    this.playerCounts = const {},
    this.minHearts = 0,
    this.minPunch = 0,
    this.minPlays = 0,
    this.maxPlays,
    this.favoritesOnly = false,
    this.forSaleOnly = false,
    this.sort = LibrarySort.nameAsc,
  });

  /// Number of active *filter* constraints (excludes sort). Drives the badge
  /// on the Filter button.
  int get activeCount {
    var count = 0;
    count += publishers.length;
    count += designers.length;
    count += gameTypes.length;
    count += categories.length;
    count += years.length;
    count += rankings.length;
    count += playerCounts.length;
    if (minHearts > 0) count++;
    if (minPunch > 0) count++;
    if (minPlays > 0) count++;
    if (maxPlays != null) count++;
    if (favoritesOnly) count++;
    if (forSaleOnly) count++;
    return count;
  }

  bool get hasActiveFilters => activeCount > 0;

  LibraryFilter copyWith({
    Set<String>? publishers,
    Set<String>? designers,
    Set<String>? gameTypes,
    Set<String>? categories,
    Set<String>? years,
    Set<String>? rankings,
    Set<int>? playerCounts,
    int? minHearts,
    int? minPunch,
    int? minPlays,
    Object? maxPlays = _sentinel,
    bool? favoritesOnly,
    bool? forSaleOnly,
    LibrarySort? sort,
  }) {
    return LibraryFilter(
      publishers: publishers ?? this.publishers,
      designers: designers ?? this.designers,
      gameTypes: gameTypes ?? this.gameTypes,
      categories: categories ?? this.categories,
      years: years ?? this.years,
      rankings: rankings ?? this.rankings,
      playerCounts: playerCounts ?? this.playerCounts,
      minHearts: minHearts ?? this.minHearts,
      minPunch: minPunch ?? this.minPunch,
      minPlays: minPlays ?? this.minPlays,
      maxPlays:
          maxPlays == _sentinel ? this.maxPlays : maxPlays as int?,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      forSaleOnly: forSaleOnly ?? this.forSaleOnly,
      sort: sort ?? this.sort,
    );
  }

  /// Clears every filter facet but preserves the chosen [sort].
  LibraryFilter cleared() => LibraryFilter(sort: sort);

  /// Toggles a value within one of the [String] multi-select facets.
  LibraryFilter toggleFacet(StringFacet facet, String value) {
    Set<String> toggled(Set<String> current) {
      final next = Set<String>.from(current);
      next.contains(value) ? next.remove(value) : next.add(value);
      return next;
    }

    switch (facet) {
      case StringFacet.publishers:
        return copyWith(publishers: toggled(publishers));
      case StringFacet.designers:
        return copyWith(designers: toggled(designers));
      case StringFacet.gameTypes:
        return copyWith(gameTypes: toggled(gameTypes));
      case StringFacet.categories:
        return copyWith(categories: toggled(categories));
      case StringFacet.years:
        return copyWith(years: toggled(years));
      case StringFacet.rankings:
        return copyWith(rankings: toggled(rankings));
    }
  }

  LibraryFilter togglePlayerCount(int count) {
    final next = Set<int>.from(playerCounts);
    next.contains(count) ? next.remove(count) : next.add(count);
    return copyWith(playerCounts: next);
  }

  /// Applies all active filters then sorts. Mirrors the filtering `useEffect`
  /// in `Library.tsx` (search is handled separately by the screen).
  List<LibraryEntry> apply(List<LibraryEntry> entries) {
    var result = entries.where(_matches).toList();
    result.sort(_compare);
    return result;
  }

  bool _matches(LibraryEntry e) {
    if (favoritesOnly && !e.isFavorite) return false;
    if (forSaleOnly && !e.forSale) return false;

    if (publishers.isNotEmpty &&
        (e.game.publisher == null || !publishers.contains(e.game.publisher))) {
      return false;
    }
    if (designers.isNotEmpty && !e.game.designers.any(designers.contains)) {
      return false;
    }
    if (minHearts > 0 && e.heartRating < minHearts) return false;
    if (minPunch > 0 && e.punchRating < minPunch) return false;
    if (gameTypes.isNotEmpty &&
        !e.game.gameType.any(gameTypes.contains)) {
      return false;
    }
    if (categories.isNotEmpty &&
        !e.game.gameCategory.any(categories.contains)) {
      return false;
    }
    if (rankings.isNotEmpty &&
        (e.personalRanking == null ||
            !rankings.contains(e.personalRanking))) {
      return false;
    }
    if (years.isNotEmpty &&
        (e.game.year == null || !years.contains(e.game.year))) {
      return false;
    }

    final plays = e.playCount;
    if (minPlays > 0 && plays < minPlays) return false;
    if (maxPlays != null && plays > maxPlays!) return false;

    if (playerCounts.isNotEmpty && !_matchesPlayerCount(e)) return false;

    return true;
  }

  /// Ports the player-count matching logic from `Library.tsx`, including the
  /// "6+" (count == 6) open-ended upper bound.
  bool _matchesPlayerCount(LibraryEntry e) {
    final min = e.game.minPlayers;
    final max = e.game.maxPlayers;
    if (min == null && max == null) return false;

    return playerCounts.any((count) {
      if (count == 6) {
        if (min == null && max != null) return max >= 6;
        if (min != null && max == null) return true;
        return (max != null && max >= 6) || (min != null && min >= 6);
      }
      if (min == null && max != null) return count <= max;
      if (min != null && max == null) return count >= min;
      return min != null && max != null && count >= min && count <= max;
    });
  }

  int _compare(LibraryEntry a, LibraryEntry b) {
    switch (sort) {
      case LibrarySort.nameAsc:
        return _compareName(a.game.name, b.game.name);
      case LibrarySort.nameDesc:
        return _compareName(b.game.name, a.game.name);
      case LibrarySort.dateAddedDesc:
        return b.addedDate.compareTo(a.addedDate);
      case LibrarySort.dateAddedAsc:
        return a.addedDate.compareTo(b.addedDate);
      case LibrarySort.playsDesc:
        return b.playCount.compareTo(a.playCount);
      case LibrarySort.playsAsc:
        return a.playCount.compareTo(b.playCount);
      case LibrarySort.designerAsc:
        return compareOptionalText(a.game.primaryDesigner,
            b.game.primaryDesigner);
      case LibrarySort.designerDesc:
        return compareOptionalText(
            a.game.primaryDesigner, b.game.primaryDesigner,
            descending: true);
      case LibrarySort.publisherAsc:
        return compareOptionalText(a.game.publisher, b.game.publisher);
      case LibrarySort.publisherDesc:
        return compareOptionalText(a.game.publisher, b.game.publisher,
            descending: true);
      case LibrarySort.heartsDesc:
        return b.heartRating.compareTo(a.heartRating);
      case LibrarySort.punchDesc:
        return b.punchRating.compareTo(a.punchRating);
    }
  }

  // Case-insensitive comparison to match the web's localeCompare(sensitivity:
  // 'base').
  int _compareName(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  static const _sentinel = Object();
}
