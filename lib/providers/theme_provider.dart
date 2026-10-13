import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    bool initialDarkMode = false,
    this.onChanged,
  }) : _themeMode = initialDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeMode _themeMode;
  final Future<void> Function(bool isDark)? onChanged;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    if (isDarkMode == isDark) return;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    onChanged?.call(isDark);
    notifyListeners();
  }
}
