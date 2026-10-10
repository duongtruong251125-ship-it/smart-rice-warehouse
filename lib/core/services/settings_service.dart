import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyLastFilter = 'last_filter';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isDarkMode => _prefs?.getBool(_keyThemeMode) ?? false;
  Future<void> setDarkMode(bool value) async => _prefs?.setBool(_keyThemeMode, value);

  bool get rememberMe => _prefs?.getBool(_keyRememberMe) ?? false;
  Future<void> setRememberMe(bool value) async => _prefs?.setBool(_keyRememberMe, value);

  bool get isBiometricEnabled => _prefs?.getBool(_keyBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool value) async => _prefs?.setBool(_keyBiometricEnabled, value);

  String get lastFilter => _prefs?.getString(_keyLastFilter) ?? 'Tất cả';
  Future<void> setLastFilter(String value) async => _prefs?.setString(_keyLastFilter, value);
}
