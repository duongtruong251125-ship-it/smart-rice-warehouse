import 'package:flutter/material.dart';

abstract final class AppTheme {
  // ==========================================
  // DESIGN TOKENS - SMART RICE WAREHOUSE
  // (Inspired by Sổ Bán Hàng)
  // ==========================================

  static const Color primaryColor = Color(0xFF16A36A); // Primary Green
  static const Color primaryDark = Color(0xFF087A4C); // Primary Dark
  static const Color primaryLight = Color(0xFFE7F7EF); // Primary Light

  static const Color backgroundColor = Color(0xFFF5F7F6); // Background
  static const Color cardColor = Color(0xFFFFFFFF); // Surface

  static const Color textPrimary = Color(0xFF17251F); // Text Primary
  static const Color textSecondary = Color(0xFF66756D); // Text Secondary

  static const Color borderColor = Color(0xFFE1E8E4); // Border

  static const Color warningColor = Color(0xFFF2A526); // Warning
  static const Color warningLight = Color(0xFFFEF3DF);

  static const Color dangerColor = Color(0xFFD94A45); // Danger
  static const Color dangerLight = Color(0xFFFDECEB);

  static const Color infoColor = Color(0xFF3B75D6); // Information
  static const Color infoLight = Color(0xFFE8F0FE);

  // Kế thừa hằng số cũ để code hiện tại không vỡ
  static const Color safeBg = primaryLight;
  static const Color safeText = primaryDark;
  static const Color safeBorder = Color(0xFFC3E8D3);

  static const Color warningBg = warningLight;
  static const Color warningText = Color(0xFFB45309);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color dangerBg = dangerLight;
  static const Color dangerText = dangerColor;
  static const Color dangerBorder = Color(0xFFFECACA);

  static const Color successColor = primaryColor;
  static const Color accentGreen = primaryColor;
  static const Color accentGreenLight = primaryLight;
  static const Color secondaryColor = warningColor;
  static const Color secondaryLight = warningLight;
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentTealLight = Color(0xFFCCFBF1);
  static const Color accentBlue = infoColor;
  static const Color accentBlueLight = infoLight;
  static const Color surfaceMuted = Color(0xFFF5F7F6);
  static const Color textMuted = Color(0xFF94A3B8);

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.02),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(23, 37, 31, 0.03),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // Tabular Numbers TextStyle Helper
  static TextStyle tabularFigures({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

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
      secondary: warningColor,
      onSecondary: Colors.white,
      secondaryContainer: warningLight,
      onSecondaryContainer: const Color(0xFF7A4A00),
      error: dangerColor,
      errorContainer: dangerBg,
      onErrorContainer: dangerText,
      surface: cardColor,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: textSecondary,
      outlineVariant: borderColor,
    );

    const cardBorderRadius = BorderRadius.all(Radius.circular(14));
    const inputBorderRadius = BorderRadius.all(Radius.circular(12));
    const buttonBorderRadius = BorderRadius.all(Radius.circular(12));

    const outlineBorder = OutlineInputBorder(
      borderRadius: inputBorderRadius,
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
          fontSize: 18,
          fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
              color: primaryDark,
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
            return const IconThemeData(color: primaryDark, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
      ),
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardBorderRadius,
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
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
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor, width: 1),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
