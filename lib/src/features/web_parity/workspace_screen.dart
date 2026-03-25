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
import '../terminal/terminal_service.dart';
import '../tools/todo_models.dart';
import 'workspace_controller.dart';

class WebParityWorkspaceScreen extends StatefulWidget {
  const WebParityWorkspaceScreen({
    required this.directory,
    this.sessionId,
    super.key,
  });

  final String directory;
  final String? sessionId;

  @override
  State<WebParityWorkspaceScreen> createState() => _WebParityWorkspaceScreenState();
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
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  ),
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
            Navigator.of(context).pushReplacementNamed(
              buildWorkspaceRoute(project.directory),
            );
          },
          onSelectSession: (sessionId) {
            Navigator.of(context).pushReplacementNamed(
              buildWorkspaceRoute(widget.directory, sessionId: sessionId),
            );
          },
          onNewSession: () {
            Navigator.of(context).pushReplacementNamed(
              buildWorkspaceRoute(widget.directory),
            );
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
                        onBackHome: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            ),
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
                                final nextRoute = controller.selectedSessionId == null
                                    ? buildWorkspaceRoute(widget.directory)
                                    : buildWorkspaceRoute(
                                        widget.directory,
                                        sessionId: controller.selectedSessionId,
                                      );
                                Navigator.of(context).pushReplacementNamed(nextRoute);
                              },
                      ),
                      Expanded(
                        child: controller.loading
                            ? const Center(child: CircularProgressIndicator())
                            : controller.error != null
                            ? _WorkspaceError(
                                error: controller.error!,
                                onBackHome: () =>
                                    Navigator.of(context).pushNamedAndRemoveUntil(
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
                                onSubmitPrompt: _submitPrompt,
                                onRunCommand: () => controller.runTerminalCommand(
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
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.16)
                                  : surfaces.panelRaised,
                              borderRadius: BorderRadius.circular(AppSpacing.md),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : surfaces.lineSoft,
                              ),
                            ),
                            child: Text(
                              _projectInitial(project.label),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
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
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
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

String _projectInitial(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.characters.first.toUpperCase();
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.compact,
    required this.controller,
    required this.promptController,
    required this.terminalController,
    required this.timelineScrollController,
    required this.onSubmitPrompt,
    required this.onRunCommand,
  });

  final bool compact;
  final WorkspaceController controller;
  final TextEditingController promptController;
  final TextEditingController terminalController;
  final ScrollController timelineScrollController;
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
          Expanded(child: content),
          SizedBox(height: 320, child: sidePanel),
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
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    _ComposerIconButton(
                      icon: Icons.add_rounded,
                      onTap: () {},
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const _ComposerMetaPill(label: 'Sisyphus'),
                    const SizedBox(width: AppSpacing.xs),
                    const _ComposerMetaPill(label: 'GPT-5.4'),
                    const SizedBox(width: AppSpacing.xs),
                    const _ComposerMetaPill(label: 'Medium'),
                    const Spacer(),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                        ),
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
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: surfaces.muted,
                  ),
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
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
    );
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
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
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
          border: Border.all(
            color: filled ? color : surfaces.lineSoft,
          ),
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

class _ComposerMetaPill extends StatelessWidget {
  const _ComposerMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surfaces.panelRaised,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
      ),
    );
  }
}

String _messageBody(ChatMessage message) {
  return message.parts.map(_partText).where((value) => value.isNotEmpty).join('\n\n');
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
    'tool' || 'reasoning' || 'step-start' || 'step-finish' || 'patch' ||
    'snapshot' || 'retry' || 'agent' || 'subtask' || 'compaction' => true,
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
                statuses: controller.fileBundle?.statuses ?? const <FileStatusSummary>[],
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.todos,
    required this.pendingRequests,
  });

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
        Text('Pending Requests', style: Theme.of(context).textTheme.titleMedium),
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
            FilledButton(
              onPressed: onBackHome,
              child: const Text('Back Home'),
            ),
          ],
        ),
      ),
    );
  }
}
