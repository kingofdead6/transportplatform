import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Section 11.3/11.6 — Archivo Condensed for Latin digits/numbers, IBM Plex Sans Arabic
/// for Arabic body text. Sharp corners (2-6px), no shadows, borders/backgrounds only.
class AppTheme {
  AppTheme._();

  static const double radiusSm = 2;
  static const double radiusMd = 6;

  static ThemeData light(String languageCode) {
    final isArabic = languageCode == 'ar';
    final fontFamily = isArabic ? 'IBMPlexSansArabic' : 'ArchivoCondensed';

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.beton,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sangle,
        primary: AppColors.sangle,
        onPrimary: AppColors.bitume,
        secondary: AppColors.acier,
        surface: AppColors.white,
        error: AppColors.halte,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bitume,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sangle,
          foregroundColor: AppColors.bitume,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.bitume,
          side: const BorderSide(color: AppColors.acier),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.bitume),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.acier, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.acier, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.sangle, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.halte, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: Color(0xFFE2E6E8)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE2E6E8), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bitume,
        contentTextStyle: const TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.beton,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        side: const BorderSide(color: Color(0xFFE2E6E8)),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
