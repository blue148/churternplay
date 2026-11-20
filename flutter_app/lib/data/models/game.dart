class Game {
  final String id;
  final String? barcode;
  final String name;
  final int? bggId;
  final String? publisher;
  final List<String> designers;
  final String? year;
  final String? edition;
  final String? coverImage;
  final List<String> gameType;
  final List<String> gameCategory;
  final List<String> gameMechanic;
  final List<String> gameFamily;
  final int? minPlayers;
  final int? maxPlayers;
  final int? playtimeMinutes;
  final bool isExpansion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Game({
    required this.id,
    this.barcode,
    required this.name,
    this.bggId,
    this.publisher,
    this.designers = const [],
    this.year,
    this.edition,
    this.coverImage,
    this.gameType = const [],
    this.gameCategory = const [],
    this.gameMechanic = const [],
    this.gameFamily = const [],
    this.minPlayers,
    this.maxPlayers,
    this.playtimeMinutes,
    this.isExpansion = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as String,
        barcode: json['barcode'] as String?,
        name: json['name'] as String,
        bggId: json['bgg_id'] as int?,
        publisher: json['publisher'] as String?,
        designers: _strings(json['designers']),
        year: json['year'] as String?,
        edition: json['edition'] as String?,
        coverImage: json['cover_image'] as String?,
        gameType: _strings(json['game_type']),
        gameCategory: _strings(json['game_category']),
        gameMechanic: _strings(json['game_mechanic']),
        gameFamily: _strings(json['game_family']),
        minPlayers: json['min_players'] as int?,
        maxPlayers: json['max_players'] as int?,
        playtimeMinutes: json['playtime_minutes'] as int?,
        isExpansion: json['is_expansion'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'bgg_id': bggId,
        'publisher': publisher,
        'designers': designers,
        'year': year,
        'edition': edition,
        'cover_image': coverImage,
        'game_type': gameType,
        'game_category': gameCategory,
        'game_mechanic': gameMechanic,
        'game_family': gameFamily,
        'min_players': minPlayers,
        'max_players': maxPlayers,
        'playtime_minutes': playtimeMinutes,
        'is_expansion': isExpansion,
      };

  /// Designers joined for display, e.g. "Uwe Rosenberg, Grzegorz Kobiela".
  String get designerLabel => designers.join(', ');

  /// First designer, used for sorting. Empty when unknown.
  String get primaryDesigner => designers.isEmpty ? '' : designers.first;

  String get playerCountLabel {
    if (minPlayers == null && maxPlayers == null) return '';
    if (minPlayers == maxPlayers) return '${minPlayers}p';
    return '${minPlayers ?? '?'}–${maxPlayers ?? '?'}p';
  }

  static List<String> _strings(dynamic val) =>
      (val as List<dynamic>?)?.cast<String>() ?? [];
}
