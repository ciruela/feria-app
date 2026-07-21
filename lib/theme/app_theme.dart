import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFEDE8DF);
  static const backgroundDark = Color(0xFFE2DAD0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F4EF);

  static const primary = Color(0xFF1B2838);
  static const primaryLight = Color(0xFF2A3F54);
  static const primaryDark = Color(0xFF111B26);

  static const accent = Color(0xFF3D8B6E);
  static const accentLight = Color(0xFF5BA888);
  static const gold = Color(0xFFD4A853);
  static const goldDark = Color(0xFFB8892E);

  static const armaCorta = Color(0xFF3B6EA8);
  static const armaLarga = Color(0xFF2F6B54);
  static const municion = Color(0xFFB86E2A);

  static const textPrimary = Color(0xFF1A1F26);
  static const textSecondary = Color(0xFF5C6672);
  static const border = Color(0xFFD8CEC0);
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF2D6A4F);
}

class AppDecorations {
  static const appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF243447), AppColors.primary],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.goldDark],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentLight, AppColors.accent],
  );

  static BoxShadow get cardShadow => BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.10),
        blurRadius: 24,
        offset: const Offset(0, 10),
      );

  static BoxShadow get softShadow => BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );

  static BorderRadius get radiusLg => BorderRadius.circular(24);
  static BorderRadius get radiusMd => BorderRadius.circular(18);
  static BorderRadius get radiusSm => BorderRadius.circular(14);
}

class AppTheme {
  static TextTheme _textTheme(TextTheme base) {
    return GoogleFonts.outfitTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  static ThemeData light() {
    final textTheme = _textTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusMd,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: AppDecorations.radiusSm,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusSm,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusSm,
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(64),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusMd,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(72, 56),
          textStyle: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusSm,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusSm,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusMd,
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
