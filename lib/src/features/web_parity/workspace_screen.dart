import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/app_routes.dart';
import '../../app/app_scope.dart';
import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../chat/session_context_insights.dart';
import '../commands/command_service.dart';
import '../files/file_models.dart';
import '../projects/project_models.dart';
import '../requests/request_models.dart';
import '../settings/agent_service.dart';
import '../settings/config_service.dart';
import '../terminal/pty_models.dart';
import '../terminal/pty_service.dart';
import '../terminal/pty_terminal_panel.dart';
import '../tools/todo_models.dart';
import 'workspace_controller.dart';

enum _CompactWorkspacePane { session, side }

class WebParityWorkspaceScreen extends StatefulWidget {
  const WebParityWorkspaceScreen({
    required this.directory,
    this.sessionId,
    this.ptyServiceFactory,
    super.key,
  });

  final String directory;
  final String? sessionId;
  final PtyService Function()? ptyServiceFactory;

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
  String? _lastTimelineScopeKey;
  int _lastTimelineMessageCount = 0;
  int _lastTimelineContentSignature = 0;
  bool _timelineWasNearBottom = true;
  _CompactWorkspacePane _compactPane = _CompactWorkspacePane.session;
  PtyService? _ptyService;
  List<PtySessionInfo> _ptySessions = const <PtySessionInfo>[];
  String? _activePtyId;
  String? _terminalError;
  bool _terminalPanelOpen = false;
  bool _loadingPtySessions = false;
  bool _creatingPtySession = false;
  int _terminalEpoch = 0;
  bool _hasPendingSessionRouteSync = false;
  bool _sessionRouteSyncInFlight = false;
  String? _pendingSessionRouteId;
  int _sessionRouteSyncRevision = 0;
  bool _promptSubmitInFlight = false;

  @override
  void initState() {
    super.initState();
    _timelineScrollController.addListener(_handleTimelineScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appController = AppScope.of(context);
    final profile = appController.selectedProfile;
    if (profile == null) {
      _disposeController();
      _profile = null;
      _resetRouteSessionSync();
      return;
    }
    final hadCachedController = appController.hasWorkspaceController(
      profile: profile,
      directory: widget.directory,
    );
    final nextController = appController.obtainWorkspaceController(
      profile: profile,
      directory: widget.directory,
      initialSessionId: widget.sessionId,
    );
    final bindingChanged =
        !identical(_controller, nextController) ||
        _profile?.storageKey != profile.storageKey;

    _controller = nextController;
    _profile = profile;

    if (!bindingChanged) {
      return;
    }

    _compactPane = _CompactWorkspacePane.session;
    _resetTerminalState(profile);
    if (hadCachedController) {
      _queueRouteSessionSync(widget.sessionId);
    } else {
      _resetRouteSessionSync();
    }
  }

  @override
  void didUpdateWidget(covariant WebParityWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory != widget.directory) {
      _disposeController();
      _resetRouteSessionSync();
      final appController = AppScope.of(context);
      final profile = appController.selectedProfile;
      if (profile != null) {
        final hadCachedController = appController.hasWorkspaceController(
          profile: profile,
          directory: widget.directory,
        );
        _controller = appController.obtainWorkspaceController(
          profile: profile,
          directory: widget.directory,
          initialSessionId: widget.sessionId,
        );
        _profile = profile;
        _compactPane = _CompactWorkspacePane.session;
        _resetTerminalState(profile);
        if (hadCachedController) {
          _queueRouteSessionSync(widget.sessionId);
        }
      }
      return;
    }
    if (oldWidget.sessionId != widget.sessionId) {
      _queueRouteSessionSync(widget.sessionId);
    }
  }

  @override
  void dispose() {
    _disposeController();
    _promptController.dispose();
    _timelineScrollController.removeListener(_handleTimelineScroll);
    _timelineScrollController.dispose();
    _ptyService?.dispose();
    super.dispose();
  }

  void _disposeController() {
    _controller = null;
  }

  void _resetRouteSessionSync() {
    _hasPendingSessionRouteSync = false;
    _sessionRouteSyncInFlight = false;
    _pendingSessionRouteId = null;
    _sessionRouteSyncRevision = 0;
  }

  void _queueRouteSessionSync(String? sessionId) {
    _pendingSessionRouteId = sessionId;
    _hasPendingSessionRouteSync = true;
    _sessionRouteSyncRevision += 1;
    _scheduleRouteSessionSync();
  }

