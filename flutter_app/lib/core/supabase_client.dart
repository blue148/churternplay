import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = 'https://oorilcytrytxhffindgy.supabase.co';
  // Publishable key is intentionally public — RLS policies protect all data
  static const anonKey = 'sb_publishable_UxLoSjJzgOzURjiQU9ITrQ_11hSxk7J';
}

SupabaseClient get supabase => Supabase.instance.client;
