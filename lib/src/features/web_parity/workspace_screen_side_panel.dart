part of 'workspace_screen.dart';

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.controller, required this.onLineComment});

  final WorkspaceController controller;
  final ValueChanged<_ReviewLineCommentSubmission> onLineComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final tab = controller.sideTab;
    final bundle = controller.fileBundle;
    final density = _workspaceDensity(context);
    final panelPadding = density.inset(_workspaceCardGap, min: AppSpacing.xs);
    final panelGap = density.inset(_workspaceCardGap, min: AppSpacing.xs);
    final compact = density.compact;
    final selectedTitle = switch (tab) {
      WorkspaceSideTab.review => context.wp('Review canvas'),
      WorkspaceSideTab.files => context.wp('Files canvas'),
      WorkspaceSideTab.context => context.wp('Context canvas'),
    };
    final selectedSubtitle = switch (tab) {
      WorkspaceSideTab.review => context.wp('Git diffs and review comments'),
      WorkspaceSideTab.files => context.wp('File tree and preview'),
      WorkspaceSideTab.context => context.wp(
        'Context metrics and raw messages',
      ),
    };
    final reviewCount = controller.reviewStatuses.length;
    final fileCount = bundle?.nodes.length ?? 0;
    final contextUsage = controller.sessionContextMetrics.context?.usagePercent;
    final messageCount = controller.messages.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Colors.black.withValues(alpha: compact ? 0.08 : 0.12),
          surfaces.background.withValues(alpha: compact ? 0.98 : 0.985),
        ),
        border: Border(
          left: BorderSide(color: surfaces.lineSoft.withValues(alpha: 0.82)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          panelPadding,
          panelPadding,
          panelPadding,
          panelPadding,
        ),
        child: Column(
          children: <Widget>[
            _WorkspaceSidePanelToolbar(
              title: selectedTitle,
              subtitle: selectedSubtitle,
              accentCount: switch (tab) {
                WorkspaceSideTab.review => reviewCount,
                WorkspaceSideTab.files => fileCount,
                WorkspaceSideTab.context =>
                  contextUsage != null
                      ? contextUsage.clamp(0, 999)
                      : messageCount,
              },
              accentLabel: switch (tab) {
                WorkspaceSideTab.review => context.wp('Diffs'),
                WorkspaceSideTab.files => context.wp('Files'),
                WorkspaceSideTab.context => context.wp('Context'),
              },
            ),
            SizedBox(height: panelGap),
            _WorkspaceSideTabSwitcher(
              selectedTab: tab,
              items: <_WorkspaceSideTabItem>[
                _WorkspaceSideTabItem(
                  tab: WorkspaceSideTab.review,
                  icon: Icons.rate_review_rounded,
                  title: context.wp('Review'),
                  subtitle: context.wp(
                    reviewCount > 0 ? 'Diffs' : 'No changes',
                  ),
                  badge: reviewCount > 0 ? '$reviewCount' : null,
                ),
                _WorkspaceSideTabItem(
                  tab: WorkspaceSideTab.files,
                  icon: Icons.folder_copy_rounded,
                  title: context.wp('Files'),
                  subtitle: context.wp('Browse'),
                  badge: fileCount > 0 ? '$fileCount' : null,
                ),
                _WorkspaceSideTabItem(
                  tab: WorkspaceSideTab.context,
                  icon: Icons.tune_rounded,
                  title: context.wp('Context'),
                  subtitle: context.wp(
                    contextUsage != null ? 'Tokens' : 'Session',
                  ),
                  badge: contextUsage != null
                      ? '${contextUsage.clamp(0, 999)}%'
                      : (messageCount > 0 ? '$messageCount' : null),
                ),
              ],
              onChanged: controller.setSideTab,
            ),
            SizedBox(height: panelGap),
            Expanded(
              child: DecoratedBox(
                decoration: _workspaceSideCanvasDecoration(
                  theme: Theme.of(context),
                  surfaces: surfaces,
                  compact: compact,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    compact ? _workspaceInnerRadius : _workspacePanelRadius,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: switch (tab) {
                      WorkspaceSideTab.review => _ReviewPanel(
                        project: controller.project,
                        configSnapshot: controller.configSnapshot,
                        statuses: controller.reviewStatuses,
                        selectedPath: controller.selectedReviewPath,
                        diff: controller.reviewDiff,
                        loadingDiff: controller.loadingReviewDiff,
                        diffError: controller.reviewDiffError,
                        initializingGitRepository:
                            controller.initializingGitRepository,
                        onInitializeGitRepository: () {
                          unawaited(controller.initializeGitRepository());
                        },
                        onLineComment: onLineComment,
                        onSelectFile: (path) {
                          unawaited(controller.selectReviewFile(path));
                        },
                      ),
                      WorkspaceSideTab.files => _FilesPanel(
                        bundle: controller.fileBundle,
                        loadingFiles: controller.loadingFilesPanel,
                        loadingPreview: controller.loadingFilePreview,
                        expandedDirectories: controller.expandedFileDirectories,
                        loadingDirectoryPath:
                            controller.loadingFileDirectoryPath,
                        onSelectFile: (path) {
                          unawaited(controller.selectFile(path));
                        },
                        onToggleDirectory: (path) {
                          unawaited(controller.toggleFileDirectory(path));
                        },
                      ),
                      WorkspaceSideTab.context => _ContextPanel(
                        session: controller.selectedSession,
                        messages: controller.messages,
                        metrics: controller.sessionContextMetrics,
                        systemPrompt: controller.sessionSystemPrompt,
                        breakdown: controller.sessionContextBreakdown,
                        userMessageCount: controller.userMessageCount,
                        assistantMessageCount: controller.assistantMessageCount,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSidePanelToolbar extends StatelessWidget {
  const _WorkspaceSidePanelToolbar({
    required this.title,
    required this.subtitle,
    required this.accentCount,
    required this.accentLabel,
  });

  final String title;
  final String subtitle;
  final num accentCount;
  final String accentLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final compact = density.compact;
    return Container(
      padding: EdgeInsets.all(
        density.inset(compact ? _workspaceRowGap : _workspaceCardGap, min: 8),
      ),
      decoration: _workspaceSidePanelDecoration(
        surfaces: surfaces,
        compact: compact,
        tint: theme.colorScheme.primary,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: surfaces.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _WorkspaceSideBadge(
                label: '$accentCount',
                tint: theme.colorScheme.primary,
                emphasized: true,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  accentLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: surfaces.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSideTabItem {
  const _WorkspaceSideTabItem({
    required this.tab,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final WorkspaceSideTab tab;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
}

class _WorkspaceSideTabSwitcher extends StatelessWidget {
  const _WorkspaceSideTabSwitcher({
    required this.selectedTab,
    required this.items,
    required this.onChanged,
  });

  final WorkspaceSideTab selectedTab;
  final List<_WorkspaceSideTabItem> items;
  final ValueChanged<WorkspaceSideTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final switcherPadding = density.inset(density.compact ? 6 : 8, min: 4);
    final compact = density.compact;
    return Container(
      key: const ValueKey<String>('workspace-side-tab-switcher'),
      padding: EdgeInsets.all(switcherPadding),
      decoration: _workspaceSidePanelDecoration(
        surfaces: surfaces,
        compact: compact,
        elevated: false,
        tint: theme.colorScheme.primary,
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < items.length; index += 1) ...<Widget>[
            if (index > 0)
              SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
            Expanded(
              child: _WorkspaceSideTabButton(
                item: items[index],
                selected: items[index].tab == selectedTab,
                onTap: () => onChanged(items[index].tab),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceSideTabButton extends StatelessWidget {
  const _WorkspaceSideTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _WorkspaceSideTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final compact = density.compact;
    final accent = _workspaceSideTabAccent(item.tab, theme, surfaces);
    final titleColor = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.92);
    final subtitleColor = selected
        ? Color.lerp(surfaces.muted, accent, 0.32) ?? surfaces.muted
        : surfaces.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('workspace-side-tab-${item.tab.name}-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          compact ? _workspaceInnerRadius : _workspacePanelRadius,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minHeight: density.inset(compact ? 54 : 68, min: compact ? 48 : 60),
          ),
          padding: EdgeInsets.fromLTRB(
            density.inset(compact ? 10 : AppSpacing.sm, min: 8),
            density.inset(compact ? 10 : AppSpacing.sm, min: 8),
            density.inset(compact ? 10 : AppSpacing.sm, min: 8),
            density.inset(compact ? 10 : AppSpacing.sm, min: 8),
          ),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    accent.withValues(alpha: compact ? 0.09 : 0.08),
                    surfaces.background.withValues(
                      alpha: compact ? 0.94 : 0.96,
                    ),
                  )
                : Color.alphaBlend(
                    Colors.black.withValues(alpha: compact ? 0.02 : 0.04),
                    surfaces.panelMuted.withValues(
                      alpha: compact ? 0.55 : 0.62,
                    ),
                  ),
            borderRadius: BorderRadius.circular(
              compact ? _workspaceInnerRadius : _workspacePanelRadius,
            ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: compact ? 0.22 : 0.24)
                  : surfaces.lineSoft.withValues(alpha: 0.72),
            ),
            boxShadow: const <BoxShadow>[],
          ),
          child: compact
              ? Row(
                  children: <Widget>[
                    Container(
                      width: density.inset(24, min: 22),
                      height: density.inset(24, min: 22),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: selected ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 14, color: accent),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.badge != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      _WorkspaceSideBadge(
                        label: item.badge!,
                        tint: accent,
                        emphasized: selected,
                      ),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: density.inset(28, min: 24),
                          height: density.inset(28, min: 24),
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: selected ? 0.14 : 0.09,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accent.withValues(
                                alpha: selected ? 0.26 : 0.16,
                              ),
                            ),
                          ),
                          child: Icon(item.icon, size: 16, color: accent),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: item.badge == null
                                ? const SizedBox.shrink()
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _WorkspaceSideBadge(
                                      label: item.badge!,
                                      tint: accent,
                                      emphasized: selected,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

Color _workspaceSideTabAccent(
  WorkspaceSideTab tab,
  ThemeData theme,
  AppSurfaces surfaces,
) {
  return switch (tab) {
    WorkspaceSideTab.review => surfaces.warning,
    WorkspaceSideTab.files => theme.colorScheme.primary,
    WorkspaceSideTab.context => surfaces.success,
  };
}

BoxDecoration _workspaceSidePanelDecoration({
  required AppSurfaces surfaces,
  required bool compact,
  Color? tint,
  bool elevated = false,
}) {
  final isDark = surfaces.background.computeLuminance() < 0.5;
  final fill = Color.alphaBlend(
    (tint ?? surfaces.muted).withValues(alpha: compact ? 0.018 : 0.024),
    Color.alphaBlend(
      isDark
          ? Colors.black.withValues(alpha: compact ? 0.04 : 0.06)
          : Colors.white.withValues(alpha: compact ? 0.18 : 0.22),
      surfaces.panelMuted.withValues(alpha: compact ? 0.94 : 0.98),
    ),
  );
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(
      compact ? _workspaceInnerRadius : _workspacePanelRadius,
    ),
    border: Border.all(
      color: surfaces.lineSoft.withValues(alpha: isDark ? 0.8 : 0.92),
    ),
    boxShadow: elevated
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? (compact ? 0.12 : 0.16) : 0.035,
              ),
              blurRadius: compact ? 12 : 16,
              offset: Offset(0, compact ? 5 : 7),
              spreadRadius: compact ? -10 : -12,
            ),
          ]
        : const <BoxShadow>[],
  );
}

BoxDecoration _workspaceSideSelectionDecoration({
  required ThemeData theme,
  required AppSurfaces surfaces,
  required bool compact,
  Color? accent,
}) {
  final resolvedAccent = accent ?? theme.colorScheme.primary;
  return BoxDecoration(
    color: Color.alphaBlend(
      resolvedAccent.withValues(alpha: compact ? 0.08 : 0.07),
      surfaces.background.withValues(alpha: compact ? 0.94 : 0.96),
    ),
    borderRadius: BorderRadius.circular(
      compact ? _workspaceInnerRadius : _workspacePanelRadius,
    ),
    border: Border.all(color: resolvedAccent.withValues(alpha: 0.18)),
    boxShadow: const <BoxShadow>[],
  );
}

BoxDecoration _workspaceSideCanvasDecoration({
  required ThemeData theme,
  required AppSurfaces surfaces,
  required bool compact,
}) {
  final accent = theme.colorScheme.primary;
  return BoxDecoration(
    color: Color.alphaBlend(
      Colors.black.withValues(alpha: compact ? 0.02 : 0.025),
      Color.alphaBlend(
        accent.withValues(alpha: compact ? 0.018 : 0.022),
        surfaces.panelMuted.withValues(alpha: compact ? 0.9 : 0.94),
      ),
    ),
    borderRadius: BorderRadius.circular(
      compact ? _workspaceInnerRadius : _workspacePanelRadius,
    ),
    border: Border.all(color: surfaces.lineSoft.withValues(alpha: 0.86)),
  );
}

class _WorkspaceSideSectionHeader extends StatelessWidget {
  const _WorkspaceSideSectionHeader({
    required this.title,
    this.caption,
    this.trailing,
    this.dense = false,
  });

  final String title;
  final String? caption;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final horizontal = density.inset(dense ? AppSpacing.sm : AppSpacing.md);
    final vertical = density.inset(
      dense ? AppSpacing.xs : AppSpacing.sm,
      min: 6,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (caption != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: surfaces.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            SizedBox(width: dense ? AppSpacing.xxs : AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _WorkspaceSideBadge extends StatelessWidget {
  const _WorkspaceSideBadge({
    required this.label,
    this.tint,
    this.emphasized = false,
  });

  final String label;
  final Color? tint;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final resolvedTint = tint ?? surfaces.muted;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.xs, min: 8),
        vertical: emphasized ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? resolvedTint.withValues(alpha: 0.11)
            : Color.alphaBlend(
                Colors.black.withValues(alpha: 0.03),
                surfaces.panelEmphasis.withValues(alpha: 0.58),
              ),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(
          color: emphasized
              ? resolvedTint.withValues(alpha: 0.2)
              : surfaces.lineSoft.withValues(alpha: 0.82),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasized ? resolvedTint : surfaces.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _WorkspaceSideActionButton extends StatelessWidget {
  const _WorkspaceSideActionButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        icon: Icon(icon),
      ),
    );
  }
}

class _WorkspaceSideEmptyState extends StatelessWidget {
  const _WorkspaceSideEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tint,
    this.titleKey,
    this.messageKey,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color? tint;
  final Key? titleKey;
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final compact = density.compact;
    final resolvedTint = tint ?? theme.colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: EdgeInsets.all(
            density.inset(AppSpacing.md, min: AppSpacing.sm),
          ),
          padding: EdgeInsets.all(
            density.inset(compact ? AppSpacing.sm : AppSpacing.md),
          ),
          decoration: _workspaceSidePanelDecoration(
            surfaces: surfaces,
            compact: compact,
            elevated: true,
            tint: resolvedTint,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: density.inset(compact ? 48 : 56, min: 46),
                  height: density.inset(compact ? 48 : 56, min: 46),
                  decoration: BoxDecoration(
                    color: resolvedTint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(compact ? 16 : 18),
                    border: Border.all(
                      color: resolvedTint.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 24 : 28,
                    color: resolvedTint,
                  ),
                ),
                SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
                Text(
                  title,
                  key: titleKey,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: density.inset(AppSpacing.xxs, min: 4)),
                Text(
                  message,
                  key: messageKey,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: surfaces.muted,
                    height: 1.45,
                  ),
                ),
                if (action != null) ...<Widget>[
                  SizedBox(height: density.inset(AppSpacing.sm)),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewPanel extends StatefulWidget {
  const _ReviewPanel({
    required this.project,
    required this.configSnapshot,
    required this.statuses,
    required this.selectedPath,
    required this.diff,
    required this.loadingDiff,
    required this.diffError,
    required this.initializingGitRepository,
    required this.onInitializeGitRepository,
    required this.onLineComment,
    required this.onSelectFile,
  });

  final ProjectTarget? project;
  final ConfigSnapshot? configSnapshot;
  final List<FileStatusSummary> statuses;
  final String? selectedPath;
  final FileDiffSummary? diff;
  final bool loadingDiff;
  final String? diffError;
  final bool initializingGitRepository;
  final VoidCallback onInitializeGitRepository;
  final ValueChanged<_ReviewLineCommentSubmission> onLineComment;
  final ValueChanged<String> onSelectFile;

  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  static const double _defaultPreviewHeight = 280;
  static const double _minPreviewHeight = 160;
  static const double _minListHeight = 220;

  double _previewHeight = _defaultPreviewHeight;
  _ReviewDiffMode _diffMode = _ReviewDiffMode.unified;
  final TextEditingController _lineCommentController = TextEditingController();

  @override
  void dispose() {
    _lineCommentController.dispose();
    super.dispose();
  }

  double _defaultPreviewHeightForDensity(_WorkspaceDensity density) {
    return density.compact ? 420 : _defaultPreviewHeight;
  }

  double _minPreviewHeightForDensity(_WorkspaceDensity density) {
    return density.compact ? 240 : _minPreviewHeight;
  }

  double _minListHeightForDensity(_WorkspaceDensity density) {
    return density.compact ? 132 : _minListHeight;
  }

  double _resolvedPreviewHeightValue(_WorkspaceDensity density) {
    if (density.compact && _previewHeight == _defaultPreviewHeight) {
      return _defaultPreviewHeightForDensity(density);
    }
    return _previewHeight;
  }

  void _resizePreview(
    double deltaDy,
    double availableHeight, {
    required _WorkspaceDensity density,
  }) {
    final minPreviewHeight = _minPreviewHeightForDensity(density);
    final minListHeight = _minListHeightForDensity(density);
    final maxPreviewHeight = (availableHeight - minListHeight).clamp(
      minPreviewHeight,
      availableHeight,
    );
    final next = (_resolvedPreviewHeightValue(density) - deltaDy).clamp(
      minPreviewHeight,
      maxPreviewHeight,
    );
    if (next == _previewHeight) {
      return;
    }
    setState(() {
      _previewHeight = next;
    });
  }

  Future<void> _startLineComment(_ReviewCommentTarget target) async {
    _lineCommentController.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    final comment = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AppDialogFrame(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          constraints: const BoxConstraints(maxWidth: 460),
          child: _ReviewLineCommentEditor(
            target: target,
            controller: _lineCommentController,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSubmit: () => Navigator.of(
              dialogContext,
            ).pop(_lineCommentController.text.trim()),
          ),
        );
      },
    );
    if (!mounted || comment == null || comment.trim().isEmpty) {
      return;
    }
    widget.onLineComment(
      _ReviewLineCommentSubmission(target: target, comment: comment),
    );
    _lineCommentController.clear();
  }

  void _openReviewPreviewFullScreen({
    required FileDiffSummary diff,
    required _ParsedReviewDiff parsedDiff,
    required bool splitEnabled,
    required bool compactMode,
    required int lineCount,
    required _ReviewDiffMode initialMode,
    required String? diffModeHint,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _WorkspaceReviewPreviewPage(
          diff: diff,
          parsedDiff: parsedDiff,
          splitEnabled: splitEnabled,
          compactMode: compactMode,
          lineCount: lineCount,
          initialMode: initialMode,
          diffModeHint: diffModeHint,
          onLineComment: _startLineComment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final currentDiff = widget.diff;
    final parsedDiff = currentDiff == null || currentDiff.isEmpty
        ? null
        : _cachedParsedReviewDiff(currentDiff.content);
    final diffLineCount = parsedDiff == null
        ? 0
        : _reviewDiffLineCount(parsedDiff);
    final splitEnabled =
        parsedDiff != null &&
        currentDiff != null &&
        _reviewDiffSupportsSplit(
          lineCount: diffLineCount,
          contentLength: currentDiff.content.length,
        );
    final compactMode =
        parsedDiff != null &&
        currentDiff != null &&
        _reviewDiffShouldUseCompactMode(
          lineCount: diffLineCount,
          contentLength: currentDiff.content.length,
        );
    final effectiveDiffMode = splitEnabled
        ? _diffMode
        : _ReviewDiffMode.unified;
    final diffModeHint = parsedDiff == null
        ? null
        : _reviewDiffModeHint(
            context,
            splitEnabled: splitEnabled,
            compactMode: compactMode,
          );
    final hasGitRepository =
        (widget.project?.vcs ?? '').trim().toLowerCase() == 'git';
    final snapshotTrackingDisabled =
        widget.configSnapshot?.snapshotTrackingEnabled == false;
    if (widget.statuses.isEmpty) {
      if (!hasGitRepository) {
        return _WorkspaceSideEmptyState(
          icon: Icons.source_rounded,
          title: context.wp('Create a Git repository'),
          message: context.wp(
            'Initialize Git for this project to unlock review diffs and tracked file changes.',
          ),
          tint: theme.colorScheme.primary,
          titleKey: const ValueKey<String>('review-no-vcs-title'),
          messageKey: const ValueKey<String>('review-no-vcs-message'),
          action: FilledButton.icon(
            key: const ValueKey<String>('review-init-git-button'),
            onPressed: widget.initializingGitRepository
                ? null
                : widget.onInitializeGitRepository,
            icon: widget.initializingGitRepository
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link_rounded),
            label: Text(
              widget.initializingGitRepository
                  ? context.wp('Creating repository...')
                  : context.wp('Create Git repository'),
            ),
          ),
        );
      }
      if (snapshotTrackingDisabled) {
        return _WorkspaceSideEmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: context.wp('Snapshot tracking is disabled'),
          message: context.wp(
            'Snapshot tracking is disabled in config, so session changes are unavailable.',
          ),
          tint: surfaces.warning,
          titleKey: const ValueKey<String>('review-no-snapshot-title'),
          messageKey: const ValueKey<String>('review-no-snapshot-message'),
        );
      }
      if (widget.loadingDiff) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.diffError != null) {
        return _WorkspaceSideEmptyState(
          icon: Icons.error_outline_rounded,
          title: context.wp('Review is unavailable'),
          message: widget.diffError!,
          tint: surfaces.danger,
        );
      }
      return _WorkspaceSideEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: context.wp('No file changes yet.'),
        message: context.wp(
          'Tracked file changes will appear here once the session edits your workspace.',
        ),
        tint: surfaces.success,
      );
    }
    final hasPreview = widget.selectedPath != null;
    FileStatusSummary? selectedItem;
    if (hasPreview) {
      for (final status in widget.statuses) {
        if (status.path == widget.selectedPath) {
          selectedItem = status;
          break;
        }
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 700.0;
        final minPreviewHeight = _minPreviewHeightForDensity(density);
        final minListHeight = _minListHeightForDensity(density);
        final previewHeight = hasPreview
            ? _resolvedPreviewHeightValue(density).clamp(
                minPreviewHeight,
                (availableHeight - minListHeight).clamp(
                  minPreviewHeight,
                  availableHeight,
                ),
              )
            : 0.0;

        return Column(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  _WorkspaceSideSectionHeader(
                    title: context.wp('Changed files'),
                    caption: hasPreview
                        ? context.wp(
                            '{count} files tracked. Preview stays pinned below while you switch between entries.',
                            args: <String, Object?>{
                              'count': widget.statuses.length,
                            },
                          )
                        : context.wp(
                            '{count} files tracked. Select one to open its diff preview.',
                            args: <String, Object?>{
                              'count': widget.statuses.length,
                            },
                          ),
                    trailing: _WorkspaceSideBadge(
                      label: '${widget.statuses.length}',
                      tint: surfaces.warning,
                      emphasized: true,
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.all(
                        density.inset(_workspaceCardGap, min: AppSpacing.xs),
                      ),
                      itemCount: widget.statuses.length,
                      separatorBuilder: (_, _) => SizedBox(
                        height: density.inset(_workspaceRowGap, min: 4),
                      ),
                      itemBuilder: (context, index) {
                        final item = widget.statuses[index];
                        final statusColor = _reviewStatusColor(
                          item.status,
                          surfaces,
                        );
                        final addedColor = item.added > 0
                            ? surfaces.success
                            : surfaces.muted;
                        final removedColor = item.removed > 0
                            ? surfaces.danger
                            : surfaces.muted;
                        final selected = item.path == widget.selectedPath;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: selected
                              ? _workspaceSideSelectionDecoration(
                                  theme: theme,
                                  surfaces: surfaces,
                                  compact: density.compact,
                                  accent: statusColor,
                                )
                              : _workspaceSidePanelDecoration(
                                  surfaces: surfaces,
                                  compact: density.compact,
                                  tint: statusColor,
                                ),
                          child: ListTile(
                            dense: density.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                density.compact ? 16 : 18,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: density.inset(AppSpacing.xs, min: 8),
                              vertical: density.inset(AppSpacing.xxs, min: 2),
                            ),
                            leading: Container(
                              width: density.inset(34, min: 30),
                              height: density.inset(34, min: 30),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Icon(
                                _reviewStatusIcon(item.status),
                                color: statusColor,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              item.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text.rich(
                                key: ValueKey<String>(
                                  'review-status-${item.path}',
                                ),
                                TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: surfaces.muted,
                                  ),
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: item.status,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const TextSpan(text: '  •  '),
                                    TextSpan(
                                      text: '+${item.added}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: addedColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const TextSpan(text: '  '),
                                    TextSpan(
                                      text: '-${item.removed}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: removedColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.chevron_right_rounded,
                                    color: statusColor,
                                  )
                                : null,
                            onTap: () => widget.onSelectFile(item.path),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (hasPreview)
              Container(
                key: const ValueKey<String>('review-preview-panel'),
                height: previewHeight,
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(
                  density.inset(_workspaceCardGap, min: AppSpacing.xs),
                  0,
                  density.inset(_workspaceCardGap, min: AppSpacing.xs),
                  density.inset(_workspaceCardGap, min: AppSpacing.xs),
                ),
                decoration: _workspaceSidePanelDecoration(
                  surfaces: surfaces,
                  compact: density.compact,
                  elevated: true,
                  tint: theme.colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey<String>(
                        'review-preview-resize-handle',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        _resizePreview(
                          details.delta.dy,
                          availableHeight,
                          density: density,
                        );
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: SizedBox(
                          height: density.compact ? 20 : 22,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: surfaces.muted.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          density.inset(_workspaceCardGap, min: AppSpacing.xs),
                          0,
                          density.inset(_workspaceCardGap, min: AppSpacing.xs),
                          density.inset(_workspaceCardGap, min: AppSpacing.xs),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: density.inset(AppSpacing.xs, min: 4),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          context.wp('Preview'),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(color: surfaces.muted),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.selectedPath!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (selectedItem != null) ...<Widget>[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: AppSpacing.xs,
                                            runSpacing: AppSpacing.xs,
                                            children: <Widget>[
                                              _WorkspaceSideBadge(
                                                label: selectedItem.status,
                                                tint: _reviewStatusColor(
                                                  selectedItem.status,
                                                  surfaces,
                                                ),
                                                emphasized: true,
                                              ),
                                              _WorkspaceSideBadge(
                                                label: '+${selectedItem.added}',
                                                tint: surfaces.success,
                                              ),
                                              _WorkspaceSideBadge(
                                                label:
                                                    '-${selectedItem.removed}',
                                                tint: surfaces.danger,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: density.inset(
                                      AppSpacing.xxs,
                                      min: 4,
                                    ),
                                  ),
                                  Flexible(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final stackControls =
                                            constraints.maxWidth < 220;
                                        final modeToggle = FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: SegmentedButton<_ReviewDiffMode>(
                                            key: const ValueKey<String>(
                                              'review-diff-mode-toggle',
                                            ),
                                            showSelectedIcon: false,
                                            segments:
                                                <
                                                  ButtonSegment<_ReviewDiffMode>
                                                >[
                                                  ButtonSegment<
                                                    _ReviewDiffMode
                                                  >(
                                                    value:
                                                        _ReviewDiffMode.unified,
                                                    label: Text(
                                                      context.wp('Unified'),
                                                    ),
                                                    icon: Icon(
                                                      Icons.view_stream_rounded,
                                                    ),
                                                  ),
                                                  ButtonSegment<
                                                    _ReviewDiffMode
                                                  >(
                                                    value:
                                                        _ReviewDiffMode.split,
                                                    label: Text(
                                                      context.wp('Split'),
                                                    ),
                                                    icon: Icon(
                                                      Icons.view_week_rounded,
                                                    ),
                                                    enabled: splitEnabled,
                                                  ),
                                                ],
                                            selected: <_ReviewDiffMode>{
                                              effectiveDiffMode,
                                            },
                                            onSelectionChanged: (selection) {
                                              final next = selection.isEmpty
                                                  ? effectiveDiffMode
                                                  : selection.first;
                                              if (!splitEnabled &&
                                                  next ==
                                                      _ReviewDiffMode.split) {
                                                return;
                                              }
                                              if (next == _diffMode) {
                                                return;
                                              }
                                              setState(() {
                                                _diffMode = next;
                                              });
                                            },
                                          ),
                                        );
                                        final fullscreenButton =
                                            currentDiff != null &&
                                                parsedDiff != null
                                            ? _WorkspaceSideActionButton(
                                                buttonKey: const ValueKey<String>(
                                                  'review-preview-fullscreen-button',
                                                ),
                                                icon:
                                                    Icons.open_in_full_rounded,
                                                tooltip: context.wp(
                                                  'Open diff in full screen',
                                                ),
                                                onPressed: () {
                                                  _openReviewPreviewFullScreen(
                                                    diff: currentDiff,
                                                    parsedDiff: parsedDiff,
                                                    splitEnabled: splitEnabled,
                                                    compactMode: compactMode,
                                                    lineCount: diffLineCount,
                                                    initialMode:
                                                        effectiveDiffMode,
                                                    diffModeHint: diffModeHint,
                                                  );
                                                },
                                              )
                                            : null;
                                        return Align(
                                          alignment: Alignment.topRight,
                                          child: stackControls
                                              ? Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: <Widget>[
                                                    if (fullscreenButton !=
                                                        null)
                                                      fullscreenButton,
                                                    modeToggle,
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: <Widget>[
                                                    if (fullscreenButton !=
                                                        null) ...<Widget>[
                                                      fullscreenButton,
                                                      SizedBox(
                                                        width: density.inset(
                                                          AppSpacing.xxs,
                                                          min: 4,
                                                        ),
                                                      ),
                                                    ],
                                                    modeToggle,
                                                  ],
                                                ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (diffModeHint != null)
                              Container(
                                margin: EdgeInsets.only(
                                  bottom: density.inset(AppSpacing.xs, min: 4),
                                ),
                                padding: EdgeInsets.all(
                                  density.inset(AppSpacing.xs, min: 8),
                                ),
                                decoration: BoxDecoration(
                                  color: surfaces.warning.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: surfaces.warning.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  diffModeHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: surfaces.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: widget.loadingDiff
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : widget.diffError != null
                                  ? Center(
                                      child: Text(
                                        widget.diffError!,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: surfaces.muted),
                                      ),
                                    )
                                  : widget.diff == null || widget.diff!.isEmpty
                                  ? Center(
                                      child: Text(
                                        context.wp(
                                          'No diff output for this file.',
                                        ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: surfaces.muted),
                                      ),
                                    )
                                  : _ReviewDiffView(
                                      diff: currentDiff!,
                                      parsedDiff: parsedDiff!,
                                      mode: effectiveDiffMode,
                                      lineCount: diffLineCount,
                                      compactMode: compactMode,
                                      onLineComment: (target) {
                                        unawaited(_startLineComment(target));
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _ReviewDiffMode { unified, split }

const int _reviewDiffSelectionLineLimit = 160;
const int _reviewDiffSplitLineLimit = 420;
const int _reviewDiffSplitContentLengthLimit = 90000;
const int _reviewDiffCompactLineLimit = 1400;
const int _reviewDiffCompactContentLengthLimit = 220000;
const int _reviewDiffCompactRenderedLineLimit = 240;

int _reviewDiffLineCount(_ParsedReviewDiff diff) {
  var count = diff.headers.length;
  for (final hunk in diff.hunks) {
    count += 1 + hunk.lines.length;
  }
  return count;
}

bool _reviewDiffSupportsSplit({
  required int lineCount,
  required int contentLength,
}) {
  return lineCount <= _reviewDiffSplitLineLimit &&
      contentLength <= _reviewDiffSplitContentLengthLimit;
}

bool _reviewDiffShouldUseCompactMode({
  required int lineCount,
  required int contentLength,
}) {
  return lineCount > _reviewDiffCompactLineLimit ||
      contentLength > _reviewDiffCompactContentLengthLimit;
}

String? _reviewDiffModeHint(
  BuildContext context, {
  required bool splitEnabled,
  required bool compactMode,
}) {
  if (compactMode && !splitEnabled) {
    return context.wp(
      'Large diff detected. Showing the first {count} lines in unified mode; split view is disabled.',
      args: <String, Object?>{'count': _reviewDiffCompactRenderedLineLimit},
    );
  }
  if (compactMode) {
    return context.wp(
      'Large diff detected. Showing the first {count} lines to keep the review panel responsive.',
      args: <String, Object?>{'count': _reviewDiffCompactRenderedLineLimit},
    );
  }
  if (!splitEnabled) {
    return context.wp(
      'Split view is disabled for large diffs to keep the review panel responsive.',
    );
  }
  return null;
}

class _ReviewDiffView extends StatelessWidget {
  const _ReviewDiffView({
    required this.diff,
    required this.parsedDiff,
    required this.mode,
    required this.lineCount,
    required this.compactMode,
    required this.onLineComment,
  });

  final FileDiffSummary diff;
  final _ParsedReviewDiff parsedDiff;
  final _ReviewDiffMode mode;
  final int lineCount;
  final bool compactMode;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final selectionEnabled =
        !compactMode && lineCount <= _reviewDiffSelectionLineLimit;
    return KeyedSubtree(
      key: const ValueKey<String>('review-diff-blur'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Container(
          key: const ValueKey<String>('review-diff-surface'),
          width: double.infinity,
          padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
          decoration:
              _workspaceSidePanelDecoration(
                surfaces: surfaces,
                compact: density.compact,
                tint: theme.colorScheme.primary,
              ).copyWith(
                color: Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.015),
                  surfaces.background.withValues(
                    alpha: density.compact ? 0.78 : 0.86,
                  ),
                ),
                borderRadius: BorderRadius.circular(AppSpacing.md),
              ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = mode == _ReviewDiffMode.split
                  ? math.max(constraints.maxWidth, density.maxContentWidth(940))
                  : constraints.maxWidth;
              final contentHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 480.0;
              final maxRenderedLines = compactMode
                  ? _reviewDiffCompactRenderedLineLimit
                  : null;
              if (mode == _ReviewDiffMode.unified) {
                final rows = _buildReviewUnifiedRowModels(
                  context,
                  parsedDiff,
                  maxRenderedLines: maxRenderedLines,
                  totalLineCount: lineCount,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: minWidth,
                    height: contentHeight,
                    child: _ReviewUnifiedDiffBody(
                      key: const ValueKey<String>('review-diff-unified-view'),
                      rows: rows,
                      filePath: diff.path,
                      contentWidth: minWidth,
                      selectionEnabled: selectionEnabled,
                      theme: theme,
                      surfaces: surfaces,
                      onLineComment: onLineComment,
                    ),
                  ),
                );
              }
              final rows = _buildReviewSplitRowModels(
                context,
                parsedDiff,
                maxRenderedLines: maxRenderedLines,
                totalLineCount: lineCount,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  height: contentHeight,
                  child: _ReviewSplitDiffBody(
                    key: const ValueKey<String>('review-diff-split-view'),
                    rows: rows,
                    filePath: diff.path,
                    selectionEnabled: selectionEnabled,
                    theme: theme,
                    surfaces: surfaces,
                    onLineComment: onLineComment,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Color _reviewStatusColor(String status, AppSurfaces surfaces) {
  switch (status.toLowerCase()) {
    case 'added':
    case 'created':
    case 'untracked':
    case 'copied':
      return surfaces.success;
    case 'deleted':
    case 'removed':
      return surfaces.danger;
    case 'modified':
    case 'changed':
    case 'renamed':
    case 'typechange':
      return surfaces.warning;
    default:
      return surfaces.muted;
  }
}

IconData _reviewStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'added':
    case 'created':
    case 'untracked':
    case 'copied':
      return Icons.add_circle_outline_rounded;
    case 'deleted':
    case 'removed':
      return Icons.remove_circle_outline_rounded;
    case 'modified':
    case 'changed':
    case 'renamed':
    case 'typechange':
      return Icons.change_circle_outlined;
    default:
      return Icons.description_outlined;
  }
}

class _ReviewSplitDiffBody extends StatelessWidget {
  const _ReviewSplitDiffBody({
    required this.rows,
    required this.filePath,
    required this.selectionEnabled,
    required this.theme,
    required this.surfaces,
    required this.onLineComment,
    super.key,
  });

  final List<_ReviewDiffRowModel> rows;
  final String filePath;
  final bool selectionEnabled;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final child = ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        switch (row.kind) {
          case _ReviewDiffRowKind.meta:
            return _ReviewDiffMetaRow(
              text: row.text!,
              theme: theme,
              surfaces: surfaces,
            );
          case _ReviewDiffRowKind.notice:
            return _ReviewDiffNoticeRow(
              text: row.text!,
              theme: theme,
              surfaces: surfaces,
            );
          case _ReviewDiffRowKind.spacerTiny:
            return const SizedBox(height: AppSpacing.xxs);
          case _ReviewDiffRowKind.spacerSmall:
            return const SizedBox(height: AppSpacing.sm);
          case _ReviewDiffRowKind.spacerDivider:
            return const SizedBox(height: 1);
          case _ReviewDiffRowKind.hunkHeader:
            return _ReviewDiffHunkHeaderRow(
              text: row.text!,
              theme: theme,
              surfaces: surfaces,
            );
          case _ReviewDiffRowKind.splitSideHeader:
            return _ReviewSplitSideHeader(theme: theme, surfaces: surfaces);
          case _ReviewDiffRowKind.splitPair:
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _ReviewSplitLineCell(
                    line: row.pair!.left,
                    filePath: filePath,
                    hunkHeader: row.hunkHeader!,
                    theme: theme,
                    surfaces: surfaces,
                    side: _ReviewSplitSide.before,
                    onLineComment: onLineComment,
                  ),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: _ReviewSplitLineCell(
                    line: row.pair!.right,
                    filePath: filePath,
                    hunkHeader: row.hunkHeader!,
                    theme: theme,
                    surfaces: surfaces,
                    side: _ReviewSplitSide.after,
                    onLineComment: onLineComment,
                  ),
                ),
              ],
            );
          case _ReviewDiffRowKind.unifiedLine:
            return const SizedBox.shrink();
        }
      },
    );
    return selectionEnabled ? SelectionArea(child: child) : child;
  }
}

class _ReviewDiffMetaRow extends StatelessWidget {
  const _ReviewDiffMetaRow({
    required this.text,
    required this.theme,
    required this.surfaces,
  });

  final String text;
  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.xs, min: 6),
        vertical: density.compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaces.lineSoft.withValues(alpha: 0.68)),
      ),
      child: Text(
        text,
        softWrap: false,
        style: _reviewDiffMetaTextStyle(theme: theme, surfaces: surfaces),
      ),
    );
  }
}

class _ReviewDiffHunkHeaderRow extends StatelessWidget {
  const _ReviewDiffHunkHeaderRow({
    required this.text,
    required this.theme,
    required this.surfaces,
  });

  final String text;
  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.xs, min: 6),
        vertical: density.compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        softWrap: false,
        style: _reviewDiffHunkTextStyle(theme: theme, surfaces: surfaces),
      ),
    );
  }
}

class _ReviewDiffNoticeRow extends StatelessWidget {
  const _ReviewDiffNoticeRow({
    required this.text,
    required this.theme,
    required this.surfaces,
  });

  final String text;
  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.xs, min: 6),
        vertical: density.compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: surfaces.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaces.warning.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: surfaces.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewSplitSideHeader extends StatelessWidget {
  const _ReviewSplitSideHeader({required this.theme, required this.surfaces});

  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: surfaces.muted,
      fontFamily: 'monospace',
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: density.inset(AppSpacing.xs, min: 6),
              vertical: density.compact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: surfaces.panelMuted.withValues(alpha: 0.62),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
              ),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text(context.wp('Before'), style: labelStyle),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: density.inset(AppSpacing.xs, min: 6),
              vertical: density.compact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: surfaces.panelMuted.withValues(alpha: 0.62),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
              ),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text(context.wp('After'), style: labelStyle),
          ),
        ),
      ],
    );
  }
}

enum _ReviewDiffRowKind {
  meta,
  notice,
  spacerTiny,
  spacerSmall,
  spacerDivider,
  hunkHeader,
  splitSideHeader,
  unifiedLine,
  splitPair,
}

class _ReviewDiffRowModel {
  const _ReviewDiffRowModel._({
    required this.kind,
    this.text,
    this.hunkHeader,
    this.line,
    this.pair,
  });

  const _ReviewDiffRowModel.meta(String text)
    : this._(kind: _ReviewDiffRowKind.meta, text: text);

  const _ReviewDiffRowModel.notice(String text)
    : this._(kind: _ReviewDiffRowKind.notice, text: text);

  const _ReviewDiffRowModel.spacerTiny()
    : this._(kind: _ReviewDiffRowKind.spacerTiny);

  const _ReviewDiffRowModel.spacerSmall()
    : this._(kind: _ReviewDiffRowKind.spacerSmall);

  const _ReviewDiffRowModel.spacerDivider()
    : this._(kind: _ReviewDiffRowKind.spacerDivider);

  const _ReviewDiffRowModel.hunkHeader(String text)
    : this._(kind: _ReviewDiffRowKind.hunkHeader, text: text);

  const _ReviewDiffRowModel.splitSideHeader()
    : this._(kind: _ReviewDiffRowKind.splitSideHeader);

  const _ReviewDiffRowModel.unifiedLine({
    required String hunkHeader,
    required _ParsedReviewLine line,
  }) : this._(
         kind: _ReviewDiffRowKind.unifiedLine,
         hunkHeader: hunkHeader,
         line: line,
       );

  const _ReviewDiffRowModel.splitPair({
    required String hunkHeader,
    required _ReviewSplitLinePair pair,
  }) : this._(
         kind: _ReviewDiffRowKind.splitPair,
         hunkHeader: hunkHeader,
         pair: pair,
       );

  final _ReviewDiffRowKind kind;
  final String? text;
  final String? hunkHeader;
  final _ParsedReviewLine? line;
  final _ReviewSplitLinePair? pair;
}

List<_ReviewDiffRowModel> _buildReviewUnifiedRowModels(
  BuildContext context,
  _ParsedReviewDiff diff, {
  required int totalLineCount,
  int? maxRenderedLines,
}) {
  final rows = <_ReviewDiffRowModel>[];
  var renderedLines = 0;
  var truncated = false;

  for (final header in diff.headers) {
    rows
      ..add(_ReviewDiffRowModel.meta(header))
      ..add(const _ReviewDiffRowModel.spacerTiny());
  }

  for (var hunkIndex = 0; hunkIndex < diff.hunks.length; hunkIndex += 1) {
    final hunk = diff.hunks[hunkIndex];
    if (diff.headers.isNotEmpty || hunkIndex > 0) {
      rows.add(const _ReviewDiffRowModel.spacerSmall());
    }
    rows
      ..add(_ReviewDiffRowModel.hunkHeader(hunk.header))
      ..add(const _ReviewDiffRowModel.spacerTiny());
    for (var lineIndex = 0; lineIndex < hunk.lines.length; lineIndex += 1) {
      if (maxRenderedLines != null && renderedLines >= maxRenderedLines) {
        truncated = true;
        break;
      }
      rows.add(
        _ReviewDiffRowModel.unifiedLine(
          hunkHeader: hunk.header,
          line: hunk.lines[lineIndex],
        ),
      );
      renderedLines += 1;
      if (lineIndex != hunk.lines.length - 1 &&
          (maxRenderedLines == null || renderedLines < maxRenderedLines)) {
        rows.add(const _ReviewDiffRowModel.spacerDivider());
      }
    }
    if (truncated) {
      break;
    }
  }

  if (truncated) {
    rows
      ..add(const _ReviewDiffRowModel.spacerSmall())
      ..add(
        _ReviewDiffRowModel.notice(
          context.wp(
            'Showing the first {rendered} of {total} diff lines.',
            args: <String, Object?>{
              'rendered': renderedLines,
              'total': totalLineCount,
            },
          ),
        ),
      );
  }

  return List<_ReviewDiffRowModel>.unmodifiable(rows);
}

List<_ReviewDiffRowModel> _buildReviewSplitRowModels(
  BuildContext context,
  _ParsedReviewDiff diff, {
  required int totalLineCount,
  int? maxRenderedLines,
}) {
  final rows = <_ReviewDiffRowModel>[];
  var renderedLines = 0;
  var truncated = false;

  for (final header in diff.headers) {
    rows
      ..add(_ReviewDiffRowModel.meta(header))
      ..add(const _ReviewDiffRowModel.spacerTiny());
  }

  for (var hunkIndex = 0; hunkIndex < diff.hunks.length; hunkIndex += 1) {
    final hunk = diff.hunks[hunkIndex];
    if (diff.headers.isNotEmpty || hunkIndex > 0) {
      rows.add(const _ReviewDiffRowModel.spacerSmall());
    }
    rows
      ..add(_ReviewDiffRowModel.hunkHeader(hunk.header))
      ..add(const _ReviewDiffRowModel.spacerTiny())
      ..add(const _ReviewDiffRowModel.splitSideHeader());
    final pairs = _pairReviewSplitLines(hunk.lines);
    for (var pairIndex = 0; pairIndex < pairs.length; pairIndex += 1) {
      if (maxRenderedLines != null && renderedLines >= maxRenderedLines) {
        truncated = true;
        break;
      }
      rows.add(
        _ReviewDiffRowModel.splitPair(
          hunkHeader: hunk.header,
          pair: pairs[pairIndex],
        ),
      );
      renderedLines += 1;
      if (pairIndex != pairs.length - 1 &&
          (maxRenderedLines == null || renderedLines < maxRenderedLines)) {
        rows.add(const _ReviewDiffRowModel.spacerDivider());
      }
    }
    if (truncated) {
      break;
    }
  }

  if (truncated) {
    rows
      ..add(const _ReviewDiffRowModel.spacerSmall())
      ..add(
        _ReviewDiffRowModel.notice(
          context.wp(
            'Showing the first {rendered} of {total} diff lines.',
            args: <String, Object?>{
              'rendered': renderedLines,
              'total': totalLineCount,
            },
          ),
        ),
      );
  }

  return List<_ReviewDiffRowModel>.unmodifiable(rows);
}

class _ReviewUnifiedDiffBody extends StatelessWidget {
  const _ReviewUnifiedDiffBody({
    required this.rows,
    required this.filePath,
    required this.contentWidth,
    required this.selectionEnabled,
    required this.theme,
    required this.surfaces,
    required this.onLineComment,
    super.key,
  });

  final List<_ReviewDiffRowModel> rows;
  final String filePath;
  final double contentWidth;
  final bool selectionEnabled;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final child = ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        switch (row.kind) {
          case _ReviewDiffRowKind.meta:
            return _ReviewDiffMetaRow(
              text: row.text!,
              theme: theme,
              surfaces: surfaces,
            );
          case _ReviewDiffRowKind.notice:
            return _ReviewDiffNoticeRow(
              text: row.text!,
              theme: theme,
              surfaces: surfaces,
            );
          case _ReviewDiffRowKind.spacerTiny:
            return const SizedBox(height: AppSpacing.xxs);
          case _ReviewDiffRowKind.spacerSmall:
            return const SizedBox(height: AppSpacing.sm);
          case _ReviewDiffRowKind.spacerDivider:
            return const SizedBox(height: 1);
          case _ReviewDiffRowKind.hunkHeader:
            return _ReviewDiffHunkHeaderRow(
              text: row.text!,
              theme: theme,
              surfaces: surfaces,
            );
          case _ReviewDiffRowKind.unifiedLine:
            return _ReviewUnifiedLineRow(
              filePath: filePath,
              hunkHeader: row.hunkHeader!,
              line: row.line!,
              theme: theme,
              surfaces: surfaces,
              onLineComment: onLineComment,
            );
          case _ReviewDiffRowKind.splitSideHeader:
          case _ReviewDiffRowKind.splitPair:
            return const SizedBox.shrink();
        }
      },
    );
    return SizedBox(
      width: contentWidth,
      child: selectionEnabled ? SelectionArea(child: child) : child,
    );
  }
}

class _ReviewUnifiedLineRow extends StatelessWidget {
  const _ReviewUnifiedLineRow({
    required this.filePath,
    required this.hunkHeader,
    required this.line,
    required this.theme,
    required this.surfaces,
    required this.onLineComment,
  });

  final String filePath;
  final String hunkHeader;
  final _ParsedReviewLine line;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    final lineNumberWidth = density.compact ? 32.0 : 40.0;
    final verticalPadding = density.compact ? 1.5 : 3.0;
    final lineTextHeight = density.compact ? 1.25 : 1.45;
    final backgroundColor = switch (line.kind) {
      _ParsedReviewLineKind.insert => surfaces.success.withValues(alpha: 0.08),
      _ParsedReviewLineKind.delete => surfaces.danger.withValues(alpha: 0.08),
      _ParsedReviewLineKind.context => Colors.transparent,
    };
    final textColor = switch (line.kind) {
      _ParsedReviewLineKind.insert => surfaces.success,
      _ParsedReviewLineKind.delete => surfaces.danger,
      _ParsedReviewLineKind.context => theme.colorScheme.onSurface,
    };
    final prefix = switch (line.kind) {
      _ParsedReviewLineKind.insert => '+',
      _ParsedReviewLineKind.delete => '-',
      _ParsedReviewLineKind.context => ' ',
    };
    final target = _reviewCommentTargetForLine(
      path: filePath,
      hunkHeader: hunkHeader,
      line: line,
    );
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.sm),
        vertical: verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: lineNumberWidth,
            child: Text(
              line.oldNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: surfaces.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            width: lineNumberWidth,
            child: Text(
              line.newNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: surfaces.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          _ReviewLineCommentButton(
            target: target,
            onPressed: () => onLineComment(target),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              '$prefix${line.text}',
              softWrap: false,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: lineTextHeight,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReviewSplitSide { before, after }

class _ReviewSplitLineCell extends StatelessWidget {
  const _ReviewSplitLineCell({
    required this.line,
    required this.filePath,
    required this.hunkHeader,
    required this.theme,
    required this.surfaces,
    required this.side,
    required this.onLineComment,
  });

  final _ParsedReviewLine? line;
  final String filePath;
  final String hunkHeader;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final _ReviewSplitSide side;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    final lineNumberWidth = density.compact ? 40.0 : 46.0;
    final prefixWidth = density.compact ? 10.0 : 12.0;
    final commentWidth = density.compact ? 20.0 : 24.0;
    final verticalPadding = density.compact ? 1.5 : 3.0;
    final lineTextHeight = density.compact ? 1.25 : 1.45;
    final lineKind = line?.kind;
    final backgroundColor = switch (lineKind) {
      _ParsedReviewLineKind.insert => surfaces.success.withValues(alpha: 0.08),
      _ParsedReviewLineKind.delete => surfaces.danger.withValues(alpha: 0.08),
      _ParsedReviewLineKind.context => Colors.transparent,
      null => surfaces.panelEmphasis.withValues(alpha: 0.32),
    };
    final textColor = switch (lineKind) {
      _ParsedReviewLineKind.insert => surfaces.success,
      _ParsedReviewLineKind.delete => surfaces.danger,
      _ParsedReviewLineKind.context || null => theme.colorScheme.onSurface,
    };
    final lineNumber = switch (side) {
      _ReviewSplitSide.before => line?.oldNumber,
      _ReviewSplitSide.after => line?.newNumber,
    };
    final prefix = switch (lineKind) {
      _ParsedReviewLineKind.insert => '+',
      _ParsedReviewLineKind.delete => '-',
      _ParsedReviewLineKind.context || null => ' ',
    };
    final commentTarget = line == null
        ? null
        : _reviewCommentTargetForLine(
            path: filePath,
            hunkHeader: hunkHeader,
            line: line!,
          );
    final showCommentButton =
        commentTarget != null && _canCommentOnSplitLine(line: line, side: side);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.sm),
        vertical: verticalPadding,
      ),
      color: backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: lineNumberWidth,
            child: Text(
              lineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: surfaces.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            width: prefixWidth,
            child: Text(
              line == null ? '' : prefix,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          SizedBox(
            width: commentWidth,
            child: !showCommentButton
                ? const SizedBox.shrink()
                : _ReviewLineCommentButton(
                    target: commentTarget,
                    onPressed: () => onLineComment(commentTarget),
                  ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              line?.text ?? '',
              softWrap: false,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: lineTextHeight,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLineCommentButton extends StatelessWidget {
  const _ReviewLineCommentButton({
    required this.target,
    required this.onPressed,
  });

  final _ReviewCommentTarget target;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    final buttonSize = density.compact ? 20.0 : 24.0;
    return Tooltip(
      message: context.wp(
        'Add review comment for {location}',
        args: <String, Object?>{'location': target.locationLabel(context)},
      ),
      child: IconButton(
        key: ValueKey<String>(_reviewCommentTargetButtonKey(target)),
        onPressed: onPressed,
        icon: Icon(Icons.add_comment_rounded, size: density.compact ? 14 : 16),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: buttonSize,
          height: buttonSize,
        ),
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
      ),
    );
  }
}

class _ReviewLineCommentEditor extends StatelessWidget {
  const _ReviewLineCommentEditor({
    required this.target,
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final _ReviewCommentTarget target;
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      key: const ValueKey<String>('review-line-comment-editor'),
      width: double.infinity,
      padding: EdgeInsets.all(density.inset(AppSpacing.sm, min: 12)),
      decoration: _workspaceSidePanelDecoration(
        surfaces: surfaces,
        compact: density.compact,
        elevated: true,
        tint: theme.colorScheme.primary,
      ).copyWith(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.wp('Add to composer context'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${target.path} · ${target.locationLabel(context)}',
            style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            target.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: surfaces.muted,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('review-line-comment-field'),
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: context.wp(
                'Explain what you want the model to focus on.',
              ),
            ),
            onSubmitted: (_) {
              if (controller.text.trim().isEmpty) {
                return;
              }
              onSubmit();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final canSubmit = value.text.trim().isNotEmpty;
              return OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: AppSpacing.xs,
                children: <Widget>[
                  TextButton(
                    onPressed: onCancel,
                    child: Text(context.wp('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey<String>('review-line-comment-submit'),
                    onPressed: canSubmit ? onSubmit : null,
                    child: Text(context.wp('Add to composer')),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewCommentTarget {
  const _ReviewCommentTarget({
    required this.path,
    required this.preview,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final String path;
  final String preview;
  final int? oldLineNumber;
  final int? newLineNumber;

  String locationLabel(BuildContext context) {
    if (oldLineNumber != null && newLineNumber != null) {
      if (oldLineNumber == newLineNumber) {
        return context.wp(
          'line {line}',
          args: <String, Object?>{'line': newLineNumber},
        );
      }
      return context.wp(
        'old {old} / new {new}',
        args: <String, Object?>{'old': oldLineNumber, 'new': newLineNumber},
      );
    }
    if (newLineNumber != null) {
      return context.wp(
        'new line {line}',
        args: <String, Object?>{'line': newLineNumber},
      );
    }
    if (oldLineNumber != null) {
      return context.wp(
        'old line {line}',
        args: <String, Object?>{'line': oldLineNumber},
      );
    }
    return context.wp('selected lines');
  }
}

class _ReviewLineCommentSubmission {
  const _ReviewLineCommentSubmission({
    required this.target,
    required this.comment,
  });

  final _ReviewCommentTarget target;
  final String comment;
}

_ReviewCommentTarget _reviewCommentTargetForLine({
  required String path,
  required String hunkHeader,
  required _ParsedReviewLine line,
}) {
  final prefix = switch (line.kind) {
    _ParsedReviewLineKind.insert => '+',
    _ParsedReviewLineKind.delete => '-',
    _ParsedReviewLineKind.context => ' ',
  };
  return _ReviewCommentTarget(
    path: path,
    oldLineNumber: line.oldNumber,
    newLineNumber: line.newNumber,
    preview: '$hunkHeader\n$prefix${line.text}',
  );
}

bool _canCommentOnSplitLine({
  required _ParsedReviewLine? line,
  required _ReviewSplitSide side,
}) {
  if (line == null) {
    return false;
  }
  return switch (line.kind) {
    _ParsedReviewLineKind.insert => side == _ReviewSplitSide.after,
    _ParsedReviewLineKind.delete => side == _ReviewSplitSide.before,
    _ParsedReviewLineKind.context => side == _ReviewSplitSide.after,
  };
}

String _reviewCommentTargetButtonKey(_ReviewCommentTarget target) {
  return 'review-line-comment-button-${target.path}-old-${target.oldLineNumber ?? 'none'}-new-${target.newLineNumber ?? 'none'}';
}

class _ParsedReviewDiff {
  const _ParsedReviewDiff({required this.headers, required this.hunks});

  final List<String> headers;
  final List<_ParsedReviewHunk> hunks;
}

class _ParsedReviewHunk {
  const _ParsedReviewHunk({required this.header, required this.lines});

  final String header;
  final List<_ParsedReviewLine> lines;
}

enum _ParsedReviewLineKind { context, delete, insert }

class _ParsedReviewLine {
  const _ParsedReviewLine({
    required this.kind,
    required this.text,
    this.oldNumber,
    this.newNumber,
  });

  final _ParsedReviewLineKind kind;
  final String text;
  final int? oldNumber;
  final int? newNumber;
}

class _ReviewSplitLinePair {
  const _ReviewSplitLinePair({this.left, this.right});

  final _ParsedReviewLine? left;
  final _ParsedReviewLine? right;
}

class _ParsedReviewDiffCacheEntry {
  const _ParsedReviewDiffCacheEntry({
    required this.content,
    required this.parsedDiff,
  });

  final String content;
  final _ParsedReviewDiff parsedDiff;
}

final _reviewDiffParseCache = _LruCache<int, _ParsedReviewDiffCacheEntry>(
  maximumSize: 24,
);

_ParsedReviewDiff _cachedParsedReviewDiff(String content) {
  if (content.trim().isEmpty) {
    return const _ParsedReviewDiff(
      headers: <String>[],
      hunks: <_ParsedReviewHunk>[],
    );
  }
  final signature = Object.hash(content.length, content.hashCode);
  final cached = _reviewDiffParseCache.get(signature);
  if (cached != null && cached.content == content) {
    return cached.parsedDiff;
  }
  final parsedDiff = _parseReviewDiff(content);
  _reviewDiffParseCache.set(
    signature,
    _ParsedReviewDiffCacheEntry(content: content, parsedDiff: parsedDiff),
  );
  return parsedDiff;
}

_ParsedReviewDiff _parseReviewDiff(String content) {
  if (content.trim().isEmpty) {
    return const _ParsedReviewDiff(
      headers: <String>[],
      hunks: <_ParsedReviewHunk>[],
    );
  }

  final lines = content.split('\n');
  final headers = <String>[];
  final hunks = <_ParsedReviewHunk>[];
  final hunkHeaderPattern = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

  String? currentHunkHeader;
  var currentHunkLines = <_ParsedReviewLine>[];
  var oldNumber = 0;
  var newNumber = 0;

  void flushCurrentHunk() {
    final header = currentHunkHeader;
    if (header == null) {
      return;
    }
    hunks.add(
      _ParsedReviewHunk(
        header: header,
        lines: List<_ParsedReviewLine>.unmodifiable(currentHunkLines),
      ),
    );
    currentHunkHeader = null;
    currentHunkLines = <_ParsedReviewLine>[];
  }

  for (final rawLine in lines) {
    if (rawLine.startsWith('@@')) {
      flushCurrentHunk();
      currentHunkHeader = rawLine;
      final match = hunkHeaderPattern.firstMatch(rawLine);
      oldNumber = int.tryParse(match?.group(1) ?? '') ?? 0;
      newNumber = int.tryParse(match?.group(2) ?? '') ?? 0;
      continue;
    }

    if (currentHunkHeader == null) {
      headers.add(rawLine);
      continue;
    }

    if (rawLine.startsWith('+') && !rawLine.startsWith('+++')) {
      currentHunkLines.add(
        _ParsedReviewLine(
          kind: _ParsedReviewLineKind.insert,
          text: rawLine.substring(1),
          newNumber: newNumber,
        ),
      );
      newNumber += 1;
      continue;
    }
    if (rawLine.startsWith('-') && !rawLine.startsWith('---')) {
      currentHunkLines.add(
        _ParsedReviewLine(
          kind: _ParsedReviewLineKind.delete,
          text: rawLine.substring(1),
          oldNumber: oldNumber,
        ),
      );
      oldNumber += 1;
      continue;
    }
    if (rawLine.startsWith(' ')) {
      currentHunkLines.add(
        _ParsedReviewLine(
          kind: _ParsedReviewLineKind.context,
          text: rawLine.substring(1),
          oldNumber: oldNumber,
          newNumber: newNumber,
        ),
      );
      oldNumber += 1;
      newNumber += 1;
      continue;
    }
  }

  flushCurrentHunk();

  return _ParsedReviewDiff(
    headers: List<String>.unmodifiable(headers),
    hunks: List<_ParsedReviewHunk>.unmodifiable(hunks),
  );
}

List<_ReviewSplitLinePair> _pairReviewSplitLines(
  List<_ParsedReviewLine> lines,
) {
  final pairs = <_ReviewSplitLinePair>[];
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    if (line.kind == _ParsedReviewLineKind.context) {
      pairs.add(_ReviewSplitLinePair(left: line, right: line));
      index += 1;
      continue;
    }
    if (line.kind == _ParsedReviewLineKind.delete) {
      final deletes = <_ParsedReviewLine>[];
      while (index < lines.length &&
          lines[index].kind == _ParsedReviewLineKind.delete) {
        deletes.add(lines[index]);
        index += 1;
      }
      final inserts = <_ParsedReviewLine>[];
      while (index < lines.length &&
          lines[index].kind == _ParsedReviewLineKind.insert) {
        inserts.add(lines[index]);
        index += 1;
      }
      final count = math.max(deletes.length, inserts.length);
      for (var pairIndex = 0; pairIndex < count; pairIndex += 1) {
        pairs.add(
          _ReviewSplitLinePair(
            left: pairIndex < deletes.length ? deletes[pairIndex] : null,
            right: pairIndex < inserts.length ? inserts[pairIndex] : null,
          ),
        );
      }
      continue;
    }
    final inserts = <_ParsedReviewLine>[];
    while (index < lines.length &&
        lines[index].kind == _ParsedReviewLineKind.insert) {
      inserts.add(lines[index]);
      index += 1;
    }
    for (final insert in inserts) {
      pairs.add(_ReviewSplitLinePair(right: insert));
    }
  }
  return pairs;
}

TextStyle? _reviewDiffMetaTextStyle({
  required ThemeData theme,
  required AppSurfaces surfaces,
}) {
  return theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    height: 1.45,
    color: surfaces.warning,
  );
}

TextStyle? _reviewDiffHunkTextStyle({
  required ThemeData theme,
  required AppSurfaces surfaces,
}) {
  return theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    height: 1.45,
    color: theme.colorScheme.primary,
    fontWeight: FontWeight.w700,
  );
}

class _FilesPanel extends StatefulWidget {
  const _FilesPanel({
    required this.bundle,
    required this.loadingFiles,
    required this.loadingPreview,
    required this.expandedDirectories,
    required this.loadingDirectoryPath,
    required this.onSelectFile,
    required this.onToggleDirectory,
  });

  final FileBrowserBundle? bundle;
  final bool loadingFiles;
  final bool loadingPreview;
  final Set<String> expandedDirectories;
  final String? loadingDirectoryPath;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onToggleDirectory;

  @override
  State<_FilesPanel> createState() => _FilesPanelState();
}

class _FilesPanelState extends State<_FilesPanel> {
  static const double _defaultPreviewHeight = 220;
  static const double _minPreviewHeight = 140;
  static const double _minTreeHeight = 180;

  double _previewHeight = _defaultPreviewHeight;

  void _resizePreview(double deltaDy, double availableHeight) {
    final maxPreviewHeight = (availableHeight - _minTreeHeight).clamp(
      _minPreviewHeight,
      availableHeight,
    );
    final next = (_previewHeight - deltaDy).clamp(
      _minPreviewHeight,
      maxPreviewHeight,
    );
    if (next == _previewHeight) {
      return;
    }
    setState(() {
      _previewHeight = next;
    });
  }

  void _openFilePreviewFullScreen(FileBrowserBundle bundle) {
    final preview = bundle.preview;
    if (preview == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _WorkspaceFilePreviewPage(
          path: bundle.selectedPath,
          content: preview.content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final bundle = widget.bundle;
    if (bundle == null) {
      if (widget.loadingFiles) {
        return const Center(child: CircularProgressIndicator());
      }
      return _WorkspaceSideEmptyState(
        icon: Icons.folder_off_rounded,
        title: context.wp('Files are unavailable'),
        message: context.wp(
          'The workspace file browser is not ready yet. Try again after the project finishes loading.',
        ),
        tint: theme.colorScheme.primary,
      );
    }
    final visibleNodes = _cachedVisibleFileNodes(
      bundle: bundle,
      expandedDirectories: widget.expandedDirectories,
      loadingDirectoryPath: widget.loadingDirectoryPath,
    );
    final hasPreview = bundle.selectedPath != null || bundle.preview != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 700.0;
        final previewHeight = hasPreview
            ? _previewHeight.clamp(
                _minPreviewHeight,
                (availableHeight - _minTreeHeight).clamp(
                  _minPreviewHeight,
                  availableHeight,
                ),
              )
            : 0.0;

        return Column(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  _WorkspaceSideSectionHeader(
                    title: context.wp('Workspace files'),
                    caption: bundle.selectedPath == null
                        ? context.wp(
                            '{count} items available. Expand folders or choose a file to inspect its preview.',
                            args: <String, Object?>{
                              'count': visibleNodes.length,
                            },
                          )
                        : context.wp(
                            '{count} items available. Preview stays pinned while you navigate the tree.',
                            args: <String, Object?>{
                              'count': visibleNodes.length,
                            },
                          ),
                    trailing: _WorkspaceSideBadge(
                      label: '${bundle.nodes.length}',
                      tint: theme.colorScheme.primary,
                      emphasized: true,
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
                      itemCount: visibleNodes.length,
                      separatorBuilder: (_, _) => SizedBox(
                        height: density.inset(AppSpacing.xxs, min: 4),
                      ),
                      itemBuilder: (context, index) {
                        final entry = visibleNodes[index];
                        final node = entry.node;
                        final selected = node.path == bundle.selectedPath;
                        final isDirectory = node.type == 'directory';
                        final accent = isDirectory
                            ? theme.colorScheme.primary
                            : surfaces.accentSoft;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: selected
                              ? _workspaceSideSelectionDecoration(
                                  theme: theme,
                                  surfaces: surfaces,
                                  compact: density.compact,
                                  accent: theme.colorScheme.primary,
                                )
                              : _workspaceSidePanelDecoration(
                                  surfaces: surfaces,
                                  compact: density.compact,
                                  tint: accent,
                                ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                density.compact ? 16 : 18,
                              ),
                            ),
                            contentPadding: EdgeInsets.only(
                              left:
                                  density.inset(AppSpacing.xs, min: 8) +
                                  (entry.depth * density.inset(18, min: 12)),
                              right: density.inset(AppSpacing.xs, min: 8),
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(
                                  width: 18,
                                  child: isDirectory
                                      ? Icon(
                                          entry.expanded
                                              ? Icons.expand_more_rounded
                                              : Icons.chevron_right_rounded,
                                          size: 18,
                                          color: surfaces.muted,
                                        )
                                      : null,
                                ),
                                SizedBox(width: density.inset(AppSpacing.xs)),
                                Container(
                                  width: density.inset(28, min: 26),
                                  height: density.inset(28, min: 26),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.16),
                                    ),
                                  ),
                                  child: Icon(
                                    isDirectory
                                        ? (entry.expanded
                                              ? Icons.folder_open_outlined
                                              : Icons.folder_outlined)
                                        : Icons.insert_drive_file_outlined,
                                    size: 16,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              node.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              node.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: surfaces.muted,
                              ),
                            ),
                            trailing: entry.loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : (selected
                                      ? Icon(
                                          Icons.chevron_right_rounded,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null),
                            onTap: () => isDirectory
                                ? widget.onToggleDirectory(node.path)
                                : widget.onSelectFile(node.path),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (hasPreview)
              Container(
                key: const ValueKey<String>('files-preview-panel'),
                height: previewHeight,
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(
                  density.inset(AppSpacing.sm),
                  0,
                  density.inset(AppSpacing.sm),
                  density.inset(AppSpacing.sm),
                ),
                decoration: _workspaceSidePanelDecoration(
                  surfaces: surfaces,
                  compact: density.compact,
                  elevated: true,
                  tint: theme.colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey<String>(
                        'files-preview-resize-handle',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        _resizePreview(details.delta.dy, availableHeight);
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: SizedBox(
                          height: density.compact ? 20 : 22,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: surfaces.muted.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          density.inset(AppSpacing.sm),
                          0,
                          density.inset(AppSpacing.sm),
                          density.inset(AppSpacing.sm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (bundle.selectedPath != null)
                              _WorkspaceSideSectionHeader(
                                title: context.wp('Preview'),
                                caption: bundle.selectedPath!,
                                dense: true,
                                trailing: bundle.preview == null
                                    ? null
                                    : _WorkspaceSideActionButton(
                                        buttonKey: const ValueKey<String>(
                                          'files-preview-fullscreen-button',
                                        ),
                                        icon: Icons.open_in_full_rounded,
                                        tooltip: context.wp(
                                          'Open file preview in full screen',
                                        ),
                                        onPressed: () {
                                          _openFilePreviewFullScreen(bundle);
                                        },
                                      ),
                              ),
                            Expanded(
                              child: widget.loadingPreview
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : bundle.preview == null
                                  ? Center(
                                      child: Text(
                                        context.wp(
                                          'Preview unavailable for this item.',
                                        ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: surfaces.muted),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(
                                        density.inset(AppSpacing.sm),
                                      ),
                                      decoration:
                                          _workspaceSidePanelDecoration(
                                            surfaces: surfaces,
                                            compact: density.compact,
                                            tint: surfaces.accentSoft,
                                          ).copyWith(
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.md,
                                            ),
                                          ),
                                      child: LayoutBuilder(
                                        builder: (context, previewConstraints) {
                                          return _WorkspaceSafeFilePreview(
                                            path: bundle.selectedPath,
                                            content: bundle.preview!.content,
                                            previewWidth:
                                                previewConstraints.maxWidth,
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VisibleFileTreeEntry {
  const _VisibleFileTreeEntry({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.loading,
  });

  final FileNodeSummary node;
  final int depth;
  final bool expanded;
  final bool loading;
}

class _VisibleFileTreeCacheKey {
  const _VisibleFileTreeCacheKey({
    required this.nodeSignature,
    required this.expandedSignature,
    required this.loadingDirectoryPath,
  });

  final int nodeSignature;
  final int expandedSignature;
  final String? loadingDirectoryPath;

  @override
  bool operator ==(Object other) {
    return other is _VisibleFileTreeCacheKey &&
        other.nodeSignature == nodeSignature &&
        other.expandedSignature == expandedSignature &&
        other.loadingDirectoryPath == loadingDirectoryPath;
  }

  @override
  int get hashCode =>
      Object.hash(nodeSignature, expandedSignature, loadingDirectoryPath);
}

final Expando<int> _fileNodeSignatureCache = Expando<int>(
  'workspaceFileNodeSignature',
);
final _visibleFileTreeCache =
    _LruCache<_VisibleFileTreeCacheKey, List<_VisibleFileTreeEntry>>(
      maximumSize: 48,
    );
const int _workspaceFilePreviewCollapsedCharacterLimit = 16000;

int _fileNodeListSignature(List<FileNodeSummary> nodes) {
  final cachedSignature = _fileNodeSignatureCache[nodes];
  if (cachedSignature != null) {
    return cachedSignature;
  }
  var signature = nodes.length;
  for (final node in nodes) {
    signature = Object.hash(
      signature,
      node.path,
      node.name,
      node.type,
      node.ignored,
    );
  }
  _fileNodeSignatureCache[nodes] = signature;
  return signature;
}

int _expandedDirectoriesSignature(Set<String> expandedDirectories) {
  if (expandedDirectories.isEmpty) {
    return 0;
  }
  return Object.hashAllUnordered(expandedDirectories);
}

List<_VisibleFileTreeEntry> _cachedVisibleFileNodes({
  required FileBrowserBundle bundle,
  required Set<String> expandedDirectories,
  required String? loadingDirectoryPath,
}) {
  final cacheKey = _VisibleFileTreeCacheKey(
    nodeSignature: _fileNodeListSignature(bundle.nodes),
    expandedSignature: _expandedDirectoriesSignature(expandedDirectories),
    loadingDirectoryPath: loadingDirectoryPath,
  );
  final cached = _visibleFileTreeCache.get(cacheKey);
  if (cached != null) {
    return cached;
  }
  final visibleNodes = List<_VisibleFileTreeEntry>.unmodifiable(
    _buildVisibleFileNodes(
      bundle: bundle,
      expandedDirectories: expandedDirectories,
      loadingDirectoryPath: loadingDirectoryPath,
    ),
  );
  _visibleFileTreeCache.set(cacheKey, visibleNodes);
  return visibleNodes;
}

class _HighlightedFilePreview extends StatefulWidget {
  const _HighlightedFilePreview({required this.path, required this.content});

  final String? path;
  final String content;

  @override
  State<_HighlightedFilePreview> createState() =>
      _HighlightedFilePreviewState();
}

class _WorkspaceSafeFilePreview extends StatefulWidget {
  const _WorkspaceSafeFilePreview({
    required this.path,
    required this.content,
    required this.previewWidth,
  });

  final String? path;
  final String content;
  final double previewWidth;

  @override
  State<_WorkspaceSafeFilePreview> createState() =>
      _WorkspaceSafeFilePreviewState();
}

class _WorkspaceSafeFilePreviewState extends State<_WorkspaceSafeFilePreview> {
  bool _expanded = false;
  _WorkspaceFilePreviewMode _previewMode = _WorkspaceFilePreviewMode.source;

  @override
  void didUpdateWidget(covariant _WorkspaceSafeFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.content != widget.content) {
      _expanded = false;
      _previewMode = _WorkspaceFilePreviewMode.source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final isMarkdown = _isMarkdownPreviewPath(widget.path);
    final canExpand =
        widget.content.length > _workspaceFilePreviewCollapsedCharacterLimit;
    final visibleContent = !_expanded && canExpand
        ? '${widget.content.substring(0, _workspaceFilePreviewCollapsedCharacterLimit)}\n\n${context.wp('[Preview collapsed to keep rendering responsive. Use Show more to inspect the rest of the safe preview.]')}'
        : widget.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (canExpand || isMarkdown)
          Padding(
            padding: EdgeInsets.only(
              bottom: density.inset(AppSpacing.xs, min: 4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (canExpand)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.visibility_rounded,
                        size: 16,
                        color: surfaces.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _expanded
                              ? context.wp(
                                  'Showing the full safe preview payload.',
                                )
                              : context.wp(
                                  'Showing the first {count} characters to keep the preview responsive.',
                                  args: <String, Object?>{
                                    'count':
                                        _workspaceFilePreviewCollapsedCharacterLimit,
                                  },
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: surfaces.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _expanded = !_expanded;
                          });
                        },
                        child: Text(
                          context.wp(_expanded ? 'Show less' : 'Show more'),
                        ),
                      ),
                    ],
                  ),
                if (canExpand && isMarkdown)
                  SizedBox(height: density.inset(AppSpacing.xxs, min: 4)),
                if (isMarkdown)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<_WorkspaceFilePreviewMode>(
                      key: const ValueKey<String>(
                        'files-preview-markdown-mode-toggle',
                      ),
                      segments: <ButtonSegment<_WorkspaceFilePreviewMode>>[
                        ButtonSegment<_WorkspaceFilePreviewMode>(
                          value: _WorkspaceFilePreviewMode.source,
                          label: Text(context.wp('Source')),
                        ),
                        ButtonSegment<_WorkspaceFilePreviewMode>(
                          value: _WorkspaceFilePreviewMode.rendered,
                          label: Text(context.wp('Preview')),
                        ),
                      ],
                      selected: <_WorkspaceFilePreviewMode>{_previewMode},
                      onSelectionChanged:
                          (Set<_WorkspaceFilePreviewMode> selection) {
                            final nextMode = selection.firstOrNull;
                            if (nextMode == null) {
                              return;
                            }
                            setState(() {
                              _previewMode = nextMode;
                            });
                          },
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: widget.previewWidth),
              child:
                  isMarkdown &&
                      _previewMode == _WorkspaceFilePreviewMode.rendered
                  ? _RenderedMarkdownFilePreview(content: visibleContent)
                  : _HighlightedFilePreview(
                      path: widget.path,
                      content: visibleContent,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _WorkspaceFilePreviewMode { source, rendered }

class _WorkspacePreviewScaffold extends StatelessWidget {
  const _WorkspacePreviewScaffold({
    required this.pageKey,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final Key pageKey;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Scaffold(
      key: pageKey,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            density.inset(AppSpacing.md, min: AppSpacing.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (subtitle != null) ...<Widget>[
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
                SizedBox(height: density.inset(AppSpacing.md)),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceFilePreviewPage extends StatelessWidget {
  const _WorkspaceFilePreviewPage({required this.path, required this.content});

  final String? path;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return _WorkspacePreviewScaffold(
      pageKey: const ValueKey<String>('fullscreen-file-preview-page'),
      title: context.wp('File Preview'),
      subtitle: path,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
        decoration: _workspaceSidePanelDecoration(
          surfaces: surfaces,
          compact: density.compact,
          elevated: true,
          tint: theme.colorScheme.primary,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _WorkspaceSafeFilePreview(
              path: path,
              content: content,
              previewWidth: constraints.maxWidth,
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceReviewPreviewPage extends StatefulWidget {
  const _WorkspaceReviewPreviewPage({
    required this.diff,
    required this.parsedDiff,
    required this.splitEnabled,
    required this.compactMode,
    required this.lineCount,
    required this.initialMode,
    required this.diffModeHint,
    required this.onLineComment,
  });

  final FileDiffSummary diff;
  final _ParsedReviewDiff parsedDiff;
  final bool splitEnabled;
  final bool compactMode;
  final int lineCount;
  final _ReviewDiffMode initialMode;
  final String? diffModeHint;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  State<_WorkspaceReviewPreviewPage> createState() =>
      _WorkspaceReviewPreviewPageState();
}

class _WorkspaceReviewPreviewPageState
    extends State<_WorkspaceReviewPreviewPage> {
  late _ReviewDiffMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final effectiveMode = widget.splitEnabled ? _mode : _ReviewDiffMode.unified;
    return _WorkspacePreviewScaffold(
      pageKey: const ValueKey<String>('fullscreen-review-preview-page'),
      title: context.wp('Diff Preview'),
      subtitle: widget.diff.path,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
        decoration: _workspaceSidePanelDecoration(
          surfaces: surfaces,
          compact: density.compact,
          elevated: true,
          tint: theme.colorScheme.primary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: SegmentedButton<_ReviewDiffMode>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<_ReviewDiffMode>>[
                    ButtonSegment<_ReviewDiffMode>(
                      value: _ReviewDiffMode.unified,
                      label: Text(context.wp('Unified')),
                      icon: Icon(Icons.view_stream_rounded),
                    ),
                    ButtonSegment<_ReviewDiffMode>(
                      value: _ReviewDiffMode.split,
                      label: Text(context.wp('Split')),
                      icon: Icon(Icons.view_week_rounded),
                      enabled: widget.splitEnabled,
                    ),
                  ],
                  selected: <_ReviewDiffMode>{effectiveMode},
                  onSelectionChanged: (selection) {
                    final next = selection.isEmpty
                        ? effectiveMode
                        : selection.first;
                    if (!widget.splitEnabled && next == _ReviewDiffMode.split) {
                      return;
                    }
                    if (next == _mode) {
                      return;
                    }
                    setState(() {
                      _mode = next;
                    });
                  },
                ),
              ),
            ),
            if (widget.diffModeHint != null) ...<Widget>[
              SizedBox(height: density.inset(AppSpacing.sm)),
              Text(
                widget.diffModeHint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                ),
              ),
            ],
            SizedBox(height: density.inset(AppSpacing.sm)),
            Expanded(
              child: _ReviewDiffView(
                diff: widget.diff,
                parsedDiff: widget.parsedDiff,
                mode: effectiveMode,
                lineCount: widget.lineCount,
                compactMode: widget.compactMode,
                onLineComment: widget.onLineComment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenderedMarkdownFilePreview extends StatelessWidget {
  const _RenderedMarkdownFilePreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final baseStyle =
        theme.textTheme.bodySmall?.copyWith(
          height: 1.55,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.94),
        ) ??
        TextStyle(
          fontSize: 12,
          height: 1.55,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.94),
        );
    final baseSheet = MarkdownStyleSheet.fromTheme(theme);
    final styleSheet = baseSheet.copyWith(
      p: baseStyle,
      h1: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      h2: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      h3: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      code: baseStyle.copyWith(
        fontFamily: 'monospace',
        color: surfaces.warning,
      ),
      codeblockDecoration: BoxDecoration(
        color: surfaces.panelRaised,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.lineSoft),
      ),
      blockquote: baseStyle.copyWith(color: surfaces.muted),
      blockquoteDecoration: BoxDecoration(
        color: surfaces.panelMuted,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.lineSoft),
      ),
      a: baseStyle.copyWith(
        color: theme.colorScheme.primary.withValues(alpha: 0.96),
        decoration: TextDecoration.underline,
      ),
      listBullet: baseStyle,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: surfaces.lineSoft)),
      ),
    );

    return MarkdownBody(
      key: const ValueKey<String>('files-preview-markdown-content'),
      data: content,
      selectable: true,
      styleSheet: styleSheet,
      shrinkWrap: true,
    );
  }
}

bool _isMarkdownPreviewPath(String? path) {
  return _previewSyntaxLanguageForPath(path) ==
      _FilePreviewSyntaxLanguage.markdown;
}

class _HighlightedFilePreviewState extends State<_HighlightedFilePreview> {
  String? _cachedPath;
  String? _cachedContent;
  int? _cachedThemeSignature;
  List<InlineSpan>? _cachedSpans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.45,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.94),
    );
    final syntaxTheme = _FilePreviewSyntaxTheme.from(
      theme: theme,
      surfaces: surfaces,
      baseStyle: baseStyle,
    );
    final themeSignature = _syntaxThemeSignature(theme, surfaces);
    if (_cachedSpans == null ||
        _cachedPath != widget.path ||
        _cachedContent != widget.content ||
        _cachedThemeSignature != themeSignature) {
      _cachedSpans = _buildHighlightedFilePreviewSpans(
        context: context,
        content: widget.content,
        path: widget.path,
        syntaxTheme: syntaxTheme,
      );
      _cachedPath = widget.path;
      _cachedContent = widget.content;
      _cachedThemeSignature = themeSignature;
    }

    return SelectableText.rich(
      key: const ValueKey<String>('files-preview-content'),
      TextSpan(style: syntaxTheme.base, children: _cachedSpans),
    );
  }
}

enum _FilePreviewSyntaxLanguage {
  plainText,
  markdown,
  yaml,
  json,
  dart,
  javascript,
  shell,
  python,
  rust,
  go,
}

class _FilePreviewSyntaxTheme {
  const _FilePreviewSyntaxTheme({
    required this.base,
    required this.comment,
    required this.keyword,
    required this.string,
    required this.number,
    required this.type,
    required this.annotation,
    required this.heading,
    required this.link,
    required this.inlineCode,
    required this.command,
  });

  final TextStyle? base;
  final TextStyle? comment;
  final TextStyle? keyword;
  final TextStyle? string;
  final TextStyle? number;
  final TextStyle? type;
  final TextStyle? annotation;
  final TextStyle? heading;
  final TextStyle? link;
  final TextStyle? inlineCode;
  final TextStyle? command;

  factory _FilePreviewSyntaxTheme.from({
    required ThemeData theme,
    required AppSurfaces surfaces,
    required TextStyle? baseStyle,
  }) {
    final base =
        baseStyle ??
        theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.45,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.94),
        ) ??
        TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.45,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.94),
        );
    return _FilePreviewSyntaxTheme(
      base: base,
      comment: base.copyWith(color: surfaces.muted),
      keyword: base.copyWith(
        color: theme.colorScheme.primary.withValues(alpha: 0.96),
        fontWeight: FontWeight.w700,
      ),
      string: base.copyWith(color: surfaces.accentSoft),
      number: base.copyWith(
        color: surfaces.warning,
        fontWeight: FontWeight.w600,
      ),
      type: base.copyWith(color: surfaces.success, fontWeight: FontWeight.w600),
      annotation: base.copyWith(
        color: surfaces.accentSoft,
        fontWeight: FontWeight.w700,
      ),
      heading: base.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      link: base.copyWith(
        color: theme.colorScheme.primary.withValues(alpha: 0.96),
        decoration: TextDecoration.underline,
      ),
      inlineCode: base.copyWith(
        color: surfaces.warning,
        backgroundColor: surfaces.panelRaised,
      ),
      command: base.copyWith(
        color: theme.colorScheme.primary.withValues(alpha: 0.9),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilePreviewHighlightPattern {
  const _FilePreviewHighlightPattern({
    required this.regex,
    required this.style,
  });

  final RegExp regex;
  final TextStyle? style;
}

int _syntaxThemeSignature(ThemeData theme, AppSurfaces surfaces) {
  return Object.hashAll(<Object?>[
    theme.colorScheme.primary,
    theme.colorScheme.onSurface,
    surfaces.panel,
    surfaces.panelRaised,
    surfaces.muted,
    surfaces.warning,
    surfaces.success,
    surfaces.accentSoft,
  ]);
}

List<InlineSpan> _buildHighlightedFilePreviewSpans({
  required BuildContext context,
  required String content,
  required String? path,
  required _FilePreviewSyntaxTheme syntaxTheme,
}) {
  if (content.isEmpty) {
    return const <InlineSpan>[TextSpan(text: '')];
  }

  const highlightLimit = 60000;
  if (content.length > highlightLimit) {
    return <InlineSpan>[
      TextSpan(text: content.substring(0, highlightLimit)),
      TextSpan(
        text:
            '\n\n${context.wp('[Syntax highlighting paused for the rest of this preview because the file is very large.]')}',
      ),
    ];
  }

  final language = _previewSyntaxLanguageForPath(path);
  final patterns = _filePreviewHighlightPatterns(language, syntaxTheme);
  if (patterns.isEmpty) {
    return <InlineSpan>[TextSpan(text: content)];
  }
  return _highlightPreviewText(content, patterns);
}

_FilePreviewSyntaxLanguage _previewSyntaxLanguageForPath(String? path) {
  final normalized = (path ?? '').trim().toLowerCase();
  final name = normalized.split('/').last;

  if (name.endsWith('.md') || name.endsWith('.markdown')) {
    return _FilePreviewSyntaxLanguage.markdown;
  }
  if (name.endsWith('.yaml') || name.endsWith('.yml')) {
    return _FilePreviewSyntaxLanguage.yaml;
  }
  if (name.endsWith('.json') || name.endsWith('.jsonc')) {
    return _FilePreviewSyntaxLanguage.json;
  }
  if (name.endsWith('.dart')) {
    return _FilePreviewSyntaxLanguage.dart;
  }
  if (name.endsWith('.ts') ||
      name.endsWith('.tsx') ||
      name.endsWith('.js') ||
      name.endsWith('.jsx') ||
      name.endsWith('.mjs') ||
      name.endsWith('.cjs')) {
    return _FilePreviewSyntaxLanguage.javascript;
  }
  if (name == '.env' ||
      name.startsWith('.env.') ||
      name.endsWith('.sh') ||
      name.endsWith('.bash') ||
      name.endsWith('.zsh') ||
      name == 'dockerfile') {
    return _FilePreviewSyntaxLanguage.shell;
  }
  if (name.endsWith('.py')) {
    return _FilePreviewSyntaxLanguage.python;
  }
  if (name.endsWith('.rs')) {
    return _FilePreviewSyntaxLanguage.rust;
  }
  if (name.endsWith('.go')) {
    return _FilePreviewSyntaxLanguage.go;
  }
  return _FilePreviewSyntaxLanguage.plainText;
}

_FilePreviewSyntaxLanguage _previewSyntaxLanguageForFence(String? language) {
  final normalized = (language ?? '').trim().toLowerCase();
  return switch (normalized) {
    'md' || 'markdown' => _FilePreviewSyntaxLanguage.markdown,
    'yaml' || 'yml' => _FilePreviewSyntaxLanguage.yaml,
    'json' || 'jsonc' => _FilePreviewSyntaxLanguage.json,
    'dart' => _FilePreviewSyntaxLanguage.dart,
    'ts' ||
    'tsx' ||
    'js' ||
    'jsx' ||
    'mjs' ||
    'cjs' ||
    'javascript' ||
    'typescript' => _FilePreviewSyntaxLanguage.javascript,
    'sh' ||
    'bash' ||
    'zsh' ||
    'shell' ||
    'shellscript' ||
    'console' ||
    'dotenv' ||
    'env' => _FilePreviewSyntaxLanguage.shell,
    'py' || 'python' => _FilePreviewSyntaxLanguage.python,
    'rs' || 'rust' => _FilePreviewSyntaxLanguage.rust,
    'go' => _FilePreviewSyntaxLanguage.go,
    _ => _FilePreviewSyntaxLanguage.plainText,
  };
}

List<_FilePreviewHighlightPattern> _filePreviewHighlightPatterns(
  _FilePreviewSyntaxLanguage language,
  _FilePreviewSyntaxTheme theme,
) {
  switch (language) {
    case _FilePreviewSyntaxLanguage.markdown:
      return <_FilePreviewHighlightPattern>[
        _FilePreviewHighlightPattern(
          regex: RegExp(r'^#{1,6}\s.*$', multiLine: true),
          style: theme.heading,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'^```.*$', multiLine: true),
          style: theme.keyword,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'^>\s.*$', multiLine: true),
          style: theme.comment,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\[[^\]]+\]\([^)]+\)'),
          style: theme.link,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'`[^`\n]+`'),
          style: theme.inlineCode,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'(?:(?:\*\*|__)(?:\\.|[^*_])+?(?:\*\*|__))'),
          style: theme.type,
        ),
      ];
    case _FilePreviewSyntaxLanguage.yaml:
      return <_FilePreviewHighlightPattern>[
        _FilePreviewHighlightPattern(
          regex: RegExp(r'#.*$', multiLine: true),
          style: theme.comment,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(
            r'''^[ \t-]*[A-Za-z0-9_."'-]+(?=\s*:)''',
            multiLine: true,
          ),
          style: theme.keyword,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"""),
          style: theme.string,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\b(?:true|false|null|yes|no|on|off)\b'),
          style: theme.type,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'[*&][A-Za-z0-9_-]+'),
          style: theme.annotation,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\b-?(?:0x[a-fA-F0-9]+|\d+(?:\.\d+)?)\b'),
          style: theme.number,
        ),
      ];
    case _FilePreviewSyntaxLanguage.json:
      return <_FilePreviewHighlightPattern>[
        _FilePreviewHighlightPattern(
          regex: RegExp(r'"(?:\\.|[^"\\])*"(?=\s*:)'),
          style: theme.keyword,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'"(?:\\.|[^"\\])*"'),
          style: theme.string,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\b(?:true|false|null)\b'),
          style: theme.type,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\b-?(?:0x[a-fA-F0-9]+|\d+(?:\.\d+)?)\b'),
          style: theme.number,
        ),
      ];
    case _FilePreviewSyntaxLanguage.shell:
      return <_FilePreviewHighlightPattern>[
        _FilePreviewHighlightPattern(
          regex: RegExp(r'#.*$', multiLine: true),
          style: theme.comment,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`[^`]*`"""),
          style: theme.string,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\$(?:[A-Za-z_][A-Za-z0-9_]*|\{[^}]+\})'),
          style: theme.annotation,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'^[ \t]*[A-Za-z_][A-Za-z0-9_]*(?==)', multiLine: true),
          style: theme.keyword,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(
            r'\b(?:if|then|fi|for|while|do|done|case|esac|function|in|export|local)\b',
          ),
          style: theme.keyword,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'--?[A-Za-z0-9][A-Za-z0-9-]*'),
          style: theme.type,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(
            r'^[ \t]*(?:sudo\s+)?[A-Za-z0-9_./-]+',
            multiLine: true,
          ),
          style: theme.command,
        ),
      ];
    case _FilePreviewSyntaxLanguage.dart:
      return _cStyleLanguagePatterns(
        theme: theme,
        keywords:
            'abstract as assert async await base break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for get hide if implements import in interface is late library mixin new null on operator part required rethrow return sealed set show static super switch sync this throw true try typedef var void while with yield',
        types:
            'bool BuildContext Color DateTime double Duration Future int Iterable List Map MaterialApp Object Offset Pattern RegExp Set Size State StatelessWidget Stream String Text ThemeData Uri Widget',
        includeAnnotations: true,
      );
    case _FilePreviewSyntaxLanguage.javascript:
      return _cStyleLanguagePatterns(
        theme: theme,
        keywords:
            'async await break case catch class const continue debugger default delete do else export extends false finally for from function if import in instanceof let new null of return static super switch this throw true try typeof var void while with yield interface implements type enum public private protected readonly',
        types:
            'Array Boolean Error Map Number Object Promise Record RegExp Set String Symbol',
      );
    case _FilePreviewSyntaxLanguage.python:
      return <_FilePreviewHighlightPattern>[
        _FilePreviewHighlightPattern(
          regex: RegExp(r'#.*$', multiLine: true),
          style: theme.comment,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(
            r""""{3}[\s\S]*?"{3}|'{3}[\s\S]*?'{3}|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'""",
          ),
          style: theme.string,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(
            r'\b(?:and|as|assert|async|await|break|class|continue|def|del|elif|else|except|False|finally|for|from|global|if|import|in|is|lambda|None|nonlocal|not|or|pass|raise|return|True|try|while|with|yield)\b',
          ),
          style: theme.keyword,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(
            r'\b(?:dict|float|int|list|set|str|tuple|bool|bytes|object)\b',
          ),
          style: theme.type,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'@[A-Za-z_][A-Za-z0-9_]*'),
          style: theme.annotation,
        ),
        _FilePreviewHighlightPattern(
          regex: RegExp(r'\b-?(?:0x[a-fA-F0-9]+|\d+(?:\.\d+)?)\b'),
          style: theme.number,
        ),
      ];
    case _FilePreviewSyntaxLanguage.rust:
      return _cStyleLanguagePatterns(
        theme: theme,
        keywords:
            'as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while',
        types:
            'Option Result String Vec bool char f32 f64 i128 i16 i32 i64 i8 isize str u128 u16 u32 u64 u8 usize',
      );
    case _FilePreviewSyntaxLanguage.go:
      return _cStyleLanguagePatterns(
        theme: theme,
        keywords:
            'break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var',
        types:
            'bool byte complex128 complex64 error float32 float64 int int16 int32 int64 int8 rune string uint uint16 uint32 uint64 uint8 uintptr',
      );
    case _FilePreviewSyntaxLanguage.plainText:
      return const <_FilePreviewHighlightPattern>[];
  }
}

List<InlineSpan> _buildHighlightedCodeBlockSpans({
  required BuildContext context,
  required String code,
  required String? language,
  required _FilePreviewSyntaxTheme syntaxTheme,
}) {
  if (code.isEmpty) {
    return const <InlineSpan>[TextSpan(text: '')];
  }

  const highlightLimit = 60000;
  if (code.length > highlightLimit) {
    return <InlineSpan>[
      TextSpan(text: code.substring(0, highlightLimit)),
      TextSpan(
        text:
            '\n\n${context.wp('[Syntax highlighting paused for the rest of this code block because it is very large.]')}',
      ),
    ];
  }

  final syntaxLanguage = _previewSyntaxLanguageForFence(language);
  final patterns = _filePreviewHighlightPatterns(syntaxLanguage, syntaxTheme);
  if (patterns.isEmpty) {
    return <InlineSpan>[TextSpan(text: code)];
  }
  return _highlightPreviewText(code, patterns);
}

List<_FilePreviewHighlightPattern> _cStyleLanguagePatterns({
  required _FilePreviewSyntaxTheme theme,
  required String keywords,
  required String types,
  bool includeAnnotations = false,
}) {
  return <_FilePreviewHighlightPattern>[
    _FilePreviewHighlightPattern(
      regex: RegExp(r'//.*$|/\*[\s\S]*?\*/', multiLine: true),
      style: theme.comment,
    ),
    _FilePreviewHighlightPattern(
      regex: RegExp(
        r""""{3}[\s\S]*?"{3}|'{3}[\s\S]*?'{3}|`(?:\\.|[^`\\])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'""",
      ),
      style: theme.string,
    ),
    if (includeAnnotations)
      _FilePreviewHighlightPattern(
        regex: RegExp(r'@[A-Za-z_][A-Za-z0-9_]*'),
        style: theme.annotation,
      ),
    _FilePreviewHighlightPattern(
      regex: RegExp('\\b(?:${keywords.replaceAll(' ', '|')})\\b'),
      style: theme.keyword,
    ),
    _FilePreviewHighlightPattern(
      regex: RegExp('\\b(?:${types.replaceAll(' ', '|')})\\b'),
      style: theme.type,
    ),
    _FilePreviewHighlightPattern(
      regex: RegExp(r'\b-?(?:0x[a-fA-F0-9]+|\d+(?:\.\d+)?)\b'),
      style: theme.number,
    ),
  ];
}

List<InlineSpan> _highlightPreviewText(
  String text,
  List<_FilePreviewHighlightPattern> patterns,
) {
  final spans = <InlineSpan>[];
  var cursor = 0;

  while (cursor < text.length) {
    Match? nextMatch;
    TextStyle? nextStyle;

    for (final pattern in patterns) {
      Match? candidate;
      for (final match in pattern.regex.allMatches(text, cursor)) {
        candidate = match;
        break;
      }
      if (candidate == null) {
        continue;
      }
      if (nextMatch == null || candidate.start < nextMatch.start) {
        nextMatch = candidate;
        nextStyle = pattern.style;
      }
    }

    if (nextMatch == null) {
      spans.add(TextSpan(text: text.substring(cursor)));
      break;
    }

    if (nextMatch.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, nextMatch.start)));
    }

    spans.add(
      TextSpan(
        text: text.substring(nextMatch.start, nextMatch.end),
        style: nextStyle,
      ),
    );
    cursor = nextMatch.end;
  }

  return spans;
}

List<_VisibleFileTreeEntry> _buildVisibleFileNodes({
  required FileBrowserBundle bundle,
  required Set<String> expandedDirectories,
  required String? loadingDirectoryPath,
}) {
  final nodesByPath = <String, FileNodeSummary>{};
  for (final node in bundle.nodes) {
    nodesByPath[node.path] = node;
    var parent = _fileNodeParentPath(node.path);
    while (parent != null && parent.isNotEmpty) {
      final directoryPath = parent;
      nodesByPath.putIfAbsent(
        directoryPath,
        () => FileNodeSummary(
          name: _fileNodeLabel(directoryPath),
          path: directoryPath,
          type: 'directory',
          ignored: false,
        ),
      );
      parent = _fileNodeParentPath(parent);
    }
  }

  final childrenByParent = <String?, List<FileNodeSummary>>{};
  for (final node in nodesByPath.values) {
    childrenByParent
        .putIfAbsent(_fileNodeParentPath(node.path), () => <FileNodeSummary>[])
        .add(node);
  }

  for (final children in childrenByParent.values) {
    children.sort((left, right) {
      final leftDirectory = left.type == 'directory';
      final rightDirectory = right.type == 'directory';
      if (leftDirectory != rightDirectory) {
        return leftDirectory ? -1 : 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
  }

  final visible = <_VisibleFileTreeEntry>[];

  void visit(String? parentPath, int depth) {
    final children = childrenByParent[parentPath];
    if (children == null) {
      return;
    }
    for (final node in children) {
      final expanded =
          node.type == 'directory' && expandedDirectories.contains(node.path);
      visible.add(
        _VisibleFileTreeEntry(
          node: node,
          depth: depth,
          expanded: expanded,
          loading: loadingDirectoryPath == node.path,
        ),
      );
      if (expanded) {
        visit(node.path, depth + 1);
      }
    }
  }

  visit(null, 0);
  return visible;
}

String? _fileNodeParentPath(String path) {
  final normalized = path.replaceAll('\\', '/').trim();
  final index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return null;
  }
  return normalized.substring(0, index);
}

String _fileNodeLabel(String path) {
  final normalized = path.replaceAll('\\', '/').trim();
  final index = normalized.lastIndexOf('/');
  if (index < 0) {
    return normalized;
  }
  return normalized.substring(index + 1);
}

class _ContextPanel extends StatefulWidget {
  const _ContextPanel({
    required this.session,
    required this.messages,
    required this.metrics,
    required this.systemPrompt,
    required this.breakdown,
    required this.userMessageCount,
    required this.assistantMessageCount,
  });

  final SessionSummary? session;
  final List<ChatMessage> messages;
  final SessionContextMetrics metrics;
  final String? systemPrompt;
  final List<SessionContextBreakdownSegment> breakdown;
  final int userMessageCount;
  final int assistantMessageCount;

  @override
  State<_ContextPanel> createState() => _ContextPanelState();
}

class _ContextPanelState extends State<_ContextPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final decimal = NumberFormat.decimalPattern(locale);
    final currency = NumberFormat.simpleCurrency(locale: locale, name: 'USD');
    final metrics = widget.metrics;
    final snapshot = metrics.context;
    final systemPrompt = widget.systemPrompt;
    final breakdown = widget.breakdown;
    final usageValue = snapshot?.usagePercent;
    final usageRatio = usageValue == null
        ? 0.0
        : (usageValue / 100).clamp(0.0, 1.0);
    final stats = <_ContextStatEntry>[
      _ContextStatEntry(
        label: context.wp('Session'),
        value: widget.session?.title.trim().isNotEmpty == true
            ? widget.session!.title.trim()
            : (widget.session?.id ?? '—'),
      ),
      _ContextStatEntry(
        label: context.wp('Messages'),
        value: decimal.format(widget.messages.length),
      ),
      _ContextStatEntry(
        label: context.wp('Provider'),
        value: snapshot?.providerLabel ?? '—',
      ),
      _ContextStatEntry(
        label: context.wp('Model'),
        value: snapshot?.modelLabel ?? '—',
      ),
      _ContextStatEntry(
        label: context.wp('Context Limit'),
        value: _formatContextNumber(snapshot?.contextLimit, decimal),
      ),
      _ContextStatEntry(
        label: context.wp('Total Tokens'),
        value: _formatContextNumber(snapshot?.totalTokens, decimal),
      ),
      _ContextStatEntry(
        label: context.wp('Usage'),
        value: _formatContextPercent(snapshot?.usagePercent, decimal),
      ),
      _ContextStatEntry(
        label: context.wp('Input Tokens'),
        value: _formatContextNumber(snapshot?.inputTokens, decimal),
      ),
      _ContextStatEntry(
        label: context.wp('Output Tokens'),
        value: _formatContextNumber(snapshot?.outputTokens, decimal),
      ),
      _ContextStatEntry(
        label: context.wp('Reasoning Tokens'),
        value: _formatContextNumber(snapshot?.reasoningTokens, decimal),
      ),
      _ContextStatEntry(
        label: context.wp('Cache Tokens (read/write)'),
        value:
            '${_formatContextNumber(snapshot?.cacheReadTokens, decimal)} / '
            '${_formatContextNumber(snapshot?.cacheWriteTokens, decimal)}',
      ),
      _ContextStatEntry(
        label: context.wp('User Messages'),
        value: decimal.format(widget.userMessageCount),
      ),
      _ContextStatEntry(
        label: context.wp('Assistant Messages'),
        value: decimal.format(widget.assistantMessageCount),
      ),
      _ContextStatEntry(
        label: context.wp('Total Cost'),
        value: currency.format(metrics.totalCost),
      ),
      _ContextStatEntry(
        label: context.wp('Session Created'),
        value: _formatContextTime(widget.session?.createdAt, locale),
      ),
      _ContextStatEntry(
        label: context.wp('Last Activity'),
        value: _formatContextTime(snapshot?.message.info.createdAt, locale),
      ),
    ];

    return SelectionArea(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          controller: _scrollController,
          primary: false,
          key: const PageStorageKey<String>('web-parity-context-panel'),
          padding: EdgeInsets.fromLTRB(
            density.inset(AppSpacing.md, min: AppSpacing.sm),
            density.inset(AppSpacing.sm),
            density.inset(AppSpacing.md, min: AppSpacing.sm),
            density.inset(AppSpacing.md, min: AppSpacing.sm),
          ),
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(
                density.inset(AppSpacing.sm, min: AppSpacing.xxs),
              ),
              decoration: _workspaceSidePanelDecoration(
                surfaces: surfaces,
                compact: density.compact,
                elevated: true,
                tint: surfaces.success,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.wp('Context overview'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.wp(
                                'Token usage, message volume, and provider details for the current session.',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: surfaces.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: density.inset(AppSpacing.xxs, min: 4)),
                      _WorkspaceSideBadge(
                        label: _formatContextPercent(usageValue, decimal),
                        tint: surfaces.success,
                        emphasized: true,
                      ),
                    ],
                  ),
                  SizedBox(height: density.inset(AppSpacing.sm)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                    child: LinearProgressIndicator(
                      minHeight: density.compact ? 10 : 12,
                      value: usageValue == null ? null : usageRatio,
                      backgroundColor: surfaces.panelMuted.withValues(
                        alpha: 0.9,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        usageValue != null && usageValue >= 85
                            ? surfaces.warning
                            : surfaces.success,
                      ),
                    ),
                  ),
                  SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
                  Wrap(
                    spacing: density.inset(AppSpacing.xs, min: 6),
                    runSpacing: density.inset(AppSpacing.xs, min: 6),
                    children: <Widget>[
                      _WorkspaceSideBadge(
                        label:
                            '${context.wp('Messages')} ${decimal.format(widget.messages.length)}',
                        tint: theme.colorScheme.primary,
                      ),
                      _WorkspaceSideBadge(
                        label:
                            '${context.wp('Model')} ${snapshot?.modelLabel ?? '—'}',
                        tint: surfaces.accentSoft,
                      ),
                      _WorkspaceSideBadge(
                        label:
                            '${context.wp('Cost')} ${currency.format(metrics.totalCost)}',
                        tint: surfaces.warning,
                      ),
                    ],
                  ),
                  SizedBox(height: density.inset(AppSpacing.sm)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: density.inset(AppSpacing.xs, min: 8),
                      vertical: density.inset(AppSpacing.xs, min: 8),
                    ),
                    decoration:
                        _workspaceSidePanelDecoration(
                          surfaces: surfaces,
                          compact: density.compact,
                          tint: theme.colorScheme.primary,
                        ).copyWith(
                          color: surfaces.panelMuted.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            context.wp('Context Limit'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: surfaces.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _formatContextNumber(snapshot?.contextLimit, decimal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: density.inset(AppSpacing.md, min: AppSpacing.sm)),
            if (breakdown.isNotEmpty) ...<Widget>[
              _WorkspaceSideSectionHeader(
                title: context.wp('Context Breakdown'),
                caption: context.wp(
                  'Visual split between system, user, assistant, and tool content.',
                ),
              ),
              SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
              _ContextBreakdownBar(segments: breakdown),
              SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
              Wrap(
                spacing: density.inset(AppSpacing.sm),
                runSpacing: density.inset(AppSpacing.xxs, min: 4),
                children: breakdown
                    .map(
                      (segment) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _breakdownColor(segment.key, surfaces),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${_breakdownLabel(context, segment.key)} '
                            '${segment.labelPercent.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: surfaces.muted,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
              SizedBox(
                height: density.inset(AppSpacing.md, min: AppSpacing.sm),
              ),
            ],
            _WorkspaceSideSectionHeader(
              title: context.wp('Session metrics'),
              caption: context.wp(
                'Compact cards surface the operational numbers without forcing a dense table layout.',
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = density.inset(AppSpacing.md, min: AppSpacing.sm);
                final columns = constraints.maxWidth >= 300 ? 2 : 1;
                final itemWidth = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: density.inset(AppSpacing.md, min: AppSpacing.sm),
                  children: stats
                      .map(
                        (entry) => SizedBox(
                          width: itemWidth,
                          child: _ContextStat(entry: entry),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            if (systemPrompt != null) ...<Widget>[
              SizedBox(
                height: density.inset(AppSpacing.md, min: AppSpacing.sm),
              ),
              _WorkspaceSideSectionHeader(
                title: context.wp('System Prompt'),
                caption: context.wp(
                  'Reference prompt currently shaping model behavior for this session.',
                ),
              ),
              SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
                decoration: _workspaceSidePanelDecoration(
                  surfaces: surfaces,
                  compact: density.compact,
                  tint: surfaces.success,
                ).copyWith(borderRadius: BorderRadius.circular(AppSpacing.md)),
                child: Text(
                  systemPrompt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.55,
                  ),
                ),
              ),
            ],
            SizedBox(height: density.inset(AppSpacing.md, min: AppSpacing.sm)),
            _WorkspaceSideSectionHeader(
              title: context.wp('Raw messages'),
              caption: context.wp(
                'Expandable transport-level payloads for debugging and auditing.',
              ),
            ),
            SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
            if (widget.messages.isEmpty)
              Container(
                padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
                decoration: _workspaceSidePanelDecoration(
                  surfaces: surfaces,
                  compact: density.compact,
                ).copyWith(borderRadius: BorderRadius.circular(AppSpacing.md)),
                child: Text(
                  context.wp('No raw messages yet.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
              )
            else
              ...widget.messages.map(
                (message) => Padding(
                  key: ValueKey<String>(
                    'context-raw-message-item-${message.info.id}',
                  ),
                  padding: EdgeInsets.only(
                    bottom: density.inset(AppSpacing.xxs, min: 4),
                  ),
                  child: _ContextRawMessageTile(
                    key: ValueKey<String>(
                      'context-raw-message-widget-${message.info.id}',
                    ),
                    message: message,
                    timestampLabel: _formatContextTime(
                      message.info.createdAt,
                      locale,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContextStatEntry {
  const _ContextStatEntry({required this.label, required this.value});

  final String label;
  final String value;
}

class _ContextStat extends StatelessWidget {
  const _ContextStat({required this.entry});

  final _ContextStatEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.all(
        density.inset(AppSpacing.sm, min: AppSpacing.xxs),
      ),
      decoration: _workspaceSidePanelDecoration(
        surfaces: surfaces,
        compact: density.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.label,
            style: theme.textTheme.labelMedium?.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: 2),
          Text(
            entry.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextBreakdownBar extends StatelessWidget {
  const _ContextBreakdownBar({required this.segments});

  final List<SessionContextBreakdownSegment> segments;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      key: const ValueKey<String>('context-breakdown-bar'),
      height: density.compact ? 12 : 14,
      decoration: _workspaceSidePanelDecoration(
        surfaces: surfaces,
        compact: density.compact,
      ).copyWith(borderRadius: BorderRadius.circular(999)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width <= 0 || segments.isEmpty) {
            return const SizedBox.shrink();
          }

          var offset = 0.0;
          final children = <Widget>[];
          for (var index = 0; index < segments.length; index += 1) {
            final segment = segments[index];
            final segmentWidth = index == segments.length - 1
                ? math.max(0.0, width - offset)
                : math.max(0.0, width * (segment.widthPercent / 100));
            if (segmentWidth <= 0) {
              continue;
            }
            children.add(
              Positioned(
                left: offset,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: ColoredBox(
                  color: _breakdownColor(segment.key, surfaces),
                ),
              ),
            );
            offset += segmentWidth;
          }
          return Stack(children: children);
        },
      ),
    );
  }
}

class _ContextRawMessageTile extends StatefulWidget {
  const _ContextRawMessageTile({
    required this.message,
    required this.timestampLabel,
    super.key,
  });

  final ChatMessage message;
  final String timestampLabel;

  @override
  State<_ContextRawMessageTile> createState() => _ContextRawMessageTileState();
}

class _ContextRawMessageTileState extends State<_ContextRawMessageTile> {
  String? _formattedMessage;
  bool _expanded = false;
  bool _restoredPageState = false;

  String get _pageStorageId =>
      'context-raw-message-expansion-state-${widget.message.info.id}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredPageState) {
      return;
    }
    final restored =
        PageStorage.maybeOf(
              context,
            )?.readState(context, identifier: _pageStorageId)
            as bool?;
    _expanded = restored ?? false;
    if (_expanded) {
      _formattedMessage = _formatContextRawMessageForDisplay(widget.message);
    }
    _restoredPageState = true;
  }

  @override
  void didUpdateWidget(covariant _ContextRawMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.info.id != widget.message.info.id) {
      _restoredPageState = false;
      _expanded = false;
      _formattedMessage = null;
      return;
    }
    if (_formattedMessage != null &&
        (!identical(oldWidget.message.info, widget.message.info) ||
            !identical(oldWidget.message.parts, widget.message.parts))) {
      _formattedMessage = _formatContextRawMessageForDisplay(widget.message);
    }
  }

  void _handleExpansionChanged(bool expanded) {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, expanded, identifier: _pageStorageId);
    setState(() {
      _expanded = expanded;
      _formattedMessage = expanded
          ? (_formattedMessage ??
                _formatContextRawMessageForDisplay(widget.message))
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      key: ValueKey<String>(
        'context-raw-message-tile-${widget.message.info.id}',
      ),
      clipBehavior: Clip.antiAlias,
      decoration:
          _workspaceSidePanelDecoration(
            surfaces: surfaces,
            compact: density.compact,
          ).copyWith(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(
            'context-raw-message-expansion-${widget.message.info.id}',
          ),
          initiallyExpanded: _expanded,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          childrenPadding: EdgeInsets.zero,
          iconColor: surfaces.muted,
          collapsedIconColor: surfaces.muted,
          onExpansionChanged: _handleExpansionChanged,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: widget.message.info.role,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: ' • ${widget.message.info.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  widget.timestampLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: surfaces.muted,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          children: <Widget>[
            Container(
              key: ValueKey<String>(
                'context-raw-message-content-${widget.message.info.id}',
              ),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              clipBehavior: Clip.antiAlias,
              decoration:
                  _workspaceSidePanelDecoration(
                    surfaces: surfaces,
                    compact: density.compact,
                    tint: surfaces.accentSoft,
                  ).copyWith(
                    color: surfaces.background.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                _formattedMessage ??
                    _formatContextRawMessageForDisplay(widget.message),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatContextRawMessageForDisplay(ChatMessage message) {
  return _wrapRawMessageForDisplay(formatRawSessionMessage(message));
}

String _formatContextNumber(int? value, NumberFormat formatter) {
  if (value == null) {
    return '—';
  }
  return formatter.format(value);
}

String _wrapRawMessageForDisplay(String value) {
  if (value.isEmpty) {
    return value;
  }

  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(character);
    if (_rawMessageBreakCharacters.contains(character)) {
      buffer.write('\u200B');
    }
  }
  return buffer.toString();
}

const Set<String> _rawMessageBreakCharacters = <String>{
  '/',
  '\\',
  '_',
  '-',
  '.',
  ':',
  ',',
  ')',
  '(',
  ']',
  '[',
  '}',
  '{',
};

String _formatContextPercent(int? value, NumberFormat formatter) {
  if (value == null) {
    return '—';
  }
  return '${formatter.format(value)}%';
}

String _formatContextTime(DateTime? value, String locale) {
  if (value == null) {
    return '—';
  }
  return DateFormat.yMMMd(locale).add_jm().format(value.toLocal());
}

String _breakdownLabel(BuildContext context, SessionContextBreakdownKey key) {
  return switch (key) {
    SessionContextBreakdownKey.system => context.wp('System'),
    SessionContextBreakdownKey.user => context.wp('User'),
    SessionContextBreakdownKey.assistant => context.wp('Assistant'),
    SessionContextBreakdownKey.tool => context.wp('Tool Calls'),
    SessionContextBreakdownKey.other => context.wp('Other'),
  };
}

Color _breakdownColor(SessionContextBreakdownKey key, AppSurfaces surfaces) {
  return switch (key) {
    SessionContextBreakdownKey.system => surfaces.accentSoft,
    SessionContextBreakdownKey.user => surfaces.success,
    SessionContextBreakdownKey.assistant => const Color(0xFFE4B184),
    SessionContextBreakdownKey.tool => surfaces.warning,
    SessionContextBreakdownKey.other => surfaces.muted,
  };
}
