import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Placeholder for editing the user's own profile (avatar, username, bio).
/// Content to be fleshed out later — this exists so the bottom nav's
/// Profile long-press menu has somewhere to go.
class ProfileDetailsScreen extends StatelessWidget {
  static const routePath = '/profile/details';

  const ProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Details')),
      body: Center(
        child: Text(
          'Profile editing coming soon',
          style: GoogleFonts.atkinsonHyperlegibleNext(
              fontSize: 15, color: AppColors.ink300),
        ),
      ),
    );
  }
}
