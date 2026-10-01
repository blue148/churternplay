import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';

/// Reached only via a password-recovery deep link (see [AuthChangeNotifier]
/// in core/router.dart) — the router forces navigation here whenever the
/// current session came from a recovery email, regardless of the requested
/// route, until a new password is set.
class ResetPasswordScreen extends StatefulWidget {
  static const routePath = '/auth/reset-password';

  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _passwordCtrl.text));
      authChangeNotifier.clearPasswordRecovery();
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.parchment200),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_reset_outlined,
                        size: 48,
                        color: AppColors.clay400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Set New Password',
                        style: GoogleFonts.literata(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: AppColors.ink600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _field(_passwordCtrl, 'NEW PASSWORD'),
                      const SizedBox(height: 16),
                      _field(_confirmCtrl, 'CONFIRM PASSWORD'),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.clay50,
                            border: Border.all(color: AppColors.clay200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _error!,
                            style: GoogleFonts.atkinsonHyperlegibleNext(
                              fontSize: 13,
                              color: AppColors.clay600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.parchment50,
                                  ),
                                )
                              : const Text('UPDATE PASSWORD'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.atkinsonHyperlegibleNext(
            fontSize: 10,
            letterSpacing: 2,
            color: AppColors.ink200,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: true,
          validator: (v) =>
              v == null || v.length < 6 ? 'Min 6 characters' : null,
          style: GoogleFonts.atkinsonHyperlegibleNext(
              fontSize: 14, color: AppColors.ink500),
          decoration: InputDecoration(
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.ink300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
