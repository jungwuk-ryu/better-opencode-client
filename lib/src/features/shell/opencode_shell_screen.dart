import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../chat/chat_part_view.dart';
import '../chat/chat_service.dart';
import '../projects/project_models.dart';
import '../tools/todo_models.dart';
import '../tools/todo_service.dart';

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
  final ChatService _chatService = ChatService();
  final TodoService _todoService = TodoService();
  bool _showContextSheet = false;
  bool _loading = true;
  String? _error;
  List<SessionSummary> _sessions = const <SessionSummary>[];
  Map<String, SessionStatusSummary> _statuses =
      const <String, SessionStatusSummary>{};
  List<ChatMessage> _messages = const <ChatMessage>[];
  List<TodoItem> _todos = const <TodoItem>[];
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  @override
  void didUpdateWidget(covariant OpenCodeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.directory != widget.project.directory ||
        oldWidget.profile.storageKey != widget.profile.storageKey) {
      _loadBundle();
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    _todoService.dispose();
    super.dispose();
  }

  Future<void> _loadBundle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await _chatService.fetchBundle(
        profile: widget.profile,
        project: widget.project,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = bundle.sessions;
        _statuses = bundle.statuses;
        _messages = bundle.messages;
        _todos = const <TodoItem>[];
        _selectedSessionId = bundle.selectedSessionId;
        _loading = false;
      });
      if (bundle.selectedSessionId != null) {
        await _loadTodos(bundle.selectedSessionId!);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectSession(String sessionId) async {
    setState(() {
      _selectedSessionId = sessionId;
      _loading = true;
      _error = null;
    });
    try {
      final messages = await _chatService.fetchMessages(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      final todos = await _todoService.fetchTodos(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
        _todos = todos;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadTodos(String sessionId) async {
    try {
      final todos = await _todoService.fetchTodos(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _todos = todos;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _todos = const <TodoItem>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1320) {
      return _DesktopShell(
        profile: widget.profile,
        project: widget.project,
        onExit: widget.onExit,
        sessions: _sessions,
        statuses: _statuses,
        messages: _messages,
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        onSelectSession: _selectSession,
      );
    }
    if (width >= 960) {
      return _TabletLandscapeShell(
        profile: widget.profile,
        project: widget.project,
        onExit: widget.onExit,
        sessions: _sessions,
        statuses: _statuses,
        messages: _messages,
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        onSelectSession: _selectSession,
      );
    }
    if (width >= 700) {
      return _TabletPortraitShell(
        profile: widget.profile,
        project: widget.project,
        onExit: widget.onExit,
        sessions: _sessions,
        statuses: _statuses,
        messages: _messages,
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        onSelectSession: _selectSession,
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
      sessions: _sessions,
      statuses: _statuses,
      messages: _messages,
      todos: _todos,
      selectedSessionId: _selectedSessionId,
      loading: _loading,
      error: _error,
      onSelectSession: _selectSession,
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
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;

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
              sessions: sessions,
              statuses: statuses,
              selectedSessionId: selectedSessionId,
              onSelectSession: onSelectSession,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: 9,
            child: _ChatCanvas(
              messages: messages,
              loading: loading,
              error: error,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(width: 340, child: _ContextRail(todos: todos)),
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
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;

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
              sessions: sessions,
              statuses: statuses,
              selectedSessionId: selectedSessionId,
              onSelectSession: onSelectSession,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _ChatCanvas(
              messages: messages,
              loading: loading,
              error: error,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 280,
            child: _ContextRail(compact: true, todos: todos),
          ),
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
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
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
          Expanded(
            child: _ChatCanvas(
              messages: messages,
              loading: loading,
              error: error,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: showContextSheet
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const _BottomUtilitySheet(),
            // kept simple for now: portrait utility content comes from shared context rail
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
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
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
          Expanded(
            child: _ChatCanvas(
              compact: true,
              messages: messages,
              loading: loading,
              error: error,
            ),
          ),
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
    required this.sessions,
    required this.statuses,
    required this.selectedSessionId,
    required this.onSelectSession,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final String? selectedSessionId;
  final ValueChanged<String> onSelectSession;

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
              children: sessions.isEmpty
                  ? <Widget>[
                      _SessionTile(
                        title: l10n.shellSessionCurrent,
                        status: l10n.shellStatusIdle,
                      ),
                    ]
                  : sessions
                        .map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _SessionTile(
                              title: session.title,
                              status: _statusLabel(
                                l10n,
                                statuses[session.id]?.type ?? 'idle',
                              ),
                              selected: session.id == selectedSessionId,
                              onTap: () => onSelectSession(session.id),
                            ),
                          ),
                        )
                        .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatCanvas extends StatelessWidget {
  const _ChatCanvas({
    required this.messages,
    required this.loading,
    required this.error,
    this.compact = false,
  });

  final bool compact;
  final List<ChatMessage> messages;
  final bool loading;
  final String? error;

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
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Text(error!)
                : compact
                ? ListView(children: _messageContent(l10n))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: ListView(children: _messageContent(l10n)),
                      ),
                      const SizedBox(height: AppSpacing.md),
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

  List<Widget> _messageContent(AppLocalizations l10n) {
    if (messages.isEmpty) {
      return <Widget>[
        _MessageBubble(
          title: l10n.shellAssistantMessageTitle,
          body: l10n.shellAssistantMessageBody,
          accent: true,
        ),
      ];
    }
    return messages
        .expand(
          (message) => message.parts.map(
            (part) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ChatPartView(message: message.info, part: part),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _ContextRail extends StatelessWidget {
  const _ContextRail({required this.todos, this.compact = false});

  final bool compact;
  final List<TodoItem> todos;

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
                _TodoTileList(todos: todos),
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
      child: const _ContextRail(compact: true, todos: <TodoItem>[]),
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
  const _SessionTile({
    required this.title,
    required this.status,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      title: Text(title),
      subtitle: Text(status),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
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

class _TodoTileList extends StatelessWidget {
  const _TodoTileList({required this.todos});

  final List<TodoItem> todos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (todos.isEmpty) {
      return _UtilityTile(
        title: l10n.shellTodoTitle,
        subtitle: l10n.shellTodoSubtitle,
      );
    }
    final sorted = todos.toList()
      ..sort((a, b) => _todoRank(a.status).compareTo(_todoRank(b.status)));
    return Column(
      children: <Widget>[
        for (final todo in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ListTile(
              title: Text(todo.content),
              subtitle: Text('${todo.status} · ${todo.priority}'),
            ),
          ),
      ],
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

String _statusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'busy' => l10n.shellStatusActive,
    'retry' => l10n.shellStatusError,
    _ => l10n.shellStatusIdle,
  };
}

int _todoRank(String status) {
  return switch (status) {
    'in_progress' => 0,
    'pending' => 1,
    'completed' => 2,
    _ => 3,
  };
}
