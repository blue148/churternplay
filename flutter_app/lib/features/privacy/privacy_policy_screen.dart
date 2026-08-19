import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'privacy_policy_content.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const routePath = '/privacy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment50,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          children: [
            Text(
              'PRIVACY POLICY',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
                color: AppColors.clay500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Churtern Play',
              style: GoogleFonts.literata(
                fontSize: 34,
                fontWeight: FontWeight.w500,
                color: AppColors.ink600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Effective $privacyPolicyEffectiveDate',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 12,
                color: AppColors.ink300,
              ),
            ),
            const SizedBox(height: 24),
            Text(privacyPolicyIntroduction, style: _bodyStyle),
            const SizedBox(height: 8),
            for (final section in privacyPolicySections) ...[
              const SizedBox(height: 24),
              Text(section.title, style: _headingStyle),
              const SizedBox(height: 8),
              for (var i = 0; i < section.paragraphs.length; i++) ...[
                Text(section.paragraphs[i], style: _bodyStyle),
                if (i < section.paragraphs.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static TextStyle get _headingStyle => GoogleFonts.literata(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.ink600,
      );

  static TextStyle get _bodyStyle => GoogleFonts.atkinsonHyperlegibleNext(
        fontSize: 14,
        height: 1.55,
        color: AppColors.ink400,
      );
}
