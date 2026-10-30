import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns one initialized Supabase client for the selected application backend.
class SupabaseBackend {
  SupabaseBackend._();

  static SupabaseClient? _client;

  static SupabaseClient? get client => _client;

  static Future<SupabaseClient> initialize({
    required String url,
    required String publishableKey,
  }) async {
    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();
    if (normalizedUrl.isEmpty || normalizedKey.isEmpty) {
      throw StateError(
        'Thiếu SUPABASE_URL hoặc SUPABASE_PUBLISHABLE_KEY trong cấu hình build.',
      );
    }
    if (_client != null) {
      return _client!;
    }
    await Supabase.initialize(
      url: normalizedUrl,
      publishableKey: normalizedKey,
    );
    _client = Supabase.instance.client;
    return _client!;
  }
}
