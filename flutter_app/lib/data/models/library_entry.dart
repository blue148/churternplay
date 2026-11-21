import 'game.dart';
import 'victory_stats.dart';

class LibraryEntry {
  final String id;
  final String userId;
  final String gameId;
  final Game game;
  final bool isFavorite;
  final bool forSale;
  final String? personalRanking; // legacy 'high' | 'medium' | 'low'
  final int heartRating; // 0-5, 0 = not rated
  final int punchRating; // 0-5 fists, 0 = not rated
  final List<DateTime> playedDates;
  final String? notes;
  final DateTime addedDate;
  final DateTime updatedAt;
  final VictoryStats? victoryStats;

  const LibraryEntry({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.game,
    required this.isFavorite,
    required this.forSale,
    this.personalRanking,
    this.heartRating = 0,
    this.punchRating = 0,
    required this.playedDates,
    this.notes,
    required this.addedDate,
    required this.updatedAt,
    this.victoryStats,
  });

  int get playCount => playedDates.length;
  bool get hasVictoryStats => victoryStats != null && victoryStats!.totalSessions > 0;

  factory LibraryEntry.fromJson(Map<String, dynamic> json) {
    final gameJson = json['game'] as Map<String, dynamic>?;
    return LibraryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gameId: json['game_id'] as String,
      game: gameJson != null ? Game.fromJson(gameJson) : _emptyGame(json['game_id'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      forSale: json['for_sale'] as bool? ?? false,
      personalRanking: json['personal_ranking'] as String?,
      heartRating: (json['heart_rating'] as int? ?? 0).clamp(0, 5),
      punchRating: (json['punch_rating'] as int? ?? 0).clamp(0, 5),
      playedDates: ((json['played_dates'] as List<dynamic>?) ?? [])
          .map((d) => DateTime.parse(d as String))
          .toList(),
      notes: json['notes'] as String?,
      addedDate: DateTime.parse(json['added_date'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  LibraryEntry copyWith({
    bool? isFavorite,
    bool? forSale,
    String? personalRanking,
    int? heartRating,
    int? punchRating,
    List<DateTime>? playedDates,
    String? notes,
    VictoryStats? victoryStats,
  }) =>
      LibraryEntry(
        id: id,
        userId: userId,
        gameId: gameId,
        game: game,
        isFavorite: isFavorite ?? this.isFavorite,
        forSale: forSale ?? this.forSale,
        personalRanking: personalRanking ?? this.personalRanking,
        heartRating: heartRating ?? this.heartRating,
        punchRating: punchRating ?? this.punchRating,
        playedDates: playedDates ?? this.playedDates,
        notes: notes ?? this.notes,
        addedDate: addedDate,
        updatedAt: updatedAt,
        victoryStats: victoryStats ?? this.victoryStats,
      );

  static Game _emptyGame(String id) => Game(
        id: id,
        name: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}
