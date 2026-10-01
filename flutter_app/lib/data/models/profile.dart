class ProfilePreferences {
  final String theme; // 'light' | 'dark'
  final bool notificationsEnabled;
  final String defaultView; // 'grid' | 'list'
  final List<String> players;

  const ProfilePreferences({
    this.theme = 'light',
    this.notificationsEnabled = true,
    this.defaultView = 'grid',
    this.players = const [],
  });

  factory ProfilePreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfilePreferences();
    return ProfilePreferences(
      theme: json['theme'] as String? ?? 'light',
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      defaultView: json['default_view'] as String? ?? 'grid',
      players: ((json['players'] as List<dynamic>?) ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'notifications_enabled': notificationsEnabled,
        'default_view': defaultView,
        'players': players,
      };
}

class AppProfile {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final ProfilePreferences preferences;
  final int totalGames;
  final int favoriteCount;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppProfile({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.phone,
    required this.preferences,
    required this.totalGames,
    required this.favoriteCount,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppProfile.fromJson(Map<String, dynamic> json) => AppProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        phone: json['phone'] as String?,
        preferences: ProfilePreferences.fromJson(
            json['preferences'] as Map<String, dynamic>?),
        totalGames: json['total_games'] as int? ?? 0,
        favoriteCount: json['favorite_count'] as int? ?? 0,
        isAdmin: json['is_admin'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
