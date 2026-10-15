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
  static const Color secondaryColor = warningColor;
  static const Color secondaryLight = warningLight;
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentTealLight = Color(0xFFCCFBF1);
  static const Color accentBlue = infoColor;
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

  // Gradients cho Dashboard hiện đại
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroEmeraldGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<BoxShadow> modernElevation = [
    BoxShadow(
      color: Color.fromRGBO(16, 163, 106, 0.22),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // ==========================================
  // DARK MODE TOKENS - DEEP EMERALD SLATE
  // ==========================================
  static const Color darkBackground = Color(0xFF0B1120); // Slate 950 sâu thẳm
  static const Color darkCard = Color(0xFF1E293B); // Slate 800 bề mặt thẻ
  static const Color darkCardElevated = Color(0xFF243048); // Slate 750 phân tầng cao
  static const Color darkBorder = Color(0xFF334155); // Slate 700 viền
  static const Color darkBorderSubtle = Color(0x1FFFFFFF); // Viền mờ 12%

  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50 trắng sáng dịu
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400 xám bạc rõ ràng
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500

  // Thẻ trạng thái phát quang (Glow Tint) cho Dark Mode
  static const Color darkSafeBg = Color(0x2610B981); // Emerald 15%
  static const Color darkSafeBorder = Color(0x4D34D399); // Emerald 30%
  static const Color darkSafeText = Color(0xFF34D399); // Emerald neon

  static const Color darkWarningBg = Color(0x26F59E0B); // Amber 15%
  static const Color darkWarningBorder = Color(0x4DFBBF24); // Amber 30%
  static const Color darkWarningText = Color(0xFFFBBF24); // Amber neon

  static const Color darkDangerBg = Color(0x26EF4444); // Rose 15%
  static const Color darkDangerBorder = Color(0x4DF87171); // Rose 30%
  static const Color darkDangerText = Color(0xFFF87171); // Rose neon

  static const Color darkInfoBg = Color(0x263B82F6); // Blue 15%
  static const Color darkInfoBorder = Color(0x4D60A5FA); // Blue 30%
  static const Color darkInfoText = Color(0xFF60A5FA); // Blue neon

  // Dark Gradients & Shadows
  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF0F766E), Color(0xFF065F46)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF162032)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<BoxShadow> darkCardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // ==========================================
  // DYNAMIC CONTEXT-AWARE HELPERS
  // ==========================================
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? darkBackground : backgroundColor;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkCard : cardColor;

  static Color elevatedCardBg(BuildContext context) =>
      isDark(context) ? darkCardElevated : cardColor;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : borderColor;

  static Color textPrimaryColor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color safeBgColor(BuildContext context) =>
      isDark(context) ? darkSafeBg : safeBg;

  static Color safeTextColor(BuildContext context) =>
      isDark(context) ? darkSafeText : safeText;

  static Color safeBorderColor(BuildContext context) =>
      isDark(context) ? darkSafeBorder : safeBorder;

  static Color warningBgColor(BuildContext context) =>
      isDark(context) ? darkWarningBg : warningBg;

  static Color warningTextColor(BuildContext context) =>
      isDark(context) ? darkWarningText : warningText;

  static Color warningBorderColor(BuildContext context) =>
      isDark(context) ? darkWarningBorder : warningBorder;

  static Color dangerBgColor(BuildContext context) =>
      isDark(context) ? darkDangerBg : dangerBg;

  static Color dangerTextColor(BuildContext context) =>
      isDark(context) ? darkDangerText : dangerText;

  static Color dangerBorderColor(BuildContext context) =>
      isDark(context) ? darkDangerBorder : dangerBorder;

  static Color infoBgColor(BuildContext context) =>
      isDark(context) ? darkInfoBg : infoLight;

  static Color infoTextColor(BuildContext context) =>
      isDark(context) ? darkInfoText : infoColor;

  static LinearGradient heroGradient(BuildContext context) =>
      isDark(context) ? darkHeroGradient : heroEmeraldGradient;

  static BoxDecoration modernCardDecoration(
    BuildContext context, {
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? darkCard : cardColor,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: Border.all(
        color: borderColor ?? (dark ? darkBorder : AppTheme.borderColor),
        width: 1,
      ),
      boxShadow: dark ? darkCardShadow : cardShadow,
    );
  }

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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
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

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      surface: darkCard,
    ).copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF064E3B),
      onPrimaryContainer: darkSafeText,
      secondary: warningColor,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF451A03),
      onSecondaryContainer: darkWarningText,
      error: dangerColor,
      errorContainer: const Color(0xFF4C0519),
      onErrorContainer: darkDangerText,
      surface: darkCard,
      onSurface: darkTextPrimary,
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      outlineVariant: const Color(0xFF1E293B),
    );

    const cardBorderRadius = BorderRadius.all(Radius.circular(14));
    const inputBorderRadius = BorderRadius.all(Radius.circular(12));
    const buttonBorderRadius = BorderRadius.all(Radius.circular(12));

    const outlineBorder = OutlineInputBorder(
      borderRadius: inputBorderRadius,
      borderSide: BorderSide(color: darkBorder, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkBorder,
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: darkBorder, width: 1)),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.25),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: darkSafeText,
            );
          }
          return const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkSafeText, size: 24);
          }
          return const IconThemeData(color: darkTextSecondary, size: 24);
        }),
      ),
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardBorderRadius,
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF131D31),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
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
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder, width: 1),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkCardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(color: darkTextPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
