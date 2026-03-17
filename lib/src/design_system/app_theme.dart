import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final class AppTheme {
  static ThemeData dark() {
    const background = Color(0xFF081019);
    const panel = Color(0xFF0F1824);
    const panelRaised = Color(0xFF152131);
    const line = Color(0xFF22344C);
    const accent = Color(0xFF9FD4FF);
    const text = Color(0xFFF5F7FB);
    const muted = Color(0xFF9DAABC);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      Typography.whiteMountainView,
    ).apply(bodyColor: text, displayColor: text);

    final colorScheme = const ColorScheme.dark(
      primary: accent,
      surface: panel,
      onSurface: text,
      secondary: Color(0xFF78B7F2),
      onPrimary: background,
      error: Color(0xFFFF8B8B),
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
          borderRadius: BorderRadius.circular(24),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
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
  });

  final Color background;
  final Color panel;
  final Color panelRaised;
  final Color line;
  final Color muted;

  @override
  AppSurfaces copyWith({
    Color? background,
    Color? panel,
    Color? panelRaised,
    Color? line,
    Color? muted,
  }) {
    return AppSurfaces(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      line: line ?? this.line,
      muted: muted ?? this.muted,
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
    );
  }
}
