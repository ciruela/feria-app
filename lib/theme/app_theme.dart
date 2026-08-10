// Tokens del sistema visual "Cobre táctico" — app de catálogo de armería.
// Fuente de verdad: handoffs design_handoff_vendedor / design_handoff_admin.
// Las pantallas no deben declarar Color(...) literales fuera de acá.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Superficies (de más profunda a más elevada) ──────────────────
  /// Fondo del lienzo, detrás de todo.
  static const canvas = Color(0xFF0D0B0A);

  /// Fondo de pantalla. Es el color base de cada vista.
  static const surface = Color(0xFF12100E);

  /// Tarjetas, franjas de datos, barras, hojas modales.
  static const surfaceRaised = Color(0xFF1A1613);

  /// Elementos táctiles secundarios: avatares, teclas, botones neutros.
  static const surfaceTouch = Color(0xFF241E1A);

  // ── Líneas ───────────────────────────────────────────────────────
  /// Borde de contenedor. Siempre 0.5 px.
  static const border = Color(0xFF2C2721);

  /// Separador entre filas. rgba(237,231,222,0.10).
  static const divider = Color(0x1AEDE7DE);

  // ── Texto ────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFEDE7DE);

  /// Rótulos y metadatos. Contraste 4.9:1 sobre surface.
  static const textMuted = Color(0xFF9A9088);

  // ── Acento ───────────────────────────────────────────────────────
  /// Cobre. ÚNICO acento del sistema.
  static const accent = Color(0xFFE2622F);

  /// Texto e íconos sobre [accent]. Contraste 4.6:1.
  static const onAccent = Color(0xFF3D1607);

  static const accentHover = Color(0xFFEE7B4B);

  // ── Velos ────────────────────────────────────────────────────────
  /// Fondo detrás de una hoja modal. rgba(13,11,10,0.72).
  static const scrim = Color(0xB80D0B0A);

  // ── Comprobante impreso ──────────────────────────────────────────
  static const paper = Color(0xFFF7F3EC);
  static const paperShade = Color(0xFFE6E0D6);
  static const paperInk = Color(0xFF2A2622);
  static const paperInkMuted = Color(0xFF4A443C);
  static const paperRule = Color(0xFFB8B0A4);

  // ── Aliases de compatibilidad (tema anterior → Cobre táctico) ────
  // Se van eliminando a medida que cada pantalla migra al handoff.
  static const background = surface;
  static const backgroundDark = canvas;
  static const surfaceMuted = surfaceTouch;
  static const primary = textPrimary;
  static const primaryLight = surfaceTouch;
  static const primaryDark = canvas;
  static const accentLight = accentHover;
  static const gold = accent;
  static const goldDark = accentHover;
  static const textSecondary = textMuted;
  /// Sin semáforo: el sistema usa cobre + opacidad.
  static const danger = accent;
  static const success = textPrimary;
  static const armaCorta = textMuted;
  static const armaLarga = textMuted;
  static const municion = textMuted;
  static const accesorios = textMuted;
}

class AppDecorations {
  AppDecorations._();

  static const double radius = 4.0;
  static const double radiusSheet = 12.0;
  static const double radiusDevice = 36.0;

  static const double hairline = 0.5;
  static const double accentBar = 2.0;

  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;

  static const double tapMin = 44.0;
  static const double rowDense = 44.0;
  static const double rowMedium = 56.0;
  static const double buttonPrimary = 48.0;

  static const containerBorder = BorderSide(
    color: AppColors.border,
    width: hairline,
  );

  static const dividerBorder = BorderSide(
    color: AppColors.divider,
    width: hairline,
  );

  static BoxDecoration get card => BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.border, width: hairline),
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration get cardFlagged => BoxDecoration(
        color: AppColors.surfaceRaised,
        border: const Border(
          top: containerBorder,
          right: containerBorder,
          bottom: containerBorder,
          left: BorderSide(color: AppColors.accent, width: accentBar),
        ),
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration get buttonAccent => BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration get buttonNeutral => BoxDecoration(
        color: AppColors.surfaceTouch,
        borderRadius: BorderRadius.circular(radius),
      );

  /// Único uso de sombra en el sistema (vendedor seleccionado).
  static const List<BoxShadow> tileLifted = [
    BoxShadow(
      color: Color(0x333D1607),
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static const List<BoxShadow> avatarGlow = [
    BoxShadow(color: Color(0x4DE2622F), blurRadius: 18),
    BoxShadow(color: Color(0x80EB9669), blurRadius: 6),
  ];

  // Aliases del tema anterior (gradientes / radios grandes → flat cobre).
  static const appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.canvas, AppColors.surface, AppColors.surfaceRaised],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surfaceRaised, AppColors.surfaceTouch],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accent, AppColors.accentHover],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentHover, AppColors.accent],
  );

  static BoxShadow get cardShadow => const BoxShadow(
        color: Color(0x00000000),
        blurRadius: 0,
        offset: Offset.zero,
      );

  static BoxShadow get softShadow => const BoxShadow(
        color: Color(0x00000000),
        blurRadius: 0,
        offset: Offset.zero,
      );

  static BorderRadius get radiusLg => BorderRadius.circular(radius);
  static BorderRadius get radiusMd => BorderRadius.circular(radius);
  static BorderRadius get radiusSm => BorderRadius.circular(radius);
}

/// Tipografía. Dos familias, sin excepciones.
///
///   Instrument Sans  → texto corrido, títulos, rótulos de UI.
///   IBM Plex Mono    → números, códigos, stock, fechas, VERSALITAS.
class AppText {
  AppText._();

  static const String sans = 'Instrument Sans';
  static const String mono = 'IBM Plex Mono';

