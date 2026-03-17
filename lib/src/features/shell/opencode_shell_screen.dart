import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../projects/project_models.dart';

class OpenCodeShellScreen extends StatefulWidget {
  const OpenCodeShellScreen({
    required this.profile,
    required this.project,
    required this.onExit,
    super.key,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;

  @override
  State<OpenCodeShellScreen> createState() => _OpenCodeShellScreenState();
}

class _OpenCodeShellScreenState extends State<OpenCodeShellScreen> {
  bool _showContextSheet = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1320) {
      return _DesktopShell(
        profile: widget.profile,
        project: widget.project,
        onExit: widget.onExit,
      );
    }
    if (width >= 960) {
      return _TabletLandscapeShell(
        profile: widget.profile,
        project: widget.project,
        onExit: widget.onExit,
      );
    }
    if (width >= 700) {
      return _TabletPortraitShell(
        profile: widget.profile,
        project: widget.project,
        onExit: widget.onExit,
        showContextSheet: _showContextSheet,
        onToggleContextSheet: () {
          setState(() {
            _showContextSheet = !_showContextSheet;
          });
        },
      );
    }
    return _MobileShell(
      profile: widget.profile,
      project: widget.project,
      onExit: widget.onExit,
      showContextSheet: _showContextSheet,
      onToggleContextSheet: () {
        setState(() {
          _showContextSheet = !_showContextSheet;
        });
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.profile,
    required this.project,
    required this.onExit,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 300,
            child: _LeftRail(
              profile: profile,
              project: project,
              onExit: onExit,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const Expanded(flex: 9, child: _ChatCanvas()),
          const SizedBox(width: AppSpacing.lg),
          const SizedBox(width: 340, child: _ContextRail()),
        ],
      ),
    );
  }
}

class _TabletLandscapeShell extends StatelessWidget {
  const _TabletLandscapeShell({
    required this.profile,
    required this.project,
    required this.onExit,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 280,
            child: _LeftRail(
              profile: profile,
              project: project,
              onExit: onExit,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const Expanded(child: _ChatCanvas()),
          const SizedBox(width: AppSpacing.lg),
          const SizedBox(width: 280, child: _ContextRail(compact: true)),
        ],
      ),
    );
  }
}

