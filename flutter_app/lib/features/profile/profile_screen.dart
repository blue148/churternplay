import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../privacy/privacy_policy_screen.dart';
import 'friends_screen.dart';
import 'profile_details_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);

    // Only block the screen on the *first* load. If the fetch errors (or
    // is still loading on a later rebuild) fall back to a null profile
    // rather than replacing the whole body — Sign Out lives in this list,
    // and a profile-load failure must never be a dead end with no way out.
    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = profileAsync.maybeWhen(data: (p) => p, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.forest100,
                  backgroundImage: profile?.avatarUrl != null
                      ? NetworkImage(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl == null
                      ? Text(
                          (profile?.username ?? user?.email ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: GoogleFonts.literata(
                            fontSize: 32,
                            color: AppColors.forest500,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  profile?.username ?? user?.email ?? '',
                  style: GoogleFonts.literata(
                    fontSize: 26,
                    color: AppColors.ink600,
                  ),
                ),
                if (profile?.bio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile!.bio!,
                    style:
                        GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink300),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),

          // Stats summary
          if (profile != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Games', value: '${profile.totalGames}'),
                _Stat(label: 'Favourites', value: '${profile.favoriteCount}'),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
          ],

          // Menu items
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.people_outline,
            label: 'Friends',
            onTap: () => context.push(FriendsScreen.routePath),
          ),
          _MenuItem(
            icon: Icons.badge_outlined,
            label: 'Profile Details',
            onTap: () => context.push(ProfileDetailsScreen.routePath),
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => context.push(SettingsScreen.routePath),
          ),
          _MenuItem(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => context.push(PrivacyPolicyScreen.routePath),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Sign out
          _MenuItem(
            icon: Icons.logout,
            label: 'Sign Out',
            color: AppColors.clay500,
            onTap: () => _confirmSignOut(context, ref),
          ),

          // Delete account
          _MenuItem(
            icon: Icons.delete_outline,
            label: 'Delete Account',
            color: AppColors.clay500,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sign out?',
            style: GoogleFonts.literata(fontSize: 22)),
        content: Text('You will need to sign in again to access your library.',
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService.signOut();
            },
            child: Text('Sign Out',
                style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.clay500)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => const _DeleteAccountSheet(),
    );
  }
}

/// Confirmation drawer shown before permanently deleting an account.
/// Holds its own loading/error state so the parent screen stays stateless.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await AuthService.deleteAccount();
      // Session is now cleared; the router redirect handles navigation to /auth.
      // Pop the sheet if it is somehow still mounted.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 40, color: AppColors.clay500),
            const SizedBox(height: 12),
            Text(
              'Delete account?',
              style: GoogleFonts.literata(
                  fontSize: 24, color: AppColors.ink600),
            ),
            const SizedBox(height: 12),
            Text(
              'This permanently deletes your account and cannot be undone. '
              'Your profile, library, wishlist, game sessions, and friends '
              'will all be removed.',
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink400),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.clay50,
                  border: Border.all(color: AppColors.clay200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _error!,
                  style:
                      GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.clay600),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deleting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _deleting ? null : _delete,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.clay500),
                    child: _deleting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Delete Account'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.literata(
                fontSize: 28, color: AppColors.ink600)),
        Text(label,
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 11, color: AppColors.ink300)),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink500;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 15, color: c)),
      trailing: color == null
          ? const Icon(Icons.chevron_right, color: AppColors.ink200)
          : null,
      onTap: onTap,
    );
  }
}
