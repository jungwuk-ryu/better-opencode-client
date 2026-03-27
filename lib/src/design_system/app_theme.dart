import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';

enum AppThemePreset {
  remote,
  opencode,
  amoled,
  github,
  catppuccin,
  nord,
  rosepine,
  tokyonight,
  vercel,
  solarized;

  String get storageValue => name;

  static AppThemePreset fromStorage(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    return switch (normalized) {
      'opencode' => AppThemePreset.opencode,
      'amoled' => AppThemePreset.amoled,
      'github' => AppThemePreset.github,
      'catppuccin' => AppThemePreset.catppuccin,
      'nord' => AppThemePreset.nord,
      'rosepine' => AppThemePreset.rosepine,
      'tokyonight' => AppThemePreset.tokyonight,
      'vercel' => AppThemePreset.vercel,
      'solarized' => AppThemePreset.solarized,
      _ => AppThemePreset.remote,
    };
  }

  AppThemePresetDefinition get definition => switch (this) {
    AppThemePreset.remote => const AppThemePresetDefinition(
      label: 'Remote',
      summary: 'The current BOC default.',
      background: Color(0xFF0D0E10),
      text: Color(0xFFEAECEF),
      primary: Color(0xFF39C8BA),
      accent: Color(0xFF7ADCD3),
      success: Color(0xFF67D98A),
      warning: Color(0xFFE2BF76),
      danger: Color(0xFFEF8A8A),
      muted: Color(0xFF9BA2AA),
    ),
    AppThemePreset.opencode => const AppThemePresetDefinition(
      label: 'OpenCode',
      summary: 'Warm terminals and violet accents.',
      background: Color(0xFF0A0A0A),
      text: Color(0xFFEEEEEE),
      primary: Color(0xFFFAB283),
      accent: Color(0xFF9D7CD8),
      success: Color(0xFF7FD88F),
      warning: Color(0xFFF5A742),
      danger: Color(0xFFE06C75),
      muted: Color(0xFF808080),
    ),
    AppThemePreset.amoled => const AppThemePresetDefinition(
      label: 'AMOLED',
      summary: 'Pure black with neon contrast.',
      background: Color(0xFF000000),
      text: Color(0xFFFFFFFF),
      primary: Color(0xFFB388FF),
      accent: Color(0xFFFF4081),
      success: Color(0xFF00FF88),
      warning: Color(0xFFFFEA00),
      danger: Color(0xFFFF1744),
      muted: Color(0xFF777777),
    ),
    AppThemePreset.github => const AppThemePresetDefinition(
      label: 'GitHub',
      summary: 'Cool steel with code-hosting blues.',
      background: Color(0xFF0D1117),
      text: Color(0xFFC9D1D9),
      primary: Color(0xFF58A6FF),
      accent: Color(0xFF39C5CF),
      success: Color(0xFF3FB950),
      warning: Color(0xFFE3B341),
      danger: Color(0xFFF85149),
      muted: Color(0xFF8B949E),
    ),
    AppThemePreset.catppuccin => const AppThemePresetDefinition(
      label: 'Catppuccin',
      summary: 'Soft mauves and milk-glass text.',
      background: Color(0xFF1E1E2E),
      text: Color(0xFFCDD6F4),
      primary: Color(0xFFB4BEFE),
      accent: Color(0xFFF38BA8),
      success: Color(0xFFA6D189),
      warning: Color(0xFFF4B8E4),
      danger: Color(0xFFF38BA8),
      muted: Color(0xFF6C7086),
    ),
    AppThemePreset.nord => const AppThemePresetDefinition(
      label: 'Nord',
      summary: 'Arctic slate with frosted cyan.',
      background: Color(0xFF2E3440),
      text: Color(0xFFE5E9F0),
      primary: Color(0xFF88C0D0),
      accent: Color(0xFFD57780),
      success: Color(0xFFA3BE8C),
      warning: Color(0xFFD08770),
      danger: Color(0xFFBF616A),
      muted: Color(0xFF616E88),
    ),
    AppThemePreset.rosepine => const AppThemePresetDefinition(
      label: 'Rose Pine',
      summary: 'Dusky plum with soft rose light.',
      background: Color(0xFF191724),
      text: Color(0xFFE0DEF4),
      primary: Color(0xFF9CCFD8),
      accent: Color(0xFFEBBCBA),
      success: Color(0xFF31748F),
      warning: Color(0xFFF6C177),
      danger: Color(0xFFEB6F92),
      muted: Color(0xFF6E6A86),
    ),
    AppThemePreset.tokyonight => const AppThemePresetDefinition(
      label: 'Tokyonight',
      summary: 'Midnight indigo with bright neon edges.',
      background: Color(0xFF1A1B26),
      text: Color(0xFFC0CAF5),
      primary: Color(0xFF7AA2F7),
      accent: Color(0xFFFF9E64),
      success: Color(0xFF9ECE6A),
      warning: Color(0xFFE0AF68),
      danger: Color(0xFFF7768E),
      muted: Color(0xFF565F89),
    ),
    AppThemePreset.vercel => const AppThemePresetDefinition(
      label: 'Vercel',
      summary: 'True black with product-brand electric blue.',
      background: Color(0xFF000000),
      text: Color(0xFFEDEDED),
      primary: Color(0xFF0070F3),
      accent: Color(0xFF8E4EC6),
      success: Color(0xFF46A758),
      warning: Color(0xFFFFB224),
      danger: Color(0xFFE5484D),
      muted: Color(0xFF878787),
    ),
    AppThemePreset.solarized => const AppThemePresetDefinition(
      label: 'Solarized',
      summary: 'Deep teal with classic amber-magenta notes.',
      background: Color(0xFF002B36),
      text: Color(0xFF93A1A1),
      primary: Color(0xFF6C71C4),
      accent: Color(0xFFD33682),
      success: Color(0xFF859900),
      warning: Color(0xFFB58900),
      danger: Color(0xFFDC322F),
      muted: Color(0xFF586E75),
    ),
  };
}

