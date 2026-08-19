import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Placeholder settings screen. Content to be fleshed out later — this
/// exists so the bottom nav's Profile long-press menu has somewhere to go.
class SettingsScreen extends StatelessWidget {
  static const routePath = '/profile/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Text(
          'Settings coming soon',
          style: GoogleFonts.atkinsonHyperlegibleNext(
              fontSize: 15, color: AppColors.ink300),
        ),
      ),
    );
  }
}
