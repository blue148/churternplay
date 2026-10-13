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
    final email = identifier.contains('@')
        ? identifier
        : await _getEmailByPhone(identifier, password);
    await supabase.auth.signInWithPassword(email: email, password: password);
    AnalyticsService.logEvent('sign_in');
  }

  /// The `resolve_phone_login` RPC only returns the email when the password
  /// also matches (and throttles failures), so it can't be used to map
  /// phone numbers to email addresses.
  static Future<String> _getEmailByPhone(String phone, String password) async {
    final email = await supabase.rpc('resolve_phone_login',
        params: {'p_phone': phone, 'p_password': password});
    if (email == null) throw Exception('Invalid login credentials');
    return email as String;
  }

  /// Sends a password-reset email. Email only: resolving a phone number to
  /// an email without the password would let anyone look up whose number
  /// is whose. Supabase doesn't reveal whether the email is registered.
  static Future<void> requestPasswordReset(String email) async {
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
