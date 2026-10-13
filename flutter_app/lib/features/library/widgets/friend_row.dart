import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// A single friend/search-result row: avatar, username, subtitle, optional
/// trailing widget. Shared between the read-only Friends list on My Games
/// and the full friend-management screen under Profile → Friends.
class FriendRow extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final int totalGames;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const FriendRow({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.totalGames,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.parchment200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              FriendAvatar(username: username, avatarUrl: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                        style: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink600)),
                    Text(
                      subtitle ?? '$totalGames games',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 12, color: AppColors.ink300),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class FriendAvatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;

  const FriendAvatar({super.key, required this.username, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.plum300, AppColors.plum500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(initial,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}
