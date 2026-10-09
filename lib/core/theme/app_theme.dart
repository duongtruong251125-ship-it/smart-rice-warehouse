import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Bảng màu phong cách FABiBox (iPOS) - Tối giản, Phẳng (Flat POS), Hiện đại
  static const Color primaryColor = Color(0xFF1D4ED8); // iPOS Royal Blue
  static const Color primaryDark = Color(0xFF1E3A8A); // Deep Navy
  static const Color primaryLight = Color(0xFFDBEAFE); // Soft Blue Tint
  static const Color secondaryColor = Color(0xFFF59E0B); // Cam/Vàng cảnh báo & Xuất kho
  static const Color secondaryLight = Color(0xFFFEF3C7);
  static const Color accentGreen = Color(0xFF16A34A); // Xanh lá hoàn thành / Nhập kho
  static const Color accentGreenLight = Color(0xFFDCFCE7);
  static const Color accentBlue = Color(0xFF0284C7);
  static const Color accentBlueLight = Color(0xFFE0F2FE);
  static const Color backgroundColor = Color(0xFFF1F5F9); // Nền xám lạnh phẳng chuẩn POS
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color dangerColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF16A34A);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: cardColor,
    ).copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: primaryDark,
      secondary: accentGreen,
      onSecondary: Colors.white,
      secondaryContainer: accentGreenLight,
      onSecondaryContainer: const Color(0xFF15803D),
      tertiary: secondaryColor,
      tertiaryContainer: secondaryLight,
      onTertiaryContainer: const Color(0xFF92400E),
      error: const Color(0xFFDC2626),
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFFB91C1C),
      surface: cardColor,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: const Color(0xFF94A3B8),
      outlineVariant: borderColor,
    );

    const borderRadius = BorderRadius.all(Radius.circular(10));
    const outlineBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: borderColor, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      typography: Typography.material2021(),
      // AppBar phẳng màu trắng, chữ đen đậm chuẩn giao diện máy POS FABiBox
      appBarTheme: const AppBarTheme(
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryLight,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            );
          }
          return const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 23);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
      ),
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor, width: 1.2),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}


