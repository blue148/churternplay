import 'dart:io';

import '../../core/supabase_client.dart';

/// First-party beta usage/error logging. Writes directly to the
/// `analytics_events` table in our own Supabase project — no third-party
/// SDK, no advertising or cross-app tracking, and never shared outside the
/// project. Used only to spot bugs and understand feature usage during beta.
abstract class AnalyticsService {
  /// Fire-and-forget: never throws, never blocks the caller. Silently no-ops
  /// when there is no signed-in user, since events must be attributable to
  /// the user who generated them (see the `analytics_events` RLS policy).
  static void logEvent(String eventName, {Map<String, dynamic>? properties}) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    supabase.from('analytics_events').insert({
      'user_id': userId,
      'event_name': eventName,
      'properties': properties,
      'platform': Platform.operatingSystem,
    }).catchError((_) {
      // Analytics must never surface an error to the user or crash the app.
    });
  }
}
