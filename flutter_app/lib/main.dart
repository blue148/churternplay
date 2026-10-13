import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_client.dart';
import 'data/services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Beta crash logging — first-party, see AnalyticsService.
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    defaultOnError?.call(details);
    AnalyticsService.logEvent('app_error', properties: {
      'source': 'flutter',
      'exception': details.exceptionAsString(),
      'library': details.library,
    });
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AnalyticsService.logEvent('app_error', properties: {
      'source': 'platform',
      'exception': error.toString(),
    });
    return true;
  };

  runApp(const ProviderScope(child: App()));
}
