import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_routes.dart';
import '../../app/app_scope.dart';
import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../files/file_models.dart';
import '../projects/project_models.dart';
import '../requests/request_models.dart';
import '../settings/agent_service.dart';
import '../terminal/terminal_service.dart';
import '../tools/todo_models.dart';
import 'workspace_controller.dart';

enum _CompactWorkspacePane { session, side }

class WebParityWorkspaceScreen extends StatefulWidget {
  const WebParityWorkspaceScreen({
    required this.directory,
    this.sessionId,
    super.key,
  });

  final String directory;
  final String? sessionId;

  @override
  State<WebParityWorkspaceScreen> createState() =>
      _WebParityWorkspaceScreenState();
}

class _WebParityWorkspaceScreenState extends State<WebParityWorkspaceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _timelineScrollController = ScrollController();
  WorkspaceController? _controller;
  ServerProfile? _profile;
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController(
    text: 'pwd',
  );
  String? _lastTimelineScopeKey;
  int _lastTimelineMessageCount = 0;
  _CompactWorkspacePane _compactPane = _CompactWorkspacePane.session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = AppScope.of(context).selectedProfile;
    if (profile == null) {
      _disposeController();
      _profile = null;
      return;
    }
    if (_controller != null &&
        _profile?.storageKey == profile.storageKey &&
        _controller!.directory == widget.directory &&
        _controller!.initialSessionId == widget.sessionId) {
      return;
    }
    _disposeController();
    _profile = profile;
    _compactPane = _CompactWorkspacePane.session;
    _controller = WorkspaceController(
      profile: profile,
      directory: widget.directory,
      initialSessionId: widget.sessionId,
    )..load();
  }

  @override
  void didUpdateWidget(covariant WebParityWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory != widget.directory ||
        oldWidget.sessionId != widget.sessionId) {
      _disposeController();
      final profile = AppScope.of(context).selectedProfile;
      if (profile != null) {
        _profile = profile;
        _compactPane = _CompactWorkspacePane.session;
        _controller = WorkspaceController(
          profile: profile,
          directory: widget.directory,
          initialSessionId: widget.sessionId,
        )..load();
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    _promptController.dispose();
    _terminalController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  void _scheduleTimelineSync(WorkspaceController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineScrollController.hasClients) {
        return;
      }

      final scopeKey =
          '${widget.directory}::${controller.selectedSessionId ?? 'new'}';
      final messageCount = controller.messages.length;
      final sessionChanged = _lastTimelineScopeKey != scopeKey;
      final messageCountChanged = _lastTimelineMessageCount != messageCount;
      final position = _timelineScrollController.position;
      final nearBottom =
          !position.hasPixels ||
          (position.maxScrollExtent - position.pixels) <= 120;

      if (sessionChanged || (messageCountChanged && nearBottom)) {
        final target = position.maxScrollExtent;
        if (sessionChanged || !position.hasPixels) {
          _timelineScrollController.jumpTo(target);
        } else {
          _timelineScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      }

      _lastTimelineScopeKey = scopeKey;
      _lastTimelineMessageCount = messageCount;
    });
  }

  Future<void> _submitPrompt() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final sessionId = await controller.submitPrompt(_promptController.text);
    _promptController.clear();
    if (!mounted || sessionId == null) {
      return;
    }
    final route = buildWorkspaceRoute(widget.directory, sessionId: sessionId);
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  Future<void> _renameSelectedSession(WorkspaceController controller) async {
    final selected = controller.selectedSession;
    if (selected == null) {
      return;
    }
    final titleController = TextEditingController(text: selected.title);
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Session title'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(titleController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (nextTitle == null || nextTitle.isEmpty) {
      return;
    }
    await controller.renameSelectedSession(nextTitle);
  }

  void _showPlaceholderDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appController = AppScope.of(context);
    final controller = _controller;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    if (appController.selectedProfile == null || controller == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Select a server first',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Return to the home screen and choose a server before opening a project.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false),
                  child: const Text('Back Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _scheduleTimelineSync(controller);
        final compact =
            MediaQuery.sizeOf(context).width < AppSpacing.wideLayoutBreakpoint;
        final sidebar = _WorkspaceSidebar(
          currentDirectory: widget.directory,
          currentSessionId: widget.sessionId,
          projects: controller.availableProjects,
          sessions: controller.sessions,
          statuses: controller.statuses,
          onSelectProject: (project) {
            Navigator.of(
              context,
            ).pushReplacementNamed(buildWorkspaceRoute(project.directory));
          },
          onSelectSession: (sessionId) {
            Navigator.of(context).pushReplacementNamed(
              buildWorkspaceRoute(widget.directory, sessionId: sessionId),
            );
          },
          onNewSession: () {
            Navigator.of(
              context,
            ).pushReplacementNamed(buildWorkspaceRoute(widget.directory));
          },
          onOpenSettings: () => _showPlaceholderDialog(
            'Settings',
            'Use "See Servers" on the home screen to manage connections while the parity shell is being completed.',
          ),
          onOpenHelp: () => _showPlaceholderDialog(
            'Help',
            'OpenCode Web parity is now organized around Home, Project, and Session routes.',
          ),
        );

        return Scaffold(
          key: _scaffoldKey,
          drawer: compact ? Drawer(child: sidebar) : null,
          body: SafeArea(
            child: Row(
              children: <Widget>[
                if (!compact) sidebar,
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _WorkspaceTopBar(
                        compact: compact,
                        profile: appController.selectedProfile,
                        project: controller.project,
                        session: controller.selectedSession,
                        status: controller.selectedStatus,
                        terminalOpen: controller.terminalOpen,
                        onBackHome: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false),
                        onOpenDrawer: compact
                            ? () => _scaffoldKey.currentState?.openDrawer()
                            : null,
                        onToggleTerminal: () => controller.setTerminalOpen(
                          !controller.terminalOpen,
                        ),
                        onRename: () => _renameSelectedSession(controller),
                        onFork: controller.selectedSession == null
                            ? null
                            : () async {
                                await controller.forkSelectedSession();
                                if (!context.mounted ||
                                    controller.selectedSessionId == null) {
                                  return;
                                }
                                Navigator.of(context).pushReplacementNamed(
                                  buildWorkspaceRoute(
                                    widget.directory,
                                    sessionId: controller.selectedSessionId,
                                  ),
                                );
                              },
                        onShare: controller.selectedSession == null
                            ? null
                            : controller.shareSelectedSession,
                        onDelete: controller.selectedSession == null
                            ? null
                            : () async {
                                await controller.deleteSelectedSession();
                                if (!context.mounted) {
                                  return;
                                }
                                final nextRoute =
                                    controller.selectedSessionId == null
                                    ? buildWorkspaceRoute(widget.directory)
                                    : buildWorkspaceRoute(
                                        widget.directory,
                                        sessionId: controller.selectedSessionId,
                                      );
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed(nextRoute);
                              },
                      ),
                      Expanded(
                        child: controller.loading
                            ? const Center(child: CircularProgressIndicator())
                            : controller.error != null
                            ? _WorkspaceError(
                                error: controller.error!,
                                onBackHome: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      '/',
                                      (route) => false,
                                    ),
                              )
                            : _WorkspaceBody(
                                compact: compact,
                                controller: controller,
                                promptController: _promptController,
                                terminalController: _terminalController,
                                timelineScrollController:
                                    _timelineScrollController,
                                compactPane: _compactPane,
                                onCompactPaneChanged: (value) {
                                  if (_compactPane == value) {
                                    return;
                                  }
                                  setState(() {
                                    _compactPane = value;
                                  });
                                },
                                onSubmitPrompt: _submitPrompt,
                                onRunCommand: () =>
                                    controller.runTerminalCommand(
                                      _terminalController.text,
                                    ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.compact,
    required this.profile,
    required this.project,
    required this.session,
    required this.status,
    required this.terminalOpen,
    required this.onBackHome,
    required this.onToggleTerminal,
    this.onOpenDrawer,
    this.onRename,
    this.onFork,
    this.onShare,
    this.onDelete,
  });

  final bool compact;
  final ServerProfile? profile;
  final ProjectTarget? project;
  final SessionSummary? session;
  final SessionStatusSummary? status;
  final bool terminalOpen;
  final VoidCallback onBackHome;
  final VoidCallback onToggleTerminal;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onRename;
  final VoidCallback? onFork;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    if (compact) {
      return Material(
        color: surfaces.panel,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: surfaces.lineSoft)),
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu_rounded, size: 18),
                splashRadius: 18,
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleTerminal,
                icon: Icon(
                  terminalOpen
                      ? Icons.terminal_rounded
                      : Icons.crop_free_rounded,
                  size: 18,
                ),
                splashRadius: 18,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
                onSelected: (value) {
                  switch (value) {
                    case 'home':
                      onBackHome();
                    case 'rename':
                      onRename?.call();
                    case 'fork':
                      onFork?.call();
                    case 'share':
                      onShare?.call();
                    case 'delete':
                      onDelete?.call();
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'home',
                    child: Text('Back Home'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename Session'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'fork',
                    child: Text('Fork Session'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Text('Share Session'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete Session'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: surfaces.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (compact)
              IconButton(
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu_rounded),
              ),
            IconButton(
              onPressed: onBackHome,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    session?.title.isNotEmpty == true
                        ? session!.title
                        : (project?.label ?? 'Project'),
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      profile?.effectiveLabel,
                      project?.directory,
                      if (status != null) status!.type,
                    ].whereType<String>().join('  •  '),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleTerminal,
              icon: Icon(
                terminalOpen
                    ? Icons.terminal_outlined
                    : Icons.keyboard_command_key_rounded,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename?.call();
                  case 'fork':
                    onFork?.call();
                  case 'share':
                    onShare?.call();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Text('Rename Session'),
                ),
                const PopupMenuItem<String>(
                  value: 'fork',
                  child: Text('Fork Session'),
                ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: Text('Share Session'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete Session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.currentDirectory,
    required this.currentSessionId,
    required this.projects,
    required this.sessions,
    required this.statuses,
    required this.onSelectProject,
    required this.onSelectSession,
    required this.onNewSession,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final String currentDirectory;
  final String? currentSessionId;
  final List<ProjectTarget> projects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final ValueChanged<ProjectTarget> onSelectProject;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewSession;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return SizedBox(
      width: 340,
      child: Row(
        children: <Widget>[
          Container(
            width: 72,
            color: surfaces.panel,
            child: Column(
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView.separated(
                    itemCount: projects.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final selected = project.directory == currentDirectory;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: InkWell(
                          onTap: () => onSelectProject(project),
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.16)
                                  : surfaces.panelRaised,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.md,
                              ),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : surfaces.lineSoft,
                              ),
                            ),
                            child: Text(
                              _projectInitial(project),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                ),
                const SizedBox(height: AppSpacing.xs),
                IconButton(
                  onPressed: onOpenHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: surfaces.panelRaised,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Sessions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: onNewSession,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: sessions.isEmpty
                        ? Text(
                            'Start a new session to begin.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: surfaces.muted),
                          )
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final selected = session.id == currentSessionId;
                              return ListTile(
                                selected: selected,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.md,
                                  ),
                                ),
                                tileColor: selected
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.12)
                                    : null,
                                title: Text(
                                  session.title.isEmpty
                                      ? 'Untitled session'
                                      : session.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  statuses[session.id]?.type ?? 'idle',
                                ),
                                onTap: () => onSelectSession(session.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _projectInitial(ProjectTarget project) {
  String pickCandidate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty);
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return trimmed;
  }

  final candidate = pickCandidate(project.label);
  final fallback = pickCandidate(project.directory);
  final resolved = candidate.isNotEmpty ? candidate : fallback;
  if (resolved.isEmpty) {
    return '?';
  }
  return resolved.characters.first.toUpperCase();
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.compact,
    required this.controller,
    required this.promptController,
    required this.terminalController,
    required this.timelineScrollController,
    required this.compactPane,
    required this.onCompactPaneChanged,
    required this.onSubmitPrompt,
    required this.onRunCommand,
  });

  final bool compact;
  final WorkspaceController controller;
  final TextEditingController promptController;
  final TextEditingController terminalController;
  final ScrollController timelineScrollController;
  final _CompactWorkspacePane compactPane;
  final ValueChanged<_CompactWorkspacePane> onCompactPaneChanged;
  final VoidCallback onSubmitPrompt;
  final VoidCallback onRunCommand;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final content = Column(
      children: <Widget>[
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.background,
              borderRadius: compact
                  ? null
                  : const BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.cardRadius),
                    ),
            ),
            child: controller.selectedSessionId == null
                ? _NewSessionView(
                    project: controller.project,
                    messages: controller.messages,
                  )
                : _MessageTimeline(
                    key: ValueKey<String>(
                      'timeline-${controller.selectedSessionId ?? 'new'}',
                    ),
                    controller: timelineScrollController,
                    messages: controller.messages,
                  ),
          ),
        ),
        _PromptComposer(
          controller: promptController,
          submitting: controller.submittingPrompt,
          agents: controller.composerAgents,
          models: controller.composerModels,
          selectedAgentName: controller.selectedAgentName,
          selectedModel: controller.selectedModel,
          selectedReasoning: controller.selectedReasoning,
          reasoningValues: controller.availableReasoningValues,
          onSelectAgent: controller.selectAgent,
          onSelectModel: controller.selectModel,
          onSelectReasoning: controller.selectReasoning,
          onSubmit: onSubmitPrompt,
        ),
        if (controller.terminalOpen || controller.lastShellResult != null)
          _TerminalPanel(
            controller: terminalController,
            running: controller.runningTerminal,
            lastResult: controller.lastShellResult,
            onRun: onRunCommand,
          ),
      ],
    );

    final sidePanel = _SidePanel(controller: controller);
    if (compact) {
      return Column(
        children: <Widget>[
          _CompactPaneSwitcher(
            activePane: compactPane,
            sideLabel: _compactSideLabel(controller),
            onChanged: onCompactPaneChanged,
          ),
          Expanded(
            child: compactPane == _CompactWorkspacePane.session
                ? content
                : sidePanel,
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: content),
        Container(width: 1, color: Theme.of(context).dividerColor),
        SizedBox(width: 360, child: sidePanel),
      ],
    );
  }
}

String _compactSideLabel(WorkspaceController controller) {
  final reviewCount = controller.fileBundle?.statuses.length ?? 0;
  return switch (controller.sideTab) {
    WorkspaceSideTab.review when reviewCount > 0 =>
      '$reviewCount Files Changed',
    WorkspaceSideTab.review => 'Review',
    WorkspaceSideTab.files => 'Files',
    WorkspaceSideTab.context => 'Context',
  };
}

class _NewSessionView extends StatelessWidget {
  const _NewSessionView({required this.project, required this.messages});

  final ProjectTarget? project;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              project?.label ?? 'New Session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Send a prompt to create a session for this worktree.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              textAlign: TextAlign.center,
            ),
            if (messages.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _MessageTimeline extends StatelessWidget {
  const _MessageTimeline({
    required this.controller,
    required this.messages,
    super.key,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
      );
    }

    return SelectionArea(
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        interactive: true,
        child: ListView.separated(
          controller: controller,
          key: const PageStorageKey<String>('web-parity-message-timeline'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
          itemBuilder: (context, index) {
            final message = messages[index];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: _TimelineMessage(message: message),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromptComposer extends StatelessWidget {
  const _PromptComposer({
    required this.controller,
    required this.submitting,
    required this.agents,
    required this.models,
    required this.selectedAgentName,
    required this.selectedModel,
    required this.selectedReasoning,
    required this.reasoningValues,
    required this.onSelectAgent,
    required this.onSelectModel,
    required this.onSelectReasoning,
    required this.onSubmit,
  });

  static const String _defaultReasoningSentinel = '__default_reasoning__';

  final TextEditingController controller;
  final bool submitting;
  final List<AgentDefinition> agents;
  final List<WorkspaceComposerModelOption> models;
  final String? selectedAgentName;
  final WorkspaceComposerModelOption? selectedModel;
  final String? selectedReasoning;
  final List<String> reasoningValues;
  final ValueChanged<String?> onSelectAgent;
  final ValueChanged<String?> onSelectModel;
  final ValueChanged<String?> onSelectReasoning;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final reasoningLabel = _reasoningLabel(selectedReasoning);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: surfaces.lineSoft),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'Ask anything...',
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.55),
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    _ComposerIconButton(icon: Icons.add_rounded, onTap: () {}),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            _ComposerSelectionPill(
                              label: selectedAgentName ?? 'Agent',
                              onTap: agents.isEmpty
                                  ? null
                                  : () async {
                                      final selection = await _showAgentPicker(
                                        context,
                                      );
                                      if (selection != null) {
                                        onSelectAgent(selection);
                                      }
                                    },
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _ComposerSelectionPill(
                              label: selectedModel?.name ?? 'Model',
                              onTap: models.isEmpty
                                  ? null
                                  : () async {
                                      final selection = await _showModelPicker(
                                        context,
                                      );
                                      if (selection != null) {
                                        onSelectModel(selection);
                                      }
                                    },
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _ComposerSelectionPill(
                              label: reasoningLabel,
                              onTap: selectedModel == null
                                  ? null
                                  : () async {
                                      final selection =
                                          await _showReasoningPicker(context);
                                      if (selection == null) {
                                        return;
                                      }
                                      onSelectReasoning(
                                        selection == _defaultReasoningSentinel
                                            ? null
                                            : selection,
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ComposerIconButton(
                      icon: Icons.arrow_upward_rounded,
                      onTap: submitting ? null : onSubmit,
                      filled: true,
                      busy: submitting,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showAgentPicker(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SearchableSelectionSheet<_AgentChoice>(
        title: 'Select Agent',
        searchHint: 'Search agents',
        items: agents
            .map(
              (agent) => _AgentChoice(
                value: agent.name,
                title: agent.name,
                subtitle: agent.description,
              ),
            )
            .toList(growable: false),
        selectedValue: selectedAgentName,
        matchesQuery: (item, query) {
          final q = query.toLowerCase();
          return item.title.toLowerCase().contains(q) ||
              (item.subtitle?.toLowerCase().contains(q) ?? false);
        },
        onSelected: (item) => Navigator.of(context).pop(item.value),
        titleBuilder: (item) => item.title,
        subtitleBuilder: (item) => item.subtitle,
        valueOf: (item) => item.value,
      ),
    );
  }

  Future<String?> _showModelPicker(BuildContext context) {
    final grouped = <String, List<WorkspaceComposerModelOption>>{};
    for (final model in models) {
      grouped
          .putIfAbsent(
            model.providerName,
            () => <WorkspaceComposerModelOption>[],
          )
          .add(model);
    }

    final items =
        grouped.entries
            .map(
              (entry) => _GroupedSelectionItems<WorkspaceComposerModelOption>(
                title: entry.key,
                items: entry.value
                  ..sort(
                    (left, right) => left.name.toLowerCase().compareTo(
                      right.name.toLowerCase(),
                    ),
                  ),
              ),
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.title.toLowerCase().compareTo(right.title.toLowerCase()),
          );

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _GroupedSelectionSheet<WorkspaceComposerModelOption>(
            title: 'Select Model',
            searchHint: 'Search models',
            groups: items,
            selectedValue: selectedModel?.key,
            matchesQuery: (item, query) {
              final q = query.toLowerCase();
              return item.name.toLowerCase().contains(q) ||
                  item.modelId.toLowerCase().contains(q) ||
                  item.providerName.toLowerCase().contains(q) ||
                  item.providerId.toLowerCase().contains(q);
            },
            onSelected: (item) => Navigator.of(context).pop(item.key),
            titleBuilder: (item) => item.name,
            subtitleBuilder: (item) => item.providerName,
            valueOf: (item) => item.key,
            trailingBuilder: (item) => item.reasoningValues.isEmpty
                ? null
                : Text(
                    '${item.reasoningValues.length} variants',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).extension<AppSurfaces>()!.muted,
                    ),
                  ),
          ),
    );
  }

  Future<String?> _showReasoningPicker(BuildContext context) {
    final options = <_ReasoningChoice>[
      const _ReasoningChoice(
        value: _defaultReasoningSentinel,
        label: 'Default',
      ),
      ...reasoningValues.map(
        (value) =>
            _ReasoningChoice(value: value, label: _reasoningLabel(value)),
      ),
    ];
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableSelectionSheet<_ReasoningChoice>(
        title: 'Reasoning',
        searchHint: 'Search variants',
        items: options,
        selectedValue: selectedReasoning ?? _defaultReasoningSentinel,
        matchesQuery: (item, query) {
          final q = query.toLowerCase();
          return item.label.toLowerCase().contains(q) ||
              (item.value?.toLowerCase().contains(q) ?? false);
        },
        onSelected: (item) => Navigator.of(context).pop(item.value),
        titleBuilder: (item) => item.label,
        subtitleBuilder: (item) => item.value,
        valueOf: (item) => item.value,
      ),
    );
  }
}

class _CompactPaneSwitcher extends StatelessWidget {
  const _CompactPaneSwitcher({
    required this.activePane,
    required this.sideLabel,
    required this.onChanged,
  });

  final _CompactWorkspacePane activePane;
  final String sideLabel;
  final ValueChanged<_CompactWorkspacePane> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(bottom: BorderSide(color: surfaces.lineSoft)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _CompactPaneButton(
              label: 'Session',
              selected: activePane == _CompactWorkspacePane.session,
              onTap: () => onChanged(_CompactWorkspacePane.session),
            ),
          ),
          Container(width: 1, color: surfaces.lineSoft),
          Expanded(
            child: _CompactPaneButton(
              label: sideLabel,
              selected: activePane == _CompactWorkspacePane.side,
              onTap: () => onChanged(_CompactWorkspacePane.side),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPaneButton extends StatelessWidget {
  const _CompactPaneButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? null : surfaces.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({
    required this.controller,
    required this.running,
    required this.lastResult,
    required this.onRun,
  });

  final TextEditingController controller;
  final bool running;
  final ShellCommandResult? lastResult;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaces.panelRaised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Shell',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (lastResult != null)
                      Text(
                        'session ${lastResult!.sessionId}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: 'pwd',
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.ibmPlexMono(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                        onSubmitted: (_) => onRun(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: running ? null : onRun,
                      child: Text(running ? 'Running...' : 'Run'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineMessage extends StatelessWidget {
  const _TimelineMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final isUser = message.info.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surfaces.panelRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: _InlineCodeText(text: _messageBody(message)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: message.parts
          .map(
            (part) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _TimelinePart(part: part),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _TimelinePart extends StatelessWidget {
  const _TimelinePart({required this.part});

  final ChatPart part;

  @override
  Widget build(BuildContext context) {
    final body = _partText(part);
    if (_isToolLikePart(part)) {
      return _ToolCard(
        title: _partTitle(part),
        body: body,
        icon: _partIcon(part),
      );
    }
    return _StructuredTextBlock(text: body);
  }
}

class _StructuredTextBlock extends StatelessWidget {
  const _StructuredTextBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final blocks = <Widget>[];
    final fencePattern = RegExp(r'```([a-zA-Z0-9_-]*)\n([\s\S]*?)```');
    var cursor = 0;
    for (final match in fencePattern.allMatches(text)) {
      final before = text.substring(cursor, match.start).trim();
      if (before.isNotEmpty) {
        blocks.add(_ParagraphBlock(text: before));
      }
      final language = match.group(1)?.trim();
      final code = (match.group(2) ?? '').trimRight();
      blocks.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (language != null && language.isNotEmpty) ...<Widget>[
                Text(
                  language.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: surfaces.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                code,
                style: GoogleFonts.ibmPlexMono(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
      cursor = match.end;
    }

    final tail = text.substring(cursor).trim();
    if (tail.isNotEmpty) {
      blocks.add(_ParagraphBlock(text: tail));
    }

    if (blocks.isEmpty) {
      blocks.add(_ParagraphBlock(text: text));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: block,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs
          .map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _InlineCodeText(text: paragraph),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _InlineCodeText extends StatelessWidget {
  const _InlineCodeText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.8);
    final codeStyle = GoogleFonts.ibmPlexMono(
      color: theme.colorScheme.primary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.8,
    );
    final codePattern = RegExp(r'`([^`]+)`');
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in codePattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: surfaces.panelRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text(match.group(1) ?? '', style: codeStyle),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaces.panelMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text(
              body,
              style: GoogleFonts.ibmPlexMono(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final color = filled
        ? Theme.of(context).colorScheme.primary
        : surfaces.panelRaised;
    final foreground = filled
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? color : surfaces.lineSoft),
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              : Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}

class _ComposerSelectionPill extends StatelessWidget {
  const _ComposerSelectionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: surfaces.panelRaised,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(color: surfaces.lineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: enabled ? null : surfaces.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: enabled ? surfaces.muted : surfaces.lineSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentChoice {
  const _AgentChoice({required this.value, required this.title, this.subtitle});

  final String value;
  final String title;
  final String? subtitle;
}

class _ReasoningChoice {
  const _ReasoningChoice({required this.value, required this.label});

  final String? value;
  final String label;
}

class _SearchableSelectionSheet<T> extends StatefulWidget {
  const _SearchableSelectionSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selectedValue,
    required this.matchesQuery,
    required this.onSelected,
    required this.titleBuilder,
    required this.valueOf,
    this.subtitleBuilder,
  });

  final String title;
  final String searchHint;
  final List<T> items;
  final String? selectedValue;
  final bool Function(T item, String query) matchesQuery;
  final void Function(T item) onSelected;
  final String Function(T item) titleBuilder;
  final String? Function(T item)? subtitleBuilder;
  final String? Function(T item) valueOf;

  @override
  State<_SearchableSelectionSheet<T>> createState() =>
      _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T>
    extends State<_SearchableSelectionSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? widget.items
        : widget.items
              .where((item) => widget.matchesQuery(item, _query.trim()))
              .toList(growable: false);

    return _SelectionSheetFrame(
      title: widget.title,
      searchHint: widget.searchHint,
      onSearchChanged: (value) {
        setState(() {
          _query = value;
        });
      },
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final selected = widget.valueOf(item) == widget.selectedValue;
          return _SelectionTile(
            title: widget.titleBuilder(item),
            subtitle: widget.subtitleBuilder?.call(item),
            selected: selected,
            onTap: () => widget.onSelected(item),
          );
        },
      ),
    );
  }
}

class _GroupedSelectionSheet<T> extends StatefulWidget {
  const _GroupedSelectionSheet({
    required this.title,
    required this.searchHint,
    required this.groups,
    required this.selectedValue,
    required this.matchesQuery,
    required this.onSelected,
    required this.titleBuilder,
    required this.valueOf,
    this.subtitleBuilder,
    this.trailingBuilder,
  });

  final String title;
  final String searchHint;
  final List<_GroupedSelectionItems<T>> groups;
  final String? selectedValue;
  final bool Function(T item, String query) matchesQuery;
  final void Function(T item) onSelected;
  final String Function(T item) titleBuilder;
  final String? Function(T item)? subtitleBuilder;
  final Widget? Function(T item)? trailingBuilder;
  final String? Function(T item) valueOf;

  @override
  State<_GroupedSelectionSheet<T>> createState() =>
      _GroupedSelectionSheetState<T>();
}

class _GroupedSelectionSheetState<T> extends State<_GroupedSelectionSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final sections = widget.groups
        .map((group) {
          final items = _query.trim().isEmpty
              ? group.items
              : group.items
                    .where((item) => widget.matchesQuery(item, _query.trim()))
                    .toList(growable: false);
          return _GroupedSelectionItems<T>(title: group.title, items: items);
        })
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);

    return _SelectionSheetFrame(
      title: widget.title,
      searchHint: widget.searchHint,
      onSearchChanged: (value) {
        setState(() {
          _query = value;
        });
      },
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final group = sections[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == sections.length - 1 ? 0 : AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    group.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).extension<AppSurfaces>()!.muted,
                    ),
                  ),
                ),
                ...group.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _SelectionTile(
                      title: widget.titleBuilder(item),
                      subtitle: widget.subtitleBuilder?.call(item),
                      trailing: widget.trailingBuilder?.call(item),
                      selected: widget.valueOf(item) == widget.selectedValue,
                      onTap: () => widget.onSelected(item),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupedSelectionItems<T> {
  const _GroupedSelectionItems({required this.title, required this.items});

  final String title;
  final List<T> items;
}

class _SelectionSheetFrame extends StatelessWidget {
  const _SelectionSheetFrame({
    required this.title,
    required this.searchHint,
    required this.onSearchChanged,
    required this.child,
  });

  final String title;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final mediaQuery = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + mediaQuery.viewInsets.bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: Material(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: surfaces.lineSoft),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Flexible(child: child),
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

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : surfaces.panelRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : surfaces.lineSoft,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null &&
                      subtitle!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (selected) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.check_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _reasoningLabel(String? value) {
  return switch (value?.trim().toLowerCase()) {
    null || '' => 'Default',
    'none' => 'None',
    'low' => 'Low',
    'medium' => 'Medium',
    'high' => 'High',
    'xhigh' || 'max' => 'Xhigh',
    final other => _titleCase(other),
  };
}

String _titleCase(String value) {
  final words = value
      .split(RegExp(r'[_\\-]+'))
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}');
  final joined = words.join(' ');
  return joined.isEmpty ? value : joined;
}

String _messageBody(ChatMessage message) {
  return message.parts
      .map(_partText)
      .where((value) => value.isNotEmpty)
      .join('\n\n');
}

String _partText(ChatPart part) {
  final candidates = <Object?>[
    part.text,
    part.metadata['summary'],
    part.metadata['content'],
    part.metadata['command'],
    part.metadata['output'],
    part.metadata['description'],
    part.metadata['text'],
  ];
  for (final value in candidates) {
    final normalized = value?.toString().trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }

  final lines = <String>[];
  for (final entry in part.metadata.entries) {
    final value = entry.value;
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isNotEmpty) {
      lines.add('${entry.key}: ${value.trim()}');
    }
  }
  return lines.join('\n');
}

bool _isToolLikePart(ChatPart part) {
  return switch (part.type) {
    'tool' ||
    'reasoning' ||
    'step-start' ||
    'step-finish' ||
    'patch' ||
    'snapshot' ||
    'retry' ||
    'agent' ||
    'subtask' ||
    'compaction' => true,
    _ => false,
  };
}

String _partTitle(ChatPart part) {
  return switch (part.type) {
    'tool' => part.tool?.trim().isNotEmpty == true ? part.tool!.trim() : 'Tool',
    'reasoning' => 'Reasoning',
    'step-start' => 'Step',
    'step-finish' => 'Step Result',
    'patch' => 'Patch',
    'snapshot' => 'Snapshot',
    'retry' => 'Retry',
    'agent' => 'Agent',
    'subtask' => 'Subtask',
    'compaction' => 'Compaction',
    _ => part.type,
  };
}

IconData _partIcon(ChatPart part) {
  return switch (part.type) {
    'tool' => Icons.terminal_rounded,
    'reasoning' => Icons.psychology_alt_outlined,
    'patch' => Icons.auto_fix_high_rounded,
    'snapshot' => Icons.photo_library_outlined,
    'agent' => Icons.hub_outlined,
    _ => Icons.code_rounded,
  };
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final tab = controller.sideTab;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SegmentedButton<WorkspaceSideTab>(
            segments: const <ButtonSegment<WorkspaceSideTab>>[
              ButtonSegment<WorkspaceSideTab>(
                value: WorkspaceSideTab.review,
                label: Text('Review'),
              ),
              ButtonSegment<WorkspaceSideTab>(
                value: WorkspaceSideTab.files,
                label: Text('Files'),
              ),
              ButtonSegment<WorkspaceSideTab>(
                value: WorkspaceSideTab.context,
                label: Text('Context'),
              ),
            ],
            selected: <WorkspaceSideTab>{tab},
            onSelectionChanged: (selection) =>
                controller.setSideTab(selection.first),
          ),
        ),
        Expanded(
          child: switch (tab) {
            WorkspaceSideTab.review => _ReviewPanel(
              statuses:
                  controller.fileBundle?.statuses ??
                  const <FileStatusSummary>[],
            ),
            WorkspaceSideTab.files => _FilesPanel(
              bundle: controller.fileBundle,
            ),
            WorkspaceSideTab.context => _ContextPanel(
              todos: controller.todos,
              pendingRequests: controller.pendingRequests,
            ),
          },
        ),
      ],
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.statuses});

  final List<FileStatusSummary> statuses;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    if (statuses.isEmpty) {
      return Center(
        child: Text(
          'No file changes yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: statuses.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = statuses[index];
        return ListTile(
          title: Text(item.path),
          subtitle: Text('${item.status}  •  +${item.added}  -${item.removed}'),
        );
      },
    );
  }
}

class _FilesPanel extends StatelessWidget {
  const _FilesPanel({required this.bundle});

  final FileBrowserBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final bundle = this.bundle;
    if (bundle == null) {
      return Center(
        child: Text(
          'Files are unavailable.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: bundle.nodes.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final node = bundle.nodes[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  node.type == 'directory'
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                ),
                title: Text(node.name),
                subtitle: Text(node.path),
              );
            },
          ),
        ),
        if (bundle.preview != null)
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: surfaces.lineSoft)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                bundle.preview!.content,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.todos, required this.pendingRequests});

  final List<TodoItem> todos;
  final PendingRequestBundle pendingRequests;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Text('Todos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (todos.isEmpty)
          Text(
            'No todos for this session.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
          )
        else
          ...todos.map(
            (todo) => ListTile(
              title: Text(todo.content),
              subtitle: Text('${todo.status}  •  ${todo.priority}'),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Pending Requests',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          title: const Text('Questions'),
          trailing: Text('${pendingRequests.questions.length}'),
        ),
        ListTile(
          title: const Text('Permissions'),
          trailing: Text('${pendingRequests.permissions.length}'),
        ),
      ],
    );
  }
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.error, required this.onBackHome});

  final String error;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Failed to load workspace',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onBackHome, child: const Text('Back Home')),
          ],
        ),
      ),
    );
  }
}
