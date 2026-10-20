import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/logic/contracts/app_settings.dart';

class SettingsService extends ChangeNotifier implements AppSettings {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyBackgroundSync = 'background_sync';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  bool get isDarkMode => _prefs?.getBool(_keyThemeMode) ?? false;
  @override
  Future<void> setDarkMode(bool value) async =>
      _prefs?.setBool(_keyThemeMode, value);

  @override
  bool get pushNotifications => _prefs?.getBool(_keyPushNotifications) ?? true;
  @override
  Future<void> setPushNotifications(bool value) async =>
      _prefs?.setBool(_keyPushNotifications, value);

  @override
  bool get backgroundSync => _prefs?.getBool(_keyBackgroundSync) ?? true;
  @override
  Future<void> setBackgroundSync(bool value) async {
    if (_prefs == null) throw StateError('Cài đặt chưa được khởi tạo.');
    if (!await _prefs!.setBool(_keyBackgroundSync, value)) {
      throw StateError('Không thể lưu cài đặt đồng bộ nền.');
    }
    notifyListeners();
  }
}