class _TabletPortraitShell extends StatelessWidget {
  const _TabletPortraitShell({
    required this.profile,
    required this.project,
    required this.onExit,
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final bool showContextSheet;
  final VoidCallback onToggleContextSheet;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      child: Column(
        children: <Widget>[
          _ShellTopBar(
            project: project,
            onExit: onExit,
            onToggleUtilities: onToggleContextSheet,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Expanded(child: _ChatCanvas()),
          const SizedBox(height: AppSpacing.lg),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: showContextSheet
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const _BottomUtilitySheet(),
            secondChild: const _UtilityToggleHint(),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.profile,
    required this.project,
    required this.onExit,
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final bool showContextSheet;
  final VoidCallback onToggleContextSheet;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      child: Column(
        children: <Widget>[
          _ShellTopBar(
            project: project,
            onExit: onExit,
            onToggleUtilities: onToggleContextSheet,
          ),
          const SizedBox(height: AppSpacing.md),
          const Expanded(child: _ChatCanvas(compact: true)),
          const SizedBox(height: AppSpacing.md),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: showContextSheet
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const _BottomUtilitySheet(compact: true),
            secondChild: const _UtilityToggleHint(compact: true),
          ),
        ],
      ),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              surfaces.background,
              surfaces.panel,
              surfaces.background.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.profile,
    required this.project,
    required this.onExit,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelCard(
          title: l10n.shellProjectRailTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                project.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(project.directory),
              const SizedBox(height: AppSpacing.md),
              _InfoChip(label: project.branch ?? l10n.shellUnknownLabel),
              const SizedBox(height: AppSpacing.sm),
              _InfoChip(label: profile.effectiveLabel),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l10n.shellBackToProjectsAction),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _PanelCard(
            title: l10n.shellSessionsTitle,
            child: Column(
              children: <Widget>[
                _SessionTile(
                  title: l10n.shellSessionCurrent,
                  status: l10n.shellStatusActive,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SessionTile(
                  title: l10n.shellSessionDraft,
                  status: l10n.shellStatusIdle,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SessionTile(
                  title: l10n.shellSessionReview,
                  status: l10n.shellStatusError,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatCanvas extends StatelessWidget {
  const _ChatCanvas({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelCard(
          title: l10n.shellChatHeaderTitle,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _InfoChip(label: l10n.shellThinkingModeLabel),
              _InfoChip(label: l10n.shellAgentLabel),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _PanelCard(
            title: l10n.shellChatTimelineTitle,
            fillChild: true,
            child: compact
                ? ListView(
                    children: <Widget>[
                      _MessageBubble(
                        title: l10n.shellUserMessageTitle,
                        body: l10n.shellUserMessageBody,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MessageBubble(
                        title: l10n.shellAssistantMessageTitle,
                        body: l10n.shellAssistantMessageBody,
                        accent: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ComposerCard(
                        compact: compact,
                        label: l10n.shellComposerPlaceholder,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _MessageBubble(
                        title: l10n.shellUserMessageTitle,
                        body: l10n.shellUserMessageBody,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MessageBubble(
                        title: l10n.shellAssistantMessageTitle,
                        body: l10n.shellAssistantMessageBody,
                        accent: true,
                      ),
                      const Spacer(),
                      _ComposerCard(
                        compact: compact,
                        label: l10n.shellComposerPlaceholder,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ContextRail extends StatelessWidget {
  const _ContextRail({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _PanelCard(
            title: l10n.shellContextTitle,
            child: Column(
              children: <Widget>[
                _UtilityTile(
                  title: l10n.shellFilesTitle,
                  subtitle: l10n.shellFilesSubtitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                _UtilityTile(
                  title: l10n.shellDiffTitle,
                  subtitle: l10n.shellDiffSubtitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                _UtilityTile(
                  title: l10n.shellTodoTitle,
                  subtitle: l10n.shellTodoSubtitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                _UtilityTile(
                  title: l10n.shellToolsTitle,
                  subtitle: l10n.shellToolsSubtitle,
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _UtilityTile(
                    title: l10n.shellTerminalTitle,
                    subtitle: l10n.shellTerminalSubtitle,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomUtilitySheet extends StatelessWidget {
  const _BottomUtilitySheet({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 220 : 260,
      child: const _ContextRail(compact: true),
    );
  }
}

class _UtilityToggleHint extends StatelessWidget {
  const _UtilityToggleHint({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PanelCard(
      title: l10n.shellUtilitiesToggleTitle,
      child: Text(
        compact
            ? l10n.shellUtilitiesToggleBodyCompact
            : l10n.shellUtilitiesToggleBody,
      ),
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.project,
    required this.onExit,
    required this.onToggleUtilities,
  });

  final ProjectTarget project;
  final VoidCallback onExit;
  final VoidCallback onToggleUtilities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                project.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(project.directory),
            ],
          ),
        ),
        IconButton(
          onPressed: onToggleUtilities,
          icon: const Icon(Icons.view_sidebar_outlined),
          tooltip: l10n.shellUtilitiesToggleTitle,
        ),
        const SizedBox(width: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(l10n.shellBackToProjectsAction),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.fillChild = false,
  });

  final String title;
  final Widget child;
  final bool fillChild;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (fillChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(status),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _UtilityTile extends StatelessWidget {
  const _UtilityTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.title,
    required this.body,
    this.accent = false,
  });

  final String title;
  final String body;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final fill = accent
        ? surfaces.accentSoft.withValues(alpha: 0.16)
        : surfaces.panelRaised.withValues(alpha: 0.78);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({required this.compact, required this.label});

  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.send_rounded),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
