import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';

final class AppTheme {
  static ThemeData dark() {
    const background = Color(0xFF081019);
    const panel = Color(0xFF0F1824);
    const panelRaised = Color(0xFF152131);
    const line = Color(0xFF22344C);
    const accent = Color(0xFF9FD4FF);
    const accentSoft = Color(0xFF78B7F2);
    const text = Color(0xFFF5F7FB);
    const muted = Color(0xFF9DAABC);
    const success = Color(0xFF8BE39B);
    const warning = Color(0xFFFFD27A);
    const danger = Color(0xFFFF8B8B);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      Typography.whiteMountainView,
    ).apply(bodyColor: text, displayColor: text);

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
        color: panel.withValues(alpha: 0.92),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: line),
        ),
      ),
      dividerColor: line,
      chipTheme: ChipThemeData(
        backgroundColor: panelRaised,
        disabledColor: panelRaised,
        selectedColor: accent.withValues(alpha: 0.16),
        secondarySelectedColor: accent.withValues(alpha: 0.16),
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelRaised.withValues(alpha: 0.88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: const BorderSide(color: line),
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
        tileColor: panelRaised.withValues(alpha: 0.64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: const BorderSide(color: line),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          line: line,
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
    required this.line,
    required this.muted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.accentSoft,
  });

  final Color background;
  final Color panel;
  final Color panelRaised;
  final Color line;
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
    Color? line,
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
      line: line ?? this.line,
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
      line: Color.lerp(line, other.line, t) ?? line,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
    );
  }
}