  void _scheduleRouteSessionSync() {
    if (!_hasPendingSessionRouteSync || _sessionRouteSyncInFlight) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = _controller;
      if (!mounted ||
          controller == null ||
          !_hasPendingSessionRouteSync ||
          _sessionRouteSyncInFlight ||
          controller.loading) {
        return;
      }

      final requestedSessionId = _pendingSessionRouteId;
      if (controller.selectedSessionId == requestedSessionId) {
        _hasPendingSessionRouteSync = false;
        return;
      }

      final revision = _sessionRouteSyncRevision;
      _sessionRouteSyncInFlight = true;
      try {
        await controller.selectSession(requestedSessionId);
      } finally {
        _sessionRouteSyncInFlight = false;
        if (mounted) {
          if (revision == _sessionRouteSyncRevision &&
              _pendingSessionRouteId == requestedSessionId) {
            _hasPendingSessionRouteSync = false;
          }
          if (_hasPendingSessionRouteSync) {
            _scheduleRouteSessionSync();
          }
        }
      }
    });
  }

  void _resetTerminalState(ServerProfile profile) {
    _terminalEpoch += 1;
    _ptyService?.dispose();
    _ptyService = (widget.ptyServiceFactory ?? PtyService.new)();
    _ptySessions = const <PtySessionInfo>[];
    _activePtyId = null;
    _terminalError = null;
    _terminalPanelOpen = false;
    _loadingPtySessions = true;
    _creatingPtySession = false;
    unawaited(_loadPtySessions(epoch: _terminalEpoch, profile: profile));
  }

  Future<void> _loadPtySessions({
    required int epoch,
    required ServerProfile profile,
  }) async {
    final service = _ptyService;
    if (service == null) {
      return;
    }
    try {
      final sessions = await service.listSessions(
        profile: profile,
        directory: widget.directory,
      );
      if (!mounted || epoch != _terminalEpoch) {
        return;
      }
      setState(() {
        _ptySessions = sessions;
        _activePtyId = _resolveActivePtyId(sessions, preferred: _activePtyId);
        _loadingPtySessions = false;
        _terminalError = null;
      });
      if (_terminalPanelOpen && sessions.isEmpty) {
        unawaited(_createPtySession());
      }
    } catch (error) {
      if (!mounted || epoch != _terminalEpoch) {
        return;
      }
      setState(() {
        _loadingPtySessions = false;
        _terminalError = error.toString();
      });
    }
  }

  String? _resolveActivePtyId(
    List<PtySessionInfo> sessions, {
    String? preferred,
  }) {
    if (sessions.isEmpty) {
      return null;
    }
    if (preferred != null) {
      for (final session in sessions) {
        if (session.id == preferred) {
          return preferred;
        }
      }
    }
    return sessions.first.id;
  }

  Future<void> _toggleTerminalPanel() async {
    if (_terminalPanelOpen) {
      setState(() {
        _terminalPanelOpen = false;
      });
      return;
    }
    setState(() {
      _terminalPanelOpen = true;
      _terminalError = null;
    });
    if (!_loadingPtySessions && _ptySessions.isEmpty) {
      await _createPtySession();
    }
  }

  Future<void> _createPtySession() async {
    final profile = _profile;
    final service = _ptyService;
    if (profile == null || service == null || _creatingPtySession) {
      return;
    }
    setState(() {
      _creatingPtySession = true;
      _terminalPanelOpen = true;
      _terminalError = null;
    });
    try {
      final session = await service.createSession(
        profile: profile,
        directory: widget.directory,
        cwd: widget.directory,
        title: _nextTerminalTitle(_ptySessions),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ptySessions = <PtySessionInfo>[
          session,
          ..._ptySessions.where((item) => item.id != session.id),
        ];
        _activePtyId = session.id;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _terminalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingPtySession = false;
        });
      }
    }
  }

  Future<void> _closePtySession(String ptyId) async {
    final profile = _profile;
    final service = _ptyService;
    if (profile == null || service == null) {
      return;
    }
    setState(() {
      _ptySessions = _ptySessions
          .where((session) => session.id != ptyId)
          .toList(growable: false);
      _activePtyId = _resolveActivePtyId(_ptySessions);
      if (_ptySessions.isEmpty) {
        _terminalPanelOpen = false;
      }
    });
    try {
      await service.removeSession(
        profile: profile,
        directory: widget.directory,
        ptyId: ptyId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _terminalError = error.toString();
      });
    }
  }

  Future<void> _renamePtySession(String ptyId, String title) async {
    final trimmed = title.trim();
    final profile = _profile;
    final service = _ptyService;
    if (profile == null || service == null || trimmed.isEmpty) {
      return;
    }

    PtySessionInfo? previous;
    setState(() {
      _ptySessions = _ptySessions
          .map((session) {
            if (session.id != ptyId) {
              return session;
            }
            previous = session;
            return session.copyWith(title: trimmed);
          })
          .toList(growable: false);
    });

    try {
      final updated = await service.updateSession(
        profile: profile,
        directory: widget.directory,
        ptyId: ptyId,
        title: trimmed,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ptySessions = _ptySessions
            .map((session) {
              return session.id == updated.id ? updated : session;
            })
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (previous != null) {
          _ptySessions = _ptySessions
              .map((session) {
                return session.id == ptyId ? previous! : session;
              })
              .toList(growable: false);
        }
        _terminalError = error.toString();
      });
    }
  }

  void _removeMissingPtySession(String ptyId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _ptySessions = _ptySessions
          .where((session) => session.id != ptyId)
          .toList(growable: false);
      _activePtyId = _resolveActivePtyId(_ptySessions, preferred: _activePtyId);
      if (_ptySessions.isEmpty) {
        _terminalPanelOpen = false;
      }
    });
  }

  String _nextTerminalTitle(List<PtySessionInfo> sessions) {
    final used = <int>{};
    final pattern = RegExp(r'^Terminal\s+(\d+)$', caseSensitive: false);
    for (final session in sessions) {
      final match = pattern.firstMatch(session.title.trim());
      final value = match == null ? null : int.tryParse(match.group(1)!);
      if (value != null && value > 0) {
        used.add(value);
      }
    }
    var number = 1;
    while (used.contains(number)) {
      number += 1;
    }
    return 'Terminal $number';
  }

  void _handleTimelineScroll() {
    if (!_timelineScrollController.hasClients) {
      return;
    }
    final position = _timelineScrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    _timelineWasNearBottom =
        !position.hasPixels ||
        (position.maxScrollExtent - position.pixels) <= 120;
  }

  void _scheduleTimelineSync(WorkspaceController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineScrollController.hasClients) {
        return;
      }

      final scopeKey =
          '${widget.directory}::${controller.selectedSessionId ?? 'new'}';
      final messageCount = controller.messages.length;
      final contentSignature = _timelineContentSignature(controller.messages);
      final sessionChanged = _lastTimelineScopeKey != scopeKey;
      final messageCountChanged = _lastTimelineMessageCount != messageCount;
      final contentChanged =
          _lastTimelineContentSignature != contentSignature ||
          messageCountChanged;
      final position = _timelineScrollController.position;
      if (!position.hasContentDimensions) {
        return;
      }
      final nearBottomNow =
          !position.hasPixels ||
          (position.maxScrollExtent - position.pixels) <= 120;
      final shouldFollowTimeline =
          sessionChanged ||
          (contentChanged && (_timelineWasNearBottom || nearBottomNow));

      if (shouldFollowTimeline) {
        final target = position.maxScrollExtent;
        if ((target - position.pixels).abs() <= 1) {
          _timelineWasNearBottom = true;
        } else if (sessionChanged || !position.hasPixels) {
          _timelineScrollController.jumpTo(target);
          _timelineWasNearBottom = true;
        } else {
          _timelineScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
          _timelineWasNearBottom = true;
        }
      }

      _lastTimelineScopeKey = scopeKey;
      _lastTimelineMessageCount = messageCount;
      _lastTimelineContentSignature = contentSignature;
    });
  }

  int _timelineContentSignature(List<ChatMessage> messages) {
    var signature = messages.length;
    for (final message in messages) {
      final encoded = jsonEncode(message.toJson());
      signature = Object.hash(signature, encoded.length, encoded.hashCode);
    }
    return signature;
  }

  Future<void> _submitPrompt() async {
    final controller = _controller;
    final draft = _promptController.text;
    if (controller == null ||
        _promptSubmitInFlight ||
        controller.submittingPrompt ||
        draft.trim().isEmpty) {
      return;
    }

    setState(() {
      _promptSubmitInFlight = true;
    });
    _promptController.clear();

    try {
      await controller.submitPrompt(draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _promptController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _promptSubmitInFlight = false;
        });
      }
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

  Future<void> _createNewSession(WorkspaceController controller) async {
    try {
      await controller.createEmptySession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create session: $error')),
      );
    }
  }

  Future<void> _shareSelectedSession(WorkspaceController controller) async {
    try {
      await controller.shareSelectedSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share session: $error')),
      );
    }
  }

  Future<void> _unshareSelectedSession(WorkspaceController controller) async {
    try {
      await controller.unshareSelectedSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unshare session: $error')),
      );
    }
  }

  Future<void> _summarizeSelectedSession(WorkspaceController controller) async {
    try {
      await controller.summarizeSelectedSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to compact session: $error')),
      );
    }
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

  Future<void> _selectSessionInPlace(
    WorkspaceController controller,
    String sessionId, {
    required bool compact,
  }) async {
    if (compact && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
    }
    await controller.selectSession(sessionId);
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
        _scheduleRouteSessionSync();
        final compact =
            MediaQuery.sizeOf(context).width < AppSpacing.wideLayoutBreakpoint;
        final selectedSession = controller.selectedSession;
        final mainSession = _rootSessionFor(
          controller.sessions,
          selectedSession,
        );
        final sidebar = _WorkspaceSidebar(
          currentDirectory: widget.directory,
          currentSessionId: mainSession?.id ?? controller.selectedSessionId,
          projects: controller.availableProjects,
          sessions: controller.visibleSessions,
          statuses: controller.statuses,
          onSelectProject: (project) {
            Navigator.of(
              context,
            ).pushReplacementNamed(buildWorkspaceRoute(project.directory));
          },
          onSelectSession: (sessionId) {
            unawaited(
              _selectSessionInPlace(controller, sessionId, compact: compact),
            );
          },
          onNewSession: () => _createNewSession(controller),
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
                        session: selectedSession,
                        mainSession: mainSession,
                        status: controller.selectedStatus,
                        terminalOpen: _terminalPanelOpen,
                        onBackHome: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false),
                        onOpenDrawer: compact
                            ? () => _scaffoldKey.currentState?.openDrawer()
                            : null,
                        onToggleTerminal: _toggleTerminalPanel,
                        onBackToMainSession:
                            selectedSession != null &&
                                mainSession != null &&
                                selectedSession.id != mainSession.id
                            ? () {
                                unawaited(
                                  _selectSessionInPlace(
                                    controller,
                                    mainSession.id,
                                    compact: compact,
                                  ),
                                );
                              }
                            : null,
                        onRename: () => _renameSelectedSession(controller),
                        onFork: controller.selectedSession == null
                            ? null
                            : () async {
                                await controller.forkSelectedSession();
                              },
                        onShare: controller.selectedSession == null
                            ? null
                            : controller.shareSelectedSession,
                        onDelete: controller.selectedSession == null
                            ? null
                            : controller.deleteSelectedSession,
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
                                allSessions: controller.sessions,
                                submittingPrompt:
                                    _promptSubmitInFlight ||
                                    controller.submittingPrompt,
                                promptController: _promptController,
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
                                onCreateSession: () =>
                                    _createNewSession(controller),
                                onOpenSession: (sessionId) {
                                  unawaited(
                                    _selectSessionInPlace(
                                      controller,
                                      sessionId,
                                      compact: compact,
                                    ),
                                  );
                                },
                                onShareSession:
                                    controller.selectedSession == null
                                    ? null
                                    : () => _shareSelectedSession(controller),
                                onUnshareSession:
                                    controller.selectedSession == null
                                    ? null
                                    : () => _unshareSelectedSession(controller),
                                onSummarizeSession:
                                    controller.selectedSession == null
                                    ? null
                                    : () =>
                                          _summarizeSelectedSession(controller),
                                onToggleTerminal: _toggleTerminalPanel,
                                terminalPanelOpen: _terminalPanelOpen,
                                terminalPanel: _ptyService == null
                                    ? null
                                    : PtyTerminalPanel(
                                        profile: _profile!,
                                        directory: widget.directory,
                                        service: _ptyService!,
                                        sessions: _ptySessions,
                                        activeSessionId: _activePtyId,
                                        loading: _loadingPtySessions,
                                        creating: _creatingPtySession,
                                        error: _terminalError,
                                        onSelectSession: (ptyId) {
                                          setState(() {
                                            _activePtyId = ptyId;
                                          });
                                        },
                                        onCreateSession: _createPtySession,
                                        onCloseSession: _closePtySession,
                                        onRetry: () => _loadPtySessions(
                                          epoch: _terminalEpoch,
                                          profile: _profile!,
                                        ),
                                        onTitleChanged: _renamePtySession,
                                        onSessionMissing:
                                            _removeMissingPtySession,
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
    required this.mainSession,
    required this.status,
    required this.terminalOpen,
    required this.onBackHome,
    required this.onToggleTerminal,
    this.onOpenDrawer,
    this.onBackToMainSession,
    this.onRename,
    this.onFork,
    this.onShare,
    this.onDelete,
  });

  final bool compact;
  final ServerProfile? profile;
  final ProjectTarget? project;
  final SessionSummary? session;
  final SessionSummary? mainSession;
  final SessionStatusSummary? status;
  final bool terminalOpen;
  final VoidCallback onBackHome;
  final VoidCallback onToggleTerminal;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onBackToMainSession;
  final VoidCallback? onRename;
  final VoidCallback? onFork;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final rootSession = mainSession;
    final canReturnToMain =
        session != null &&
        rootSession != null &&
        session!.id != rootSession.id &&
        onBackToMainSession != null;
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
              if (canReturnToMain)
                IconButton(
                  key: const ValueKey<String>(
                    'workspace-back-to-main-session-button',
                  ),
                  tooltip: 'Back to main session',
                  onPressed: onBackToMainSession,
                  icon: const Icon(
                    Icons.subdirectory_arrow_left_rounded,
                    size: 18,
                  ),
                  splashRadius: 18,
                ),
              Expanded(
                child: Text(
                  session?.title.isNotEmpty == true
                      ? session!.title
                      : (project?.label ?? 'Session'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
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
                    case 'main':
                      onBackToMainSession?.call();
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
                  if (canReturnToMain)
                    const PopupMenuItem<String>(
                      value: 'main',
                      child: Text('Back to Main Session'),
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
                  if (canReturnToMain)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: InkWell(
                        key: const ValueKey<String>(
                          'workspace-back-to-main-session-link',
                        ),
                        onTap: onBackToMainSession,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.subdirectory_arrow_left_rounded,
                                size: 14,
                                color: surfaces.muted,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Flexible(
                                child: Text(
                                  rootSession.title.isNotEmpty
                                      ? rootSession.title
                                      : 'Main session',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: surfaces.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                  case 'main':
                    onBackToMainSession?.call();
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
                if (canReturnToMain)
                  const PopupMenuItem<String>(
                    value: 'main',
                    child: Text('Back to Main Session'),
                  ),
                if (canReturnToMain) const PopupMenuDivider(),
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

SessionSummary? _sessionById(List<SessionSummary> sessions, String? sessionId) {
  if (sessionId == null || sessionId.isEmpty) {
    return null;
  }
  for (final session in sessions) {
    if (session.id == sessionId) {
      return session;
    }
  }
  return null;
}

SessionSummary? _rootSessionFor(
  List<SessionSummary> sessions,
  SessionSummary? session,
) {
  if (session == null) {
    return null;
  }

  var current = session;
  final seen = <String>{current.id};
  while (current.parentId != null && current.parentId!.isNotEmpty) {
    final parent = _sessionById(sessions, current.parentId);
    if (parent == null || !seen.add(parent.id)) {
      break;
    }
    current = parent;
  }
  return current;
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.compact,
    required this.controller,
    required this.allSessions,
    required this.submittingPrompt,
    required this.promptController,
    required this.timelineScrollController,
    required this.compactPane,
    required this.onCompactPaneChanged,
    required this.onSubmitPrompt,
    required this.onCreateSession,
    required this.onOpenSession,
    required this.onToggleTerminal,
    required this.terminalPanelOpen,
    required this.terminalPanel,
    this.onShareSession,
    this.onUnshareSession,
    this.onSummarizeSession,
  });

  final bool compact;
  final WorkspaceController controller;
  final List<SessionSummary> allSessions;
  final bool submittingPrompt;
  final TextEditingController promptController;
  final ScrollController timelineScrollController;
  final _CompactWorkspacePane compactPane;
  final ValueChanged<_CompactWorkspacePane> onCompactPaneChanged;
  final VoidCallback onSubmitPrompt;
  final Future<void> Function() onCreateSession;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onToggleTerminal;
  final bool terminalPanelOpen;
  final Widget? terminalPanel;
  final Future<void> Function()? onShareSession;
  final Future<void> Function()? onUnshareSession;
  final Future<void> Function()? onSummarizeSession;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final questionRequest = controller.currentQuestionRequest;
    final todoLive =
        (controller.selectedStatus?.type ?? 'idle') != 'idle' ||
        questionRequest != null;
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
                    currentSessionId: controller.selectedSessionId,
                    loading: controller.sessionLoading,
                    error: controller.sessionLoadError,
                    messages: controller.messages,
                    sessions: allSessions,
                    onOpenSession: onOpenSession,
                    onRetry: controller.retrySelectedSessionMessages,
                  ),
          ),
        ),
        if (controller.selectedSessionId != null)
          _SessionTodoDock(
            key: ValueKey<String>(
              'session-todo-dock-${controller.selectedSessionId}',
            ),
            sessionId: controller.selectedSessionId!,
            todos: controller.todos,
            live: todoLive,
            blocked: questionRequest != null,
            onClearStale: controller.clearTodos,
          ),
        if (questionRequest != null)
          _QuestionPromptDock(
            key: ValueKey<String>('question-dock-${questionRequest.id}'),
            request: questionRequest,
            onReply: controller.replyToQuestion,
            onReject: controller.rejectQuestion,
          )
        else
          _PromptComposer(
            controller: promptController,
            submitting: submittingPrompt,
            agents: controller.composerAgents,
            models: controller.composerModels,
            selectedAgentName: controller.selectedAgentName,
            selectedModel: controller.selectedModel,
            selectedReasoning: controller.selectedReasoning,
            reasoningValues: controller.availableReasoningValues,
            customCommands: controller.composerCommands,
            onSelectAgent: controller.selectAgent,
            onSelectModel: controller.selectModel,
            onSelectReasoning: controller.selectReasoning,
            onCreateSession: onCreateSession,
            onShareSession: onShareSession,
            onUnshareSession: onUnshareSession,
            onSummarizeSession: onSummarizeSession,
            onToggleTerminal: onToggleTerminal,
            onSelectSideTab: controller.setSideTab,
            onSubmit: onSubmitPrompt,
          ),
        if (terminalPanelOpen && terminalPanel != null) terminalPanel!,
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
    required this.currentSessionId,
    required this.loading,
    required this.error,
    required this.messages,
    required this.sessions,
    required this.onOpenSession,
    required this.onRetry,
    super.key,
  });

  final ScrollController controller;
  final String? currentSessionId;
  final bool loading;
  final String? error;
  final List<ChatMessage> messages;
  final List<SessionSummary> sessions;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final theme = Theme.of(context);
    if (loading) {
      return const _TimelineStatusCard(
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: 'Loading messages...',
        message: 'Connecting to the server and loading this session.',
      );
    }
    if (error != null) {
      return _TimelineStatusCard(
        icon: Icon(
          Icons.wifi_tethering_error_rounded,
          color: theme.colorScheme.error,
          size: 22,
        ),
        title: 'Couldn\'t load this session',
        message: error!,
        action: OutlinedButton(
          onPressed: () => unawaited(onRetry()),
          child: const Text('Retry'),
        ),
      );
    }
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.',
          style: theme.textTheme.bodyMedium?.copyWith(color: surfaces.muted),
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
                child: _TimelineMessage(
                  currentSessionId: currentSessionId,
                  message: message,
                  sessions: sessions,
                  onOpenSession: onOpenSession,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimelineStatusCard extends StatelessWidget {
  const _TimelineStatusCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: surfaces.panelMuted,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                icon,
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: surfaces.muted,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
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

class _PromptComposer extends StatefulWidget {
  const _PromptComposer({
    required this.controller,
    required this.submitting,
    required this.agents,
    required this.models,
    required this.selectedAgentName,
    required this.selectedModel,
    required this.selectedReasoning,
    required this.reasoningValues,
    required this.customCommands,
    required this.onSelectAgent,
    required this.onSelectModel,
    required this.onSelectReasoning,
    required this.onCreateSession,
    required this.onToggleTerminal,
    required this.onSelectSideTab,
    required this.onSubmit,
    this.onShareSession,
    this.onUnshareSession,
    this.onSummarizeSession,
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
  final List<CommandDefinition> customCommands;
  final ValueChanged<String?> onSelectAgent;
  final ValueChanged<String?> onSelectModel;
  final ValueChanged<String?> onSelectReasoning;
  final Future<void> Function() onCreateSession;
  final Future<void> Function() onToggleTerminal;
  final ValueChanged<WorkspaceSideTab> onSelectSideTab;
  final VoidCallback onSubmit;
  final Future<void> Function()? onShareSession;
  final Future<void> Function()? onUnshareSession;
  final Future<void> Function()? onSummarizeSession;

  @override
  State<_PromptComposer> createState() => _PromptComposerState();
}

class _PromptComposerState extends State<_PromptComposer> {
  final FocusNode _focusNode = FocusNode();

  bool get _canSubmit => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleComposerChanged);
  }

  @override
  void didUpdateWidget(covariant _PromptComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleComposerChanged);
      widget.controller.addListener(_handleComposerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleComposerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String? get _slashQuery {
    final text = widget.controller.text;
    final firstLine = text.split('\n').first;
    if (!firstLine.startsWith('/')) {
      return null;
    }
    final body = firstLine.substring(1);
    if (body.contains(RegExp(r'\s'))) {
      return null;
    }
    return body;
  }

  List<_ComposerSlashCommand> get _slashCommands {
    final commands = <_ComposerSlashCommand>[
      const _ComposerSlashCommand(
        id: 'builtin.new',
        trigger: 'new',
        title: 'New session',
        description: 'Create a new session',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.newSession,
      ),
      if (widget.onShareSession != null)
        const _ComposerSlashCommand(
          id: 'builtin.share',
          trigger: 'share',
          title: 'Share session',
          description: 'Share this session',
          type: _ComposerSlashCommandType.builtin,
          action: _ComposerBuiltinSlashAction.shareSession,
        ),
      if (widget.onUnshareSession != null)
        const _ComposerSlashCommand(
          id: 'builtin.unshare',
          trigger: 'unshare',
          title: 'Unshare session',
          description: 'Remove the current share link',
          type: _ComposerSlashCommandType.builtin,
          action: _ComposerBuiltinSlashAction.unshareSession,
        ),
      if (widget.onSummarizeSession != null)
        const _ComposerSlashCommand(
          id: 'builtin.compact',
          trigger: 'compact',
          title: 'Compact session',
          description: 'Summarize the session to reduce context size',
          type: _ComposerSlashCommandType.builtin,
          action: _ComposerBuiltinSlashAction.compactSession,
        ),
      if (widget.models.isNotEmpty)
        const _ComposerSlashCommand(
          id: 'builtin.model',
          trigger: 'model',
          title: 'Switch model',
          description: 'Select a different model',
          type: _ComposerSlashCommandType.builtin,
          action: _ComposerBuiltinSlashAction.modelPicker,
        ),
      if (widget.agents.isNotEmpty)
        const _ComposerSlashCommand(
          id: 'builtin.agent',
          trigger: 'agent',
          title: 'Switch agent',
          description: 'Select a different agent',
          type: _ComposerSlashCommandType.builtin,
          action: _ComposerBuiltinSlashAction.agentPicker,
        ),
      if (widget.selectedModel != null)
        const _ComposerSlashCommand(
          id: 'builtin.reasoning',
          trigger: 'reasoning',
          title: 'Adjust reasoning',
          description: 'Choose a different reasoning depth',
          type: _ComposerSlashCommandType.builtin,
          action: _ComposerBuiltinSlashAction.reasoningPicker,
        ),
      const _ComposerSlashCommand(
        id: 'builtin.terminal',
        trigger: 'terminal',
        title: 'Open terminal',
        description: 'Toggle the terminal panel',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.terminal,
      ),
      const _ComposerSlashCommand(
        id: 'builtin.review',
        trigger: 'review',
        title: 'Open review',
        description: 'Show the review panel',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.reviewTab,
      ),
      const _ComposerSlashCommand(
        id: 'builtin.files',
        trigger: 'files',
        title: 'Open files',
        description: 'Show the files panel',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.filesTab,
      ),
      const _ComposerSlashCommand(
        id: 'builtin.context',
        trigger: 'context',
        title: 'Open context',
        description: 'Show the context panel',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.contextTab,
      ),
      ...widget.customCommands.map(
        (command) => _ComposerSlashCommand(
          id: 'custom.${command.name}',
          trigger: command.name,
          title: command.name,
          description: command.description,
          type: _ComposerSlashCommandType.custom,
          source: command.source,
        ),
      ),
    ];
    return commands;
  }

  List<_ComposerSlashCommand> get _filteredSlashCommands {
    final query = _slashQuery;
    if (query == null) {
      return const <_ComposerSlashCommand>[];
    }
    final normalized = query.toLowerCase();
    if (normalized.isEmpty) {
      return _slashCommands;
    }

    final exact = <_ComposerSlashCommand>[];
    final prefix = <_ComposerSlashCommand>[];
    final partial = <_ComposerSlashCommand>[];
    for (final command in _slashCommands) {
      final trigger = command.trigger.toLowerCase();
      final title = command.title.toLowerCase();
      final description = command.description?.toLowerCase() ?? '';
      if (trigger == normalized) {
        exact.add(command);
        continue;
      }
      if (trigger.startsWith(normalized)) {
        prefix.add(command);
        continue;
      }
      if (trigger.contains(normalized) ||
          title.contains(normalized) ||
          description.contains(normalized)) {
        partial.add(command);
      }
    }
    return <_ComposerSlashCommand>[...exact, ...prefix, ...partial];
  }

  _ComposerSlashCommand? get _exactBuiltinSlashCommand {
    final query = _slashQuery?.trim();
    if (query == null || query.isEmpty) {
      return null;
    }
    for (final command in _slashCommands) {
      if (command.type == _ComposerSlashCommandType.builtin &&
          command.trigger == query) {
        return command;
      }
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (widget.submitting || !_canSubmit) {
      return;
    }
    final builtin = _exactBuiltinSlashCommand;
    if (builtin != null) {
      await _selectSlashCommand(builtin);
      return;
    }
    widget.onSubmit();
  }

  Future<void> _selectSlashCommand(_ComposerSlashCommand command) async {
    if (command.type == _ComposerSlashCommandType.custom) {
      _applyCustomSlashCommand(command.trigger);
      return;
    }
    await _runBuiltinSlashCommand(command.action!);
  }

  void _applyCustomSlashCommand(String trigger) {
    final text = '/$trigger ';
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  void _clearComposer() {
    widget.controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  Future<void> _runBuiltinSlashCommand(
    _ComposerBuiltinSlashAction action,
  ) async {
    _clearComposer();
    switch (action) {
      case _ComposerBuiltinSlashAction.newSession:
        await widget.onCreateSession();
        break;
      case _ComposerBuiltinSlashAction.shareSession:
        final callback = widget.onShareSession;
        if (callback != null) {
          await callback();
        }
        break;
      case _ComposerBuiltinSlashAction.unshareSession:
        final callback = widget.onUnshareSession;
        if (callback != null) {
          await callback();
        }
        break;
      case _ComposerBuiltinSlashAction.compactSession:
        final callback = widget.onSummarizeSession;
        if (callback != null) {
          await callback();
        }
        break;
      case _ComposerBuiltinSlashAction.modelPicker:
        final selection = await _showModelPicker(context);
        if (selection != null) {
          widget.onSelectModel(selection);
        }
        break;
      case _ComposerBuiltinSlashAction.agentPicker:
        final selection = await _showAgentPicker(context);
        if (selection != null) {
          widget.onSelectAgent(selection);
        }
        break;
      case _ComposerBuiltinSlashAction.reasoningPicker:
        final selection = await _showReasoningPicker(context);
        if (selection != null) {
          widget.onSelectReasoning(
            selection == _PromptComposer._defaultReasoningSentinel
                ? null
                : selection,
          );
        }
        break;
      case _ComposerBuiltinSlashAction.terminal:
        await widget.onToggleTerminal();
        break;
      case _ComposerBuiltinSlashAction.reviewTab:
        widget.onSelectSideTab(WorkspaceSideTab.review);
        break;
      case _ComposerBuiltinSlashAction.filesTab:
        widget.onSelectSideTab(WorkspaceSideTab.files);
        break;
      case _ComposerBuiltinSlashAction.contextTab:
        widget.onSelectSideTab(WorkspaceSideTab.context);
        break;
    }
    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final reasoningLabel = _reasoningLabel(widget.selectedReasoning);
    final slashCommands = _filteredSlashCommands;
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
                if (slashCommands.isNotEmpty) ...<Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: DecoratedBox(
                      key: const ValueKey<String>('composer-slash-popover'),
                      decoration: BoxDecoration(
                        color: surfaces.panelMuted,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: surfaces.lineSoft),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: slashCommands.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final command = slashCommands[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey<String>(
                                'composer-slash-option-${command.id}',
                              ),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _selectSlashCommand(command),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? surfaces.panel
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Row(
                                        children: <Widget>[
                                          Text(
                                            '/${command.trigger}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          if ((command.description ?? '')
                                              .trim()
                                              .isNotEmpty) ...<Widget>[
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Expanded(
                                              child: Text(
                                                command.description!,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: surfaces.muted,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (command.type ==
                                            _ComposerSlashCommandType.custom &&
                                        command.source != null &&
                                        command.source !=
                                            'command') ...<Widget>[
                                      const SizedBox(width: AppSpacing.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: surfaces.panel,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          command.source!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: surfaces.muted),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextField(
                  key: const ValueKey<String>('composer-text-field'),
                  controller: widget.controller,
                  focusNode: _focusNode,
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
                  onSubmitted: (_) => _handleSubmit(),
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
                              label: widget.selectedAgentName ?? 'Agent',
                              onTap: widget.agents.isEmpty
                                  ? null
                                  : () async {
                                      final selection = await _showAgentPicker(
                                        context,
                                      );
                                      if (selection != null) {
                                        widget.onSelectAgent(selection);
                                      }
                                    },
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _ComposerSelectionPill(
                              label: widget.selectedModel?.name ?? 'Model',
                              onTap: widget.models.isEmpty
                                  ? null
                                  : () async {
                                      final selection = await _showModelPicker(
                                        context,
                                      );
                                      if (selection != null) {
                                        widget.onSelectModel(selection);
                                      }
                                    },
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _ComposerSelectionPill(
                              label: reasoningLabel,
                              onTap: widget.selectedModel == null
                                  ? null
                                  : () async {
                                      final selection =
                                          await _showReasoningPicker(context);
                                      if (selection == null) {
                                        return;
                                      }
                                      widget.onSelectReasoning(
                                        selection ==
                                                _PromptComposer
                                                    ._defaultReasoningSentinel
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
                      key: const ValueKey<String>('composer-submit-button'),
                      icon: Icons.arrow_upward_rounded,
                      onTap: widget.submitting || !_canSubmit
                          ? null
                          : _handleSubmit,
                      filled: true,
                      busy: widget.submitting,
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
        items: widget.agents
            .map(
              (agent) => _AgentChoice(
                value: agent.name,
                title: agent.name,
                subtitle: agent.description,
              ),
            )
            .toList(growable: false),
        selectedValue: widget.selectedAgentName,
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
    for (final model in widget.models) {
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
            selectedValue: widget.selectedModel?.key,
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
        value: _PromptComposer._defaultReasoningSentinel,
        label: 'Default',
      ),
      ...widget.reasoningValues.map(
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
        selectedValue:
            widget.selectedReasoning ??
            _PromptComposer._defaultReasoningSentinel,
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

enum _ComposerSlashCommandType { builtin, custom }

enum _ComposerBuiltinSlashAction {
  newSession,
  shareSession,
  unshareSession,
  compactSession,
  modelPicker,
  agentPicker,
  reasoningPicker,
  terminal,
  reviewTab,
  filesTab,
  contextTab,
}

class _ComposerSlashCommand {
  const _ComposerSlashCommand({
    required this.id,
    required this.trigger,
    required this.title,
    required this.type,
    this.description,
    this.source,
    this.action,
  });

  final String id;
  final String trigger;
  final String title;
  final String? description;
  final _ComposerSlashCommandType type;
  final String? source;
  final _ComposerBuiltinSlashAction? action;
}

class _QuestionPromptDock extends StatefulWidget {
  const _QuestionPromptDock({
    required this.request,
    required this.onReply,
    required this.onReject,
    super.key,
  });

  final QuestionRequestSummary request;
  final Future<void> Function(String requestId, List<List<String>> answers)
  onReply;
  final Future<void> Function(String requestId) onReject;

  @override
  State<_QuestionPromptDock> createState() => _QuestionPromptDockState();
}

class _QuestionPromptDockState extends State<_QuestionPromptDock> {
  int _tab = 0;
  bool _submitting = false;
  List<List<String>> _answers = const <List<String>>[];
  List<String> _customValues = const <String>[];
  List<bool> _customEnabled = const <bool>[];
  List<TextEditingController> _customControllers =
      const <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _resetState();
  }

  @override
  void didUpdateWidget(covariant _QuestionPromptDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.questions.length != widget.request.questions.length) {
      _resetState();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _customControllers) {
      controller.dispose();
    }
    _customControllers = const <TextEditingController>[];
  }

  void _resetState() {
    _disposeControllers();
    final count = widget.request.questions.length;
    _tab = 0;
    _submitting = false;
    _answers = List<List<String>>.generate(
      count,
      (_) => <String>[],
      growable: false,
    );
    _customValues = List<String>.filled(count, '', growable: false);
    _customEnabled = List<bool>.filled(count, false, growable: false);
    _customControllers = List<TextEditingController>.generate(
      count,
      (_) => TextEditingController(),
      growable: false,
    );
  }

  QuestionPromptSummary? get _question {
    if (widget.request.questions.isEmpty) {
      return null;
    }
    final index = _tab.clamp(0, widget.request.questions.length - 1);
    return widget.request.questions[index];
  }

  bool get _isLastQuestion => _tab >= widget.request.questions.length - 1;

  void _replaceAnswersForTab(List<String> values) {
    final next = _answers
        .map((item) => List<String>.from(item))
        .toList(growable: false);
    next[_tab] = values;
    setState(() {
      _answers = next;
    });
  }

  void _selectOption(String label) {
    final question = _question;
    if (question == null || _submitting) {
      return;
    }

    if (question.multiple) {
      final current = List<String>.from(_answers[_tab]);
      if (current.contains(label)) {
        current.removeWhere((item) => item == label);
      } else {
        current.add(label);
      }
      _replaceAnswersForTab(current);
      return;
    }

    final nextEnabled = List<bool>.from(_customEnabled);
    nextEnabled[_tab] = false;
    setState(() {
      _customEnabled = nextEnabled;
      _answers = _answers
          .asMap()
          .entries
          .map(
            (entry) => entry.key == _tab
                ? <String>[label]
                : List<String>.from(entry.value),
          )
          .toList(growable: false);
    });
  }

  void _toggleCustom() {
    final question = _question;
    if (question == null || _submitting) {
      return;
    }

    final nextEnabled = List<bool>.from(_customEnabled);
    final currentValue = _customControllers[_tab].text.trim();
    if (!question.multiple) {
      nextEnabled[_tab] = true;
      setState(() {
        _customEnabled = nextEnabled;
        _answers = _answers
            .asMap()
            .entries
            .map(
              (entry) => entry.key == _tab
                  ? (currentValue.isEmpty ? <String>[] : <String>[currentValue])
                  : List<String>.from(entry.value),
            )
            .toList(growable: false);
      });
      return;
    }

    final nextSelected = !nextEnabled[_tab];
    nextEnabled[_tab] = nextSelected;
    final previousValue = _customValues[_tab].trim();
    final current = _answers[_tab]
        .where((item) => item.trim() != previousValue)
        .toList(growable: true);
    if (nextSelected && currentValue.isNotEmpty) {
      current.add(currentValue);
    }
    setState(() {
      _customEnabled = nextEnabled;
      _answers = _answers
          .asMap()
          .entries
          .map(
            (entry) =>
                entry.key == _tab ? current : List<String>.from(entry.value),
          )
          .toList(growable: false);
    });
  }

  void _updateCustomValue(String value) {
    final question = _question;
    if (question == null) {
      return;
    }

    final previousValue = _customValues[_tab].trim();
    final nextValues = List<String>.from(_customValues);
    nextValues[_tab] = value;

    if (!_customEnabled[_tab]) {
      setState(() {
        _customValues = nextValues;
      });
      return;
    }

    final trimmed = value.trim();
    if (question.multiple) {
      final current = _answers[_tab]
          .where((item) => item.trim() != previousValue)
          .toList(growable: true);
      if (trimmed.isNotEmpty && !current.contains(trimmed)) {
        current.add(trimmed);
      }
      setState(() {
        _customValues = nextValues;
        _answers = _answers
            .asMap()
            .entries
            .map(
              (entry) =>
                  entry.key == _tab ? current : List<String>.from(entry.value),
            )
            .toList(growable: false);
      });
      return;
    }

    setState(() {
      _customValues = nextValues;
      _answers = _answers
          .asMap()
          .entries
          .map(
            (entry) => entry.key == _tab
                ? (trimmed.isEmpty ? <String>[] : <String>[trimmed])
                : List<String>.from(entry.value),
          )
          .toList(growable: false);
    });
  }

  Future<void> _submitAnswers() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      await widget.onReply(
        widget.request.id,
        _answers
            .map((item) => List<String>.unmodifiable(item))
            .toList(growable: false),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _dismiss() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      await widget.onReject(widget.request.id);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final question = _question;
    if (question == null) {
      return const SizedBox.shrink();
    }

    final total = widget.request.questions.length;
    final summary = '${_tab + 1} of $total questions';
    final customValue = _customControllers[_tab].text.trim();
    final customSelected = _customEnabled[_tab];

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
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        summary,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...List<Widget>.generate(total, (index) {
                      final answered = _answers[index].isNotEmpty;
                      final active = index == _tab;
                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : AppSpacing.xs,
                        ),
                        child: InkWell(
                          onTap: _submitting
                              ? null
                              : () => setState(() => _tab = index),
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 4,
                            decoration: BoxDecoration(
                              color: active
                                  ? theme.colorScheme.onSurface
                                  : answered
                                  ? theme.colorScheme.primary
                                  : surfaces.lineSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (question.header.trim().isNotEmpty) ...<Widget>[
                          Text(
                            question.header,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: surfaces.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          question.question,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          question.multiple
                              ? 'Select one or more answers.'
                              : 'Select one answer.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: surfaces.muted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final option in question.options) ...<Widget>[
                          _QuestionChoiceTile(
                            title: option.label,
                            subtitle: option.description,
                            selected: _answers[_tab].contains(option.label),
                            multiple: question.multiple,
                            onTap: () => _selectOption(option.label),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        _QuestionChoiceTile(
                          title: 'Type your own answer',
                          subtitle: customValue.isEmpty
                              ? 'Type your answer...'
                              : customValue,
                          selected: customSelected,
                          multiple: question.multiple,
                          onTap: _toggleCustom,
                        ),
                        if (customSelected ||
                            customValue.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _customControllers[_tab],
                            onChanged: _updateCustomValue,
                            enabled: !_submitting,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Type your answer...',
                              filled: true,
                              fillColor: surfaces.panelMuted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: surfaces.lineSoft,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: surfaces.lineSoft,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: _submitting ? null : _dismiss,
                      child: const Text('Dismiss'),
                    ),
                    const Spacer(),
                    if (_tab > 0) ...<Widget>[
                      OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _tab -= 1),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    FilledButton(
                      key: const ValueKey<String>('question-dock-submit'),
                      onPressed: _submitting
                          ? null
                          : _isLastQuestion
                          ? _submitAnswers
                          : () => setState(() => _tab += 1),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLastQuestion ? 'Submit' : 'Next'),
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

class _QuestionChoiceTile extends StatelessWidget {
  const _QuestionChoiceTile({
    required this.title,
    required this.selected,
    required this.multiple,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final borderColor = selected
        ? theme.colorScheme.primary
        : surfaces.lineSoft;
    final icon = multiple
        ? (selected
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded)
        : (selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? surfaces.panelRaised : surfaces.panelMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: borderColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null &&
                        subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: surfaces.muted,
                          height: 1.45,
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

enum _TodoDockState { hide, clear, open, close }

_TodoDockState _todoDockState({
  required int count,
  required bool done,
  required bool live,
}) {
  if (count == 0) {
    return _TodoDockState.hide;
  }
  if (!live) {
    return _TodoDockState.clear;
  }
  if (!done) {
    return _TodoDockState.open;
  }
  return _TodoDockState.close;
}

class _SessionTodoDock extends StatefulWidget {
  const _SessionTodoDock({
    required this.sessionId,
    required this.todos,
    required this.live,
    required this.blocked,
    required this.onClearStale,
    super.key,
  });

  final String sessionId;
  final List<TodoItem> todos;
  final bool live;
  final bool blocked;
  final VoidCallback onClearStale;

  @override
  State<_SessionTodoDock> createState() => _SessionTodoDockState();
}

class _SessionTodoDockState extends State<_SessionTodoDock> {
  static const Duration _closeDelay = Duration(milliseconds: 400);

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  Timer? _closeTimer;
  bool _visible = false;
  bool _closing = false;
  bool _collapsed = false;
  bool _stuck = false;
  bool _clearQueued = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _syncState(initial: true);
  }

  @override
  void didUpdateWidget(covariant _SessionTodoDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _collapsed = false;
      _stuck = false;
      _clearQueued = false;
      _cancelCloseTimer();
    }
    _syncState();
  }

  @override
  void dispose() {
    _cancelCloseTimer();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  bool get _done =>
      widget.todos.isNotEmpty &&
      widget.todos.every(
        (todo) => todo.status == 'completed' || todo.status == 'cancelled',
      );

  int get _doneCount =>
      widget.todos.where((todo) => todo.status == 'completed').length;

  TodoItem? get _activeTodo {
    for (final todo in widget.todos) {
      if (todo.status == 'in_progress') {
        return todo;
      }
    }
    for (final todo in widget.todos) {
      if (todo.status == 'pending') {
        return todo;
      }
    }
    for (final todo in widget.todos.reversed) {
      if (todo.status == 'completed') {
        return todo;
      }
    }
    return widget.todos.isEmpty ? null : widget.todos.first;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final stuck = _scrollController.offset > 0;
    if (stuck == _stuck) {
      return;
    }
    setState(() {
      _stuck = stuck;
    });
  }

  void _syncState({bool initial = false}) {
    final next = _todoDockState(
      count: widget.todos.length,
      done: _done,
      live: widget.live,
    );

    if (next == _TodoDockState.hide) {
      _cancelCloseTimer();
      if (_visible || _closing) {
        setState(() {
          _visible = false;
          _closing = false;
        });
      }
      return;
    }

    if (next == _TodoDockState.clear) {
      _cancelCloseTimer();
      if (_visible || _closing) {
        setState(() {
          _visible = false;
          _closing = false;
        });
      }
      _scheduleClear();
      return;
    }

    if (next == _TodoDockState.open) {
      _cancelCloseTimer();
      if (!_visible || _closing) {
        setState(() {
          _visible = true;
          _closing = false;
        });
      }
      if (!_collapsed) {
        _scheduleEnsureVisible();
      }
      return;
    }

    if (!_visible || !_closing) {
      setState(() {
        _visible = true;
        _closing = true;
      });
    }
    _scheduleClose();
    if (initial && !_collapsed) {
      _scheduleEnsureVisible();
    }
  }

  void _scheduleClear() {
    if (_clearQueued || widget.todos.isEmpty) {
      return;
    }
    _clearQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearQueued = false;
      if (!mounted) {
        return;
      }
      widget.onClearStale();
    });
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    if (_closeTimer != null) {
      return;
    }
    _closeTimer = Timer(_closeDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = false;
        _closing = false;
      });
      _closeTimer = null;
    });
  }

  void _scheduleEnsureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeTodo = _activeTodo;
      if (!mounted ||
          _collapsed ||
          !_visible ||
          widget.blocked ||
          activeTodo == null) {
        return;
      }
      final key = _itemKeys[activeTodo.id];
      final context = key?.currentContext;
      final renderObject = context?.findRenderObject();
      if (context == null ||
          renderObject is! RenderBox ||
          !renderObject.hasSize ||
          !_scrollController.hasClients) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.12,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  GlobalKey _keyForTodo(TodoItem todo) {
    return _itemKeys.putIfAbsent(
      todo.id,
      () => GlobalKey(debugLabel: 'todo-${widget.sessionId}-${todo.id}'),
    );
  }

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
    });
    if (!_collapsed) {
      _scheduleEnsureVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final progressLabel =
        '$_doneCount of ${widget.todos.length} todos completed';
    final preview = _activeTodo?.content.trim() ?? '';
    final shouldRender = _visible && widget.todos.isNotEmpty && !widget.blocked;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: !shouldRender
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaces.panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: Column(
                      children: <Widget>[
                        InkWell(
                          onTap: _toggleCollapsed,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                            bottom: Radius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  progressLabel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_collapsed &&
                                    preview.isNotEmpty) ...<Widget>[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: surfaces.muted,
                                            height: 1.45,
                                          ),
                                    ),
                                  ),
                                ] else
                                  const Spacer(),
                                IconButton(
                                  key: const ValueKey<String>(
                                    'session-todo-toggle-button',
                                  ),
                                  onPressed: _toggleCollapsed,
                                  icon: AnimatedRotation(
                                    turns: _collapsed ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: surfaces.muted,
                                    ),
                                  ),
                                  tooltip: _collapsed ? 'Expand' : 'Collapse',
                                ),
                              ],
                            ),
                          ),
                        ),
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: _collapsed
                                ? const SizedBox.shrink()
                                : Stack(
                                    children: <Widget>[
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 260,
                                        ),
                                        child: SingleChildScrollView(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.md,
                                            0,
                                            AppSpacing.md,
                                            AppSpacing.xl,
                                          ),
                                          child: Column(
                                            key: const ValueKey<String>(
                                              'session-todo-list',
                                            ),
                                            children: widget.todos
                                                .map(
                                                  (todo) => Padding(
                                                    key: _keyForTodo(todo),
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: AppSpacing.sm,
                                                        ),
                                                    child: _TodoDockRow(
                                                      todo: todo,
                                                    ),
                                                  ),
                                                )
                                                .toList(growable: false),
                                          ),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          opacity: _stuck ? 1 : 0,
                                          child: Container(
                                            height: 16,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: <Color>[
                                                  surfaces.panel,
                                                  surfaces.panel.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
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
                ),
              ),
            ),
    );
  }
}

class _TodoDockRow extends StatelessWidget {
  const _TodoDockRow({required this.todo});

  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final completed = todo.status == 'completed' || todo.status == 'cancelled';
    final pending = todo.status == 'pending';
    final color = completed ? surfaces.muted : theme.colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _TodoStatusIcon(status: todo.status),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            todo.content,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: color,
              height: 1.45,
              decoration: completed
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationColor: surfaces.muted,
              decorationThickness: 1.6,
              fontWeight: pending ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoStatusIcon extends StatelessWidget {
  const _TodoStatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    final (icon, color) = switch (status) {
      'completed' => (
        Icons.check_box_rounded,
        theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
      'in_progress' => (
        Icons.indeterminate_check_box_rounded,
        theme.colorScheme.primary,
      ),
      'cancelled' => (
        Icons.disabled_by_default_rounded,
        surfaces.muted.withValues(alpha: 0.8),
      ),
      _ => (
        Icons.check_box_outline_blank_rounded,
        surfaces.muted.withValues(alpha: 0.7),
      ),
    };

    return Icon(icon, size: 18, color: color);
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

class _TimelineMessage extends StatelessWidget {
  const _TimelineMessage({
    required this.currentSessionId,
    required this.message,
    required this.sessions,
    required this.onOpenSession,
  });

  final String? currentSessionId;
  final ChatMessage message;
  final List<SessionSummary> sessions;
  final ValueChanged<String> onOpenSession;

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
      children: [
        for (final part in message.parts.where(_shouldRenderTimelinePart))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _TimelinePart(
              currentSessionId: currentSessionId,
              part: part,
              sessions: sessions,
              shimmerActive: _activityPartShimmerActive(
                part,
                messageIsActive: _messageIsActive(message),
              ),
              onOpenSession: onOpenSession,
            ),
          ),
      ],
    );
  }
}

class _TimelinePart extends StatelessWidget {
  const _TimelinePart({
    required this.currentSessionId,
    required this.part,
    required this.sessions,
    required this.shimmerActive,
    required this.onOpenSession,
  });

  final String? currentSessionId;
  final ChatPart part;
  final List<SessionSummary> sessions;
  final bool shimmerActive;
  final ValueChanged<String> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final body = _partText(part);
    final linkedSession = _partLinkedSession(
      part,
      sessions: sessions,
      currentSessionId: currentSessionId,
      fallbackSummary: _partSummary(part, body),
    );
    if (_isToolLikePart(part)) {
      return _TimelineActivityPart(
        key: ValueKey<String>('timeline-activity-${part.id}'),
        shimmerKey: ValueKey<String>('timeline-activity-shimmer-${part.id}'),
        title: _partTitle(part),
        summary: linkedSession?.label ?? _partSummary(part, body),
        body: body,
        shimmerActive: shimmerActive,
        summaryTapKey: linkedSession == null
            ? null
            : ValueKey<String>('timeline-activity-link-${part.id}'),
        onSummaryTap: linkedSession == null
            ? null
            : () => onOpenSession(linkedSession.sessionId),
      );
    }
    return _StructuredTextBlock(text: body);
  }
}

class _TimelineActivityPart extends StatefulWidget {
  const _TimelineActivityPart({
    required this.title,
    required this.summary,
    required this.body,
    required this.shimmerActive,
    this.summaryTapKey,
    this.onSummaryTap,
    this.shimmerKey,
    super.key,
  });

  final String title;
  final String summary;
  final String body;
  final bool shimmerActive;
  final Key? summaryTapKey;
  final VoidCallback? onSummaryTap;
  final Key? shimmerKey;

  @override
  State<_TimelineActivityPart> createState() => _TimelineActivityPartState();
}

class _TimelineActivityPartState extends State<_TimelineActivityPart> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final canExpand = widget.body.trim().isNotEmpty;
    final hasLinkedSummary =
        widget.onSummaryTap != null && widget.summary.trim().isNotEmpty;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final summaryStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.6,
      color: surfaces.muted,
    );
    final summaryLinkStyle = summaryStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.9),
    );

    Widget buildTitleOnly() {
      final titleText = _ShimmeringRichText(
        key: widget.shimmerKey,
        active: widget.shimmerActive,
        text: TextSpan(text: widget.title, style: titleStyle),
      );
      if (!canExpand) {
        return titleText;
      }
      return InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: titleText,
        ),
      );
    }

    Widget buildHeaderText() {
      if (!hasLinkedSummary) {
        return _ShimmeringRichText(
          key: widget.shimmerKey,
          active: widget.shimmerActive,
          text: TextSpan(
            children: <InlineSpan>[
              TextSpan(text: widget.title, style: titleStyle),
              if (widget.summary.isNotEmpty)
                TextSpan(text: ' ${widget.summary}', style: summaryStyle),
            ],
          ),
        );
      }

      return Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          buildTitleOnly(),
          InkWell(
            key: widget.summaryTapKey,
            onTap: widget.onSummaryTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(widget.summary, style: summaryLinkStyle),
            ),
          ),
        ],
      );
    }

    final headerContent = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: buildHeaderText()),
          if (canExpand) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            if (hasLinkedSummary)
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: surfaces.muted,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: surfaces.muted,
                ),
              ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: hasLinkedSummary
              ? headerContent
              : InkWell(
                  onTap: canExpand
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: headerContent,
                ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: !_expanded || !canExpand
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      top: AppSpacing.xs,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: surfaces.panelMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: _StructuredTextBlock(text: widget.body),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ShimmeringRichText extends StatefulWidget {
  const _ShimmeringRichText({
    required this.text,
    required this.active,
    super.key,
  });

  final InlineSpan text;
  final bool active;

  @override
  State<_ShimmeringRichText> createState() => _ShimmeringRichTextState();
}

class _ShimmeringRichTextState extends State<_ShimmeringRichText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ShimmeringRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = Text.rich(widget.text);
    if (!widget.active) {
      return child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            final start = (width * 2.4 * _controller.value) - width * 1.2;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.transparent,
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.78),
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ],
              stops: const <double>[0, 0.35, 0.5, 0.65, 1],
            ).createShader(
              Rect.fromLTWH(
                start,
                0,
                width * 2.2,
                bounds.height <= 0 ? 1 : bounds.height,
              ),
            );
          },
          child: child,
        );
      },
    );
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

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onTap,
    super.key,
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
    final enabled = onTap != null || busy;
    final color = filled
        ? enabled
              ? Theme.of(context).colorScheme.primary
              : surfaces.panelRaised
        : surfaces.panelRaised;
    final foreground = filled
        ? enabled
              ? Theme.of(context).colorScheme.onPrimary
              : surfaces.muted
        : enabled
        ? Theme.of(context).colorScheme.onSurface
        : surfaces.muted;
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

bool _messageIsActive(ChatMessage message) {
  return message.info.role == 'assistant' && message.info.completedAt == null;
}

bool _activityPartShimmerActive(
  ChatPart part, {
  required bool messageIsActive,
}) {
  if (part.type == 'tool') {
    final status = _toolStateStatus(part);
    return status == 'pending' || status == 'running';
  }

  return switch (part.type) {
    'reasoning' || 'agent' || 'subtask' || 'step-start' => messageIsActive,
    _ => false,
  };
}

String _partText(ChatPart part) {
  if (_isQuestionToolPart(part)) {
    final formatted = _questionToolBody(part);
    if (formatted.isNotEmpty) {
      return formatted;
    }
  }

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

String _partSummary(ChatPart part, String body) {
  if (_isQuestionToolPart(part)) {
    final questions = _questionToolQuestions(part);
    final count = questions.length;
    if (count > 0) {
      final answers = _questionToolAnswers(part);
      return answers.isNotEmpty
          ? '$count answered question${count == 1 ? '' : 's'}'
          : '$count question${count == 1 ? '' : 's'}';
    }
  }

  final value = switch (part.type) {
    'reasoning' => _firstNonEmpty(<String?>[
      _markdownHeading(part.text),
      _markdownHeading(_nestedString(part.metadata, const <String>['summary'])),
      _firstMeaningfulLine(body),
    ]),
    'tool' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['state', 'title']),
      _nestedString(part.metadata, const <String>[
        'state',
        'input',
        'description',
      ]),
      _toolInputSummary(part),
      _firstMeaningfulLine(body),
    ]),
    'step-start' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['title']),
      _nestedString(part.metadata, const <String>['description']),
      _firstMeaningfulLine(body),
    ]),
    'step-finish' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['reason']),
      _nestedString(part.metadata, const <String>['message']),
      _firstMeaningfulLine(body),
    ]),
    'patch' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['summary']),
      _nestedString(part.metadata, const <String>['description']),
      _firstMeaningfulLine(body),
    ]),
    'snapshot' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['summary']),
      _firstMeaningfulLine(body),
    ]),
    'retry' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['message']),
      _nestedString(part.metadata, const <String>['reason']),
      _firstMeaningfulLine(body),
    ]),
    'agent' || 'subtask' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['description']),
      _nestedString(part.metadata, const <String>['summary']),
      _firstMeaningfulLine(body),
    ]),
    'compaction' => _firstNonEmpty(<String?>[
      _nestedString(part.metadata, const <String>['summary']),
      _firstMeaningfulLine(body),
    ]),
    _ => _firstMeaningfulLine(body),
  };
  return _truncateSummary(value ?? '');
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
    'tool' => _toolTitle(part.tool),
    'reasoning' => 'Thinking',
    'step-start' => 'Step',
    'step-finish' => 'Step Result',
    'patch' => 'Patch',
    'snapshot' => 'Snapshot',
    'retry' => 'Retry',
    'agent' => 'Agent',
    'subtask' => 'Subtask',
    'compaction' => 'Session compacted',
    _ => part.type,
  };
}

