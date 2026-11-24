import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Exception khusus autentikasi.
///
/// toString() sengaja mengembalikan format 'Exception: pesan' agar kode lama
/// yang memakai `e.toString().replaceFirst('Exception: ', '')` tetap bekerja.
class AuthFailure implements Exception {
  final String message;

  /// True jika kegagalan disebabkan email/ID atau password salah.
  final bool invalidCredentials;

  const AuthFailure(this.message, {this.invalidCredentials = false});

  @override
  String toString() => 'Exception: $message';
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => SupabaseService.client;

  // Penyimpanan terenkripsi (Keystore di Android, Keychain di iOS).
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _bioIdentifierKey = 'elora_bio_identifier';
  static const String _bioPasswordKey = 'elora_bio_password';

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  String _loginEmailForStudentId(String studentId) {
    final digest = sha256.convert(utf8.encode(studentId.trim().toLowerCase()));

    return 'student_${digest.toString().substring(0, 32)}@example.com';
  }

  // =========================================================
  // LOGIN DAN REGISTRASI
  // =========================================================

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
        throw const AuthFailure(
          'Akun kamu telah dinonaktifkan. Hubungi admin.',
        );
      }
    } on AuthException catch (e) {
      throw AuthFailure(
        _authMessage(e),
        invalidCredentials: _isInvalidCredentials(e),
      );
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

  // =========================================================
  // LOGIN BIOMETRIK
  //
  // Alur: setelah login manual berhasil dan pengguna menyetujui,
  // identifier dan password disimpan di secure storage. Saat logout,
  // sesi Supabase dihapus tetapi kredensial ini tetap ada, sehingga
  // biometrik bisa dipakai untuk masuk kembali. Kredensial hanya dibaca
  // setelah autentikasi biometrik berhasil (dipastikan oleh layar login).
  // =========================================================

  Future<bool> hasBiometricCredentials() async {
    try {
      final id = await _secureStorage.read(key: _bioIdentifierKey);
      final pw = await _secureStorage.read(key: _bioPasswordKey);

      return id != null && id.isNotEmpty && pw != null && pw.isNotEmpty;
    } catch (_) {
      // Data tidak bisa dibaca (misalnya rusak setelah restore backup).
      await clearBiometricCredentials();
      return false;
    }
  }

  Future<String?> storedBiometricIdentifier() async {
    try {
      return await _secureStorage.read(key: _bioIdentifierKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBiometricCredentials({
    required String identifier,
    required String password,
  }) async {
    Future<void> write() async {
      await _secureStorage.write(
        key: _bioIdentifierKey,
        value: identifier.trim(),
      );
      await _secureStorage.write(key: _bioPasswordKey, value: password);
    }

    try {
      await write();
    } catch (e) {
      // Data lama rusak (misalnya hasil restore backup Android), bersihkan
      // seluruh storage lalu coba tulis ulang satu kali.
      debugPrint('SECURE STORAGE WRITE ERROR, resetting: $e');
      await _secureStorage.deleteAll();
      await write();
    }
  }

  Future<void> clearBiometricCredentials() async {
    try {
      await _secureStorage.delete(key: _bioIdentifierKey);
      await _secureStorage.delete(key: _bioPasswordKey);
    } catch (_) {
      try {
        await _secureStorage.deleteAll();
      } catch (_) {
        // Abaikan: storage tidak tersedia.
      }
    }
  }

  /// Masuk memakai kredensial yang tersimpan. Panggil hanya setelah
  /// autentikasi biometrik berhasil.
  Future<void> signInWithBiometric() async {
    String? identifier;
    String? password;

    try {
      identifier = await _secureStorage.read(key: _bioIdentifierKey);
      password = await _secureStorage.read(key: _bioPasswordKey);
    } catch (_) {
      await clearBiometricCredentials();
    }

    if (identifier == null ||
        identifier.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw const AuthFailure(
        'Biometrik belum diaktifkan. Silakan login manual terlebih dahulu.',
      );
    }

    try {
      await signIn(identifier: identifier, password: password);
    } on AuthFailure catch (e) {
      if (e.invalidCredentials) {
        // Password kemungkinan sudah diganti, kredensial lama tidak berlaku.
        await clearBiometricCredentials();
        throw const AuthFailure(
          'Password akun sudah berubah. Silakan login manual lalu aktifkan '
          'ulang biometrik.',
          invalidCredentials: true,
        );
      }
      rethrow;
    }
  }

  // =========================================================
  // PROFIL DAN SESI
  // =========================================================

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

  /// Logout hanya menghapus sesi lokal. Kredensial biometrik sengaja
  /// dibiarkan agar biometrik tetap bisa dipakai setelah logout.
  /// Hapus lewat clearBiometricCredentials() jika pengguna menonaktifkannya.
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

  // =========================================================
  // PESAN ERROR
  // =========================================================

  bool _isInvalidCredentials(AuthException error) {
    return error.message.toLowerCase().contains('invalid login credentials');
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