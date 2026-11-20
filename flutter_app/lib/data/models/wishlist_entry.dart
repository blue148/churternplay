import 'game.dart';

class WishlistEntry {
  final String id;
  final String userId;
  final String gameId;
  final Game game;
  final String priority; // 'high' | 'medium' | 'low'
  final int heartRating; // 0-5, 0 = not rated
  final int punchRating; // 0-5 fists, 0 = not rated
  final List<DateTime> playedDates;
  final String? notes;
  final DateTime addedDate;
  final DateTime updatedAt;

  const WishlistEntry({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.game,
    required this.priority,
    this.heartRating = 0,
    this.punchRating = 0,
    this.playedDates = const [],
    this.notes,
    required this.addedDate,
    required this.updatedAt,
  });

  int get playCount => playedDates.length;

  factory WishlistEntry.fromJson(Map<String, dynamic> json) {
    final gameJson = json['game'] as Map<String, dynamic>?;
    return WishlistEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gameId: json['game_id'] as String,
      game: gameJson != null
          ? Game.fromJson(gameJson)
          : Game(
              id: json['game_id'] as String,
              name: 'Unknown',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      priority: json['priority'] as String? ?? 'medium',
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

  WishlistEntry copyWith({
    String? priority,
    int? heartRating,
    int? punchRating,
    List<DateTime>? playedDates,
    String? notes,
  }) =>
      WishlistEntry(
        id: id,
        userId: userId,
        gameId: gameId,
        game: game,
        priority: priority ?? this.priority,
        heartRating: heartRating ?? this.heartRating,
        punchRating: punchRating ?? this.punchRating,
        playedDates: playedDates ?? this.playedDates,
        notes: notes ?? this.notes,
        addedDate: addedDate,
        updatedAt: updatedAt,
      );
}