String _toolTitle(String? tool) {
  final value = tool?.trim().toLowerCase();
  return switch (value) {
    null || '' => 'Tool',
    'bash' => 'Shell',
    'question' => 'Questions',
    'task' => 'Agent',
    'apply_patch' => 'Patch',
    'websearch' => 'Web Search',
    'webfetch' => 'Web Fetch',
    'codesearch' => 'Code Search',
    'todowrite' => 'To-dos',
    final other => _titleCase(other),
  };
}

bool _shouldRenderTimelinePart(ChatPart part) {
  if (_isTodoWriteToolPart(part)) {
    return false;
  }
  if (_isQuestionToolPart(part)) {
    final status = _toolStateStatus(part);
    if (status == 'pending' || status == 'running') {
      return false;
    }
  }
  return true;
}

bool _isQuestionToolPart(ChatPart part) {
  return part.type == 'tool' && part.tool?.trim().toLowerCase() == 'question';
}

bool _isTodoWriteToolPart(ChatPart part) {
  return part.type == 'tool' && part.tool?.trim().toLowerCase() == 'todowrite';
}

String? _toolStateStatus(ChatPart part) {
  return _nestedValue(part.metadata, const <String>[
    'state',
    'status',
  ])?.toString().trim().toLowerCase();
}

List<QuestionPromptSummary> _questionToolQuestions(ChatPart part) {
  final raw =
      _nestedValue(part.metadata, const <String>[
        'state',
        'input',
        'questions',
      ]) ??
      _nestedValue(part.metadata, const <String>['input', 'questions']) ??
      _nestedValue(part.metadata, const <String>['questions']);
  if (raw is! List) {
    return const <QuestionPromptSummary>[];
  }
  return raw
      .whereType<Map>()
      .map(
        (item) => QuestionPromptSummary.fromJson(item.cast<String, Object?>()),
      )
      .toList(growable: false);
}

