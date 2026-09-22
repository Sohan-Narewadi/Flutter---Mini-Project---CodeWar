import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CodeWar dark palette, extracted from the Stitch Material-3-style
/// tailwind config shared across battle_arena / world_map / coding_battle_ide.
class AppColors {
  AppColors._();

  static const background = Color(0xFF10141A);
  static const surfaceContainerLow = Color(0xFF181C22);
  static const surfaceContainer = Color(0xFF1C2026);
  static const surfaceContainerHigh = Color(0xFF262A31);
  static const surfaceContainerHighest = Color(0xFF31353C);
  static const surfaceContainerLowest = Color(0xFF0A0E14);

  static const primary = Color(0xFFD0BCFF);
  static const onPrimary = Color(0xFF3C0091);
  static const primaryContainer = Color(0xFFA078FF);

  static const secondary = Color(0xFF7BD0FF);
  static const secondaryContainer = Color(0xFF00A6E0);

  static const tertiary = Color(0xFFFFB95F);
  static const tertiaryContainer = Color(0xFFCA8100);

  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);

  static const onSurface = Color(0xFFDFE2EB);
  static const onSurfaceVariant = Color(0xFFCBC3D7);
  static const outline = Color(0xFF958EA0);
  static const outlineVariant = Color(0xFF494454);

  // Semantic aliases used across screens
  static const success = Color(0xFF7BD0FF);
}

class AppRadius {
  AppRadius._();
  static const sm = 4.0;
  static const lg = 8.0;
  static const xl = 12.0;
  static const full = 999.0;
}

class AppTheme {
  AppTheme._();

  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.onSurface,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    );

    final colorScheme = const ColorScheme.dark().copyWith(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryContainer,
      tertiary: AppColors.tertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      error: AppColors.error,
      errorContainer: AppColors.errorContainer,
      surface: AppColors.background,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      dividerColor: AppColors.outlineVariant,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.outlineVariant),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceContainerHigh,
        labelStyle: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 12),
        side: const BorderSide(color: AppColors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceContainerHigh,
      ),
    );
  }
}
