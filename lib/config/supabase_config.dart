import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();
  static const String url = 'https://wvpjknsznujbwjgvumnj.supabase.co';
  static const String publishableKey =
      'sb_publishable_qjbZ_9LvZmrn74vDQxVL-A_HKpxfVpl';

  static String get apiKey => publishableKey;

  static bool get isConfigured =>
      url.startsWith('https://') &&
      url.contains('.supabase.co') &&
      !url.contains('GANTI_PROJECT_ID') &&
      publishableKey.isNotEmpty &&
      !publishableKey.startsWith('GANTI_');

  static Future<void> initialize() async {
    if (!isConfigured) {
      throw StateError(
        'Konfigurasi Supabase belum diisi. '
        'Periksa URL dan Publishable Key.',
      );
    }

    await Supabase.initialize(url: url, publishableKey: apiKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