List<List<String>> _questionToolAnswers(ChatPart part) {
  final raw =
      _nestedValue(part.metadata, const <String>['metadata', 'answers']) ??
      _nestedValue(part.metadata, const <String>[
        'state',
        'metadata',
        'answers',
      ]) ??
      _nestedValue(part.metadata, const <String>['answers']);
  if (raw is! List) {
    return const <List<String>>[];
  }
  return raw
      .map((item) {
        if (item is List) {
          return item
              .map((answer) => answer.toString())
              .toList(growable: false);
        }
        return <String>[item.toString()];
      })
      .toList(growable: false);
}

String _questionToolBody(ChatPart part) {
  final questions = _questionToolQuestions(part);
  final answers = _questionToolAnswers(part);
  if (questions.isEmpty && answers.isEmpty) {
    return '';
  }

  final count = questions.length > answers.length
      ? questions.length
      : answers.length;
  final lines = <String>[];
  for (var index = 0; index < count; index += 1) {
    final prompt = index < questions.length
        ? questions[index].question.trim()
        : 'Question ${index + 1}';
    final answerList = index < answers.length
        ? answers[index]
        : const <String>[];
    lines.add(prompt.isEmpty ? 'Question ${index + 1}' : prompt);
    lines.add(answerList.isEmpty ? 'Unanswered' : answerList.join(', '));
  }
  return lines.join('\n\n').trim();
}

