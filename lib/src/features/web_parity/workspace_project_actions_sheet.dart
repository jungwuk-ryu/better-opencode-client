import 'package:flutter/material.dart';

import '../../design_system/app_spacing.dart';
import '../../design_system/app_surface_decor.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/web_parity_localizations.dart';
import '../chat/chat_models.dart';
import '../projects/project_action_models.dart';
import '../projects/project_models.dart';

class WorkspaceProjectActionsSheet extends StatelessWidget {
  const WorkspaceProjectActionsSheet({
    required this.profileLabel,
    required this.project,
    required this.session,
    required this.status,
    required this.sections,
    required this.serviceSnapshots,
    required this.recentLinks,
    required this.portPresets,
    required this.onSelectAction,
    required this.onOpenLink,
    required this.onSelectPortPreset,
    super.key,
  });

  final String profileLabel;
  final ProjectTarget? project;
  final SessionSummary? session;
  final SessionStatusSummary? status;
  final List<ProjectActionSection> sections;
  final List<ProjectServiceSnapshot> serviceSnapshots;
  final List<RecentRemoteLink> recentLinks;
  final List<PortForwardPreset> portPresets;
  final Future<void> Function(ProjectActionItem action) onSelectAction;
  final Future<void> Function(RecentRemoteLink link) onOpenLink;
  final Future<void> Function(PortForwardPreset preset) onSelectPortPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final project = this.project;
    final session = this.session;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: AppGlassPanel(
            radius: AppSpacing.sheetRadius,
            tone: AppSurfaceTone.accent,
            blur: 22,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: surfaces.muted.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.pillRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.wp('Project Actions'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            context.wp(
                              'Keep the most common remote workflows one tap away.',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: surfaces.muted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: surfaces.panelRaised.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: context.wp('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      _ProjectActionsOverviewCard(
                        profileLabel: profileLabel,
                        project: project,
                        session: session,
                        status: status,
                      ),
                      if (serviceSnapshots.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _ProjectActionsSectionTitle(
                          title: context.wp('Runtime'),
                          subtitle: context.wp(
                            'A compact view of startup commands and live project state.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...serviceSnapshots.map(
                          (snapshot) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _ProjectServiceCard(snapshot: snapshot),
                          ),
                        ),
                      ],
                      for (final section in sections) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _ProjectActionsSectionTitle(
                          title: section.title,
                          subtitle: section.subtitle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...section.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _ProjectActionTile(
                              item: item,
                              onTap: () async {
                                Navigator.of(context).pop();
                                await onSelectAction(item);
                              },
                            ),
                          ),
                        ),
                      ],
                      if (recentLinks.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _ProjectActionsSectionTitle(
                          title: context.wp('Recent Links'),
                          subtitle: context.wp(
                            'Re-open or copy the remote links that matter most right now.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...recentLinks.map(
                          (link) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _ProjectLinkTile(
                              link: link,
                              onTap: () async {
                                Navigator.of(context).pop();
                                await onOpenLink(link);
                              },
                            ),
                          ),
                        ),
                      ],
                      if (portPresets.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _ProjectActionsSectionTitle(
                          title: context.wp('Port Presets'),
                          subtitle: context.wp(
                            'Keep a reusable handoff command ready when remote services need a local hop.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...portPresets.map(
                          (preset) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _PortPresetTile(
                              preset: preset,
                              onTap: () async {
                                Navigator.of(context).pop();
                                await onSelectPortPreset(preset);
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectActionsOverviewCard extends StatelessWidget {
  const _ProjectActionsOverviewCard({
    required this.profileLabel,
    required this.project,
    required this.session,
    required this.status,
  });

  final String profileLabel;
  final ProjectTarget? project;
  final SessionSummary? session;
  final SessionStatusSummary? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final branch = project?.branch?.trim() ?? '';
    final sessionTitle = session?.title.trim() ?? '';
    final statusLabel = _statusLabel(context, status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: appSoftCardDecoration(
        context,
        radius: 24,
        tone: AppSurfaceTone.accent,
        emphasized: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.dashboard_customize_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            project?.title ?? context.wp('Workspace'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            project?.directory ?? context.wp('Pick a project to see actions.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: surfaces.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (profileLabel.trim().isNotEmpty)
                _OverviewChip(
                  icon: Icons.dns_rounded,
                  label: profileLabel.trim(),
                ),
              if (branch.isNotEmpty)
                _OverviewChip(icon: Icons.commit_rounded, label: branch),
              if (sessionTitle.isNotEmpty)
                _OverviewChip(icon: Icons.forum_rounded, label: sessionTitle),
              if (statusLabel.isNotEmpty)
                _OverviewChip(icon: Icons.bolt_rounded, label: statusLabel),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, SessionStatusSummary? status) {
    final type = status?.type.trim().toLowerCase();
    return switch (type) {
      'running' || 'busy' || 'pending' => context.wp('Active'),
      'retry' => context.wp('Needs attention'),
      'idle' || null || '' => '',
      _ => status?.type ?? '',
    };
  }
}

class _ProjectActionsSectionTitle extends StatelessWidget {
  const _ProjectActionsSectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: surfaces.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProjectActionTile extends StatelessWidget {
  const _ProjectActionTile({required this.item, required this.onTap});

  final ProjectActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final accent = item.destructive
        ? theme.colorScheme.error
        : item.attention
        ? surfaces.warning
        : theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: appSoftCardDecoration(
            context,
            radius: 20,
            tone: item.destructive
                ? AppSurfaceTone.danger
                : item.attention
                ? AppSurfaceTone.warning
                : AppSurfaceTone.accent,
            muted: !item.enabled,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: item.enabled ? null : surfaces.muted,
                            ),
                          ),
                        ),
                        if (item.badge?.trim().isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.badge!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: item.enabled ? surfaces.muted : surfaces.line,
                        ),
                      ],
                    ),
                    if (item.subtitle?.trim().isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                    if (item.description?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (item.commandPreview?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: surfaces.panel.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: surfaces.lineSoft),
                        ),
                        child: Text(
                          item.commandPreview!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectServiceCard extends StatelessWidget {
  const _ProjectServiceCard({required this.snapshot});

  final ProjectServiceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final toneColor = switch (snapshot.tone) {
      ProjectRuntimeTone.success => theme.colorScheme.primary,
      ProjectRuntimeTone.warning => surfaces.warning,
      ProjectRuntimeTone.danger => theme.colorScheme.error,
      ProjectRuntimeTone.info => surfaces.accentSoft,
      ProjectRuntimeTone.neutral => surfaces.muted,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: appSoftCardDecoration(
        context,
        radius: 20,
        tone: switch (snapshot.tone) {
          ProjectRuntimeTone.success => AppSurfaceTone.success,
          ProjectRuntimeTone.warning => AppSurfaceTone.warning,
          ProjectRuntimeTone.danger => AppSurfaceTone.danger,
          ProjectRuntimeTone.info => AppSurfaceTone.accent,
          ProjectRuntimeTone.neutral => AppSurfaceTone.neutral,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  snapshot.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (snapshot.statusLabel?.trim().isNotEmpty == true)
                Text(
                  snapshot.statusLabel!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            snapshot.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: surfaces.muted,
              height: 1.4,
            ),
          ),
          if (snapshot.command?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: surfaces.panel.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: surfaces.lineSoft),
              ),
              child: Text(
                snapshot.command!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectLinkTile extends StatelessWidget {
  const _ProjectLinkTile({required this.link, required this.onTap});

  final RecentRemoteLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: appSoftCardDecoration(
            context,
            radius: 20,
            tone: AppSurfaceTone.neutral,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 360;
                  final sourceChip = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: surfaces.panel.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.pillRadius,
                      ),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: Text(
                      link.source,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.link_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                link.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        sourceChip,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          link.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      sourceChip,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                link.url,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                  height: 1.4,
                ),
              ),
              if (link.supportingText?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  link.supportingText!,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PortPresetTile extends StatelessWidget {
  const _PortPresetTile({required this.preset, required this.onTap});

  final PortForwardPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: appSoftCardDecoration(
            context,
            radius: 20,
            tone: AppSurfaceTone.accent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      preset.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'localhost:${preset.localPort} -> ${preset.host}:${preset.remotePort}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                  height: 1.4,
                ),
              ),
              if (preset.description?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  preset.description!,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: surfaces.panel.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaces.lineSoft),
                ),
                child: Text(
                  preset.command,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: appSoftCardDecoration(
        context,
        radius: AppSpacing.pillRadius,
        muted: true,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: surfaces.muted),
          const SizedBox(width: AppSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
