import 'package:churtern_play/data/models/game.dart';
import 'package:churtern_play/data/models/library_entry.dart';
import 'package:churtern_play/data/models/library_filter.dart';
import 'package:churtern_play/data/models/wishlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _gameJson(String name,
        {String? publisher, List<String>? designers}) =>
    {
      'id': name,
      'name': name,
      'publisher': publisher,
      if (designers != null) 'designers': designers,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

LibraryEntry _entry(String name,
    {String? publisher,
    List<String>? designers,
    int hearts = 0,
    int fists = 0}) {
  return LibraryEntry.fromJson({
    'id': 'e-$name',
    'user_id': 'u',
    'game_id': name,
    'game': _gameJson(name, publisher: publisher, designers: designers),
    'heart_rating': hearts,
    'punch_rating': fists,
    'added_date': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  });
}

List<String> _names(List<LibraryEntry> l) => l.map((e) => e.game.name).toList();

void main() {
  group('Game.designers', () {
    test('parses, defaults to empty, and joins for display', () {
      expect(Game.fromJson(_gameJson('A')).designers, isEmpty);
      final g = Game.fromJson(_gameJson('A', designers: ['X Y', 'Z W']));
      expect(g.designerLabel, 'X Y, Z W');
      expect(g.primaryDesigner, 'X Y');
    });
  });

  group('ratings', () {
    test('library entry parses and clamps ratings; defaults to 0', () {
      expect(_entry('A').heartRating, 0);
      final e = _entry('A', hearts: 9, fists: 3);
      expect(e.heartRating, 5);
      expect(e.punchRating, 3);
      expect(e.copyWith(heartRating: 2).heartRating, 2);
    });

    test('wishlist entry parses ratings and supports copyWith', () {
      final w = WishlistEntry.fromJson({
        'id': 'w',
        'user_id': 'u',
        'game_id': 'g',
        'game': _gameJson('G'),
        'priority': 'high',
        'heart_rating': 4,
        'punch_rating': 1,
        'played_dates': ['2026-05-01', '2026-06-02'],
        'added_date': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect((w.heartRating, w.punchRating), (4, 1));
      expect(w.playCount, 2);
      expect(w.copyWith(playedDates: []).playCount, 0);
      expect(w.copyWith(punchRating: 5).punchRating, 5);
      expect(w.copyWith(punchRating: 5).heartRating, 4);
    });
  });

  group('LibraryFilter sort/filter', () {
    final a = _entry('A', publisher: 'Zed', designers: ['Carl'], hearts: 2, fists: 5);
    final b = _entry('B', publisher: 'alpha', designers: ['bob'], hearts: 5, fists: 1);
    final c = _entry('C'); // no publisher, no designer
    final all = [c, a, b];

    List<String> sorted(LibrarySort s) =>
        _names(LibraryFilter(sort: s).apply(all));

    test('designer sort is case-insensitive with unknowns last (both ways)', () {
      expect(sorted(LibrarySort.designerAsc), ['B', 'A', 'C']);
      expect(sorted(LibrarySort.designerDesc), ['A', 'B', 'C']);
    });

    test('publisher sort puts unknowns last (both ways)', () {
      expect(sorted(LibrarySort.publisherAsc), ['B', 'A', 'C']);
      expect(sorted(LibrarySort.publisherDesc), ['A', 'B', 'C']);
    });

    test('hearts and fists sort descending', () {
      expect(sorted(LibrarySort.heartsDesc).first, 'B');
      expect(sorted(LibrarySort.punchDesc).first, 'A');
    });

    test('designer and minimum-rating filters', () {
      expect(
          _names(const LibraryFilter(designers: {'Carl'}).apply(all)), ['A']);
      expect(_names(const LibraryFilter(minHearts: 3).apply(all)), ['B']);
      expect(_names(const LibraryFilter(minPunch: 2).apply(all)), ['A']);
      expect(const LibraryFilter(minHearts: 1, minPunch: 1, designers: {'x'})
          .activeCount, 3);
    });

    test('toggleFacet touches only the named facet', () {
      const f = LibraryFilter();
      final next = f.toggleFacet(StringFacet.designers, 'Carl');
      expect(next.designers, {'Carl'});
      expect(next.publishers, isEmpty);
      expect(next.toggleFacet(StringFacet.designers, 'Carl').designers,
          isEmpty);
    });
  });

  test('compareOptionalText keeps empties last', () {
    expect(compareOptionalText(null, 'a'), 1);
    expect(compareOptionalText('a', ''), -1);
    expect(compareOptionalText('', null), 0);
    expect(compareOptionalText('a', 'B', descending: true), greaterThan(0));
  });
}
