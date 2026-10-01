import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const routePath = '/auth/forgot-password';

  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.requestPasswordReset(_identifierCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
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
                      'Reset Password',
                      style: GoogleFonts.literata(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: AppColors.ink600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_sent) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.parchment50,
                          border: Border.all(color: AppColors.parchment300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'If an account exists for that email or phone, a reset link has been sent. Check your inbox.',
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 13,
                            color: AppColors.ink400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/auth'),
                          child: const Text('RETURN TO SIGN IN'),
                        ),
                      ),
                    ] else ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMAIL OR PHONE',
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: AppColors.ink200,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _identifierCtrl,
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Required'
                                  : null,
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 14, color: AppColors.ink500),
                              decoration: InputDecoration(
                                fillColor: AppColors.parchment50,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: AppColors.parchment300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: AppColors.parchment300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      const BorderSide(color: AppColors.ink300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              : const Text('SEND RESET LINK'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/auth'),
                        child: Text(
                          'Return to Sign In',
                          style: GoogleFonts.atkinsonHyperlegibleNext(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: AppColors.ink300,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
