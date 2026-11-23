import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  String _loginEmailForStudentId(String studentId) {
    final digest = sha256.convert(utf8.encode(studentId.trim().toLowerCase()));

    return 'student_${digest.toString().substring(0, 32)}@example.com';
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final value = identifier.trim();

    final email = value.contains('@')
        ? value.toLowerCase()
        : _loginEmailForStudentId(value);

    try {
      await _client.auth.signInWithPassword(email: email, password: password);

      final profile = await currentProfile();

      if (profile['is_active'] != true) {
        await signOut();
        throw Exception('Akun kamu telah dinonaktifkan. Hubungi admin.');
      }
    } on AuthException catch (e) {
      throw Exception(_authMessage(e));
    }
  }

  Future<void> signUp({
    required String studentId,
    required String fullName,
    required int institutionId,
    required String password,
  }) async {
    final safeId = studentId.trim();
    final email = _loginEmailForStudentId(safeId);

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'student_id': safeId,
          'full_name': fullName.trim(),
          'institution_id': institutionId,
        },
      );

      if (response.user == null) {
        throw Exception('Registrasi belum berhasil. Silakan coba kembali.');
      }
      
      if (response.session != null) {
        await _client.auth.signOut();
      }
    } on AuthException catch (e) {
      throw Exception(_authMessage(e));
    }
  }

  Future<Map<String, dynamic>> currentProfile() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      throw Exception(
        'Profil pengguna belum dibuat. Jalankan trigger SQL Supabase.',
      );
    }

    final result = Map<String, dynamic>.from(row);
    final institutionId = result['institution_id'];

    String institutionName = '';

    if (institutionId != null) {
      final institution = await _client
          .from('institutions')
          .select('name')
          .eq('id', institutionId)
          .maybeSingle();

      institutionName = institution?['name']?.toString() ?? '';
    }

    result['nama'] = result['full_name']?.toString() ?? '';
    result['institution'] = institutionName;
    result['email'] = user.email;
    result['role'] = result['role']?.toString() ?? 'student';

    return result;
  }

  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }

    final path = '${user.id}/avatar.$extension';

    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', user.id);

    return publicUrl;
  }

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return 'Nomor pelajar/email atau password salah.';
    }

    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'NIS / ID Pelajar ini sudah terdaftar.';
    }

    if (message.contains('email not confirmed')) {
      return 'Konfirmasi email masih aktif. Nonaktifkan Email Confirmations di Supabase Auth.';
    }

    return error.message;
  }
}
