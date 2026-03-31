part of 'project_workspace_section.dart';

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _CatalogNoticeBanner extends StatelessWidget {
  const _CatalogNoticeBanner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.warning.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: surfaces.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
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

class _ProjectChoiceTile extends StatelessWidget {
  const _ProjectChoiceTile({
    required this.target,
    required this.selected,
    required this.pinned,
    required this.pinTooltip,
    required this.onPinToggle,
    required this.onTap,
  });

  final ProjectTarget target;
  final bool selected;
  final bool pinned;
  final String pinTooltip;
  final VoidCallback onPinToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final hasBranch = (target.branch ?? '').trim().isNotEmpty;
    final hasVcs = (target.vcs ?? '').trim().isNotEmpty;
    final lastSessionTitle = target.lastSession?.title?.trim();
    final lastSessionStatus = target.lastSession?.status?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('project-choice-${target.directory}'),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.16)
                    : surfaces.panelRaised.withValues(alpha: 0.88),
                selected
                    ? surfaces.panelRaised.withValues(alpha: 0.96)
                    : surfaces.panel.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.34)
                  : surfaces.line,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.14 : 0.08),
                blurRadius: selected ? 20 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ProjectAvatar(target: target),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            target.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            target.directory,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: surfaces.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: pinTooltip,
                      onPressed: onPinToggle,
                      icon: Icon(
                        pinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    _ProjectMetaChip(
                      icon: Icons.hub_rounded,
                      label: target.source ?? '-',
                      emphasis: selected,
                    ),
                    if (hasVcs)
                      _ProjectMetaChip(
                        icon: Icons.account_tree_outlined,
                        label: target.vcs!,
                      ),
                    if (hasBranch)
                      _ProjectMetaChip(
                        icon: Icons.commit_rounded,
                        label: target.branch!,
                      ),
                    if (lastSessionStatus != null &&
                        lastSessionStatus.isNotEmpty)
                      _ProjectMetaChip(
                        icon: Icons.bolt_rounded,
                        label: lastSessionStatus,
                      ),
                  ],
                ),
                if (lastSessionTitle != null &&
                    lastSessionTitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    lastSessionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : surfaces.accentSoft,
                      fontWeight: FontWeight.w600,
                    ),
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

class _ProjectAvatar extends StatelessWidget {
  const _ProjectAvatar({required this.target, this.large = false});

  final ProjectTarget target;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final size = large ? 52.0 : 42.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaces.panelEmphasis.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(large ? 16 : 14),
        border: Border.all(color: surfaces.line),
      ),
      alignment: Alignment.center,
      child: Text(
        _projectMonogram(target.label),
        style: theme.textTheme.titleMedium?.copyWith(
          color: surfaces.accentSoft,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProjectMetaChip extends StatelessWidget {
  const _ProjectMetaChip({
    required this.icon,
    required this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : surfaces.panelMuted.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(
          color: emphasis
              ? theme.colorScheme.primary.withValues(alpha: 0.24)
              : surfaces.lineSoft,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: AppSpacing.md,
              color: emphasis ? theme.colorScheme.primary : surfaces.accentSoft,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: emphasis
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectOverviewChip extends StatelessWidget {
  const _ProjectOverviewChip({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final accent = accentColor ?? surfaces.accentSoft;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppSpacing.md, color: accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$label: $value',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 120, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _projectMonogram(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
  if (cleaned.isEmpty) {
    return 'PR';
  }
  final parts = cleaned.split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
  if (parts.first.length == 1) {
    return parts.first.toUpperCase();
  }
  return parts.first.substring(0, 2).toUpperCase();
}
