import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_theme.dart';

enum AppSnackBarTone { info, success, warning, danger }

class AppSnackBarAction {
  const AppSnackBarAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

void showAppSnackBar(
  BuildContext context, {
  required String message,
  AppSnackBarTone tone = AppSnackBarTone.info,
  Duration duration = const Duration(seconds: 4),
  AppSnackBarAction? action,
  bool replaceCurrent = false,
  int maxLines = 3,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  if (replaceCurrent) {
    messenger.hideCurrentSnackBar();
  }
  messenger.showSnackBar(
    buildAppSnackBar(
      context,
      message: message,
      tone: tone,
      duration: duration,
      action: action,
      maxLines: maxLines,
    ),
  );
}

SnackBar buildAppSnackBar(
  BuildContext context, {
  required String message,
  AppSnackBarTone tone = AppSnackBarTone.info,
  Duration duration = const Duration(seconds: 4),
  AppSnackBarAction? action,
  int maxLines = 3,
}) {
  final theme = Theme.of(context);
  final palette = _AppSnackBarPalette.resolve(
    theme,
    theme.extension<AppSurfaces>()!,
    tone,
  );
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.md,
    ),
    padding: EdgeInsets.zero,
    duration: duration,
    dismissDirection: DismissDirection.horizontal,
    content: _AppSnackBarBody(
      message: message,
      action: action,
      palette: palette,
      maxLines: maxLines,
    ),
  );
}

class _AppSnackBarBody extends StatelessWidget {
  const _AppSnackBarBody({
    required this.message,
    required this.action,
    required this.palette,
    required this.maxLines,
  });

  final String message;
  final AppSnackBarAction? action;
  final _AppSnackBarPalette palette;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(color: palette.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.badgeBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.badgeBorder),
                  ),
                  alignment: Alignment.center,
                  child: Icon(palette.icon, size: 18, color: palette.accent),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      message,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                      action!.onPressed();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: palette.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        side: BorderSide(
                          color: palette.accent.withValues(alpha: 0.24),
                        ),
                      ),
                    ),
                    child: Text(action!.label),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppSnackBarPalette {
  const _AppSnackBarPalette({
    required this.background,
    required this.border,
    required this.badgeBackground,
    required this.badgeBorder,
    required this.foreground,
    required this.accent,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color badgeBackground;
  final Color badgeBorder;
  final Color foreground;
  final Color accent;
  final IconData icon;

  static _AppSnackBarPalette resolve(
    ThemeData theme,
    AppSurfaces surfaces,
    AppSnackBarTone tone,
  ) {
    final accent = switch (tone) {
      AppSnackBarTone.info => theme.colorScheme.primary,
      AppSnackBarTone.success => surfaces.success,
      AppSnackBarTone.warning => surfaces.warning,
      AppSnackBarTone.danger => theme.colorScheme.error,
    };
    final icon = switch (tone) {
      AppSnackBarTone.info => Icons.info_outline_rounded,
      AppSnackBarTone.success => Icons.check_circle_outline_rounded,
      AppSnackBarTone.warning => Icons.warning_amber_rounded,
      AppSnackBarTone.danger => Icons.error_outline_rounded,
    };
    return _AppSnackBarPalette(
      background: Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        surfaces.panel.withValues(alpha: 0.56),
      ),
      border: accent.withValues(alpha: 0.34),
      badgeBackground: accent.withValues(alpha: 0.14),
      badgeBorder: accent.withValues(alpha: 0.22),
      foreground: theme.colorScheme.onSurface,
      accent: accent,
      icon: icon,
    );
  }
}