String? _toolInputSummary(ChatPart part) {
  final tool = part.tool?.trim().toLowerCase();
  return switch (tool) {
    'read' => _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'filePath',
    ]),
    'list' => _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'path',
    ]),
    'glob' || 'grep' => _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'pattern',
    ]),
    'websearch' || 'codesearch' => _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'query',
    ]),
    'webfetch' => _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'url',
    ]),
    'task' || 'bash' || 'skill' => _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'description',
    ]),
    _ => null,
  };
}

class _LinkedSessionSummary {
  const _LinkedSessionSummary({required this.sessionId, required this.label});

  final String sessionId;
  final String label;
}

_LinkedSessionSummary? _partLinkedSession(
  ChatPart part, {
  required List<SessionSummary> sessions,
  required String? currentSessionId,
  required String fallbackSummary,
}) {
  final type = part.type.trim().toLowerCase();
  final tool = part.tool?.trim().toLowerCase();
  final isChildSessionPart =
      (type == 'tool' && tool == 'task') ||
      type == 'agent' ||
      type == 'subtask';
  if (!isChildSessionPart) {
    return null;
  }

  final sessionId = _firstNonEmpty(<String?>[
    _nestedString(part.metadata, const <String>[
      'state',
      'metadata',
      'sessionId',
    ]),
    _nestedString(part.metadata, const <String>[
      'state',
      'metadata',
      'sessionID',
    ]),
    _nestedString(part.metadata, const <String>['metadata', 'sessionId']),
    _nestedString(part.metadata, const <String>['metadata', 'sessionID']),
    _nestedString(part.metadata, const <String>['sessionId']),
    _nestedString(part.metadata, const <String>['sessionID']),
  ]);
  if (sessionId == null || sessionId.isEmpty || sessionId == currentSessionId) {
    return null;
  }

  final session = _sessionById(sessions, sessionId);
  final label = _firstNonEmpty(<String?>[
    if (type == 'tool' && tool == 'task')
      _nestedString(part.metadata, const <String>[
        'state',
        'input',
        'description',
      ]),
    _nestedString(part.metadata, const <String>['description']),
    _nestedString(part.metadata, const <String>['summary']),
    fallbackSummary,
    session?.title,
    sessionId,
  ]);
  if (label == null || label.isEmpty) {
    return null;
  }

  return _LinkedSessionSummary(sessionId: sessionId, label: label);
}

