import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyBackgroundSync = 'background_sync';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isDarkMode => _prefs?.getBool(_keyThemeMode) ?? false;
  Future<void> setDarkMode(bool value) async =>
      _prefs?.setBool(_keyThemeMode, value);

  bool get pushNotifications => _prefs?.getBool(_keyPushNotifications) ?? true;
  Future<void> setPushNotifications(bool value) async =>
      _prefs?.setBool(_keyPushNotifications, value);

  bool get backgroundSync => _prefs?.getBool(_keyBackgroundSync) ?? true;
  Future<void> setBackgroundSync(bool value) async =>
      _prefs?.setBool(_keyBackgroundSync, value);
}
