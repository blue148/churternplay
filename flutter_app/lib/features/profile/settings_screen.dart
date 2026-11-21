import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

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
          style: AppFonts.sans(
              fontSize: 15, color: AppColors.ink300),
        ),
      ),
    );
  }
}
