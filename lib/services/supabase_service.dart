import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Base access point untuk client dan sesi Supabase di seluruh service ELORA.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => SupabaseConfig.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null;

  static Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}
