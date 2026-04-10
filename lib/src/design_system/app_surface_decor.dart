import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_theme.dart';

enum AppSurfaceTone { neutral, accent, success, warning, danger }

Color _toneAccent(ThemeData theme, AppSurfaces surfaces, AppSurfaceTone tone) {
  return switch (tone) {
    AppSurfaceTone.neutral => theme.colorScheme.primary,
    AppSurfaceTone.accent => theme.colorScheme.primary,
    AppSurfaceTone.success => surfaces.success,
    AppSurfaceTone.warning => surfaces.warning,
    AppSurfaceTone.danger => theme.colorScheme.error,
  };
}

BoxDecoration appSoftCardDecoration(
  BuildContext context, {
  double radius = AppSpacing.panelRadius,
  AppSurfaceTone tone = AppSurfaceTone.neutral,
  bool emphasized = false,
  bool muted = false,
  bool selected = false,
}) {
  final theme = Theme.of(context);
  final surfaces = theme.extension<AppSurfaces>()!;
  final accent = _toneAccent(theme, surfaces, tone);
  final background = selected
      ? Color.alphaBlend(
          accent.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.045 : 0.06,
          ),
          surfaces.panelEmphasis.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.96 : 0.985,
          ),
        )
      : muted
      ? surfaces.panelMuted.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.94 : 0.975,
        )
      : surfaces.panelRaised.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.96 : 0.985,
        );
  return BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected
          ? accent.withValues(alpha: 0.24)
          : emphasized
          ? surfaces.line.withValues(alpha: 0.82)
          : surfaces.lineSoft.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.94 : 0.98,
            ),
      width: selected || emphasized ? 1.1 : 1,
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.22 : 0.05,
        ),
        blurRadius: emphasized || selected ? 16 : 10,
        spreadRadius: emphasized ? -8 : -10,
        offset: Offset(0, emphasized || selected ? 8 : 5),
      ),
    ],
  );
}

class AppGlassPanel extends StatelessWidget {
  const AppGlassPanel({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = AppSpacing.sheetRadius,
    this.blur = 12,
    this.tone = AppSurfaceTone.neutral,
    this.backgroundOpacity,
    this.showShadow = true,
    this.borderOpacity = 0.08,
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final AppSurfaceTone tone;
  final double? backgroundOpacity;
  final bool showShadow;
  final double borderOpacity;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final accent = _toneAccent(theme, surfaces, tone);
    final opacity =
        backgroundOpacity ??
        (theme.brightness == Brightness.dark ? 0.94 : 0.975);
    final background = Color.alphaBlend(
      accent.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.016 : 0.022,
      ),
      surfaces.panelRaised.withValues(alpha: opacity),
    );

    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? surfaces.lineSoft.withValues(alpha: 0.96)
                  : surfaces.lineSoft.withValues(alpha: 0.92),
            ),
            boxShadow: showShadow
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.20
                            : 0.06,
                      ),
                      blurRadius: 16,
                      spreadRadius: -10,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (margin == null) {
      return panel;
    }
    return Padding(padding: margin!, child: panel);
  }
}
