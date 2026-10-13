import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/profile.dart';
import '../../data/services/auth_service.dart';
import '../../providers/auth_provider.dart';

const _presetAvatars = [
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Aneka',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Max',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Sophie',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Charlie',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Luna',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Oliver',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Bella',
];

/// Edits the user's own profile (avatar, username, phone, bio) and password,
/// mirroring the web app's ProfileDrawer. Also offers account deletion.
class ProfileDetailsScreen extends ConsumerStatefulWidget {
  static const routePath = '/profile/details';

  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String? _avatarUrl;
  bool _initialized = false;

  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  bool _success = false;

  bool _passwordSectionOpen = false;
  bool _passwordSaving = false;
  String? _passwordError;
  bool _passwordSuccess = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _hydrate(AppProfile? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    _usernameCtrl.text = profile.username;
    _phoneCtrl.text = profile.phone ?? '';
    _bioCtrl.text = profile.bio ?? '';
    _avatarUrl = profile.avatarUrl;
  }

  Future<void> _pickAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final fileName = '${user.id}/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$ext',
            ),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      setState(() => _avatarUrl = publicUrl);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _success = false;
    });

    try {
      await AuthService.updateProfile(user.id, {
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      ref.invalidate(profileProvider);
      setState(() => _success = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _success = false);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = false;
    });

    if (_newPasswordCtrl.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _passwordError = 'Passwords do not match');
      return;
    }

    setState(() => _passwordSaving = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordCtrl.text),
      );
      setState(() {
        _passwordSuccess = true;
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _passwordSuccess = false);
      });
    } catch (e) {
      setState(() => _passwordError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _passwordSaving = false);
    }
  }

  void _confirmDeleteAccount() {
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    final profile = profileAsync.maybeWhen(data: (p) => p, orElse: () => null);
    _hydrate(profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Details')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Avatar ────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.forest100,
                      backgroundImage:
                          _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null
                          ? Text(
                              (_usernameCtrl.text.isNotEmpty
                                      ? _usernameCtrl.text
                                      : (user?.email ?? 'U'))
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: GoogleFonts.literata(
                                fontSize: 32,
                                color: AppColors.forest500,
                              ),
                            )
                          : null,
                    ),
                    if (_uploadingAvatar)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black38,
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _uploadingAvatar ? null : _pickAvatar,
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('Upload Photo'),
                ),
                const SizedBox(height: 4),
                Text('Or choose a preset',
                    style: GoogleFonts.atkinsonHyperlegibleNext(
                        fontSize: 12, color: AppColors.ink300)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _presetAvatars.map((avatar) {
                    final selected = _avatarUrl == avatar;
                    return GestureDetector(
                      onTap: () => setState(() => _avatarUrl = avatar),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.ink600
                                : AppColors.parchment300,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(avatar, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Email (read-only) ────────────────────────────────
          _label('EMAIL'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: user?.email ?? '',
            enabled: false,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 14, color: AppColors.ink300),
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 16),

          // ── Username ──────────────────────────────────────────
          _label('USERNAME'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameCtrl,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 14, color: AppColors.ink500),
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 16),

          // ── Phone ─────────────────────────────────────────────
          _label('PHONE (OPTIONAL)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 14, color: AppColors.ink500),
            decoration: _inputDecoration(hint: '+1 555 123 4567'),
          ),
          const SizedBox(height: 4),
          Text('Used as a secondary contact method, not for sign-in',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 11, color: AppColors.ink300)),
          const SizedBox(height: 16),

          // ── Bio ───────────────────────────────────────────────
          _label('BIO'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _bioCtrl,
            maxLines: 3,
            maxLength: 500,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 14, color: AppColors.ink500),
            decoration: _inputDecoration(hint: 'Tell us about yourself...'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            _errorBox(_error!),
          ],
          if (_success) ...[
            const SizedBox(height: 8),
            _successBox('Profile updated successfully.'),
          ],

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),

          // ── Password ──────────────────────────────────────────
          InkWell(
            onTap: () =>
                setState(() => _passwordSectionOpen = !_passwordSectionOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Change Password',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 13,
                          letterSpacing: 1,
                          color: AppColors.ink300)),
                  Icon(
                    _passwordSectionOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.ink200,
                  ),
                ],
              ),
            ),
          ),
          if (_passwordSectionOpen) ...[
            _label('NEW PASSWORD'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _newPasswordCtrl,
              obscureText: true,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 14, color: AppColors.ink500),
              decoration: _inputDecoration(hint: 'Minimum 6 characters'),
            ),
            const SizedBox(height: 16),
            _label('CONFIRM PASSWORD'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: true,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 14, color: AppColors.ink500),
              decoration: _inputDecoration(hint: 'Re-enter new password'),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: 8),
              _errorBox(_passwordError!),
            ],
            if (_passwordSuccess) ...[
              const SizedBox(height: 8),
              _successBox('Password updated successfully.'),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _passwordSaving ||
                        _newPasswordCtrl.text.isEmpty ||
                        _confirmPasswordCtrl.text.isEmpty
                    ? null
                    : _changePassword,
                child: _passwordSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update Password'),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // ── Delete account ────────────────────────────────────
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            leading: const Icon(Icons.delete_outline, color: AppColors.clay500),
            title: Text('Delete Account',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 15, color: AppColors.clay500)),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.atkinsonHyperlegibleNext(
          fontSize: 10,
          letterSpacing: 2,
          color: AppColors.ink200,
          fontWeight: FontWeight.w500,
        ),
      );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        fillColor: AppColors.parchment50,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.parchment300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.parchment300),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.parchment200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.ink300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _errorBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.clay50,
          border: Border.all(color: AppColors.clay200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(message,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 13, color: AppColors.clay600)),
      );

  Widget _successBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.forest50,
          border: Border.all(color: AppColors.forest200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(message,
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 13, color: AppColors.forest600)),
      );
}

/// Confirmation drawer shown before permanently deleting an account.
/// Mirrors the sheet on the main Profile menu so deletion works the same
/// way from either entry point.
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
              style: GoogleFonts.literata(fontSize: 24, color: AppColors.ink600),
            ),
            const SizedBox(height: 12),
            Text(
              'This permanently deletes your account and cannot be undone. '
              'Your profile, library, wishlist, game sessions, and friends '
              'will all be removed.',
              style: GoogleFonts.atkinsonHyperlegibleNext(
                  fontSize: 14, color: AppColors.ink400),
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
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontSize: 13, color: AppColors.clay600),
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
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.clay500),
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