  static const display = TextStyle(
    fontFamily: mono,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 1.0,
    color: AppColors.textPrimary,
  );
  static const title = TextStyle(
    fontFamily: sans,
    fontSize: 21,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const heading = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const subheading = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const bodyLarge = TextStyle(
    fontFamily: sans,
    fontSize: 13.5,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    color: AppColors.textPrimary,
  );
  static const bodySmall = TextStyle(
    fontFamily: sans,
    fontSize: 11.5,
    color: AppColors.textMuted,
  );
  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    color: AppColors.textMuted,
  );

  /// Rótulo de sección: mono, versalita, tracking 0.06em.
  static const label = TextStyle(
    fontFamily: mono,
    fontSize: 10.5,
    letterSpacing: 0.63,
    color: AppColors.textMuted,
  );

  static const numberLarge = TextStyle(
    fontFamily: mono,
    fontSize: 21,
    fontWeight: FontWeight.w500,
    height: 1.0,
    color: AppColors.textPrimary,
  );
  static const number = TextStyle(
    fontFamily: mono,
    fontSize: 13.5,
    color: AppColors.textPrimary,
  );
  static const numberSmall = TextStyle(
    fontFamily: mono,
    fontSize: 12.5,
    color: AppColors.textPrimary,
  );
  static const code = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    color: AppColors.textMuted,
  );

  static const displayDesktop = TextStyle(
    fontFamily: mono,
    fontSize: 34,
    fontWeight: FontWeight.w500,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  static const paperBody = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    color: AppColors.paperInk,
  );
  static const paperCaption = TextStyle(
    fontFamily: sans,
    fontSize: 9,
    color: AppColors.paperInkMuted,
  );
  static const paperNumber = TextStyle(
    fontFamily: mono,
    fontSize: 8.5,
    color: AppColors.paperInk,
  );
}

class AppTheme {
  /// Identidad visual del producto: superficie oscura + cobre.
  /// No es un "modo oscuro" opcional — es el único tema.
  static ThemeData light() {
    const sans = AppText.sans;
    const mono = AppText.mono;

    TextStyle sansStyle({
      double size = 13.5,
      FontWeight weight = FontWeight.w400,
      Color color = AppColors.textPrimary,
      double? letterSpacing,
      double? height,
    }) {
      return TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }

    final textTheme = TextTheme(
      displayLarge: sansStyle(size: 34, weight: FontWeight.w500),
      displayMedium: const TextStyle(
        fontFamily: mono,
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.0,
      ),
      displaySmall: sansStyle(size: 21, weight: FontWeight.w500),
      headlineLarge: sansStyle(size: 21, weight: FontWeight.w500),
      headlineMedium: sansStyle(size: 17, weight: FontWeight.w500),
      headlineSmall: sansStyle(size: 15, weight: FontWeight.w500),
      titleLarge: sansStyle(size: 17, weight: FontWeight.w500),
      titleMedium: sansStyle(size: 15, weight: FontWeight.w500),
      titleSmall: sansStyle(size: 13.5, weight: FontWeight.w500),
      bodyLarge: sansStyle(size: 13.5),
      bodyMedium: sansStyle(size: 12.5, color: AppColors.textMuted),
      bodySmall: sansStyle(size: 11.5, color: AppColors.textMuted),
      labelLarge: sansStyle(size: 13.5, weight: FontWeight.w500, color: AppColors.onAccent),
      labelMedium: const TextStyle(
        fontFamily: mono,
        fontSize: 10.5,
        letterSpacing: 0.63,
        color: AppColors.textMuted,
      ),
      labelSmall: sansStyle(size: 11, color: AppColors.textMuted),
    );

    final radius = BorderRadius.circular(AppDecorations.radius);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.surface,
      canvasColor: AppColors.canvas,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        surface: AppColors.surfaceRaised,
        onSurface: AppColors.textPrimary,
        error: AppColors.accent,
        onError: AppColors.onAccent,
        outline: AppColors.border,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: sansStyle(size: 17, weight: FontWeight.w500),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(
            color: AppColors.border,
            width: AppDecorations.hairline,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppDecorations.hairline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppDecorations.hairline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.accent, width: 1),
        ),
        labelStyle: sansStyle(size: 12.5, color: AppColors.textMuted),
        hintStyle: sansStyle(size: 12.5, color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.onAccent.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: sansStyle(size: 13.5, weight: FontWeight.w500, color: AppColors.onAccent),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(72, AppDecorations.tapMin),
          textStyle: sansStyle(size: 13.5, weight: FontWeight.w500),
          side: const BorderSide(
            color: AppColors.border,
            width: AppDecorations.hairline,
          ),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: sansStyle(size: 13.5, weight: FontWeight.w500),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceTouch,
        contentTextStyle: sansStyle(size: 13.5, weight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: sansStyle(size: 17, weight: FontWeight.w500),
        contentTextStyle: sansStyle(size: 13.5, color: AppColors.textMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceRaised,
        modalBackgroundColor: AppColors.surfaceRaised,
        modalBarrierColor: AppColors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDecorations.radiusSheet),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: AppDecorations.hairline,
        space: AppDecorations.hairline,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceRaised,
        selectedColor: AppColors.textPrimary,
        disabledColor: AppColors.surfaceTouch.withValues(alpha: 0.5),
        labelStyle: sansStyle(size: 12.5, color: AppColors.textMuted),
        secondaryLabelStyle: sansStyle(size: 12.5, color: AppColors.surface),
        side: const BorderSide(
          color: AppColors.border,
          width: AppDecorations.hairline,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      iconTheme: const IconThemeData(color: AppColors.textMuted, size: 20),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }
}
