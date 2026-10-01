import '../../core/supabase_client.dart';
import '../models/profile.dart';
import 'analytics_service.dart';

abstract class AuthService {
  /// Signs in with an email or a phone number, resolving phone to its
  /// account's email first (phone is a lookup key, not a Supabase Auth
  /// identifier — no SMS/OTP involved).
  static Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final email =
        identifier.contains('@') ? identifier : await _getEmailByPhone(identifier);
    await supabase.auth.signInWithPassword(email: email, password: password);
    AnalyticsService.logEvent('sign_in');
  }

  static Future<String> _getEmailByPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final data = await supabase
        .from('profiles')
        .select('email')
        .eq('phone_digits', digits)
        .maybeSingle();
    if (data == null) throw Exception('Invalid login credentials');
    return data['email'] as String;
  }

  /// Sends a password-reset email, resolving phone to its account's email
  /// first. Silently no-ops for an unrecognized phone number rather than
  /// surfacing a "not found" error, so this can't be used to enumerate
  /// registered phone numbers — callers should show the same "check your
  /// email" message regardless, same as Supabase already does for an
  /// unrecognized email.
  static Future<void> requestPasswordReset(String identifier) async {
    String email;
    if (identifier.contains('@')) {
      email = identifier;
    } else {
      try {
        email = await _getEmailByPhone(identifier);
      } catch (_) {
        return;
      }
    }
    await supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'churternplay://reset-password',
    );
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
    String? phone,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    AnalyticsService.logEvent('sign_up');
  }

  static Future<void> signOut() async {
    AnalyticsService.logEvent('sign_out');
    await supabase.auth.signOut();
  }

  /// Permanently deletes the current user's account and all associated data
  /// via the `delete-account` edge function, then clears the local session
  /// (which triggers the router redirect back to the auth screen).
  static Future<void> deleteAccount() async {
    AnalyticsService.logEvent('account_deleted');
    final response = await supabase.functions.invoke('delete-account');
    if (response.status != 200) {
      throw Exception('Failed to delete account. Please try again.');
    }
    await supabase.auth.signOut();
  }

  static Future<AppProfile?> getProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data == null ? null : AppProfile.fromJson(data);
  }

  static Future<AppProfile> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    final data = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return AppProfile.fromJson(data);
  }
}
