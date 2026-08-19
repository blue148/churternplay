import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../privacy/privacy_policy_screen.dart';

/// Shown once per app launch on the auth screen so every beta tester sees
/// it each session, since builds and data model can change frequently
/// during the beta.
Future<void> showBetaDisclaimerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_outlined,
                      color: AppColors.clay400, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'BETA PREVIEW',
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 13,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "You're using a pre-release beta version of The Catalogue, "
                'distributed through TestFlight / Google Play testing to a '
                'limited group of invited testers. By continuing you '
                'acknowledge:',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 13, height: 1.5, color: AppColors.ink400),
              ),
              const SizedBox(height: 14),
              ..._points.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 10),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.clay400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          p,
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.ink400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.push(PrivacyPolicyScreen.routePath);
                },
                icon: const Icon(Icons.privacy_tip_outlined, size: 17),
                label: Text(
                  'Read the Privacy Policy',
                  style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'I UNDERSTAND',
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 12,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.parchment50,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const _points = [
  'This build is unfinished software. Bugs, crashes, and unexpected behavior '
      'are expected.',
  'Your account data — library, wishlist, sessions, and profile — may be '
      'reset, wiped, or lost at any time without notice as the beta evolves.',
  'Content you add may be visible to other testers you connect with as '
      'friends, per the Privacy Policy.',
  'Features, screens, and this data model may change or be removed before '
      'public release.',
];
