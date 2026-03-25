import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';

final class AppTheme {
  static ThemeData dark() {
    const background = Color(0xFF0D0E10);
    const panel = Color(0xFF111315);
    const panelRaised = Color(0xFF15181B);
    const panelMuted = Color(0xFF101214);
    const panelEmphasis = Color(0xFF181B1E);
    const line = Color(0xFF30343A);
    const lineSoft = Color(0xFF23272C);
    const accent = Color(0xFF39C8BA);
    const accentSoft = Color(0xFF7ADCD3);
    const text = Color(0xFFEAECEF);
    const muted = Color(0xFF9BA2AA);
    const success = Color(0xFF67D98A);
    const warning = Color(0xFFE2BF76);
    const danger = Color(0xFFEF8A8A);

    final textTheme =
        GoogleFonts.ibmPlexSansTextTheme(Typography.whiteMountainView)
            .apply(bodyColor: text, displayColor: text)
            .copyWith(
              headlineMedium: GoogleFonts.ibmPlexSans(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                height: 1.05,
                color: text,
              ),
              headlineSmall: GoogleFonts.ibmPlexSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
                height: 1.1,
                color: text,
              ),
              titleLarge: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
                height: 1.15,
                color: text,
              ),
              titleMedium: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
                height: 1.2,
                color: text,
              ),
              titleSmall: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                height: 1.25,
                color: text,
              ),
              bodyLarge: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.55,
                color: text,
              ),
              bodyMedium: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: text,
              ),
              bodySmall: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: muted,
              ),
              labelLarge: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
                height: 1.2,
                color: text,
              ),
              labelMedium: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1.2,
                color: muted,
              ),
            );

    final colorScheme = const ColorScheme.dark(
      primary: accent,
      surface: panel,
      onSurface: text,
      secondary: accentSoft,
      onPrimary: background,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: panelRaised.withValues(alpha: 0.82),
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: lineSoft),
        ),
      ),
      dividerColor: lineSoft,
      chipTheme: ChipThemeData(
        backgroundColor: panelMuted.withValues(alpha: 0.96),
        disabledColor: panelMuted,
        selectedColor: accent.withValues(alpha: 0.16),
        secondarySelectedColor: accent.withValues(alpha: 0.16),
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        side: const BorderSide(color: lineSoft),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          backgroundColor: panelMuted.withValues(alpha: 0.4),
          side: const BorderSide(color: lineSoft),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelMuted.withValues(alpha: 0.88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: lineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: lineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: panelMuted.withValues(alpha: 0.68),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: const BorderSide(color: lineSoft),
        ),
        iconColor: accentSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: Color(0x553A78A9),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      extensions: const [
        AppSurfaces(
          background: background,
          panel: panel,
          panelRaised: panelRaised,
          panelMuted: panelMuted,
          panelEmphasis: panelEmphasis,
          line: line,
          lineSoft: lineSoft,
          muted: muted,
          success: success,
          warning: warning,
          danger: danger,
          accentSoft: accentSoft,
        ),
      ],
    );
  }
}

@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.background,
    required this.panel,
    required this.panelRaised,
    required this.panelMuted,
    required this.panelEmphasis,
    required this.line,
    required this.lineSoft,
    required this.muted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.accentSoft,
  });

  final Color background;
  final Color panel;
  final Color panelRaised;
  final Color panelMuted;
  final Color panelEmphasis;
  final Color line;
  final Color lineSoft;
  final Color muted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color accentSoft;

  @override
  AppSurfaces copyWith({
    Color? background,
    Color? panel,
    Color? panelRaised,
    Color? panelMuted,
    Color? panelEmphasis,
    Color? line,
    Color? lineSoft,
    Color? muted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? accentSoft,
  }) {
    return AppSurfaces(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      panelMuted: panelMuted ?? this.panelMuted,
      panelEmphasis: panelEmphasis ?? this.panelEmphasis,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      muted: muted ?? this.muted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  AppSurfaces lerp(ThemeExtension<AppSurfaces>? other, double t) {
    if (other is! AppSurfaces) {
      return this;
    }
    return AppSurfaces(
      background: Color.lerp(background, other.background, t) ?? background,
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelRaised: Color.lerp(panelRaised, other.panelRaised, t) ?? panelRaised,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t) ?? panelMuted,
      panelEmphasis:
          Color.lerp(panelEmphasis, other.panelEmphasis, t) ?? panelEmphasis,
      line: Color.lerp(line, other.line, t) ?? line,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t) ?? lineSoft,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
    );
  }
}
