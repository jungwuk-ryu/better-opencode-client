import 'package:flutter/material.dart';

import '../design_system/app_modal.dart';
import '../design_system/app_spacing.dart';
import '../design_system/app_surface_decor.dart';
import '../design_system/app_theme.dart';
import 'app_release_notes.dart';

class AppReleaseNotesDialog extends StatelessWidget {
  const AppReleaseNotesDialog({required this.notes, super.key});

  final AppReleaseNotesPresentation notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 420;
    final dialogInset = EdgeInsets.symmetric(
      horizontal: compact ? AppSpacing.md : AppSpacing.lg,
      vertical: compact ? AppSpacing.md : AppSpacing.xl,
    );
    final panelPadding = EdgeInsets.all(
      compact ? AppSpacing.md : AppSpacing.lg,
    );
    final sectionGap = compact ? AppSpacing.md : AppSpacing.lg;

    return AppDialogFrame(
      key: const ValueKey<String>('release-notes-dialog'),
      insetPadding: dialogInset,
      constraints: const BoxConstraints(maxWidth: 560),
      child: AppGlassPanel(
        radius: AppSpacing.dialogRadius,
        blur: 14,
        backgroundOpacity: theme.brightness == Brightness.dark ? 0.88 : 0.94,
        borderOpacity: 0.08,
        padding: panelPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: compact ? AppSpacing.xs : AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                Text(
                  "What's New",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    notes.versionLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Text(
              notes.headline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              notes.previousVersion == null
                  ? notes.summary
                  : 'Updated from v${notes.previousVersion} to ${notes.versionLabel}. ${notes.summary}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: surfaces.muted,
              ),
            ),
            SizedBox(height: sectionGap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: size.height * (compact ? 0.38 : 0.45),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: notes.highlights
                      .map(
                        (highlight) => Padding(
                          padding: EdgeInsets.only(
                            bottom: highlight == notes.highlights.last
                                ? 0
                                : (compact ? AppSpacing.sm : AppSpacing.md),
                          ),
                          child: _ReleaseHighlightCard(
                            highlight: highlight,
                            compact: compact,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            SizedBox(height: sectionGap),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('release-notes-close-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseHighlightCard extends StatelessWidget {
  const _ReleaseHighlightCard({required this.highlight, required this.compact});

  final AppReleaseHighlight highlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return Container(
      width: double.infinity,
      decoration: appSoftCardDecoration(
        context,
        radius: AppSpacing.panelRadius,
        muted: true,
        emphasized: true,
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                highlight.icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    highlight.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    highlight.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: surfaces.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
