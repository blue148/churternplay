import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import 'widgets/beta_disclaimer_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showBetaDisclaimerDialog(context);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await AuthService.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
        );
      } else {
        await AuthService.signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      // Commit the autofill context so iOS/1Password offers to save the login.
      TextInput.finishAutofillContext();
      // Router redirect handles navigation after auth state change
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
                  child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ────────────────────────────────────────────
                      Icon(
                        Icons.menu_book_outlined,
                        size: 48,
                        color: AppColors.clay400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'The Catalogue',
                        style: GoogleFonts.literata(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: AppColors.ink600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(height: 1, width: 48, color: AppColors.parchment300),
                      const SizedBox(height: 8),
                      Text(
                        (_isSignUp ? 'Registration' : 'Authentication').toUpperCase(),
                        style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 10,
                          letterSpacing: 2.5,
                          color: AppColors.ink200,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Fields ────────────────────────────────────────────
                      if (_isSignUp) ...[
                        _field(
                          controller: _usernameCtrl,
                          label: 'USERNAME',
                          autofill: AutofillHints.username,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _field(
                        controller: _emailCtrl,
                        label: 'EMAIL',
                        autofill: AutofillHints.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v == null || !v.contains('@') ? 'Valid email required' : null,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: _passwordCtrl,
                        label: 'PASSWORD',
                        autofill: _isSignUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                        obscure: true,
                        validator: (v) => v == null || v.length < 6
                            ? 'Min 6 characters'
                            : null,
                      ),

                      // ── Error ─────────────────────────────────────────────
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

                      // ── Submit ────────────────────────────────────────────
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
                              : Text(
                                  (_isSignUp ? 'Register' : 'Enter').toUpperCase(),
                                  style: GoogleFonts.atkinsonHyperlegibleNext(
                                    fontSize: 12,
                                    letterSpacing: 2.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.parchment50,
                                  ),
                                ),
                        ),
                      ),

                      // ── Toggle ────────────────────────────────────────────
                      const SizedBox(height: 24),
                      Divider(color: AppColors.parchment200),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                        }),
                        child: Text(
                          _isSignUp
                              ? 'Return to Sign In'
                              : 'Create New Account',
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: AppColors.ink300,
                          ),
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
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String autofill,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
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
          autofillHints: [autofill],
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14, color: AppColors.ink500),
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