Object? _nestedValue(Map<String, Object?> source, List<String> path) {
  Object? current = source;
  for (final segment in path) {
    if (current is! Map) {
      return null;
    }
    current = current[segment];
  }
  return current;
}

String? _nestedString(Map<String, Object?> source, List<String> path) {
  final value = _nestedValue(source, path)?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String? _firstMeaningfulLine(String? value) {
  if (value == null) {
    return null;
  }
  final lines = value
      .split('\n')
      .map(_cleanInlineSummary)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return lines.isEmpty ? null : lines.first;
}

String? _markdownHeading(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final markdown = value.replaceAll(RegExp(r'\r\n?'), '\n');
  final html = RegExp(
    r'<h[1-6][^>]*>([\s\S]*?)<\/h[1-6]>',
    caseSensitive: false,
  ).firstMatch(markdown);
  if (html != null) {
    final cleaned = _cleanInlineSummary(
      html.group(1)?.replaceAll(RegExp(r'<[^>]+>'), ' ') ?? '',
    );
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  final atx = RegExp(
    r'^\s{0,3}#{1,6}[ \t]+(.+?)(?:[ \t]+#+[ \t]*)?$',
    multiLine: true,
  ).firstMatch(markdown);
  if (atx != null) {
    final cleaned = _cleanInlineSummary(atx.group(1) ?? '');
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  final setext = RegExp(
    r'^([^\n]+)\n(?:=+|-+)\s*$',
    multiLine: true,
  ).firstMatch(markdown);
  if (setext != null) {
    final cleaned = _cleanInlineSummary(setext.group(1) ?? '');
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  final strong = RegExp(
    r'^\s*(?:\*\*|__)(.+?)(?:\*\*|__)\s*$',
    multiLine: true,
  ).firstMatch(markdown);
  if (strong != null) {
    final cleaned = _cleanInlineSummary(strong.group(1) ?? '');
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return null;
}

String _truncateSummary(String value, {int maxLength = 120}) {
  final cleaned = _cleanInlineSummary(value);
  if (cleaned.length <= maxLength) {
    return cleaned;
  }
  return '${cleaned.substring(0, maxLength - 1).trimRight()}…';
}

String _cleanInlineSummary(String value) {
  return value
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '')
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'[*_~]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
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
              loadingPreview: controller.loadingFilePreview,
              onSelectFile: (path) {
                unawaited(controller.selectFile(path));
              },
            ),
            WorkspaceSideTab.context => _ContextPanel(
              session: controller.selectedSession,
              messages: controller.messages,
              configSnapshot: controller.configSnapshot,
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
  const _FilesPanel({
    required this.bundle,
    required this.loadingPreview,
    required this.onSelectFile,
  });

  final FileBrowserBundle? bundle;
  final bool loadingPreview;
  final ValueChanged<String> onSelectFile;

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
              final selected = node.path == bundle.selectedPath;
              return ListTile(
                dense: true,
                selected: selected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                tileColor: selected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12)
                    : null,
                leading: Icon(
                  node.type == 'directory'
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                ),
                title: Text(node.name),
                subtitle: Text(node.path),
                onTap: () => onSelectFile(node.path),
              );
            },
          ),
        ),
        if (bundle.selectedPath != null || bundle.preview != null)
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: surfaces.lineSoft)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (bundle.selectedPath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      bundle.selectedPath!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: surfaces.muted),
                    ),
                  ),
                Expanded(
                  child: loadingPreview
                      ? const Center(child: CircularProgressIndicator())
                      : bundle.preview == null
                      ? Center(
                          child: Text(
                            'Preview unavailable for this item.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: surfaces.muted),
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            bundle.preview!.content,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ContextPanel extends StatefulWidget {
  const _ContextPanel({
    required this.session,
    required this.messages,
    required this.configSnapshot,
  });

  final SessionSummary? session;
  final List<ChatMessage> messages;
  final ConfigSnapshot? configSnapshot;

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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final decimal = NumberFormat.decimalPattern(locale);
    final currency = NumberFormat.simpleCurrency(locale: locale, name: 'USD');
    final metrics = getSessionContextMetrics(
      messages: widget.messages,
      providerCatalog: widget.configSnapshot?.providerCatalog,
    );
    final snapshot = metrics.context;
    final systemPrompt = resolveSessionSystemPrompt(
      messages: widget.messages,
      revertMessageId: widget.session?.revertMessageId,
    );
    final breakdown = snapshot == null
        ? const <SessionContextBreakdownSegment>[]
        : estimateSessionContextBreakdown(
            messages: widget.messages,
            inputTokens: snapshot.inputTokens,
            systemPrompt: systemPrompt,
          );
    final userMessages = widget.messages
        .where((message) => message.info.role == 'user')
        .length;
    final assistantMessages = widget.messages
        .where((message) => message.info.role == 'assistant')
        .length;
    final stats = <_ContextStatEntry>[
      _ContextStatEntry(
        label: 'Session',
        value: widget.session?.title.trim().isNotEmpty == true
            ? widget.session!.title.trim()
            : (widget.session?.id ?? '—'),
      ),
      _ContextStatEntry(
        label: 'Messages',
        value: decimal.format(widget.messages.length),
      ),
      _ContextStatEntry(
        label: 'Provider',
        value: snapshot?.providerLabel ?? '—',
      ),
      _ContextStatEntry(label: 'Model', value: snapshot?.modelLabel ?? '—'),
      _ContextStatEntry(
        label: 'Context Limit',
        value: _formatContextNumber(snapshot?.contextLimit, decimal),
      ),
      _ContextStatEntry(
        label: 'Total Tokens',
        value: _formatContextNumber(snapshot?.totalTokens, decimal),
      ),
      _ContextStatEntry(
        label: 'Usage',
        value: _formatContextPercent(snapshot?.usagePercent, decimal),
      ),
      _ContextStatEntry(
        label: 'Input Tokens',
        value: _formatContextNumber(snapshot?.inputTokens, decimal),
      ),
      _ContextStatEntry(
        label: 'Output Tokens',
        value: _formatContextNumber(snapshot?.outputTokens, decimal),
      ),
      _ContextStatEntry(
        label: 'Reasoning Tokens',
        value: _formatContextNumber(snapshot?.reasoningTokens, decimal),
      ),
      _ContextStatEntry(
        label: 'Cache Tokens (read/write)',
        value:
            '${_formatContextNumber(snapshot?.cacheReadTokens, decimal)} / '
            '${_formatContextNumber(snapshot?.cacheWriteTokens, decimal)}',
      ),
      _ContextStatEntry(
        label: 'User Messages',
        value: decimal.format(userMessages),
      ),
      _ContextStatEntry(
        label: 'Assistant Messages',
        value: decimal.format(assistantMessages),
      ),
      _ContextStatEntry(
        label: 'Total Cost',
        value: currency.format(metrics.totalCost),
      ),
      _ContextStatEntry(
        label: 'Session Created',
        value: _formatContextTime(widget.session?.createdAt, locale),
      ),
      _ContextStatEntry(
        label: 'Last Activity',
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = AppSpacing.lg;
                final columns = constraints.maxWidth >= 300 ? 2 : 1;
                final itemWidth = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: AppSpacing.lg,
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
            if (breakdown.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Context Breakdown',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: surfaces.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ContextBreakdownBar(segments: breakdown),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
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
                            '${_breakdownLabel(segment.key)} '
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
            ],
            if (systemPrompt != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'System Prompt',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: surfaces.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: surfaces.panelMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: surfaces.lineSoft),
                ),
                child: Text(
                  systemPrompt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.55,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Raw messages',
              style: theme.textTheme.labelMedium?.copyWith(
                color: surfaces.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.messages.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: surfaces.panelMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: surfaces.lineSoft),
                ),
                child: Text(
                  'No raw messages yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
              )
            else
              ...widget.messages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ContextRawMessageTile(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          entry.label,
          style: theme.textTheme.labelMedium?.copyWith(color: surfaces.muted),
        ),
        const SizedBox(height: 2),
        Text(
          entry.value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ContextBreakdownBar extends StatelessWidget {
  const _ContextBreakdownBar({required this.segments});

  final List<SessionContextBreakdownSegment> segments;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      key: const ValueKey<String>('context-breakdown-bar'),
      height: 14,
      decoration: BoxDecoration(
        color: surfaces.panelMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.lineSoft),
      ),
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

class _ContextRawMessageTile extends StatelessWidget {
  const _ContextRawMessageTile({
    required this.message,
    required this.timestampLabel,
  });

  final ChatMessage message;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      key: ValueKey<String>('context-raw-message-tile-${message.info.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          childrenPadding: EdgeInsets.zero,
          iconColor: surfaces.muted,
          collapsedIconColor: surfaces.muted,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: message.info.role,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: ' • ${message.info.id}',
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
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  timestampLabel,
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
                'context-raw-message-content-${message.info.id}',
              ),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: surfaces.background,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: surfaces.lineSoft),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _wrapRawMessageForDisplay(formatRawSessionMessage(message)),
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

String _breakdownLabel(SessionContextBreakdownKey key) {
  return switch (key) {
    SessionContextBreakdownKey.system => 'System',
    SessionContextBreakdownKey.user => 'User',
    SessionContextBreakdownKey.assistant => 'Assistant',
    SessionContextBreakdownKey.tool => 'Tool Calls',
    SessionContextBreakdownKey.other => 'Other',
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
