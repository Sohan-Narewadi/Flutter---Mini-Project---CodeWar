import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CodeWar "neon arcade" palette: a near-black navy base with ONE electric
/// accent (cyan). Gold is reserved for rewards, green for success and red for
/// danger. The violet [accentDeep] only appears as the second stop of the
/// accent gradient.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = Color(0xFF0A0C14);
  static const surfaceLow = Color(0xFF0D1019);
  static const surface = Color(0xFF11141F);
  static const surfaceHigh = Color(0xFF181C2B);
  static const surfaceHighest = Color(0xFF212638);
  static const surfaceLowest = Color(0xFF070910);
  static const line = Color(0xFF262B3F);

  // Brand
  static const accent = Color(0xFF2BE4FF);
  static const accentDim = Color(0xFF12A9C4);
  static const accentDeep = Color(0xFF7C5CFF);
  static const onAccent = Color(0xFF03141C);

  // Semantic
  static const gold = Color(0xFFFFC24B);
  static const goldDim = Color(0xFFB8841F);
  static const success = Color(0xFF34F5A5);
  static const danger = Color(0xFFFF5C7A);
  static const dangerDim = Color(0xFF7A1630);

  // Text
  static const text = Color(0xFFEEF1FF);
  static const textDim = Color(0xFFA4ABC8);
  static const textFaint = Color(0xFF6C7391);

  // Rank medals
  static const silver = Color(0xFFC9D2E8);
  static const bronze = Color(0xFFD9915B);

  /// The signature gradient used by primary buttons and hero accents.
  static const accentGradient = LinearGradient(
    colors: [accent, accentDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadius {
  AppRadius._();
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const full = 999.0;
}

class AppSpace {
  AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal page padding.
  static const page = 20.0;

  /// Max width of page content on wide screens.
  static const maxContentWidth = 560.0;
}

class AppTheme {
  AppTheme._();

  /// Display / numeral face (headlines, big numbers, buttons).
  static TextStyle display({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.chakraPetch(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.text,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small caps-style overline used for section labels.
  static TextStyle overline({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
      color: color ?? AppColors.textFaint,
    );
  }

  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.text,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final body = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    final textTheme = body.copyWith(
      displayLarge: display(fontSize: 40),
      displayMedium: display(fontSize: 32),
      displaySmall: display(fontSize: 28),
      headlineLarge: display(fontSize: 28),
      headlineMedium: display(fontSize: 24),
      headlineSmall: display(fontSize: 20),
      titleLarge: display(fontSize: 20),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );

    final colorScheme = const ColorScheme.dark().copyWith(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.accentDeep,
      secondary: AppColors.accent,
      secondaryContainer: AppColors.accentDim,
      tertiary: AppColors.gold,
      tertiaryContainer: AppColors.goldDim,
      error: AppColors.danger,
      errorContainer: AppColors.dangerDim,
      surface: AppColors.background,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textDim,
      outline: AppColors.textFaint,
      outlineVariant: AppColors.line,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.line),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(fontSize: 20),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerColor: AppColors.line,
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        space: 1,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          textStyle: display(fontSize: 15, letterSpacing: 0.4),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: buttonShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          textStyle: display(fontSize: 15, letterSpacing: 0.4),
          minimumSize: const Size(48, 52),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          textStyle: display(fontSize: 15, letterSpacing: 0.4),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
          minimumSize: const Size(48, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.textDim),
        hintStyle: GoogleFonts.inter(color: AppColors.textFaint),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceHigh,
        selectedColor: AppColors.accent.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.inter(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.line),
        ),
        titleTextStyle: display(fontSize: 20),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHighest,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: GoogleFonts.inter(color: AppColors.text, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onAccent
              : AppColors.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.surfaceHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
