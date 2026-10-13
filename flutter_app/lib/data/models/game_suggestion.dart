import 'game.dart';
import 'profile.dart';

/// A one-off "suggest this game to a friend" event (PRD §13.2) — distinct
/// from `SharedLibraryAccess`, which controls ongoing library visibility.
class GameSuggestion {
  final String id;
  final String senderId;
  final String recipientId;
  final String gameId;
  final String? note;
  final String status; // 'pending' | 'accepted' | 'dismissed'
  final AppProfile? sender;
  final AppProfile? recipient;
  final Game? game;
  final DateTime createdAt;

  const GameSuggestion({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.gameId,
    this.note,
    required this.status,
    this.sender,
    this.recipient,
    this.game,
    required this.createdAt,
  });

  factory GameSuggestion.fromJson(Map<String, dynamic> json) =>
      GameSuggestion(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        recipientId: json['recipient_id'] as String,
        gameId: json['game_id'] as String,
        note: json['note'] as String?,
        status: json['status'] as String,
        sender: json['sender'] != null
            ? AppProfile.fromJson(json['sender'] as Map<String, dynamic>)
            : null,
        recipient: json['recipient'] != null
            ? AppProfile.fromJson(json['recipient'] as Map<String, dynamic>)
            : null,
        game: json['game'] != null
            ? Game.fromJson(json['game'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
