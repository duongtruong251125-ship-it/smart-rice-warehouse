abstract interface class AppSettings {
  bool get isDarkMode;
  bool get pushNotifications;
  bool get backgroundSync;
  Future<void> setDarkMode(bool value);
  Future<void> setPushNotifications(bool value);
  Future<void> setBackgroundSync(bool value);
}
