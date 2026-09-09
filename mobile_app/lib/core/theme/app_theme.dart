import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Clean, light, minimal design: white surfaces, soft shadows instead of hard borders,
/// generous rounding, confident single-accent CTAs, and a calm typographic hierarchy.
class AppTheme {
  AppTheme._();

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;

  static List<BoxShadow> get softShadow => [
        BoxShadow(color: AppColors.bitume.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        BoxShadow(color: AppColors.bitume.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  static ThemeData light(String languageCode) {
    final isArabic = languageCode == 'ar';
    final fontFamily = isArabic ? 'IBMPlexSansArabic' : 'ArchivoCondensed';

    final textTheme = TextTheme(
      displaySmall: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
      headlineMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3),
      headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
      bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.acier),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      labelSmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.acier),
    ).apply(fontFamily: fontFamily, bodyColor: AppColors.bitume, displayColor: AppColors.bitume);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.beton,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sangle,
        primary: AppColors.sangle,
        onPrimary: AppColors.white,
        secondary: AppColors.bitume,
        surface: AppColors.white,
        error: AppColors.halte,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.beton,
        foregroundColor: AppColors.bitume,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.bitume,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.bitume),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sangle,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.sangle.withValues(alpha: 0.4),
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.bitume,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          backgroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sangle,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.bitume),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(color: AppColors.acier, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: AppColors.acier, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.sangle, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.halte, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.halte, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bitume,
        contentTextStyle: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.sangle,
        unselectedItemColor: AppColors.acier,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.white,
        selectedIconTheme: IconThemeData(color: AppColors.sangle),
        unselectedIconTheme: IconThemeData(color: AppColors.acier),
        selectedLabelTextStyle: TextStyle(color: AppColors.bitume, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: AppColors.acier),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: const TextStyle(color: AppColors.bitume, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(color: AppColors.acier, fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.acier,
        textColor: AppColors.bitume,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.sangle),
    );
  }
}
