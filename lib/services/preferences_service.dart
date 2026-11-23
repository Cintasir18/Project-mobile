import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
  Future<void> setString(String key, String value) async => (await _prefs).setString(key, value);
  Future<String?> getString(String key) async => (await _prefs).getString(key);
  Future<void> remove(String key) async => (await _prefs).remove(key);
}
