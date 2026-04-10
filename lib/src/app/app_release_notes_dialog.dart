import 'package:flutter/material.dart';

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

    return Dialog(
      key: const ValueKey<String>('release-notes-dialog'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AppGlassPanel(
          radius: AppSpacing.dialogRadius,
          blur: 14,
          backgroundOpacity: theme.brightness == Brightness.dark ? 0.88 : 0.94,
          borderOpacity: 0.08,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
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
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.22,
                        ),
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
              const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
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
                                  : AppSpacing.sm,
                            ),
                            child: _ReleaseHighlightCard(highlight: highlight),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
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
      ),
    );
  }
}

class _ReleaseHighlightCard extends StatelessWidget {
  const _ReleaseHighlightCard({required this.highlight});

  final AppReleaseHighlight highlight;

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
        padding: const EdgeInsets.all(AppSpacing.md),
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
            const SizedBox(width: AppSpacing.md),
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
