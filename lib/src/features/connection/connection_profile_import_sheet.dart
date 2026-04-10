import 'package:flutter/material.dart';

import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_surface_decor.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/web_parity_localizations.dart';
import 'connection_profile_import.dart';

class ConnectionProfileImportSheet extends StatelessWidget {
  const ConnectionProfileImportSheet({
    required this.routeData,
    required this.existingProfile,
    super.key,
  });

  final ConnectionImportRouteData routeData;
  final ServerProfile? existingProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final payload = routeData.payload;
    final existing = existingProfile;
    final valid = routeData.hasValidPayload;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AppGlassPanel(
              radius: AppSpacing.dialogRadius,
              blur: 14,
              backgroundOpacity: theme.brightness == Brightness.dark
                  ? 0.9
                  : 0.95,
              borderOpacity: 0.08,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.wp('Import Connection'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                valid
                                    ? context.wp(
                                        'Review the shared server profile before saving it to this device.',
                                      )
                                    : context.wp(
                                        'This shared connection could not be trusted yet. Review the validation issues below.',
                                      ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: surfaces.muted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ConnectionImportCard(
                      title: payload.label.isNotEmpty
                          ? payload.label
                          : context.wp('Shared Server'),
                      subtitle: payload.baseUrl.isNotEmpty
                          ? payload.baseUrl
                          : context.wp('Missing server address'),
                      children: <Widget>[
                        _ConnectionImportMetaRow(
                          label: context.wp('Auth'),
                          value: switch (payload.authType) {
                            ConnectionProfileImportAuthType.basic => 'Basic',
                            ConnectionProfileImportAuthType.none => context.wp(
                              'None',
                            ),
                          },
                        ),
                        _ConnectionImportMetaRow(
                          label: context.wp('Expires'),
                          value: payload.expiresAt == null
                              ? context.wp('No expiry')
                              : MaterialLocalizations.of(
                                  context,
                                ).formatShortDate(payload.expiresAt!),
                        ),
                        if (existing != null)
                          _ConnectionImportMetaRow(
                            label: context.wp('Duplicate'),
                            value: context.wp(
                              'Will update "{label}"',
                              args: <String, Object?>{
                                'label': existing.effectiveLabel,
                              },
                            ),
                          ),
                      ],
                    ),
                    if (!valid) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _ConnectionImportCard(
                        title: context.wp('Validation Issues'),
                        subtitle: context.wp(
                          'Shared profiles must pass version, auth, URL, and expiry checks before import.',
                        ),
                        accentColor: theme.colorScheme.error,
                        children: routeData.validation.issues
                            .map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        issue.message,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 420;
                        final cancelButton = OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(context.wp('Cancel')),
                        );
                        final saveButton = FilledButton.icon(
                          onPressed: valid
                              ? () => Navigator.of(context).pop(true)
                              : null,
                          icon: Icon(
                            existing == null
                                ? Icons.download_done_rounded
                                : Icons.system_update_alt_rounded,
                          ),
                          label: Text(
                            existing == null
                                ? context.wp('Save Server')
                                : context.wp('Update Saved Server'),
                          ),
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              saveButton,
                              const SizedBox(height: AppSpacing.sm),
                              cancelButton,
                            ],
                          );
                        }
                        return Row(
                          children: <Widget>[
                            Expanded(child: cancelButton),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: saveButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionImportCard extends StatelessWidget {
  const _ConnectionImportCard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: appSoftCardDecoration(
        context,
        radius: 24,
        tone: accentColor == theme.colorScheme.error
            ? AppSurfaceTone.danger
            : AppSurfaceTone.neutral,
        muted: true,
        emphasized: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _ConnectionImportMetaRow extends StatelessWidget {
  const _ConnectionImportMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: surfaces.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