@immutable
class AppThemePresetDefinition {
  const AppThemePresetDefinition({
    required this.label,
    required this.summary,
    required this.background,
    required this.text,
    required this.primary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
  });

  final String label;
  final String summary;
  final Color background;
  final Color text;
  final Color primary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color muted;
}

final class AppTheme {
  static final Map<AppThemePreset, ThemeData> _cache =
      <AppThemePreset, ThemeData>{};

  static ThemeData dark([AppThemePreset preset = AppThemePreset.remote]) {
    return _cache.putIfAbsent(preset, () => _buildTheme(preset.definition));
  }

  static ThemeData theme(AppThemePreset preset) => dark(preset);

  static AppThemePresetDefinition definition(AppThemePreset preset) =>
      preset.definition;

  static ThemeData _buildTheme(AppThemePresetDefinition preset) {
    final background = preset.background;
    final text = preset.text;
    final panel = _mix(background, text, 0.050);
    final panelRaised = _mix(background, text, 0.082);
    final panelMuted = _mix(background, text, 0.036);
    final panelEmphasis = _mix(background, text, 0.116);
    final line = _mix(background, text, 0.200);
    final lineSoft = _mix(background, text, 0.125);
    final accent = preset.primary;
    final accentSoft = preset.accent;
    final muted = preset.muted;
    final success = preset.success;
    final warning = preset.warning;
    final danger = preset.danger;

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

    final colorScheme = ColorScheme.dark(
      primary: accent,
      secondary: accentSoft,
      surface: panel,
      onSurface: text,
      onPrimary: _onColor(accent),
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: panelRaised.withValues(alpha: 0.84),
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: lineSoft),
        ),
      ),
      dividerColor: lineSoft,
      chipTheme: ChipThemeData(
        backgroundColor: panelMuted.withValues(alpha: 0.96),
        disabledColor: panelMuted,
        selectedColor: accent.withValues(alpha: 0.16),
        secondarySelectedColor: accent.withValues(alpha: 0.16),
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        side: BorderSide(color: lineSoft),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: _onColor(accent),
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
          side: BorderSide(color: lineSoft),
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
          borderSide: BorderSide(color: lineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: BorderSide(color: lineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: BorderSide(color: accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.formFieldRadius),
          borderSide: BorderSide(color: danger),
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
          side: BorderSide(color: lineSoft),
        ),
        iconColor: accentSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: accentSoft,
        disabledActionTextColor: muted,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.30),
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
      extensions: <ThemeExtension<dynamic>>[
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

  static Color _mix(Color from, Color to, double amount) {
    return Color.lerp(from, to, amount) ?? from;
  }

  static Color _onColor(Color fill) {
    return ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;
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
