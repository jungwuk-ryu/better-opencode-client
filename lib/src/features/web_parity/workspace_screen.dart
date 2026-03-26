import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../chat/prompt_attachment_models.dart';
import '../chat/prompt_attachment_service.dart';
import '../chat/session_context_insights.dart';
import '../commands/command_service.dart';
import '../files/file_models.dart';
import '../projects/project_catalog_service.dart';
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
    this.attachmentPicker,
    this.projectCatalogService,
    super.key,
  });

  final String directory;
  final String? sessionId;
  final PtyService Function()? ptyServiceFactory;
  final Future<List<PromptAttachment>> Function()? attachmentPicker;
  final ProjectCatalogService? projectCatalogService;

  @override
  State<WebParityWorkspaceScreen> createState() =>
      _WebParityWorkspaceScreenState();
}

class _WebParityWorkspaceScreenState extends State<WebParityWorkspaceScreen> {
  static final PromptAttachmentService _attachmentService =
      PromptAttachmentService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _timelineScrollController = ScrollController(
    keepScrollOffset: false,
  );
  WorkspaceController? _controller;
  ServerProfile? _profile;
  final TextEditingController _promptController = TextEditingController();
  List<PromptAttachment> _composerAttachments = const <PromptAttachment>[];
  bool _pickingComposerAttachments = false;
  String? _lastTimelineScopeKey;
  int _lastTimelineMessageCount = 0;
  int _lastTimelineContentSignature = 0;
  bool _lastTimelineLoading = false;
  bool _timelineWasNearBottom = true;
  String? _forcedTimelineBottomScopeKey;
  String? _timelineBottomLockScopeKey;
  double? _timelineBottomLockLastExtent;
  int _timelineBottomLockStableFrames = 0;
  int _timelineBottomLockAttempts = 0;
  bool _timelineBottomLockScheduled = false;
  _CompactWorkspacePane _compactPane = _CompactWorkspacePane.session;
  PtyService? _ptyService;
  List<PtySessionInfo> _ptySessions = const <PtySessionInfo>[];
  String? _activePtyId;
  String? _terminalError;
  bool _terminalPanelOpen = false;
  bool _terminalPanelMounted = false;
  bool _loadingPtySessions = false;
  bool _creatingPtySession = false;
  int _terminalEpoch = 0;
  bool _hasPendingSessionRouteSync = false;
  bool _sessionRouteSyncInFlight = false;
  String? _pendingSessionRouteId;
  int _sessionRouteSyncRevision = 0;
  bool _promptSubmitInFlight = false;
  late String _activeDirectory;
  String? _activeRouteSessionId;
  _WorkspaceProjectLoadingShellState? _projectLoadingShellState;
  late final ProjectCatalogService _projectCatalogService;
  late final bool _ownsProjectCatalogService;

  @override
  void initState() {
    super.initState();
    _activeDirectory = widget.directory;
    _activeRouteSessionId = widget.sessionId;
    _projectCatalogService =
        widget.projectCatalogService ?? ProjectCatalogService();
    _ownsProjectCatalogService = widget.projectCatalogService == null;
    _timelineScrollController.addListener(_handleTimelineScroll);
  }

  String get _currentDirectory => _activeDirectory;

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
    if (_controller != null && _profile?.storageKey == profile.storageKey) {
      return;
    }
    _bindWorkspace(
      appController: appController,
      profile: profile,
      directory: _activeDirectory,
      routeSessionId: _activeRouteSessionId,
    );
  }

  @override
  void didUpdateWidget(covariant WebParityWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory == widget.directory &&
        oldWidget.sessionId == widget.sessionId) {
      return;
    }
    _activeDirectory = widget.directory;
    _activeRouteSessionId = widget.sessionId;
    final appController = AppScope.of(context);
    final profile = appController.selectedProfile;
    if (profile == null) {
      _disposeController();
      _profile = null;
      _resetRouteSessionSync();
      return;
    }
    _bindWorkspace(
      appController: appController,
      profile: profile,
      directory: _activeDirectory,
      routeSessionId: _activeRouteSessionId,
    );
  }

  @override
  void dispose() {
    _disposeController();
    _promptController.dispose();
    _timelineScrollController.removeListener(_handleTimelineScroll);
    _timelineScrollController.dispose();
    _ptyService?.dispose();
    if (_ownsProjectCatalogService) {
      _projectCatalogService.dispose();
    }
    super.dispose();
  }

  void _disposeController() {
    _controller = null;
    _projectLoadingShellState = null;
  }

  void _bindWorkspace({
    required WebParityAppController appController,
    required ServerProfile profile,
    required String directory,
    String? routeSessionId,
  }) {
    final hadCachedController = appController.hasWorkspaceController(
      profile: profile,
      directory: directory,
    );
    final nextController = appController.obtainWorkspaceController(
      profile: profile,
      directory: directory,
      initialSessionId: routeSessionId,
    );
    final bindingChanged =
        !identical(_controller, nextController) ||
        _profile?.storageKey != profile.storageKey ||
        _activeDirectory != directory;

    _controller = nextController;
    _profile = profile;
    _activeDirectory = directory;
    _activeRouteSessionId = routeSessionId;

    if (bindingChanged) {
      _compactPane = _CompactWorkspacePane.session;
      _resetTimelineTracking();
      _resetTerminalState(profile);
    }

    if (routeSessionId != null && hadCachedController) {
      _queueRouteSessionSync(routeSessionId);
    } else {
      _resetRouteSessionSync();
    }

    if (!nextController.loading) {
      _projectLoadingShellState = null;
    }
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
      if (requestedSessionId == null ||
          controller.selectedSessionId == requestedSessionId) {
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
    _terminalPanelMounted = false;
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
        directory: _currentDirectory,
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
      _terminalPanelMounted = true;
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
      _terminalPanelMounted = true;
      _terminalPanelOpen = true;
      _terminalError = null;
    });
    try {
      final session = await service.createSession(
        profile: profile,
        directory: _currentDirectory,
        cwd: _currentDirectory,
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
        directory: _currentDirectory,
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
        directory: _currentDirectory,
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

  void _resetTimelineTracking() {
    _lastTimelineScopeKey = null;
    _lastTimelineMessageCount = 0;
    _lastTimelineContentSignature = 0;
    _lastTimelineLoading = false;
    _timelineWasNearBottom = true;
    _forcedTimelineBottomScopeKey = null;
    _clearTimelineBottomLock();
  }

  void _forceTimelineBottomForSession(String? sessionId) {
    final trimmed = sessionId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _forcedTimelineBottomScopeKey = null;
      return;
    }
    _forcedTimelineBottomScopeKey = '$_currentDirectory::$trimmed';
    _timelineWasNearBottom = true;
  }

  void _scheduleTimelineSync(WorkspaceController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineScrollController.hasClients) {
        return;
      }

      final scopeKey =
          '$_currentDirectory::${controller.selectedSessionId ?? 'new'}';
      final messageCount = controller.messages.length;
      final contentSignature = controller.timelineContentSignature;
      final sessionChanged = _lastTimelineScopeKey != scopeKey;
      final sessionLoadFinished =
          _lastTimelineLoading &&
          !controller.sessionLoading &&
          messageCount > 0 &&
          _lastTimelineScopeKey == scopeKey;
      final forceBottomLock = _forcedTimelineBottomScopeKey == scopeKey;
      final messageCountChanged = _lastTimelineMessageCount != messageCount;
      final contentChanged =
          _lastTimelineContentSignature != contentSignature ||
          messageCountChanged;

      if (messageCount > 0 &&
          (sessionChanged || sessionLoadFinished || forceBottomLock)) {
        _beginTimelineBottomLock(scopeKey);
        if (forceBottomLock) {
          _forcedTimelineBottomScopeKey = null;
        }
      } else if (forceBottomLock &&
          !controller.sessionLoading &&
          messageCount == 0) {
        _forcedTimelineBottomScopeKey = null;
      }

      final position = _timelineScrollController.position;
      if (!position.hasContentDimensions) {
        return;
      }
      final nearBottomNow =
          !position.hasPixels ||
          (position.maxScrollExtent - position.pixels) <= 120;
      final shouldFollowTimeline =
          forceBottomLock ||
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
      _lastTimelineLoading = controller.sessionLoading;
    });
  }

  void _beginTimelineBottomLock(String scopeKey) {
    _timelineBottomLockScopeKey = scopeKey;
    _timelineBottomLockLastExtent = null;
    _timelineBottomLockStableFrames = 0;
    _timelineBottomLockAttempts = 0;
    _scheduleTimelineBottomLock();
  }

  void _clearTimelineBottomLock() {
    _timelineBottomLockScopeKey = null;
    _timelineBottomLockLastExtent = null;
    _timelineBottomLockStableFrames = 0;
    _timelineBottomLockAttempts = 0;
  }

  void _scheduleTimelineBottomLock() {
    if (_timelineBottomLockScheduled || _timelineBottomLockScopeKey == null) {
      return;
    }
    _timelineBottomLockScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timelineBottomLockScheduled = false;
      if (!mounted) {
        return;
      }
      final expectedScopeKey = _timelineBottomLockScopeKey;
      if (expectedScopeKey == null) {
        return;
      }
      if (!_timelineScrollController.hasClients) {
        _scheduleTimelineBottomLock();
        return;
      }
      final controller = _controller;
      final currentScopeKey = controller == null
          ? null
          : '$_currentDirectory::${controller.selectedSessionId ?? 'new'}';
      if (currentScopeKey != expectedScopeKey) {
        _clearTimelineBottomLock();
        return;
      }
      final position = _timelineScrollController.position;
      if (!position.hasContentDimensions) {
        _scheduleTimelineBottomLock();
        return;
      }

      final target = position.maxScrollExtent;
      if (!position.hasPixels || (target - position.pixels).abs() > 1) {
        _timelineScrollController.jumpTo(target);
      }
      _timelineWasNearBottom = true;

      final lastExtent = _timelineBottomLockLastExtent;
      if (lastExtent != null && (target - lastExtent).abs() <= 1) {
        _timelineBottomLockStableFrames += 1;
      } else {
        _timelineBottomLockStableFrames = 0;
        _timelineBottomLockLastExtent = target;
      }

      _timelineBottomLockAttempts += 1;
      if (_timelineBottomLockStableFrames >= 1 ||
          _timelineBottomLockAttempts >= 8) {
        _clearTimelineBottomLock();
        return;
      }
      _scheduleTimelineBottomLock();
    });
  }

  Future<void> _pickComposerAttachments() async {
    if (_promptSubmitInFlight || _pickingComposerAttachments) {
      return;
    }

    setState(() {
      _pickingComposerAttachments = true;
    });

    try {
      final attachments = widget.attachmentPicker != null
          ? await widget.attachmentPicker!()
          : await _pickSystemAttachments();
      if (!mounted || attachments.isEmpty) {
        return;
      }
      setState(() {
        _composerAttachments = <PromptAttachment>[
          ..._composerAttachments,
          ...attachments,
        ];
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to attach files: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _pickingComposerAttachments = false;
        });
      }
    }
  }

  Future<List<PromptAttachment>> _pickSystemAttachments() async {
    final files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[PromptAttachmentService.pickerTypeGroup],
    );
    if (files.isEmpty) {
      return const <PromptAttachment>[];
    }
    final result = await _attachmentService.loadFiles(files);
    if (!mounted) {
      return result.attachments;
    }
    if (result.rejectedNames.isNotEmpty) {
      final names = result.rejectedNames.take(3).join(', ');
      final overflow = result.rejectedNames.length > 3
          ? ' and ${result.rejectedNames.length - 3} more'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only images, PDFs, and text files are supported. Skipped: $names$overflow',
          ),
        ),
      );
    }
    return result.attachments;
  }

  void _removeComposerAttachment(String attachmentId) {
    setState(() {
      _composerAttachments = _composerAttachments
          .where((attachment) => attachment.id != attachmentId)
          .toList(growable: false);
    });
  }

  Future<void> _submitPrompt() async {
    final controller = _controller;
    final draft = _promptController.text;
    final attachments = List<PromptAttachment>.from(_composerAttachments);
    if (controller == null ||
        _promptSubmitInFlight ||
        controller.submittingPrompt ||
        (draft.trim().isEmpty && attachments.isEmpty)) {
      return;
    }

    setState(() {
      _promptSubmitInFlight = true;
      _composerAttachments = const <PromptAttachment>[];
    });
    _promptController.clear();

    try {
      await controller.submitPrompt(draft, attachments: attachments);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _composerAttachments = attachments;
      });
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

  Future<void> _interruptSelectedSession() async {
    final controller = _controller;
    if (controller == null || controller.interruptingSession) {
      return;
    }
    try {
      await controller.interruptSelectedSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to interrupt the session: $error')),
      );
    }
  }

  Future<void> _renameSelectedSession(WorkspaceController controller) async {
    final selected = controller.selectedSession;
    if (selected == null) {
      return;
    }
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) => _RenameSessionDialog(initialTitle: selected.title),
    );
    if (nextTitle == null || nextTitle.isEmpty) {
      return;
    }
    try {
      final updated = await controller.renameSelectedSession(nextTitle);
      if (!mounted || updated == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed session to "${updated.title}".')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename session: $error')),
      );
    }
  }

  Future<void> _forkSelectedSession(WorkspaceController controller) async {
    try {
      final forked = await controller.forkSelectedSession();
      if (!mounted || forked == null) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Forked into "${forked.title}".')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fork session: $error')));
    }
  }

  Future<void> _forkMessageIntoSession(
    WorkspaceController controller,
    ChatMessage message,
  ) async {
    final messageId = message.info.id.trim();
    if (messageId.isEmpty) {
      return;
    }
    try {
      final forked = await controller.forkSelectedSession(messageId: messageId);
      if (!mounted || forked == null) {
        return;
      }
      _forceTimelineBottomForSession(forked.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forked from this message into "${forked.title}".'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fork from this message: $error')),
      );
    }
  }

  Future<void> _revertToMessage(
    WorkspaceController controller,
    ChatMessage message,
  ) async {
    final messageId = message.info.id.trim();
    if (messageId.isEmpty) {
      return;
    }
    try {
      final updated = await controller.revertSelectedSession(
        messageId: messageId,
      );
      if (!mounted || updated == null) {
        return;
      }
      _forceTimelineBottomForSession(updated.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverted the session to this message.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert to this message: $error')),
      );
    }
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
      final shared = await controller.shareSelectedSession();
      if (!mounted || shared == null) {
        return;
      }
      final shareUrl = shared.shareUrl?.trim();
      if (shareUrl != null && shareUrl.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: shareUrl));
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share link copied to clipboard.')),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session shared.')));
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
      final updated = await controller.unshareSelectedSession();
      if (!mounted || updated == null) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Share link removed.')));
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

  Future<void> _deleteSelectedSession(WorkspaceController controller) async {
    final selected = controller.selectedSession;
    if (selected == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Delete "${selected.title.trim().isEmpty ? 'this session' : selected.title.trim()}"? This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      final nextSession = await controller.deleteSelectedSession();
      if (!mounted) {
        return;
      }
      final message = nextSession == null
          ? 'Session deleted.'
          : 'Session deleted. Opened "${nextSession.title}".';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete session: $error')),
      );
    }
  }

  Future<void> _openWorkspaceSettingsSheet(
    WebParityAppController appController,
    WorkspaceController controller,
  ) async {
    final profile = appController.selectedProfile;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _WorkspaceSettingsSheet(
          appController: appController,
          profile: profile,
          report: appController.selectedReport,
          project: controller.project,
          onManageServers: () {
            Navigator.of(context).pop();
            Navigator.of(
              this.context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
    );
  }

  Future<void> _selectSessionInPlace(
    WorkspaceController controller,
    String sessionId, {
    required bool compact,
  }) async {
    _forceTimelineBottomForSession(sessionId);
    if (compact && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
    }
    await controller.selectSession(sessionId);
  }

  Future<void> _selectProjectInPlace(
    ProjectTarget project, {
    required bool compact,
  }) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    if (project.directory == _currentDirectory) {
      if (compact && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (compact && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
    }

    final appController = AppScope.of(context);
    final shouldPreserveShell =
        _controller != null &&
        !appController.hasWorkspaceController(
          profile: profile,
          directory: project.directory,
        );
    _promptController.clear();
    _composerAttachments = const <PromptAttachment>[];

    setState(() {
      _projectLoadingShellState = shouldPreserveShell
          ? _WorkspaceProjectLoadingShellState(
              targetProject: project,
              projects: _mergedProjectsWithTarget(
                _controller?.availableProjects ?? const <ProjectTarget>[],
                project,
              ),
            )
          : null;
      _bindWorkspace(
        appController: appController,
        profile: profile,
        directory: project.directory,
      );
    });
  }

  Future<void> _editProject(ProjectTarget project) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final draft = await showDialog<_ProjectEditDraft>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _EditProjectDialog(project: project),
    );
    if (draft == null) {
      return;
    }

    final normalizedName = draft.name.trim();
    final folderName = projectDisplayLabel(project.directory);
    final savedName = normalizedName.isEmpty || normalizedName == folderName
        ? null
        : normalizedName;
    final nextIcon =
        draft.icon?.effectiveImage == null &&
            (draft.icon?.color?.trim().isEmpty ?? true)
        ? null
        : draft.icon;
    final nextCommands = draft.startup.trim().isEmpty
        ? null
        : ProjectCommandsInfo(start: draft.startup.trim());

    final nextTarget = await _saveProjectEdit(
      project: project,
      savedName: savedName,
      icon: nextIcon,
      commands: nextCommands,
    );
    if (nextTarget == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    await AppScope.of(
      context,
    ).persistProjectUpdate(profile: profile, target: nextTarget);
  }

  Future<ProjectTarget?> _saveProjectEdit({
    required ProjectTarget project,
    required String? savedName,
    required ProjectIconInfo? icon,
    required ProjectCommandsInfo? commands,
  }) async {
    final projectId = project.id?.trim();
    if (projectId != null &&
        projectId.isNotEmpty &&
        projectId.toLowerCase() != 'global') {
      try {
        return await _projectCatalogService.updateProject(
          profile: _profile!,
          project: project,
          name: savedName,
          icon: icon,
          commands: commands,
        );
      } catch (error) {
        if (!mounted) {
          return null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update project: $error')),
        );
        return null;
      }
    }

    return project.copyWith(
      label: projectDisplayLabel(project.directory, name: savedName),
      name: savedName,
      icon: icon,
      commands: commands,
      clearName: savedName == null,
      clearIcon: icon == null,
      clearCommands: commands == null,
    );
  }

  Future<void> _removeProject(
    WorkspaceController controller,
    ProjectTarget project, {
    required bool compact,
  }) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final remainingProjects = controller.availableProjects
        .where((item) => item.directory != project.directory)
        .toList(growable: false);
    await AppScope.of(
      context,
    ).hideProject(profile: profile, directory: project.directory);

    if (!mounted) {
      return;
    }

    if (project.directory != _currentDirectory) {
      return;
    }

    if (remainingProjects.isEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      return;
    }

    await _selectProjectInPlace(remainingProjects.first, compact: compact);
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
        final projectLoadingShell = controller.loading
            ? _projectLoadingShellState
            : null;
        if (!controller.loading && _projectLoadingShellState != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _controller?.loading == true) {
              return;
            }
            setState(() {
              _projectLoadingShellState = null;
            });
          });
        }
        final compact =
            MediaQuery.sizeOf(context).width < AppSpacing.wideLayoutBreakpoint;
        final displayProject =
            controller.project ?? projectLoadingShell?.targetProject;
        final displayProjects = controller.availableProjects.isNotEmpty
            ? controller.availableProjects
            : (projectLoadingShell?.projects ?? const <ProjectTarget>[]);
        final showProjectLoadingShell = projectLoadingShell != null;
        final displaySessions = showProjectLoadingShell
            ? const <SessionSummary>[]
            : controller.visibleSessions;
        final displayAllSessions = showProjectLoadingShell
            ? const <SessionSummary>[]
            : controller.sessions;
        final displayStatuses = showProjectLoadingShell
            ? const <String, SessionStatusSummary>{}
            : controller.statuses;
        final selectedSession = showProjectLoadingShell
            ? null
            : controller.selectedSession;
        final mainSession = _rootSessionFor(
          displayAllSessions,
          selectedSession,
        );
        final sidebar = _WorkspaceSidebar(
          currentDirectory: _currentDirectory,
          currentSessionId: showProjectLoadingShell
              ? null
              : controller.selectedSessionId,
          project: displayProject,
          projects: displayProjects,
          sessions: displaySessions,
          allSessions: displayAllSessions,
          statuses: displayStatuses,
          showSubsessions: appController.sidebarChildSessionsVisible,
          loadingProjectContents: showProjectLoadingShell,
          onSelectProject: (project) =>
              unawaited(_selectProjectInPlace(project, compact: compact)),
          onEditProject: (project) => unawaited(_editProject(project)),
          onRemoveProject: (project) =>
              unawaited(_removeProject(controller, project, compact: compact)),
          onSelectSession: (sessionId) {
            unawaited(
              _selectSessionInPlace(controller, sessionId, compact: compact),
            );
          },
          onNewSession: () => _createNewSession(controller),
          onOpenSettings: () =>
              _openWorkspaceSettingsSheet(appController, controller),
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
                        project: displayProject,
                        session: selectedSession,
                        mainSession: mainSession,
                        status: showProjectLoadingShell
                            ? null
                            : controller.selectedStatus,
                        contextMetrics: showProjectLoadingShell
                            ? const SessionContextMetrics(
                                totalCost: 0,
                                context: null,
                              )
                            : controller.sessionContextMetrics,
                        shellToolPartsExpanded:
                            appController.shellToolPartsExpanded,
                        onSetShellToolPartsExpanded:
                            appController.setShellToolPartsExpanded,
                        timelineProgressDetailsVisible:
                            appController.timelineProgressDetailsVisible,
                        onSetTimelineProgressDetailsVisible:
                            appController.setTimelineProgressDetailsVisible,
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
                            : () => _forkSelectedSession(controller),
                        onShare: controller.selectedSession == null
                            ? null
                            : () => _shareSelectedSession(controller),
                        onDelete: controller.selectedSession == null
                            ? null
                            : () => _deleteSelectedSession(controller),
                      ),
                      Expanded(
                        child: showProjectLoadingShell
                            ? _WorkspaceProjectLoadingView(
                                key: ValueKey<String>(
                                  'workspace-project-loading-${displayProject?.directory ?? _currentDirectory}',
                                ),
                                project: displayProject,
                                compact: compact,
                              )
                            : controller.loading
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
                                selectedSession: controller.selectedSession,
                                configSnapshot: controller.configSnapshot,
                                submittingPrompt:
                                    _promptSubmitInFlight ||
                                    controller.submittingPrompt,
                                pickingAttachments: _pickingComposerAttachments,
                                attachments: _composerAttachments,
                                promptController: _promptController,
                                timelineScrollController:
                                    _timelineScrollController,
                                compactPane: _compactPane,
                                shellToolDefaultExpanded:
                                    appController.shellToolPartsExpanded,
                                timelineProgressDetailsVisible: appController
                                    .timelineProgressDetailsVisible,
                                onForkMessage: (message) =>
                                    _forkMessageIntoSession(
                                      controller,
                                      message,
                                    ),
                                onRevertMessage: (message) =>
                                    _revertToMessage(controller, message),
                                interruptiblePrompt:
                                    controller.selectedSessionId != null &&
                                    (_promptSubmitInFlight ||
                                        controller
                                            .selectedSessionInterruptible),
                                interruptingPrompt:
                                    controller.interruptingSession,
                                onCompactPaneChanged: (value) {
                                  if (_compactPane == value) {
                                    return;
                                  }
                                  setState(() {
                                    _compactPane = value;
                                  });
                                },
                                onSubmitPrompt: _submitPrompt,
                                onInterruptPrompt: _interruptSelectedSession,
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
                                onPickAttachments: _pickComposerAttachments,
                                onRemoveAttachment: _removeComposerAttachment,
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
                                terminalPanel:
                                    !_terminalPanelMounted ||
                                        _ptyService == null
                                    ? null
                                    : PtyTerminalPanel(
                                        profile: _profile!,
                                        directory: _currentDirectory,
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

class _WorkspaceProjectLoadingShellState {
  const _WorkspaceProjectLoadingShellState({
    required this.targetProject,
    required this.projects,
  });

  final ProjectTarget targetProject;
  final List<ProjectTarget> projects;
}

List<ProjectTarget> _mergedProjectsWithTarget(
  List<ProjectTarget> projects,
  ProjectTarget target,
) {
  final next = <ProjectTarget>[...projects];
  final existingIndex = next.indexWhere(
    (candidate) => candidate.directory == target.directory,
  );
  if (existingIndex >= 0) {
    next[existingIndex] = target;
    return List<ProjectTarget>.unmodifiable(next);
  }
  return List<ProjectTarget>.unmodifiable(<ProjectTarget>[target, ...next]);
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.compact,
    required this.profile,
    required this.project,
    required this.session,
    required this.mainSession,
    required this.status,
    required this.contextMetrics,
    required this.shellToolPartsExpanded,
    required this.onSetShellToolPartsExpanded,
    required this.timelineProgressDetailsVisible,
    required this.onSetTimelineProgressDetailsVisible,
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
  final SessionContextMetrics contextMetrics;
  final bool shellToolPartsExpanded;
  final Future<void> Function(bool value) onSetShellToolPartsExpanded;
  final bool timelineProgressDetailsVisible;
  final Future<void> Function(bool value) onSetTimelineProgressDetailsVisible;
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
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final rootSession = mainSession;
    final canReturnToMain =
        session != null &&
        rootSession != null &&
        session!.id != rootSession.id &&
        onBackToMainSession != null;
    final busy = _isActiveSessionStatus(status);
    final title = _sessionHeaderTitle(session, project);
    final contextSnapshot = contextMetrics.context;
    final titleStyle = compact
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            overflow: TextOverflow.ellipsis,
          )
        : theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            overflow: TextOverflow.ellipsis,
          );
    final metaParts = <String>[
      if (profile != null && profile!.effectiveLabel.trim().isNotEmpty)
        profile!.effectiveLabel.trim(),
      if (project?.directory.trim().isNotEmpty == true) project!.directory,
    ];
    final menuSections = <List<_SessionOverflowMenuAction>>[
      <_SessionOverflowMenuAction>[
        if (compact)
          _SessionOverflowMenuAction(
            id: 'home',
            label: 'Back Home',
            icon: Icons.home_rounded,
            onSelected: onBackHome,
          ),
        if (canReturnToMain)
          _SessionOverflowMenuAction(
            id: 'main',
            label: 'Back to Main Session',
            icon: Icons.subdirectory_arrow_left_rounded,
            onSelected: onBackToMainSession,
          ),
      ],
      <_SessionOverflowMenuAction>[
        _SessionOverflowMenuAction(
          id: 'shell-default',
          label: 'Expand shell output by default',
          icon: Icons.terminal_rounded,
          checked: shellToolPartsExpanded,
          onSelected: () {
            unawaited(onSetShellToolPartsExpanded(!shellToolPartsExpanded));
          },
        ),
        _SessionOverflowMenuAction(
          id: 'timeline-progress-details',
          label: 'Show to-do and step details in timeline',
          icon: Icons.checklist_rtl_rounded,
          checked: timelineProgressDetailsVisible,
          onSelected: () {
            unawaited(
              onSetTimelineProgressDetailsVisible(
                !timelineProgressDetailsVisible,
              ),
            );
          },
        ),
      ],
      <_SessionOverflowMenuAction>[
        _SessionOverflowMenuAction(
          id: 'rename',
          label: 'Rename Session',
          icon: Icons.edit_rounded,
          enabled: onRename != null,
          onSelected: onRename,
        ),
        _SessionOverflowMenuAction(
          id: 'fork',
          label: 'Fork Session',
          icon: Icons.call_split_rounded,
          enabled: onFork != null,
          onSelected: onFork,
        ),
        _SessionOverflowMenuAction(
          id: 'share',
          label: 'Share Session',
          icon: Icons.ios_share_rounded,
          enabled: onShare != null,
          onSelected: onShare,
        ),
      ],
      <_SessionOverflowMenuAction>[
        _SessionOverflowMenuAction(
          id: 'delete',
          label: 'Delete Session',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          enabled: onDelete != null,
          onSelected: onDelete,
        ),
      ],
    ].where((section) => section.isNotEmpty).toList(growable: false);
    if (compact) {
      return Material(
        color: surfaces.panel,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: surfaces.lineSoft)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  child: _SessionIdentity(
                    compact: true,
                    title: title,
                    titleKey: ValueKey<String>(
                      'session-header-title-${session?.id ?? 'new'}',
                    ),
                    titleStyle: titleStyle,
                    busy: busy,
                    busyKey: ValueKey<String>(
                      'session-header-busy-${session?.id ?? 'new'}',
                    ),
                  ),
                ),
              ),
              if (session != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xxs),
                  child: _SessionContextUsageRing(
                    key: ValueKey<String>(
                      'session-header-context-ring-${session!.id}',
                    ),
                    usagePercent: contextSnapshot?.usagePercent,
                    totalTokens: contextSnapshot?.totalTokens,
                    contextLimit: contextSnapshot?.contextLimit,
                    compact: true,
                  ),
                ),
              IconButton(
                onPressed: onToggleTerminal,
                icon: Icon(
                  terminalOpen
                      ? Icons.terminal_rounded
                      : Icons.terminal_outlined,
                  size: 18,
                ),
                tooltip: terminalOpen ? 'Hide terminal' : 'Show terminal',
                splashRadius: 18,
              ),
              _SessionOverflowMenuButton(compact: true, sections: menuSections),
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  _SessionIdentity(
                    compact: false,
                    title: title,
                    titleKey: ValueKey<String>(
                      'session-header-title-${session?.id ?? 'new'}',
                    ),
                    titleStyle: titleStyle,
                    busy: busy,
                    busyKey: ValueKey<String>(
                      'session-header-busy-${session?.id ?? 'new'}',
                    ),
                  ),
                  if (metaParts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        metaParts.join('  •  '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (session != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _SessionContextUsageRing(
                  key: ValueKey<String>(
                    'session-header-context-ring-${session!.id}',
                  ),
                  usagePercent: contextSnapshot?.usagePercent,
                  totalTokens: contextSnapshot?.totalTokens,
                  contextLimit: contextSnapshot?.contextLimit,
                ),
              ),
            IconButton(
              onPressed: onToggleTerminal,
              icon: Icon(
                terminalOpen ? Icons.terminal_rounded : Icons.terminal_outlined,
              ),
              tooltip: terminalOpen ? 'Hide terminal' : 'Show terminal',
            ),
            _SessionOverflowMenuButton(sections: menuSections),
          ],
        ),
      ),
    );
  }
}

class _SessionOverflowMenuAction {
  const _SessionOverflowMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.checked = false,
    this.destructive = false,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback? onSelected;
  final bool checked;
  final bool destructive;
  final bool enabled;
}

class _SessionOverflowMenuButton extends StatefulWidget {
  const _SessionOverflowMenuButton({
    required this.sections,
    this.compact = false,
  });

  final List<List<_SessionOverflowMenuAction>> sections;
  final bool compact;

  @override
  State<_SessionOverflowMenuButton> createState() =>
      _SessionOverflowMenuButtonState();
}

class _SessionOverflowMenuButtonState
    extends State<_SessionOverflowMenuButton> {
  final GlobalKey _buttonKey = GlobalKey();

  Rect? _resolveButtonRect() {
    final overlay = Overlay.maybeOf(context);
    final buttonContext = _buttonKey.currentContext;
    if (overlay == null || buttonContext == null) {
      return null;
    }
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null || !buttonBox.hasSize) {
      return null;
    }
    final topLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & buttonBox.size;
  }

  Future<void> _openMenu() async {
    if (widget.sections.isEmpty) {
      return;
    }
    final anchorRect = _resolveButtonRect();
    if (anchorRect == null) {
      return;
    }
    final selected = await showGeneralDialog<_SessionOverflowMenuAction?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss session menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _SessionOverflowMenuOverlay(
          anchorRect: anchorRect,
          sections: widget.sections,
          compact: widget.compact,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
    if (!mounted || selected == null || !selected.enabled) {
      return;
    }
    selected.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _buttonKey,
      child: IconButton(
        key: const ValueKey<String>('session-header-overflow-menu-button'),
        onPressed: _openMenu,
        icon: Icon(Icons.more_horiz_rounded, size: widget.compact ? 18 : 20),
        tooltip: 'Show menu',
        splashRadius: 18,
      ),
    );
  }
}

class _SessionOverflowMenuOverlay extends StatelessWidget {
  const _SessionOverflowMenuOverlay({
    required this.anchorRect,
    required this.sections,
    required this.compact,
  });

  final Rect anchorRect;
  final List<List<_SessionOverflowMenuAction>> sections;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final horizontalMargin = compact ? AppSpacing.sm : AppSpacing.md;
    final verticalMargin = AppSpacing.sm;
    final screenSize = mediaQuery.size;
    const menuWidth = 320.0;
    final left = math.max(
      horizontalMargin,
      math.min(
        anchorRect.right - menuWidth,
        screenSize.width - menuWidth - horizontalMargin,
      ),
    );
    final top = math.min(
      anchorRect.bottom + 10,
      screenSize.height - mediaQuery.padding.bottom - verticalMargin - 280,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: SafeArea(
              child: _SessionOverflowMenuPanel(sections: sections),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionOverflowMenuPanel extends StatelessWidget {
  const _SessionOverflowMenuPanel({required this.sections});

  final List<List<_SessionOverflowMenuAction>> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          key: const ValueKey<String>('session-header-overflow-menu-panel'),
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 260),
          decoration: BoxDecoration(
            color: surfaces.panelRaised.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 34,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: surfaces.background.withValues(alpha: 0.24),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var sectionIndex = 0;
                  sectionIndex < sections.length;
                  sectionIndex += 1
                ) ...<Widget>[
                  if (sectionIndex > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                        horizontal: AppSpacing.sm,
                      ),
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                    ),
                  ...sections[sectionIndex].map(
                    (action) => _SessionOverflowMenuItem(action: action),
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

class _SessionOverflowMenuItem extends StatelessWidget {
  const _SessionOverflowMenuItem({required this.action});

  final _SessionOverflowMenuAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final destructiveColor = surfaces.danger;
    final accentColor = theme.colorScheme.primary;
    final itemColor = action.destructive
        ? destructiveColor
        : theme.colorScheme.onSurface;
    final iconTone = action.checked ? accentColor : itemColor;

    return Opacity(
      opacity: action.enabled ? 1 : 0.44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>(
            'session-header-overflow-menu-item-${action.id}',
          ),
          onTap: !action.enabled
              ? null
              : () => Navigator.of(context).pop(action),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: (action.checked ? accentColor : itemColor)
                        .withValues(alpha: action.destructive ? 0.12 : 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: (action.checked ? accentColor : itemColor)
                          .withValues(alpha: 0.16),
                    ),
                  ),
                  child: Icon(action.icon, size: 16, color: iconTone),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    action.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: itemColor,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (action.checked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: accentColor,
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

class _WorkspaceSettingsSheet extends StatefulWidget {
  const _WorkspaceSettingsSheet({
    required this.appController,
    required this.onManageServers,
    this.profile,
    this.report,
    this.project,
  });

  final WebParityAppController appController;
  final ServerProfile? profile;
  final ServerProbeReport? report;
  final ProjectTarget? project;
  final VoidCallback onManageServers;

  @override
  State<_WorkspaceSettingsSheet> createState() =>
      _WorkspaceSettingsSheetState();
}

class _WorkspaceSettingsSheetState extends State<_WorkspaceSettingsSheet> {
  bool _refreshingProbe = false;

  Future<void> _refreshProbe() async {
    final profile = widget.profile;
    if (profile == null || _refreshingProbe) {
      return;
    }
    setState(() {
      _refreshingProbe = true;
    });
    try {
      await widget.appController.refreshProbe(profile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh server status: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingProbe = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return AnimatedBuilder(
      animation: widget.appController,
      builder: (context, _) {
        final profile = widget.appController.selectedProfile ?? widget.profile;
        final report = widget.appController.selectedReport ?? widget.report;
        final statusMeta = _workspaceSettingsStatusMeta(
          theme,
          surfaces,
          report,
        );
        final currentProject = widget.project;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: const Offset(0, 24),
                ),
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 36,
                  spreadRadius: -18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                key: const ValueKey<String>('workspace-settings-sheet-blur'),
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  key: const ValueKey<String>('workspace-settings-sheet'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: surfaces.panel.withValues(alpha: 0.72),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Column(
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.025),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                AppSpacing.lg,
                                AppSpacing.md,
                                AppSpacing.md,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Workspace Settings',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Text(
                                          'Adjust workspace behavior and inspect the current server connection.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: surfaces.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: 'Close settings',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                AppSpacing.md,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              children: <Widget>[
                                _WorkspaceSettingsSection(
                                  title: 'Server',
                                  child: _WorkspaceSettingsCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    profile?.effectiveLabel ??
                                                        'No server selected',
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    height: AppSpacing.xxs,
                                                  ),
                                                  Text(
                                                    report?.summary ??
                                                        profile
                                                            ?.normalizedBaseUrl ??
                                                        'Return to Home to choose a server.',
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: surfaces.muted,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            _WorkspaceSettingsStatusChip(
                                              label: statusMeta.label,
                                              color: statusMeta.color,
                                            ),
                                          ],
                                        ),
                                        if (currentProject != null) ...<Widget>[
                                          const SizedBox(height: AppSpacing.md),
                                          _WorkspaceSettingsMetaRow(
                                            label: 'Project',
                                            value: currentProject.directory,
                                          ),
                                        ],
                                        if (profile != null) ...<Widget>[
                                          const SizedBox(height: AppSpacing.md),
                                          Wrap(
                                            spacing: AppSpacing.sm,
                                            runSpacing: AppSpacing.sm,
                                            children: <Widget>[
                                              OutlinedButton.icon(
                                                key: const ValueKey<String>(
                                                  'workspace-settings-refresh-probe-button',
                                                ),
                                                onPressed: _refreshingProbe
                                                    ? null
                                                    : _refreshProbe,
                                                icon: _refreshingProbe
                                                    ? const SizedBox.square(
                                                        dimension: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.refresh_rounded,
                                                      ),
                                                label: const Text(
                                                  'Refresh Status',
                                                ),
                                              ),
                                              FilledButton.icon(
                                                key: const ValueKey<String>(
                                                  'workspace-settings-manage-servers-button',
                                                ),
                                                onPressed:
                                                    widget.onManageServers,
                                                icon: const Icon(
                                                  Icons.storage_rounded,
                                                ),
                                                label: const Text(
                                                  'Manage Servers',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _WorkspaceSettingsSection(
                                  title: 'Timeline',
                                  child: _WorkspaceSettingsCard(
                                    child: Column(
                                      children: <Widget>[
                                        _WorkspaceSettingsToggleRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-shell-toggle',
                                          ),
                                          title:
                                              'Expand shell output by default',
                                          subtitle:
                                              'Show live shell command details immediately in the timeline.',
                                          value: widget
                                              .appController
                                              .shellToolPartsExpanded,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setShellToolPartsExpanded(
                                                    value,
                                                  ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _WorkspaceSettingsToggleRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-progress-toggle',
                                          ),
                                          title:
                                              'Show to-do and step details in timeline',
                                          subtitle:
                                              'Display internal progress events directly in the chat stream.',
                                          value: widget
                                              .appController
                                              .timelineProgressDetailsVisible,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setTimelineProgressDetailsVisible(
                                                    value,
                                                  ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _WorkspaceSettingsToggleRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-code-highlight-toggle',
                                          ),
                                          title: 'Highlight chat code blocks',
                                          subtitle:
                                              'Apply language-aware syntax colors to fenced code blocks in the timeline.',
                                          value: widget
                                              .appController
                                              .chatCodeBlockHighlightingEnabled,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setChatCodeBlockHighlightingEnabled(
                                                    value,
                                                  ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _WorkspaceSettingsSection(
                                  title: 'Sidebar',
                                  child: _WorkspaceSettingsCard(
                                    child: _WorkspaceSettingsToggleRow(
                                      key: const ValueKey<String>(
                                        'workspace-settings-sidebar-child-sessions-toggle',
                                      ),
                                      title: 'Show sub-sessions in sidebar',
                                      subtitle:
                                          'Display nested agent sessions under their root session in the session list.',
                                      value: widget
                                          .appController
                                          .sidebarChildSessionsVisible,
                                      onChanged: (value) {
                                        unawaited(
                                          widget.appController
                                              .setSidebarChildSessionsVisible(
                                                value,
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceSettingsSection extends StatelessWidget {
  const _WorkspaceSettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: surfaces.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _WorkspaceSettingsCard extends StatelessWidget {
  const _WorkspaceSettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: surfaces.panelRaised.withValues(alpha: 0.42),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WorkspaceSettingsToggleRow extends StatelessWidget {
  const _WorkspaceSettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsMetaRow extends StatelessWidget {
  const _WorkspaceSettingsMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: surfaces.muted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _WorkspaceSettingsStatusMeta {
  const _WorkspaceSettingsStatusMeta({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

_WorkspaceSettingsStatusMeta _workspaceSettingsStatusMeta(
  ThemeData theme,
  AppSurfaces surfaces,
  ServerProbeReport? report,
) {
  final classification = report?.classification;
  return switch (classification) {
    ConnectionProbeClassification.ready => _WorkspaceSettingsStatusMeta(
      label: 'Ready',
      color: theme.colorScheme.primary,
    ),
    ConnectionProbeClassification.authFailure => _WorkspaceSettingsStatusMeta(
      label: 'Auth Required',
      color: surfaces.warning,
    ),
    ConnectionProbeClassification.unsupportedCapabilities =>
      _WorkspaceSettingsStatusMeta(label: 'Partial', color: surfaces.warning),
    ConnectionProbeClassification.specFetchFailure ||
    ConnectionProbeClassification.connectivityFailure =>
      _WorkspaceSettingsStatusMeta(
        label: 'Unavailable',
        color: surfaces.danger,
      ),
    null => _WorkspaceSettingsStatusMeta(
      label: 'Unknown',
      color: surfaces.muted,
    ),
  };
}

class _WorkspaceSettingsStatusChip extends StatelessWidget {
  const _WorkspaceSettingsStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _SessionIdentity extends StatelessWidget {
  const _SessionIdentity({
    required this.compact,
    required this.title,
    required this.titleKey,
    required this.titleStyle,
    required this.busy,
    required this.busyKey,
  });

  final bool compact;
  final String title;
  final Key titleKey;
  final TextStyle? titleStyle;
  final bool busy;
  final Key busyKey;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Row(
      children: <Widget>[
        _SessionGlyph(compact: compact),
        SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ShimmeringRichText(
                key: titleKey,
                active: busy,
                text: TextSpan(text: title, style: titleStyle),
              ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    key: busyKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          'Busy',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: surfaces.accentSoft,
                                fontWeight: FontWeight.w700,
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
  }
}

class _SessionGlyph extends StatelessWidget {
  const _SessionGlyph({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final size = compact ? 3.0 : 4.0;
    final gap = compact ? 2.0 : 2.5;
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: compact ? 16 : 18,
      height: compact ? 16 : 18,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List<Widget>.generate(9, (index) {
          final highlight = <int>{1, 3, 4, 5, 7}.contains(index);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: (highlight ? accent : surfaces.lineSoft).withValues(
                alpha: highlight ? 0.8 : 0.7,
              ),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: SizedBox(width: size, height: size),
          );
        }),
      ),
    );
  }
}

class _SessionContextUsageRing extends StatelessWidget {
  const _SessionContextUsageRing({
    required this.usagePercent,
    required this.totalTokens,
    required this.contextLimit,
    this.compact = false,
    super.key,
  });

  final int? usagePercent;
  final int? totalTokens;
  final int? contextLimit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numberFormat = NumberFormat.decimalPattern(locale);
    final percent = usagePercent?.clamp(0, 100);
    final value = percent == null ? 0.0 : percent / 100;
    final color = _sessionContextUsageColor(percent, theme, surfaces);
    final strokeWidth = compact ? 2.8 : 3.2;
    final size = compact ? 24.0 : 28.0;
    final tooltip = switch ((percent, totalTokens, contextLimit)) {
      (null, _, _) => 'Context window usage unavailable',
      (final usage?, final total?, final limit?) =>
        '$usage% of context window used '
            '(${numberFormat.format(total)} / ${numberFormat.format(limit)} tokens)',
      (final usage?, _, _) => '$usage% of context window used',
    };

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 120),
      child: Semantics(
        label: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: surfaces.lineSoft,
                    width: strokeWidth,
                  ),
                ),
              ),
              if (percent != null)
                Padding(
                  padding: const EdgeInsets.all(0.5),
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: strokeWidth,
                    backgroundColor: Colors.transparent,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: percent == null ? 0.28 : 0.85,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: compact ? 4 : 5,
                    height: compact ? 4 : 5,
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

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.currentDirectory,
    required this.currentSessionId,
    required this.project,
    required this.projects,
    required this.sessions,
    required this.allSessions,
    required this.statuses,
    required this.showSubsessions,
    this.loadingProjectContents = false,
    required this.onSelectProject,
    required this.onEditProject,
    required this.onRemoveProject,
    required this.onSelectSession,
    required this.onNewSession,
    required this.onOpenSettings,
  });

  final String currentDirectory;
  final String? currentSessionId;
  final ProjectTarget? project;
  final List<ProjectTarget> projects;
  final List<SessionSummary> sessions;
  final List<SessionSummary> allSessions;
  final Map<String, SessionStatusSummary> statuses;
  final bool showSubsessions;
  final bool loadingProjectContents;
  final ValueChanged<ProjectTarget> onSelectProject;
  final ValueChanged<ProjectTarget> onEditProject;
  final ValueChanged<ProjectTarget> onRemoveProject;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewSession;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final currentProject =
        project ?? _projectForDirectory(projects, currentDirectory);
    final rootSelectedSessionId = _rootSessionFor(
      allSessions,
      _sessionById(allSessions, currentSessionId),
    )?.id;
    final sessionEntries = _buildSidebarSessionEntries(
      roots: sessions,
      allSessions: allSessions,
      statuses: statuses,
      selectedSessionId: currentSessionId,
      includeNested: showSubsessions,
    );

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
                        child: _ProjectSidebarTile(
                          key: ValueKey<String>(
                            'workspace-project-${project.directory}',
                          ),
                          project: project,
                          selected: selected,
                          onSelect: () => onSelectProject(project),
                          onEdit: () => onEditProject(project),
                          onRemove: () => onRemoveProject(project),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>(
                    'workspace-sidebar-settings-button',
                  ),
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'Workspace settings',
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
                  if (currentProject != null) ...<Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                currentProject.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentProject.directory,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 12,
                                  color: surfaces.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _SidebarProjectMenuButton(
                          project: currentProject,
                          onEdit: () => onEditProject(currentProject),
                          onRemove: () => onRemoveProject(currentProject),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ] else ...<Widget>[
                    Text(
                      projectDisplayLabel(currentDirectory),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'workspace-sidebar-new-session-button',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        textStyle: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: surfaces.lineSoft),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: surfaces.panel,
                      ),
                      onPressed: loadingProjectContents ? null : onNewSession,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('New session'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: loadingProjectContents
                        ? const _SidebarSessionLoadingState()
                        : sessionEntries.isEmpty
                        ? Text(
                            'Start a new session to begin.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: surfaces.muted,
                            ),
                          )
                        : ListView.separated(
                            itemCount: sessionEntries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final entry = sessionEntries[index];
                              return _SidebarSessionTreeRow(
                                key: ValueKey<String>(
                                  'workspace-session-entry-${entry.session.id}-${entry.depth}',
                                ),
                                entry: entry,
                                project: currentProject,
                                status: statuses[entry.session.id],
                                selected: showSubsessions
                                    ? entry.session.id == currentSessionId
                                    : entry.rootId == rootSelectedSessionId,
                                onTap: () => onSelectSession(entry.session.id),
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

class _SidebarSessionLoadingState extends StatelessWidget {
  const _SidebarSessionLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey<String>('workspace-sidebar-session-loading-state'),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) => const _SidebarSessionLoadingRow(),
    );
  }
}

class _SidebarSessionLoadingRow extends StatelessWidget {
  const _SidebarSessionLoadingRow();

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      key: const ValueKey<String>('workspace-sidebar-session-loading-row'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: surfaces.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 22,
            alignment: Alignment.center,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: surfaces.lineSoft,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ShimmerBox(height: 16, widthFactor: 1, borderRadius: 8),
          ),
        ],
      ),
    );
  }
}

Future<_ProjectMenuAction?> _showProjectContextMenu({
  required BuildContext context,
  required Offset position,
  required ProjectTarget project,
}) {
  return showGeneralDialog<_ProjectMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss project menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ProjectContextMenuOverlay(position: position, project: project);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _SidebarProjectMenuButton extends StatelessWidget {
  const _SidebarProjectMenuButton({
    required this.project,
    required this.onEdit,
    required this.onRemove,
  });

  final ProjectTarget project;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Builder(
      builder: (buttonContext) {
        return IconButton(
          key: const ValueKey<String>('workspace-sidebar-project-menu-button'),
          tooltip: 'Project menu',
          onPressed: () async {
            final renderObject = buttonContext.findRenderObject();
            if (renderObject is! RenderBox) {
              return;
            }
            final origin = renderObject.localToGlobal(Offset.zero);
            final action = await _showProjectContextMenu(
              context: context,
              position: Offset(
                origin.dx + renderObject.size.width - 220,
                origin.dy + renderObject.size.height + 8,
              ),
              project: project,
            );
            switch (action) {
              case _ProjectMenuAction.edit:
                onEdit();
              case _ProjectMenuAction.remove:
                onRemove();
              case null:
                break;
            }
          },
          splashRadius: 18,
          icon: Icon(Icons.more_horiz_rounded, color: surfaces.muted, size: 20),
        );
      },
    );
  }
}

class _ProjectSidebarTile extends StatefulWidget {
  const _ProjectSidebarTile({
    required this.project,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  final ProjectTarget project;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  State<_ProjectSidebarTile> createState() => _ProjectSidebarTileState();
}

class _ProjectSidebarTileState extends State<_ProjectSidebarTile> {
  Future<void> _showMenu(Offset globalPosition) async {
    final action = await _showProjectContextMenu(
      context: context,
      position: globalPosition,
      project: widget.project,
    );

    switch (action) {
      case _ProjectMenuAction.edit:
        widget.onEdit();
      case _ProjectMenuAction.remove:
        widget.onRemove();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return GestureDetector(
      onSecondaryTapDown: (details) => _showMenu(details.globalPosition),
      onLongPressStart: (details) => _showMenu(details.globalPosition),
      child: InkWell(
        onTap: widget.onSelect,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
                : surfaces.panelRaised,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
              color: widget.selected
                  ? Theme.of(context).colorScheme.primary
                  : surfaces.lineSoft,
            ),
          ),
          child: _ProjectAvatar(
            project: widget.project,
            size: 38,
            fontSize: 22,
            rounded: 10,
          ),
        ),
      ),
    );
  }
}

class _SidebarSessionEntry {
  const _SidebarSessionEntry({
    required this.session,
    required this.depth,
    required this.rootId,
  });

  final SessionSummary session;
  final int depth;
  final String rootId;
}

class _SidebarSessionTreeRow extends StatelessWidget {
  const _SidebarSessionTreeRow({
    required this.entry,
    required this.project,
    required this.status,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _SidebarSessionEntry entry;
  final ProjectTarget? project;
  final SessionStatusSummary? status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final title = entry.session.title.trim().isEmpty
        ? 'Untitled session'
        : entry.session.title.trim();
    final active = _isActiveSessionStatus(status);
    final isRoot = entry.depth == 0;
    final indent = entry.depth * 18.0;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: Center(
                    child: isRoot
                        ? (project != null
                              ? _ProjectAvatar(
                                  project: project!,
                                  size: 16,
                                  fontSize: 10,
                                  rounded: 5,
                                )
                              : Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ))
                        : Container(
                            width: 10,
                            height: 2,
                            decoration: BoxDecoration(
                              color: surfaces.muted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ShimmeringRichText(
                    key: ValueKey<String>(
                      'sidebar-session-shimmer-${entry.session.id}',
                    ),
                    active: active,
                    text: TextSpan(
                      text: title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isRoot ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: isRoot ? 0.96 : 0.9,
                              ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

enum _ProjectMenuAction { edit, remove }

class _ProjectContextMenuOverlay extends StatelessWidget {
  const _ProjectContextMenuOverlay({
    required this.position,
    required this.project,
  });

  final Offset position;
  final ProjectTarget project;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const panelWidth = 236.0;
    const horizontalInset = 12.0;
    const verticalInset = 12.0;
    final maxLeft = math.max(
      horizontalInset,
      size.width - panelWidth - horizontalInset,
    );
    final left = math.min(position.dx, maxLeft);
    final top = math.min(position.dy, size.height - 132 - verticalInset);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: math.max(verticalInset, top),
            child: _ProjectContextMenuPanel(project: project),
          ),
        ],
      ),
    );
  }
}

class _ProjectContextMenuPanel extends StatelessWidget {
  const _ProjectContextMenuPanel({required this.project});

  final ProjectTarget project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 236),
          decoration: BoxDecoration(
            color: surfaces.panelRaised.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      _ProjectAvatar(project: project, size: 34, fontSize: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                _ProjectContextMenuItem(
                  label: 'Edit project',
                  icon: Icons.edit_rounded,
                  onTap: () =>
                      Navigator.of(context).pop(_ProjectMenuAction.edit),
                ),
                _ProjectContextMenuItem(
                  label: 'Delete project',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onTap: () =>
                      Navigator.of(context).pop(_ProjectMenuAction.remove),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectContextMenuItem extends StatelessWidget {
  const _ProjectContextMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final color = destructive ? surfaces.danger : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
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

class _EditProjectDialog extends StatefulWidget {
  const _EditProjectDialog({required this.project});

  final ProjectTarget project;

  @override
  State<_EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<_EditProjectDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _startupController;
  late String _selectedColor;
  String? _iconDataUrl;
  bool _pickingIcon = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text:
          widget.project.name ?? projectDisplayLabel(widget.project.directory),
    );
    _startupController = TextEditingController(
      text: widget.project.commands?.start ?? '',
    );
    _selectedColor = widget.project.icon?.color ?? 'pink';
    _iconDataUrl = widget.project.icon?.effectiveImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startupController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    if (_pickingIcon) {
      return;
    }
    setState(() {
      _pickingIcon = true;
    });
    try {
      final image = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'Images',
            extensions: <String>[
              'png',
              'jpg',
              'jpeg',
              'webp',
              'gif',
              'bmp',
              'svg',
            ],
          ),
        ],
      );
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _iconDataUrl = _dataUrlForFile(image.name, bytes);
      });
    } finally {
      if (mounted) {
        setState(() {
          _pickingIcon = false;
        });
      }
    }
  }

  void _submit() {
    Navigator.of(context).pop(
      _ProjectEditDraft(
        name: _nameController.text,
        startup: _startupController.text,
        icon: ProjectIconInfo(
          url: _iconDataUrl,
          override: _iconDataUrl,
          color: _selectedColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final hasCustomIcon = _iconDataUrl != null && _iconDataUrl!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: surfaces.panel.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 42,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Edit project',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Icon',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Stack(
                          children: <Widget>[
                            InkWell(
                              onTap: _pickIcon,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: surfaces.panelRaised,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: surfaces.lineSoft),
                                ),
                                alignment: Alignment.center,
                                child: _ProjectAvatar(
                                  project: widget.project.copyWith(
                                    name: _nameController.text.trim().isEmpty
                                        ? widget.project.name
                                        : _nameController.text.trim(),
                                    label: projectDisplayLabel(
                                      widget.project.directory,
                                      name: _nameController.text.trim().isEmpty
                                          ? widget.project.name
                                          : _nameController.text.trim(),
                                    ),
                                    icon: ProjectIconInfo(
                                      url: _iconDataUrl,
                                      override: _iconDataUrl,
                                      color: _selectedColor,
                                    ),
                                  ),
                                  size: 84,
                                  fontSize: 34,
                                  rounded: 10,
                                ),
                              ),
                            ),
                            if (hasCustomIcon)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.56),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      setState(() {
                                        _iconDataUrl = null;
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _pickingIcon
                                      ? 'Loading image...'
                                      : 'Click to choose an image',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Recommended: 128x128px',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasCustomIcon) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Color',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _projectAvatarColorKeys
                            .map((colorKey) {
                              final palette = _projectAvatarPalette(colorKey);
                              final selected = colorKey == _selectedColor;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedColor = colorKey;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : Colors.white.withValues(
                                              alpha: 0.06,
                                            ),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: palette.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _projectInitial(
                                          widget.project.copyWith(
                                            name:
                                                _nameController.text
                                                    .trim()
                                                    .isEmpty
                                                ? widget.project.name
                                                : _nameController.text.trim(),
                                            label: projectDisplayLabel(
                                              widget.project.directory,
                                              name:
                                                  _nameController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? widget.project.name
                                                  : _nameController.text.trim(),
                                            ),
                                          ),
                                        ),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: palette.foreground,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _startupController,
                      maxLines: 3,
                      minLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Workspace startup script',
                        hintText: 'e.g. bun install',
                        helperText:
                            'Runs after creating a new workspace (worktree).',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: _submit,
                          child: const Text('Save'),
                        ),
                      ],
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

class _ProjectEditDraft {
  const _ProjectEditDraft({
    required this.name,
    required this.startup,
    required this.icon,
  });

  final String name;
  final String startup;
  final ProjectIconInfo? icon;
}

class _ProjectAvatar extends StatelessWidget {
  const _ProjectAvatar({
    required this.project,
    required this.size,
    required this.fontSize,
    this.rounded = 12,
  });

  final ProjectTarget project;
  final double size;
  final double fontSize;
  final double rounded;

  @override
  Widget build(BuildContext context) {
    final image = project.icon?.effectiveImage;
    final palette = _projectAvatarPalette(project.icon?.color);
    final initial = _projectInitial(project);

    return ClipRRect(
      borderRadius: BorderRadius.circular(rounded),
      child: Container(
        width: size,
        height: size,
        color: palette.background,
        alignment: Alignment.center,
        child: image == null
            ? Text(
                initial,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: palette.foreground,
                ),
              )
            : _ProjectAvatarImage(image: image),
      ),
    );
  }
}

class _ProjectAvatarImage extends StatelessWidget {
  const _ProjectAvatarImage({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    UriData? uriData;
    if (image.startsWith('data:')) {
      try {
        uriData = UriData.parse(image);
      } catch (_) {
        uriData = null;
      }
    }
    if (uriData != null) {
      return Image.memory(
        uriData.contentAsBytes(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      image,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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

const List<String> _projectAvatarColorKeys = <String>[
  'pink',
  'mint',
  'orange',
  'purple',
  'cyan',
  'lime',
];

({Color background, Color foreground}) _projectAvatarPalette(String? key) {
  return switch (key?.trim()) {
    'pink' => (
      background: const Color(0xFF5D2448),
      foreground: const Color(0xFFF6B4E5),
    ),
    'mint' => (
      background: const Color(0xFF164740),
      foreground: const Color(0xFFB8F7E8),
    ),
    'orange' => (
      background: const Color(0xFF6A3814),
      foreground: const Color(0xFFFFC38D),
    ),
    'purple' => (
      background: const Color(0xFF4C2D67),
      foreground: const Color(0xFFD1B0FF),
    ),
    'cyan' => (
      background: const Color(0xFF1A4172),
      foreground: const Color(0xFFA5D4FF),
    ),
    'lime' => (
      background: const Color(0xFF42571A),
      foreground: const Color(0xFFD6F48E),
    ),
    _ => (
      background: const Color(0xFF164740),
      foreground: const Color(0xFFB8F7E8),
    ),
  };
}

String _dataUrlForFile(String filename, Uint8List bytes) {
  final extension = filename.trim().split('.').last.toLowerCase();
  final mimeType = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    'svg' => 'image/svg+xml',
    _ => 'image/png',
  };
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

ProjectTarget? _projectForDirectory(
  List<ProjectTarget> projects,
  String currentDirectory,
) {
  for (final project in projects) {
    if (project.directory == currentDirectory) {
      return project;
    }
  }
  return null;
}

List<_SidebarSessionEntry> _buildSidebarSessionEntries({
  required List<SessionSummary> roots,
  required List<SessionSummary> allSessions,
  required Map<String, SessionStatusSummary> statuses,
  required String? selectedSessionId,
  required bool includeNested,
}) {
  final childrenByParent = <String, List<SessionSummary>>{};
  for (final session in allSessions) {
    final parentId = session.parentId;
    if (parentId == null || parentId.isEmpty || session.archivedAt != null) {
      continue;
    }
    childrenByParent
        .putIfAbsent(parentId, () => <SessionSummary>[])
        .add(session);
  }

  int compareSessions(SessionSummary left, SessionSummary right) {
    final leftSelected = left.id == selectedSessionId;
    final rightSelected = right.id == selectedSessionId;
    if (leftSelected != rightSelected) {
      return leftSelected ? -1 : 1;
    }
    final leftActive = _isActiveSessionStatus(statuses[left.id]);
    final rightActive = _isActiveSessionStatus(statuses[right.id]);
    if (leftActive != rightActive) {
      return leftActive ? -1 : 1;
    }
    final updated = right.updatedAt.compareTo(left.updatedAt);
    if (updated != 0) {
      return updated;
    }
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  for (final children in childrenByParent.values) {
    children.sort(compareSessions);
  }

  final entries = <_SidebarSessionEntry>[];
  final seen = <String>{};

  void visit(SessionSummary session, int depth, String rootId) {
    if (!seen.add(session.id)) {
      return;
    }
    entries.add(
      _SidebarSessionEntry(session: session, depth: depth, rootId: rootId),
    );
    if (!includeNested) {
      return;
    }
    for (final child
        in childrenByParent[session.id] ?? const <SessionSummary>[]) {
      visit(child, depth + 1, rootId);
    }
  }

  for (final root in roots) {
    visit(root, 0, root.id);
  }
  return entries;
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

bool _isActiveSessionStatus(SessionStatusSummary? status) {
  return (status?.type.trim().toLowerCase() ?? 'idle') != 'idle';
}

String _sessionHeaderTitle(SessionSummary? session, ProjectTarget? project) {
  final sessionTitle = session?.title.trim();
  if (sessionTitle != null && sessionTitle.isNotEmpty) {
    return sessionTitle;
  }
  final projectLabel = project?.label.trim();
  if (projectLabel != null && projectLabel.isNotEmpty) {
    return projectLabel;
  }
  return 'Session';
}

class _RenameSessionDialog extends StatefulWidget {
  const _RenameSessionDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameSessionDialog> createState() => _RenameSessionDialogState();
}

class _RenameSessionDialogState extends State<_RenameSessionDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Session'),
      content: TextField(
        controller: _titleController,
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
              Navigator.of(context).pop(_titleController.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.compact,
    required this.controller,
    required this.allSessions,
    required this.selectedSession,
    required this.configSnapshot,
    required this.submittingPrompt,
    required this.interruptiblePrompt,
    required this.interruptingPrompt,
    required this.pickingAttachments,
    required this.attachments,
    required this.promptController,
    required this.timelineScrollController,
    required this.compactPane,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onCompactPaneChanged,
    required this.onSubmitPrompt,
    required this.onInterruptPrompt,
    required this.onCreateSession,
    required this.onOpenSession,
    required this.onPickAttachments,
    required this.onRemoveAttachment,
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
  final SessionSummary? selectedSession;
  final ConfigSnapshot? configSnapshot;
  final bool submittingPrompt;
  final bool interruptiblePrompt;
  final bool interruptingPrompt;
  final bool pickingAttachments;
  final List<PromptAttachment> attachments;
  final TextEditingController promptController;
  final ScrollController timelineScrollController;
  final _CompactWorkspacePane compactPane;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<_CompactWorkspacePane> onCompactPaneChanged;
  final VoidCallback onSubmitPrompt;
  final Future<void> Function() onInterruptPrompt;
  final Future<void> Function() onCreateSession;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onPickAttachments;
  final ValueChanged<String> onRemoveAttachment;
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
    final activeChildSessions = controller.activeChildSessions;
    final todoLive =
        (controller.selectedStatus?.type ?? 'idle') != 'idle' ||
        questionRequest != null;
    void openActiveChildSession(String sessionId) {
      if (compact && compactPane != _CompactWorkspacePane.session) {
        onCompactPaneChanged(_CompactWorkspacePane.session);
      }
      onOpenSession(sessionId);
    }

    final activeSubSessionPanel = _ActiveSubSessionPanel(
      rootSessionId: controller.rootSelectedSession?.id,
      sessions: activeChildSessions,
      currentSessionId: controller.selectedSessionId,
      compact: compact,
      onOpenSession: openActiveChildSession,
    );
    final content = Column(
      children: <Widget>[
        if (!compact) activeSubSessionPanel,
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
                    showingCachedMessages:
                        controller.showingCachedSessionMessages,
                    error: controller.sessionLoadError,
                    messages: controller.orderedMessages,
                    sessions: allSessions,
                    selectedSession: selectedSession,
                    configSnapshot: configSnapshot,
                    shellToolDefaultExpanded: shellToolDefaultExpanded,
                    timelineProgressDetailsVisible:
                        timelineProgressDetailsVisible,
                    onForkMessage: onForkMessage,
                    onRevertMessage: onRevertMessage,
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
            interruptible: interruptiblePrompt,
            interrupting: interruptingPrompt,
            pickingAttachments: pickingAttachments,
            attachments: attachments,
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
            onInterrupt: onInterruptPrompt,
            onPickAttachments: onPickAttachments,
            onRemoveAttachment: onRemoveAttachment,
            onShareSession: onShareSession,
            onUnshareSession: onUnshareSession,
            onSummarizeSession: onSummarizeSession,
            onToggleTerminal: onToggleTerminal,
            onSelectSideTab: controller.setSideTab,
            onSubmit: onSubmitPrompt,
          ),
        if (terminalPanel != null)
          Offstage(
            offstage: !terminalPanelOpen,
            child: IgnorePointer(
              ignoring: !terminalPanelOpen,
              child: terminalPanel!,
            ),
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
          activeSubSessionPanel,
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

class _ActiveSubSessionPanel extends StatefulWidget {
  const _ActiveSubSessionPanel({
    required this.rootSessionId,
    required this.sessions,
    required this.currentSessionId,
    required this.compact,
    required this.onOpenSession,
  });

  final String? rootSessionId;
  final List<SessionSummary> sessions;
  final String? currentSessionId;
  final bool compact;
  final ValueChanged<String> onOpenSession;

  @override
  State<_ActiveSubSessionPanel> createState() => _ActiveSubSessionPanelState();
}

class _ActiveSubSessionPanelState extends State<_ActiveSubSessionPanel> {
  bool _collapsed = false;

  @override
  void didUpdateWidget(covariant _ActiveSubSessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameVisible =
        oldWidget.sessions.isEmpty && widget.sessions.isNotEmpty;
    if (oldWidget.rootSessionId != widget.rootSessionId || becameVisible) {
      _collapsed = false;
    }
  }

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shouldShow = widget.sessions.isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SizeTransition(
            sizeFactor: curved,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: !shouldShow
          ? const SizedBox(
              key: ValueKey<String>('active-subsessions-panel-hidden'),
            )
          : _ActiveSubSessionPanelBody(
              key: const ValueKey<String>('active-subsessions-panel'),
              sessions: widget.sessions,
              currentSessionId: widget.currentSessionId,
              compact: widget.compact,
              collapsed: _collapsed,
              onToggleCollapsed: _toggleCollapsed,
              onOpenSession: widget.onOpenSession,
            ),
    );
  }
}

class _ActiveSubSessionPanelBody extends StatelessWidget {
  const _ActiveSubSessionPanelBody({
    required this.sessions,
    required this.currentSessionId,
    required this.compact,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onOpenSession,
    super.key,
  });

  final List<SessionSummary> sessions;
  final String? currentSessionId;
  final bool compact;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final preview = sessions.take(2).map(_sessionDisplayTitle).join('  •  ');
    final showPreview = collapsed && !compact && preview.isNotEmpty;
    final idsSignature = sessions.map((session) => session.id).join('|');

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Column(
              children: <Widget>[
                InkWell(
                  onTap: onToggleCollapsed,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.hub_rounded,
                            size: 18,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.92,
                            ),
                          ),
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
                                      'Sub-agents Running',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${sessions.length}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: !showPreview
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        key: const ValueKey<String>(
                                          'active-subsessions-preview',
                                        ),
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.xs,
                                          right: AppSpacing.xs,
                                        ),
                                        child: Text(
                                          preview,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: surfaces.muted),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey<String>(
                            'active-subsessions-toggle-button',
                          ),
                          onPressed: onToggleCollapsed,
                          icon: AnimatedRotation(
                            turns: collapsed ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: surfaces.muted,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          splashRadius: 18,
                          tooltip: collapsed ? 'Expand' : 'Collapse',
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: collapsed
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final curved = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                );
                                return FadeTransition(
                                  opacity: curved,
                                  child: SizeTransition(
                                    sizeFactor: curved,
                                    axisAlignment: -1,
                                    child: child,
                                  ),
                                );
                              },
                              child: Wrap(
                                key: ValueKey<String>(
                                  'active-subsessions-list-$idsSignature',
                                ),
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: sessions
                                    .map(
                                      (session) => _ActiveSubSessionChip(
                                        session: session,
                                        selected:
                                            session.id == currentSessionId,
                                        compact: compact,
                                        onTap: () => onOpenSession(session.id),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          ),
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

class _ActiveSubSessionChip extends StatelessWidget {
  const _ActiveSubSessionChip({
    required this.session,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final SessionSummary session;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final selectedColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('active-subsession-chip-${session.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(maxWidth: compact ? 320 : 280),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.14)
                : surfaces.panelRaised.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: 0.52)
                  : surfaces.lineSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? selectedColor : const Color(0xFF64D7C4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _sessionDisplayTitle(session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? selectedColor : null,
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

String _sessionDisplayTitle(SessionSummary session) {
  final title = session.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  return session.id;
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

class _WorkspaceProjectLoadingView extends StatelessWidget {
  const _WorkspaceProjectLoadingView({
    required this.project,
    required this.compact,
    super.key,
  });

  final ProjectTarget? project;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final title =
        project?.title ?? projectDisplayLabel(project?.directory ?? '');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.background,
        borderRadius: compact
            ? null
            : const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.cardRadius),
              ),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: surfaces.panel,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Loading ${title.isEmpty ? 'project' : title}...',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Keeping the current workspace shell in place while the new project sessions and timeline load.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: surfaces.muted),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _WorkspaceProjectLoadingSkeleton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: surfaces.panel,
              border: Border(top: BorderSide(color: surfaces.lineSoft)),
            ),
            child: const _PromptComposerLoadingPlaceholder(),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceProjectLoadingSkeleton extends StatelessWidget {
  const _WorkspaceProjectLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('workspace-project-loading-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        _ShimmerBox(height: 18, widthFactor: 0.42, borderRadius: 9),
        SizedBox(height: AppSpacing.md),
        _ShimmerBox(height: 14, widthFactor: 1, borderRadius: 8),
        SizedBox(height: AppSpacing.sm),
        _ShimmerBox(height: 14, widthFactor: 0.86, borderRadius: 8),
        SizedBox(height: AppSpacing.lg),
        _ShimmerBox(height: 96, widthFactor: 1, borderRadius: 18),
      ],
    );
  }
}

class _PromptComposerLoadingPlaceholder extends StatelessWidget {
  const _PromptComposerLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaces.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ShimmerBox(height: 16, widthFactor: 0.18, borderRadius: 8),
          SizedBox(height: AppSpacing.md),
          _ShimmerBox(height: 44, widthFactor: 1, borderRadius: 14),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _ShimmerBox(
                  height: 28,
                  widthFactor: 1,
                  borderRadius: 999,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ShimmerBox(
                  height: 28,
                  widthFactor: 1,
                  borderRadius: 999,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ShimmerBox(
                  height: 28,
                  widthFactor: 1,
                  borderRadius: 999,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageTimeline extends StatelessWidget {
  const _MessageTimeline({
    required this.controller,
    required this.currentSessionId,
    required this.loading,
    required this.showingCachedMessages,
    required this.error,
    required this.messages,
    required this.sessions,
    required this.selectedSession,
    required this.configSnapshot,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onOpenSession,
    required this.onRetry,
    super.key,
  });

  final ScrollController controller;
  final String? currentSessionId;
  final bool loading;
  final bool showingCachedMessages;
  final String? error;
  final List<ChatMessage> messages;
  final List<SessionSummary> sessions;
  final SessionSummary? selectedSession;
  final ConfigSnapshot? configSnapshot;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final theme = Theme.of(context);
    if (loading && messages.isEmpty) {
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
    if (error != null && messages.isEmpty) {
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

    return Column(
      children: <Widget>[
        if (showingCachedMessages && loading)
          _TimelineCachedRefreshBanner(
            key: const ValueKey<String>('timeline-cached-refresh-banner'),
            shimmering: true,
            title: 'Refreshing cached messages...',
            message:
                'Showing the last saved snapshot while the server loads newer messages.',
          )
        else if (showingCachedMessages && error != null)
          _TimelineCachedRefreshBanner(
            key: const ValueKey<String>('timeline-cached-refresh-banner'),
            shimmering: false,
            title: 'Showing cached messages',
            message: error!,
            action: OutlinedButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Retry'),
            ),
          ),
        Expanded(
          child: SelectionArea(
            child: Scrollbar(
              controller: controller,
              thumbVisibility: true,
              interactive: true,
              child: ListView.separated(
                controller: controller,
                key: const PageStorageKey<String>(
                  'web-parity-message-timeline',
                ),
                restorationId: null,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                itemCount: messages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xl),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: SizedBox(
                        width: double.infinity,
                        child: _TimelineMessage(
                          currentSessionId: currentSessionId,
                          message: message,
                          sessions: sessions,
                          selectedSession: selectedSession,
                          configSnapshot: configSnapshot,
                          shellToolDefaultExpanded: shellToolDefaultExpanded,
                          timelineProgressDetailsVisible:
                              timelineProgressDetailsVisible,
                          onForkMessage: onForkMessage,
                          onRevertMessage: onRevertMessage,
                          onOpenSession: onOpenSession,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineCachedRefreshBanner extends StatelessWidget {
  const _TimelineCachedRefreshBanner({
    required this.title,
    required this.message,
    required this.shimmering,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final bool shimmering;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaces.panelRaised.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: shimmering
                    ? theme.colorScheme.primary.withValues(alpha: 0.34)
                    : surfaces.lineSoft,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    shimmering
                        ? Icons.sync_rounded
                        : Icons.history_toggle_off_rounded,
                    size: 18,
                    color: shimmering
                        ? theme.colorScheme.primary
                        : surfaces.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ShimmeringRichText(
                        key: const ValueKey<String>(
                          'timeline-cached-refresh-shimmer',
                        ),
                        active: shimmering,
                        text: TextSpan(
                          text: title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
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
    required this.interruptible,
    required this.interrupting,
    required this.pickingAttachments,
    required this.attachments,
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
    required this.onInterrupt,
    required this.onPickAttachments,
    required this.onRemoveAttachment,
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
  final bool interruptible;
  final bool interrupting;
  final bool pickingAttachments;
  final List<PromptAttachment> attachments;
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
  final Future<void> Function() onInterrupt;
  final Future<void> Function() onPickAttachments;
  final ValueChanged<String> onRemoveAttachment;
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

  bool get _canSubmit =>
      widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty;

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
    if (widget.interruptible) {
      if (!widget.interrupting) {
        await widget.onInterrupt();
      }
      return;
    }
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
    final submitIcon = widget.interruptible
        ? Icons.stop_rounded
        : Icons.arrow_upward_rounded;
    final submitEnabled = widget.interruptible
        ? !widget.interrupting
        : !(widget.submitting || !_canSubmit);
    final submitBusy = !widget.interruptible && widget.submitting;
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
                if (widget.attachments.isNotEmpty) ...<Widget>[
                  _ComposerAttachmentStrip(
                    attachments: widget.attachments,
                    onRemove: widget.onRemoveAttachment,
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
                    _ComposerIconButton(
                      key: const ValueKey<String>('composer-attach-button'),
                      icon: Icons.add_rounded,
                      onTap: widget.submitting || widget.pickingAttachments
                          ? null
                          : () {
                              unawaited(widget.onPickAttachments());
                            },
                      busy: widget.pickingAttachments,
                    ),
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
                      icon: submitIcon,
                      onTap: submitEnabled ? _handleSubmit : null,
                      filled: true,
                      busy: submitBusy,
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

class _ComposerAttachmentStrip extends StatelessWidget {
  const _ComposerAttachmentStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<PromptAttachment> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: attachments
            .map(
              (attachment) => _ComposerAttachmentTile(
                key: ValueKey<String>('composer-attachment-${attachment.id}'),
                attachment: attachment,
                onRemove: () => onRemove(attachment.id),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ComposerAttachmentTile extends StatelessWidget {
  const _ComposerAttachmentTile({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  final PromptAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final previewBytes = _attachmentDataBytes(attachment.url);
    return Container(
      width: attachment.isImage ? 112 : 200,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaces.panelMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (attachment.isImage && previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                previewBytes,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _AttachmentIcon(mime: attachment.mime),
              ),
            )
          else
            _AttachmentIcon(mime: attachment.mime),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  attachment.filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _attachmentLabel(attachment.mime),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            key: ValueKey<String>(
              'composer-attachment-remove-${attachment.id}',
            ),
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
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
    required this.selectedSession,
    required this.configSnapshot,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onOpenSession,
  });

  final String? currentSessionId;
  final ChatMessage message;
  final List<SessionSummary> sessions;
  final SessionSummary? selectedSession;
  final ConfigSnapshot? configSnapshot;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<String> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final isUser = message.info.role == 'user';
    if (isUser) {
      final attachments = message.parts
          .where(_isAttachmentFilePart)
          .toList(growable: false);
      final text = _messageBody(message);
      return _UserTimelineMessage(
        message: message,
        text: text,
        attachments: attachments,
        configSnapshot: configSnapshot,
        selectedSession: selectedSession,
        onForkMessage: onForkMessage,
        onRevertMessage: onRevertMessage,
      );
    }

    final orderedParts = _orderedTimelineParts(
      message,
      showProgressDetails: timelineProgressDetailsVisible,
    );
    final timelineItems = <Widget>[];
    for (var index = 0; index < orderedParts.length; index += 1) {
      final part = orderedParts[index];
      if (_isContextGroupToolPart(part)) {
        final contextParts = <ChatPart>[part];
        while (index + 1 < orderedParts.length &&
            _isContextGroupToolPart(orderedParts[index + 1])) {
          index += 1;
          contextParts.add(orderedParts[index]);
        }
        timelineItems.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _TimelineExploredContextPart(parts: contextParts),
          ),
        );
        continue;
      }
      timelineItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _TimelinePart(
            currentSessionId: currentSessionId,
            part: part,
            sessions: sessions,
            shellToolDefaultExpanded: shellToolDefaultExpanded,
            textStreamingActive: _messageIsActive(message),
            shimmerActive: _activityPartShimmerActive(
              part,
              messageIsActive: _messageIsActive(message),
            ),
            onOpenSession: onOpenSession,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: timelineItems,
    );
  }
}

class _UserTimelineMessage extends StatefulWidget {
  const _UserTimelineMessage({
    required this.message,
    required this.text,
    required this.attachments,
    required this.configSnapshot,
    required this.selectedSession,
    required this.onForkMessage,
    required this.onRevertMessage,
  });

  final ChatMessage message;
  final String text;
  final List<ChatPart> attachments;
  final ConfigSnapshot? configSnapshot;
  final SessionSummary? selectedSession;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;

  @override
  State<_UserTimelineMessage> createState() => _UserTimelineMessageState();
}

class _UserTimelineMessageState extends State<_UserTimelineMessage> {
  bool _hovering = false;
  String? _runningActionId;

  bool get _isOptimistic {
    return widget.message.info.metadata['_optimistic'] == true ||
        widget.message.info.id.startsWith('local_user_');
  }

  bool get _supportsHover {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  bool get _canCopy => widget.text.trim().isNotEmpty;

  bool get _canFork =>
      !_isOptimistic && widget.message.info.id.trim().isNotEmpty;

  bool get _canRevert {
    if (_isOptimistic || widget.message.info.id.trim().isEmpty) {
      return false;
    }
    return widget.selectedSession?.revertMessageId != widget.message.info.id;
  }

  bool get _showDesktopActions => _supportsHover && _hovering;

  Future<void> _copyMessage() async {
    if (!_canCopy || _runningActionId != null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: widget.text.trimRight()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied.')));
  }

  Future<void> _runAction(
    String actionId,
    Future<void> Function() action,
  ) async {
    if (_runningActionId != null) {
      return;
    }
    setState(() {
      _runningActionId = actionId;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _runningActionId = null;
        });
      }
    }
  }

  Future<void> _openTouchActionSheet() async {
    if (_supportsHover) {
      return;
    }
    final hasActions = _canCopy || _canFork || _canRevert;
    if (!hasActions) {
      return;
    }
    final head = _userMessageMetaHead(
      widget.message,
      widget.configSnapshot?.providerCatalog,
    );
    final stamp = _formatTimelineMessageStamp(context, widget.message);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).extension<AppSurfaces>()!.panel,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final surfaces = theme.extension<AppSurfaces>()!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (head.isNotEmpty || stamp.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    [
                      if (head.isNotEmpty) head,
                      if (stamp.isNotEmpty) stamp,
                    ].join('  •  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: surfaces.muted,
                    ),
                  ),
                ),
              if (_canFork)
                ListTile(
                  key: ValueKey<String>(
                    'timeline-user-action-sheet-fork-${widget.message.info.id}',
                  ),
                  leading: const Icon(Icons.call_split_rounded),
                  title: const Text('Fork to New Session'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      _runAction(
                        'fork',
                        () => widget.onForkMessage(widget.message),
                      ),
                    );
                  },
                ),
              if (_canRevert)
                ListTile(
                  key: ValueKey<String>(
                    'timeline-user-action-sheet-revert-${widget.message.info.id}',
                  ),
                  leading: const Icon(Icons.undo_rounded),
                  title: const Text('Revert Message'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      _runAction(
                        'revert',
                        () => widget.onRevertMessage(widget.message),
                      ),
                    );
                  },
                ),
              if (_canCopy)
                ListTile(
                  key: ValueKey<String>(
                    'timeline-user-action-sheet-copy-${widget.message.info.id}',
                  ),
                  leading: const Icon(Icons.content_copy_rounded),
                  title: const Text('Copy Message'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_copyMessage());
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final hasText = widget.text.trim().isNotEmpty;
    final hasActions = _canCopy || _canFork || _canRevert;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: MouseRegion(
          onEnter: _supportsHover
              ? (_) => setState(() {
                  _hovering = true;
                })
              : null,
          onExit: _supportsHover
              ? (_) => setState(() {
                  _hovering = false;
                })
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              GestureDetector(
                key: ValueKey<String>(
                  'timeline-user-message-${widget.message.info.id}',
                ),
                onLongPress: hasActions ? _openTouchActionSheet : null,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: surfaces.panelRaised,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: surfaces.lineSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.attachments.isNotEmpty)
                        _UserMessageAttachmentGrid(
                          attachments: widget.attachments,
                        ),
                      if (widget.attachments.isNotEmpty && hasText)
                        const SizedBox(height: AppSpacing.md),
                      if (hasText) _InlineCodeText(text: widget.text),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: !_showDesktopActions
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey<String>(
                          'timeline-user-actions-${widget.message.info.id}',
                        ),
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _UserMessageHoverBar(
                          message: widget.message,
                          configSnapshot: widget.configSnapshot,
                          canCopy: _canCopy,
                          canFork: _canFork,
                          canRevert: _canRevert,
                          runningActionId: _runningActionId,
                          onCopy: _copyMessage,
                          onFork: () => _runAction(
                            'fork',
                            () => widget.onForkMessage(widget.message),
                          ),
                          onRevert: () => _runAction(
                            'revert',
                            () => widget.onRevertMessage(widget.message),
                          ),
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

class _UserMessageHoverBar extends StatelessWidget {
  const _UserMessageHoverBar({
    required this.message,
    required this.configSnapshot,
    required this.canCopy,
    required this.canFork,
    required this.canRevert,
    required this.runningActionId,
    required this.onCopy,
    required this.onFork,
    required this.onRevert,
  });

  final ChatMessage message;
  final ConfigSnapshot? configSnapshot;
  final bool canCopy;
  final bool canFork;
  final bool canRevert;
  final String? runningActionId;
  final Future<void> Function() onCopy;
  final Future<void> Function() onFork;
  final Future<void> Function() onRevert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final head = _userMessageMetaHead(message, configSnapshot?.providerCatalog);
    final stamp = _formatTimelineMessageStamp(context, message);
    final meta = [
      if (head.isNotEmpty) head,
      if (stamp.isNotEmpty) stamp,
    ].join('  •  ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: surfaces.panel.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
              if (canFork)
                _UserMessageActionChip(
                  key: ValueKey<String>(
                    'timeline-user-action-fork-${message.info.id}',
                  ),
                  icon: Icons.call_split_rounded,
                  label: 'Fork to New Session',
                  busy: runningActionId == 'fork',
                  onTap: onFork,
                ),
              if (canRevert)
                _UserMessageActionChip(
                  key: ValueKey<String>(
                    'timeline-user-action-revert-${message.info.id}',
                  ),
                  icon: Icons.undo_rounded,
                  label: 'Revert Message',
                  busy: runningActionId == 'revert',
                  onTap: onRevert,
                ),
              if (canCopy)
                _UserMessageActionChip(
                  key: ValueKey<String>(
                    'timeline-user-action-copy-${message.info.id}',
                  ),
                  icon: Icons.content_copy_rounded,
                  label: 'Copy Message',
                  onTap: onCopy,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserMessageActionChip extends StatelessWidget {
  const _UserMessageActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : () => unawaited(onTap()),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: surfaces.panelRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 14, color: theme.colorScheme.onSurface),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelinePart extends StatelessWidget {
  const _TimelinePart({
    required this.currentSessionId,
    required this.part,
    required this.sessions,
    required this.shellToolDefaultExpanded,
    required this.textStreamingActive,
    required this.shimmerActive,
    required this.onOpenSession,
  });

  final String? currentSessionId;
  final ChatPart part;
  final List<SessionSummary> sessions;
  final bool shellToolDefaultExpanded;
  final bool textStreamingActive;
  final bool shimmerActive;
  final ValueChanged<String> onOpenSession;

  @override
  Widget build(BuildContext context) {
    if (part.type == 'text') {
      final body = _partText(part);
      if (body.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return _StreamingTextPart(
        key: ValueKey<String>('timeline-streaming-text-${part.id}'),
        partId: part.id,
        text: body,
        animate: _shouldAnimateStreamingText(part, textStreamingActive),
      );
    }
    if (part.type == 'compaction') {
      return _TimelineCompactionDivider(
        key: ValueKey<String>('timeline-compaction-${part.id}'),
        label: _partTitle(part),
      );
    }
    final body = _partText(part);
    final linkedSession = _partLinkedSession(
      part,
      sessions: sessions,
      currentSessionId: currentSessionId,
      fallbackSummary: _partSummary(part, body),
    );
    if (_isAttachmentFilePart(part)) {
      return _UserMessageAttachmentTile(part: part);
    }
    if (_isShellToolPart(part)) {
      return _ShellTimelinePart(
        key: ValueKey<String>('timeline-shell-${part.id}'),
        partId: part.id,
        title: _partTitle(part),
        subtitle: _shellToolSubtitle(part),
        body: _shellToolBody(part),
        shimmerActive: shimmerActive,
        defaultExpanded: shellToolDefaultExpanded,
      );
    }
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

class _TimelineCompactionDivider extends StatelessWidget {
  const _TimelineCompactionDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Divider(color: surfaces.lineSoft, thickness: 1, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: surfaces.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: surfaces.lineSoft, thickness: 1, height: 1),
          ),
        ],
      ),
    );
  }
}

class _UserMessageAttachmentGrid extends StatelessWidget {
  const _UserMessageAttachmentGrid({required this.attachments});

  final List<ChatPart> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: attachments
          .map((part) => _UserMessageAttachmentTile(part: part))
          .toList(growable: false),
    );
  }
}

class _UserMessageAttachmentTile extends StatelessWidget {
  const _UserMessageAttachmentTile({required this.part});

  final ChatPart part;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final url = _attachmentPartUrl(part);
    final mime = _attachmentPartMime(part) ?? 'application/octet-stream';
    final filename = _attachmentPartFilename(part);
    final previewBytes = url == null ? null : _attachmentDataBytes(url);
    return Container(
      width: mime.startsWith('image/') ? 164 : 220,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (mime.startsWith('image/') && previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                previewBytes,
                width: double.infinity,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: Center(child: _AttachmentIcon(mime: mime)),
                ),
              ),
            )
          else
            _AttachmentIcon(mime: mime),
          const SizedBox(height: AppSpacing.sm),
          Text(
            filename,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            _attachmentLabel(mime),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
        ],
      ),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({required this.mime});

  final String mime;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final icon = switch (mime) {
      final value when value.startsWith('image/') => Icons.image_outlined,
      'application/pdf' => Icons.picture_as_pdf_outlined,
      'text/plain' => Icons.description_outlined,
      _ => Icons.attach_file_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: surfaces.panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Icon(icon, size: 22, color: surfaces.muted),
    );
  }
}

class _ShellTimelinePart extends StatefulWidget {
  const _ShellTimelinePart({
    required this.partId,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.shimmerActive,
    required this.defaultExpanded,
    super.key,
  });

  final String partId;
  final String title;
  final String? subtitle;
  final String body;
  final bool shimmerActive;
  final bool defaultExpanded;

  @override
  State<_ShellTimelinePart> createState() => _ShellTimelinePartState();
}

class _ShellTimelinePartState extends State<_ShellTimelinePart> {
  Timer? _copiedTimer;
  late bool _expanded = widget.defaultExpanded;
  bool _copied = false;

  @override
  void didUpdateWidget(covariant _ShellTimelinePart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultExpanded != widget.defaultExpanded) {
      _expanded = widget.defaultExpanded;
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyBody() async {
    if (widget.body.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: widget.body));
    _copiedTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _copied = true;
    });
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _copied = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final pending = widget.shimmerActive;
    final subtitle = widget.subtitle?.trim() ?? '';
    final hasSubtitle = !pending && subtitle.isNotEmpty;
    final hasBody = widget.body.trim().isNotEmpty;
    final canToggle = hasBody && !pending;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.6,
      color: surfaces.muted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('timeline-shell-header-${widget.partId}'),
            onTap: canToggle
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _ShimmeringRichText(
                          key: ValueKey<String>(
                            'timeline-shell-shimmer-${widget.partId}',
                          ),
                          active: pending,
                          text: TextSpan(text: widget.title, style: titleStyle),
                        ),
                        if (hasSubtitle)
                          Text(
                            subtitle,
                            style: subtitleStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (canToggle)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: surfaces.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: !_expanded || !hasBody
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      top: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: surfaces.panelMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: Stack(
                      children: <Widget>[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            56,
                            AppSpacing.md,
                          ),
                          child: Text(
                            widget.body,
                            key: ValueKey<String>(
                              'timeline-shell-body-${widget.partId}',
                            ),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 14,
                              height: 1.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: Tooltip(
                            message: _copied ? 'Copied' : 'Copy',
                            waitDuration: const Duration(milliseconds: 100),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: surfaces.panel,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: surfaces.lineSoft),
                              ),
                              child: IconButton(
                                key: ValueKey<String>(
                                  'timeline-shell-copy-${widget.partId}',
                                ),
                                onPressed: _copyBody,
                                icon: Icon(
                                  _copied
                                      ? Icons.check_rounded
                                      : Icons.content_copy_rounded,
                                  size: 16,
                                ),
                                visualDensity: VisualDensity.compact,
                                splashRadius: 18,
                                tooltip: _copied ? 'Copied' : 'Copy',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
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

class _TimelineExploredContextPart extends StatefulWidget {
  const _TimelineExploredContextPart({required this.parts});

  final List<ChatPart> parts;

  @override
  State<_TimelineExploredContextPart> createState() =>
      _TimelineExploredContextPartState();
}

class _TimelineExploredContextPartState
    extends State<_TimelineExploredContextPart> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final summary = _contextToolSummary(widget.parts);
    final pending = widget.parts.any(_isPendingContextToolPart);
    final label = pending ? 'Exploring' : 'Explored';
    final summaryText = _contextToolSummaryLabel(summary);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );
    final detailStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.65,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>(
              'timeline-explored-context-header-${widget.parts.first.id}',
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ShimmeringRichText(
                      key: ValueKey<String>(
                        'timeline-explored-context-shimmer-${widget.parts.first.id}',
                      ),
                      active: pending,
                      text: TextSpan(
                        text: summaryText.isEmpty
                            ? label
                            : '$label $summaryText',
                        style: titleStyle,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: surfaces.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: !_expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      top: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.parts
                          .map(
                            (part) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                _contextToolDetailLine(part),
                                key: ValueKey<String>(
                                  'timeline-explored-context-detail-${part.id}',
                                ),
                                style: detailStyle,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
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
    duration: const Duration(milliseconds: 2200),
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

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.height,
    required this.widthFactor,
    required this.borderRadius,
  });

  final double height;
  final double widthFactor;
  final double borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final width = math.max(24.0, maxWidth * widget.widthFactor).toDouble();
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                final shimmerWidth = bounds.width <= 0 ? 1.0 : bounds.width;
                final start =
                    (shimmerWidth * 2.4 * _controller.value) -
                    shimmerWidth * 1.2;
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
                    shimmerWidth * 2.2,
                    bounds.height <= 0 ? 1 : bounds.height,
                  ),
                );
              },
              child: child,
            );
          },
          child: Container(
            width: width,
            height: widget.height,
            decoration: BoxDecoration(
              color: surfaces.panelRaised,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
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
      blocks.add(_StructuredCodeFenceBlock(language: language, code: code));
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

class _StructuredCodeFenceBlock extends StatefulWidget {
  const _StructuredCodeFenceBlock({required this.code, this.language});

  final String code;
  final String? language;

  @override
  State<_StructuredCodeFenceBlock> createState() =>
      _StructuredCodeFenceBlockState();
}

class _StructuredCodeFenceBlockState extends State<_StructuredCodeFenceBlock> {
  Timer? _copiedTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyCode() async {
    final code = widget.code;
    if (code.isEmpty) {
      return;
    }
    unawaited(Clipboard.setData(ClipboardData(text: code)));
    _copiedTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _copied = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code block copied.')));
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _copied = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final language = widget.language?.trim();
    final hasLanguage = language != null && language.isNotEmpty;
    final languageKey = hasLanguage ? language.toLowerCase() : 'plain';
    final highlightEnabled = AppScope.of(
      context,
    ).chatCodeBlockHighlightingEnabled;
    final syntaxTheme = _FilePreviewSyntaxTheme.from(
      theme: theme,
      surfaces: surfaces,
      baseStyle: GoogleFonts.ibmPlexMono(
        color: theme.colorScheme.onSurface,
        fontSize: 13,
        height: 1.6,
      ),
    );
    final syntaxLanguage = _previewSyntaxLanguageForFence(language);
    final canHighlight =
        highlightEnabled &&
        syntaxLanguage != _FilePreviewSyntaxLanguage.plainText;
    final highlightedSpans = canHighlight
        ? _buildHighlightedCodeBlockSpans(
            code: widget.code,
            language: language,
            syntaxTheme: syntaxTheme,
          )
        : null;

    return Container(
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
          Row(
            children: <Widget>[
              Expanded(
                child: hasLanguage
                    ? Text(
                        language.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: surfaces.muted,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Tooltip(
                message: _copied ? 'Copied' : 'Copy code',
                waitDuration: const Duration(milliseconds: 100),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaces.panelMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: surfaces.lineSoft),
                  ),
                  child: IconButton(
                    key: ValueKey<String>(
                      'timeline-code-copy-${language ?? 'plain'}',
                    ),
                    onPressed: _copyCode,
                    icon: Icon(
                      _copied
                          ? Icons.check_rounded
                          : Icons.content_copy_rounded,
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    tooltip: _copied ? 'Copied' : 'Copy code',
                  ),
                ),
              ),
            ],
          ),
          if (hasLanguage) const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: canHighlight
                ? SelectableText.rich(
                    key: ValueKey<String>(
                      'timeline-code-content-highlighted-$languageKey',
                    ),
                    TextSpan(
                      style: syntaxTheme.base,
                      children: highlightedSpans,
                    ),
                  )
                : SelectableText(
                    key: ValueKey<String>(
                      'timeline-code-content-plain-$languageKey',
                    ),
                    widget.code,
                    style: syntaxTheme.base,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StreamingTextPart extends StatefulWidget {
  const _StreamingTextPart({
    required this.partId,
    required this.text,
    required this.animate,
    super.key,
  });

  final String partId;
  final String text;
  final bool animate;

  @override
  State<_StreamingTextPart> createState() => _StreamingTextPartState();
}

class _StreamingTextPartState extends State<_StreamingTextPart> {
  static const Duration _revealStep = Duration(milliseconds: 55);
  static const Duration _fadeDuration = Duration(milliseconds: 220);

  late _StreamingWordSequence _sequence;
  late int _visibleChunkCount;
  int? _revealingChunkIndex;
  int _animationEpoch = 0;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _sequence = _tokenizeStreamingWords(widget.text);
    if (widget.animate &&
        widget.text.trim().isNotEmpty &&
        _sequence.chunks.isNotEmpty) {
      _visibleChunkCount = 1;
      _revealingChunkIndex = 0;
      _animationEpoch = 1;
      _scheduleReveal();
      return;
    }
    _visibleChunkCount = _sequence.chunks.length;
    _revealingChunkIndex = null;
  }

  @override
  void didUpdateWidget(covariant _StreamingTextPart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSequence = _tokenizeStreamingWords(widget.text);
    final appendOnly = oldWidget.text.isEmpty
        ? widget.text.trim().isNotEmpty
        : widget.text.startsWith(oldWidget.text);
    if (!widget.animate || widget.text.trim().isEmpty || !appendOnly) {
      _cancelRevealTimer();
      _sequence = nextSequence;
      _visibleChunkCount = nextSequence.chunks.length;
      _revealingChunkIndex = null;
      return;
    }

    _sequence = nextSequence;
    if (_visibleChunkCount > _sequence.chunks.length) {
      _visibleChunkCount = _sequence.chunks.length;
    }
    if (_visibleChunkCount < _sequence.chunks.length) {
      _revealNextChunk(immediate: true);
    }
  }

  @override
  void dispose() {
    _cancelRevealTimer();
    super.dispose();
  }

  void _cancelRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = null;
  }

  void _scheduleReveal() {
    if (_revealTimer != null || _visibleChunkCount >= _sequence.chunks.length) {
      return;
    }
    _revealTimer = Timer(_revealStep, () {
      _revealTimer = null;
      if (!mounted) {
        return;
      }
      _revealNextChunk();
    });
  }

  void _revealNextChunk({bool immediate = false}) {
    if (_visibleChunkCount >= _sequence.chunks.length) {
      _cancelRevealTimer();
      return;
    }
    void update() {
      _revealingChunkIndex = _visibleChunkCount;
      _visibleChunkCount += 1;
      _animationEpoch += 1;
    }

    if (immediate) {
      setState(update);
    } else {
      setState(update);
    }
    _scheduleReveal();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || widget.text.trim().isEmpty) {
      return _StructuredTextBlock(text: widget.text);
    }

    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.8);
    final transparentStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: Colors.transparent,
    );
    final spans = <InlineSpan>[];
    if (_sequence.leadingWhitespace.isNotEmpty) {
      spans.add(TextSpan(text: _sequence.leadingWhitespace));
    }
    for (var index = 0; index < _visibleChunkCount; index += 1) {
      final chunk = _sequence.chunks[index];
      if (_revealingChunkIndex == index) {
        final revealEpoch = _animationEpoch;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: TweenAnimationBuilder<double>(
              key: ValueKey<String>(
                'streaming-text-fade-${widget.partId}-$index-$_animationEpoch',
              ),
              tween: Tween<double>(begin: 0, end: 1),
              duration: _fadeDuration,
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (!mounted ||
                    _revealingChunkIndex != index ||
                    _animationEpoch != revealEpoch) {
                  return;
                }
                setState(() {
                  if (_revealingChunkIndex == index &&
                      _animationEpoch == revealEpoch) {
                    _revealingChunkIndex = null;
                  }
                });
              },
              child: Text(
                chunk.text,
                key: ValueKey<String>(
                  'streaming-text-chunk-${widget.partId}-$index',
                ),
                style: baseStyle,
              ),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: chunk.text));
      }
    }
    for (
      var index = _visibleChunkCount;
      index < _sequence.chunks.length;
      index += 1
    ) {
      spans.add(
        TextSpan(text: _sequence.chunks[index].text, style: transparentStyle),
      );
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      key: ValueKey<String>('streaming-text-${widget.partId}'),
    );
  }
}

class _StreamingWordSequence {
  const _StreamingWordSequence({
    required this.leadingWhitespace,
    required this.chunks,
  });

  final String leadingWhitespace;
  final List<_StreamingWordChunk> chunks;
}

class _StreamingWordChunk {
  const _StreamingWordChunk({required this.text});

  final String text;
}

_StreamingWordSequence _tokenizeStreamingWords(String text) {
  final leadingMatch = RegExp(r'^\s*').firstMatch(text);
  final leadingWhitespace = leadingMatch?.group(0) ?? '';
  final body = text.substring(leadingWhitespace.length);
  final matches = RegExp(r'\S+\s*').allMatches(body);
  final chunks = matches
      .map((match) => _StreamingWordChunk(text: match.group(0) ?? ''))
      .toList(growable: false);
  return _StreamingWordSequence(
    leadingWhitespace: leadingWhitespace,
    chunks: chunks,
  );
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
      .where((part) => part.type == 'text')
      .map(_partText)
      .where((value) => value.isNotEmpty)
      .join('\n\n');
}

String _userMessageMetaHead(
  ChatMessage message,
  ProviderCatalog? providerCatalog,
) {
  final info = message.info;
  final agent = info.agent?.trim() ?? '';
  final model = _resolvedUserMessageModelLabel(message, providerCatalog);
  final parts = <String>[
    if (agent.isNotEmpty) agent,
    if (model.isNotEmpty) model,
  ];
  return parts.join('  •  ');
}

String _resolvedUserMessageModelLabel(
  ChatMessage message,
  ProviderCatalog? providerCatalog,
) {
  final providerId = message.info.providerId?.trim() ?? '';
  final modelId = message.info.modelId?.trim() ?? '';
  if (modelId.isEmpty) {
    return '';
  }
  if (providerCatalog == null || providerId.isEmpty) {
    return modelId;
  }
  final provider = _findProviderDefinition(providerCatalog, providerId);
  final model = provider == null
      ? null
      : _findProviderModelDefinition(provider, providerId, modelId);
  final providerLabel = provider?.name.trim() ?? '';
  final modelLabel = model?.name.trim().isNotEmpty == true
      ? model!.name.trim()
      : modelId;
  if (providerLabel.isEmpty) {
    return modelLabel;
  }
  return '$providerLabel · $modelLabel';
}

ProviderDefinition? _findProviderDefinition(
  ProviderCatalog catalog,
  String providerId,
) {
  for (final provider in catalog.providers) {
    if (provider.id == providerId) {
      return provider;
    }
  }
  return null;
}

ProviderModelDefinition? _findProviderModelDefinition(
  ProviderDefinition provider,
  String providerId,
  String modelId,
) {
  final direct = provider.models['$providerId/$modelId'];
  if (direct != null) {
    return direct;
  }
  for (final model in provider.models.values) {
    if (model.id == modelId) {
      return model;
    }
  }
  return null;
}

String _formatTimelineMessageStamp(BuildContext context, ChatMessage message) {
  final timestamp = message.info.createdAt ?? message.info.completedAt;
  if (timestamp == null) {
    return '';
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.MMMd(locale).add_jm().format(timestamp.toLocal());
}

bool _messageIsActive(ChatMessage message) {
  return message.info.role == 'assistant' && message.info.completedAt == null;
}

List<ChatPart> _orderedTimelineParts(
  ChatMessage message, {
  required bool showProgressDetails,
}) {
  final visible = message.parts
      .where(
        (part) => _shouldRenderTimelinePart(
          part,
          showProgressDetails: showProgressDetails,
        ),
      )
      .toList(growable: false);
  if (visible.length <= 1 || !_messageIsActive(message)) {
    return visible;
  }

  final leading = <ChatPart>[];
  final trailingActive = <ChatPart>[];
  for (final part in visible) {
    if (_activityPartShimmerActive(part, messageIsActive: true)) {
      trailingActive.add(part);
    } else {
      leading.add(part);
    }
  }
  if (trailingActive.isEmpty || leading.isEmpty) {
    return visible;
  }
  return <ChatPart>[...leading, ...trailingActive];
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
  if (part.type == 'text') {
    return _resolvedRawPartText(part);
  }
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
    'tool' => _toolTitle(part),
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

String _toolTitle(ChatPart part) {
  final value = part.tool?.trim().toLowerCase();
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
    'skill' => _skillToolName(part) ?? 'Skill',
    final other => _titleCase(other),
  };
}

String? _skillToolName(ChatPart part) {
  return _firstNonEmpty(<String?>[
    _nestedString(part.metadata, const <String>['state', 'input', 'name']),
    _nestedString(part.metadata, const <String>['input', 'name']),
    _nestedString(part.metadata, const <String>['name']),
    _nestedString(part.metadata, const <String>['state', 'name']),
    _nestedString(part.metadata, const <String>['state', 'title']),
  ]);
}

bool _shouldRenderTimelinePart(
  ChatPart part, {
  required bool showProgressDetails,
}) {
  if (part.type == 'text') {
    return _resolvedRawPartText(part).trim().isNotEmpty;
  }
  if (_isProgressDetailPart(part) && !showProgressDetails) {
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

bool _isProgressDetailPart(ChatPart part) {
  if (_isTodoWriteToolPart(part)) {
    return true;
  }
  return part.type == 'step-start' || part.type == 'step-finish';
}

bool _shouldAnimateStreamingText(ChatPart part, bool messageIsActive) {
  if (!messageIsActive || part.type != 'text') {
    return false;
  }
  return part.metadata['_streaming'] == true ||
      part.metadata.containsKey('content');
}

bool _isAttachmentFilePart(ChatPart part) {
  return part.type == 'file' && (_attachmentPartUrl(part)?.isNotEmpty ?? false);
}

String? _attachmentPartUrl(ChatPart part) {
  final value = part.metadata['url']?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _attachmentPartMime(ChatPart part) {
  final value = part.metadata['mime']?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String _attachmentPartFilename(ChatPart part) {
  final value = part.filename?.trim();
  if (value != null && value.isNotEmpty) {
    return value;
  }
  final metadataValue = part.metadata['filename']?.toString().trim();
  if (metadataValue != null && metadataValue.isNotEmpty) {
    return metadataValue;
  }
  return 'Attachment';
}

Uint8List? _attachmentDataBytes(String url) {
  if (!url.startsWith('data:')) {
    return null;
  }
  final commaIndex = url.indexOf(',');
  if (commaIndex == -1 || commaIndex == url.length - 1) {
    return null;
  }
  try {
    return base64Decode(url.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

String _attachmentLabel(String mime) {
  if (mime.startsWith('image/')) {
    return mime.replaceFirst('image/', '').toUpperCase();
  }
  if (mime == 'application/pdf') {
    return 'PDF';
  }
  if (mime == 'text/plain') {
    return 'Text file';
  }
  return mime;
}

String _resolvedRawPartText(ChatPart part) {
  final textCandidate = part.text;
  if (textCandidate != null && textCandidate.trim().isNotEmpty) {
    return textCandidate;
  }
  final metadataText = part.metadata['text']?.toString();
  if (metadataText != null && metadataText.trim().isNotEmpty) {
    return metadataText;
  }
  final content = part.metadata['content']?.toString();
  if (content != null && content.trim().isNotEmpty) {
    return content;
  }
  return '';
}

bool _isQuestionToolPart(ChatPart part) {
  return part.type == 'tool' && part.tool?.trim().toLowerCase() == 'question';
}

bool _isTodoWriteToolPart(ChatPart part) {
  return part.type == 'tool' && part.tool?.trim().toLowerCase() == 'todowrite';
}

bool _isShellToolPart(ChatPart part) {
  return part.type == 'tool' && part.tool?.trim().toLowerCase() == 'bash';
}

bool _isContextGroupToolPart(ChatPart part) {
  final tool = part.tool?.trim().toLowerCase();
  return part.type == 'tool' &&
      (tool == 'read' || tool == 'glob' || tool == 'grep' || tool == 'list');
}

bool _isPendingContextToolPart(ChatPart part) {
  if (!_isContextGroupToolPart(part)) {
    return false;
  }
  final status = _toolStateStatus(part);
  return status == 'pending' || status == 'running';
}

String? _toolStateStatus(ChatPart part) {
  return _nestedValue(part.metadata, const <String>[
    'state',
    'status',
  ])?.toString().trim().toLowerCase();
}

_ContextToolSummary _contextToolSummary(List<ChatPart> parts) {
  var read = 0;
  var search = 0;
  var list = 0;
  for (final part in parts) {
    switch (part.tool?.trim().toLowerCase()) {
      case 'read':
        read += 1;
      case 'glob':
      case 'grep':
        search += 1;
      case 'list':
        list += 1;
    }
  }
  return _ContextToolSummary(read: read, search: search, list: list);
}

String _contextToolSummaryLabel(_ContextToolSummary summary) {
  final segments = <String>[
    if (summary.read > 0) '${summary.read} read${summary.read == 1 ? '' : 's'}',
    if (summary.search > 0)
      '${summary.search} search${summary.search == 1 ? '' : 'es'}',
    if (summary.list > 0) '${summary.list} list${summary.list == 1 ? '' : 's'}',
  ];
  return segments.join(', ');
}

String _contextToolDetailLine(ChatPart part) {
  final tool = part.tool?.trim().toLowerCase();
  switch (tool) {
    case 'read':
      final filePath = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>[
          'state',
          'input',
          'filePath',
        ]),
        _nestedString(part.metadata, const <String>['input', 'filePath']),
        _nestedString(part.metadata, const <String>['filePath']),
      ]);
      final offset = _firstNonEmpty(<String?>[
        _nestedValue(part.metadata, const <String>[
          'state',
          'input',
          'offset',
        ])?.toString(),
        _nestedValue(part.metadata, const <String>[
          'input',
          'offset',
        ])?.toString(),
        _nestedValue(part.metadata, const <String>['offset'])?.toString(),
      ]);
      final limit = _firstNonEmpty(<String?>[
        _nestedValue(part.metadata, const <String>[
          'state',
          'input',
          'limit',
        ])?.toString(),
        _nestedValue(part.metadata, const <String>[
          'input',
          'limit',
        ])?.toString(),
        _nestedValue(part.metadata, const <String>['limit'])?.toString(),
      ]);
      return _joinContextToolDetail(
        'Read',
        _basename(filePath ?? '').trim().isEmpty
            ? 'file'
            : _basename(filePath ?? '').trim(),
        <String>[
          if (offset != null) 'offset=$offset',
          if (limit != null) 'limit=$limit',
        ],
      );
    case 'list':
      final path = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>['state', 'input', 'path']),
        _nestedString(part.metadata, const <String>['input', 'path']),
        _nestedString(part.metadata, const <String>['path']),
      ]);
      return _joinContextToolDetail(
        'List',
        _dirname(path ?? '/'),
        const <String>[],
      );
    case 'glob':
      final path = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>['state', 'input', 'path']),
        _nestedString(part.metadata, const <String>['input', 'path']),
        _nestedString(part.metadata, const <String>['path']),
      ]);
      final pattern = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>[
          'state',
          'input',
          'pattern',
        ]),
        _nestedString(part.metadata, const <String>['input', 'pattern']),
        _nestedString(part.metadata, const <String>['pattern']),
      ]);
      return _joinContextToolDetail('Search', _dirname(path ?? '/'), <String>[
        if (pattern != null && pattern.isNotEmpty) 'pattern=$pattern',
      ]);
    case 'grep':
      final path = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>['state', 'input', 'path']),
        _nestedString(part.metadata, const <String>['input', 'path']),
        _nestedString(part.metadata, const <String>['path']),
      ]);
      final pattern = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>[
          'state',
          'input',
          'pattern',
        ]),
        _nestedString(part.metadata, const <String>['input', 'pattern']),
        _nestedString(part.metadata, const <String>['pattern']),
      ]);
      final include = _firstNonEmpty(<String?>[
        _nestedString(part.metadata, const <String>[
          'state',
          'input',
          'include',
        ]),
        _nestedString(part.metadata, const <String>['input', 'include']),
        _nestedString(part.metadata, const <String>['include']),
      ]);
      return _joinContextToolDetail('Search', _dirname(path ?? '/'), <String>[
        if (pattern != null && pattern.isNotEmpty) 'pattern=$pattern',
        if (include != null && include.isNotEmpty) 'include=$include',
      ]);
    default:
      return _partSummary(part, _partText(part));
  }
}

String _joinContextToolDetail(
  String title,
  String subtitle,
  List<String> args,
) {
  final segments = <String>[
    title,
    if (subtitle.trim().isNotEmpty) subtitle.trim(),
    ...args,
  ];
  return segments.join('  ');
}

String _basename(String value) {
  if (value.isEmpty) {
    return value;
  }
  final normalized = value.replaceAll('\\', '/');
  final segments = normalized.split('/');
  return segments.isEmpty ? value : segments.last;
}

String _dirname(String value) {
  if (value.isEmpty) {
    return '/';
  }
  var normalized = value.replaceAll('\\', '/').trim();
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final index = normalized.lastIndexOf('/');
  if (index < 0) {
    return normalized;
  }
  if (index == 0) {
    return '/';
  }
  return normalized.substring(0, index);
}

class _ContextToolSummary {
  const _ContextToolSummary({
    required this.read,
    required this.search,
    required this.list,
  });

  final int read;
  final int search;
  final int list;
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

String? _shellToolSubtitle(ChatPart part) {
  return _firstNonEmpty(<String?>[
    _nestedString(part.metadata, const <String>[
      'state',
      'input',
      'description',
    ]),
    _nestedString(part.metadata, const <String>['input', 'description']),
    _nestedString(part.metadata, const <String>['description']),
    _nestedString(part.metadata, const <String>['state', 'title']),
  ]);
}

String _shellToolBody(ChatPart part) {
  final command = _firstNonEmpty(<String?>[
    _nestedString(part.metadata, const <String>['state', 'input', 'command']),
    _nestedString(part.metadata, const <String>['input', 'command']),
    _nestedString(part.metadata, const <String>['command']),
  ]);
  final output = _stringifyShellOutput(
    _nestedValue(part.metadata, const <String>['state', 'output']) ??
        _nestedValue(part.metadata, const <String>['output']) ??
        part.text,
  );
  if (command == null || command.isEmpty) {
    return output;
  }
  if (output.isEmpty) {
    return '\$ $command';
  }
  return '\$ $command\n\n$output';
}

String _stringifyShellOutput(Object? value) {
  if (value == null) {
    return '';
  }
  final text = switch (value) {
    final String text => text,
    final Map value => const JsonEncoder.withIndent(
      '  ',
    ).convert(value.cast<Object?, Object?>()),
    final List value => const JsonEncoder.withIndent('  ').convert(value),
    _ => value.toString(),
  };
  return text.isEmpty ? '' : text.replaceAll(_ansiEscapePattern, '');
}

final RegExp _ansiEscapePattern = RegExp(
  r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])',
);

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
              selectedPath: controller.selectedReviewPath,
              diff: controller.reviewDiff,
              loadingDiff: controller.loadingReviewDiff,
              diffError: controller.reviewDiffError,
              onSelectFile: (path) {
                unawaited(controller.selectReviewFile(path));
              },
            ),
            WorkspaceSideTab.files => _FilesPanel(
              bundle: controller.fileBundle,
              loadingPreview: controller.loadingFilePreview,
              expandedDirectories: controller.expandedFileDirectories,
              loadingDirectoryPath: controller.loadingFileDirectoryPath,
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
      ],
    );
  }
}

class _ReviewPanel extends StatefulWidget {
  const _ReviewPanel({
    required this.statuses,
    required this.selectedPath,
    required this.diff,
    required this.loadingDiff,
    required this.diffError,
    required this.onSelectFile,
  });

  final List<FileStatusSummary> statuses;
  final String? selectedPath;
  final FileDiffSummary? diff;
  final bool loadingDiff;
  final String? diffError;
  final ValueChanged<String> onSelectFile;

  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  static const double _defaultPreviewHeight = 280;
  static const double _minPreviewHeight = 160;
  static const double _minListHeight = 220;

  double _previewHeight = _defaultPreviewHeight;

  void _resizePreview(double deltaDy, double availableHeight) {
    final maxPreviewHeight = (availableHeight - _minListHeight).clamp(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    if (widget.statuses.isEmpty) {
      return Center(
        child: Text(
          'No file changes yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
      );
    }
    final hasPreview = widget.selectedPath != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 700.0;
        final previewHeight = hasPreview
            ? _previewHeight.clamp(
                _minPreviewHeight,
                (availableHeight - _minListHeight).clamp(
                  _minPreviewHeight,
                  availableHeight,
                ),
              )
            : 0.0;

        return Column(
          children: <Widget>[
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: widget.statuses.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final item = widget.statuses[index];
                  final statusColor = _reviewStatusColor(item.status, surfaces);
                  final addedColor = item.added > 0
                      ? surfaces.success
                      : surfaces.muted;
                  final removedColor = item.removed > 0
                      ? surfaces.danger
                      : surfaces.muted;
                  final selected = item.path == widget.selectedPath;
                  return ListTile(
                    selected: selected,
                    tileColor: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : null,
                    leading: Icon(
                      _reviewStatusIcon(item.status),
                      color: statusColor,
                      size: 18,
                    ),
                    title: Text(
                      item.path,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text.rich(
                      key: ValueKey<String>('review-status-${item.path}'),
                      TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: item.status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '  •  '),
                          TextSpan(
                            text: '+${item.added}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: addedColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: '-${item.removed}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: removedColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () => widget.onSelectFile(item.path),
                  );
                },
              ),
            ),
            if (hasPreview)
              Container(
                key: const ValueKey<String>('review-preview-panel'),
                height: previewHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: surfaces.lineSoft)),
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
                        _resizePreview(details.delta.dy, availableHeight);
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: SizedBox(
                          height: 20,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: surfaces.muted.withValues(alpha: 0.75),
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
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                widget.selectedPath!,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: surfaces.muted,
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
                                        'No diff output for this file.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: surfaces.muted),
                                      ),
                                    )
                                  : _ReviewDiffView(diff: widget.diff!),
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

class _ReviewDiffView extends StatelessWidget {
  const _ReviewDiffView({required this.diff});

  final FileDiffSummary diff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: BackdropFilter(
        key: const ValueKey<String>('review-diff-blur'),
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.045),
                surfaces.panelRaised.withValues(alpha: 0.7),
                surfaces.panelMuted.withValues(alpha: 0.62),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SingleChildScrollView(
                    child: SelectableText.rich(
                      TextSpan(
                        children: _buildReviewDiffSpans(
                          diff.content,
                          theme: theme,
                          surfaces: surfaces,
                        ),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
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

List<InlineSpan> _buildReviewDiffSpans(
  String content, {
  required ThemeData theme,
  required AppSurfaces surfaces,
}) {
  if (content.isEmpty) {
    return const <InlineSpan>[];
  }

  final lines = content.split('\n');
  final spans = <InlineSpan>[];
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    final style = _reviewDiffLineStyle(line, theme: theme, surfaces: surfaces);
    spans.add(TextSpan(text: line, style: style));
    if (index != lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }
  return spans;
}

TextStyle? _reviewDiffLineStyle(
  String line, {
  required ThemeData theme,
  required AppSurfaces surfaces,
}) {
  final base = theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    height: 1.45,
    color: theme.colorScheme.onSurface,
  );
  if (line.startsWith('+++') || line.startsWith('---')) {
    return base?.copyWith(color: surfaces.warning, fontWeight: FontWeight.w700);
  }
  if (line.startsWith('@@')) {
    return base?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
  }
  if (line.startsWith('diff --git') ||
      line.startsWith('index ') ||
      line.startsWith('new file') ||
      line.startsWith('deleted file') ||
      line.startsWith('rename ')) {
    return base?.copyWith(color: surfaces.warning);
  }
  if (line.startsWith('+') && !line.startsWith('+++')) {
    return base?.copyWith(
      color: surfaces.success,
      backgroundColor: surfaces.success.withValues(alpha: 0.08),
    );
  }
  if (line.startsWith('-') && !line.startsWith('---')) {
    return base?.copyWith(
      color: surfaces.danger,
      backgroundColor: surfaces.danger.withValues(alpha: 0.08),
    );
  }
  return base;
}

class _FilesPanel extends StatefulWidget {
  const _FilesPanel({
    required this.bundle,
    required this.loadingPreview,
    required this.expandedDirectories,
    required this.loadingDirectoryPath,
    required this.onSelectFile,
    required this.onToggleDirectory,
  });

  final FileBrowserBundle? bundle;
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

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final bundle = widget.bundle;
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
    final visibleNodes = _buildVisibleFileNodes(
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
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: visibleNodes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final entry = visibleNodes[index];
                  final node = entry.node;
                  final selected = node.path == bundle.selectedPath;
                  final isDirectory = node.type == 'directory';
                  return ListTile(
                    dense: true,
                    selected: selected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    contentPadding: EdgeInsets.only(
                      left: AppSpacing.md + (entry.depth * 18.0),
                      right: AppSpacing.md,
                    ),
                    tileColor: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12)
                        : null,
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
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          isDirectory
                              ? (entry.expanded
                                    ? Icons.folder_open_outlined
                                    : Icons.folder_outlined)
                              : Icons.insert_drive_file_outlined,
                        ),
                      ],
                    ),
                    title: Text(node.name),
                    subtitle: Text(node.path),
                    trailing: entry.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: () => isDirectory
                        ? widget.onToggleDirectory(node.path)
                        : widget.onSelectFile(node.path),
                  );
                },
              ),
            ),
            if (hasPreview)
              Container(
                key: const ValueKey<String>('files-preview-panel'),
                height: previewHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: surfaces.lineSoft)),
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
                          height: 20,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: surfaces.muted.withValues(alpha: 0.75),
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
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (bundle.selectedPath != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Text(
                                  bundle.selectedPath!,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: surfaces.muted),
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
                                        'Preview unavailable for this item.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: surfaces.muted),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: surfaces.panelMuted,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.md,
                                        ),
                                        border: Border.all(
                                          color: surfaces.lineSoft,
                                        ),
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, previewConstraints) {
                                          return SingleChildScrollView(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minWidth:
                                                    previewConstraints.maxWidth,
                                              ),
                                              child: _HighlightedFilePreview(
                                                path: bundle.selectedPath,
                                                content:
                                                    bundle.preview!.content,
                                              ),
                                            ),
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

class _HighlightedFilePreview extends StatelessWidget {
  const _HighlightedFilePreview({required this.path, required this.content});

  final String? path;
  final String content;

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
    final spans = _buildHighlightedFilePreviewSpans(
      content: content,
      path: path,
      syntaxTheme: syntaxTheme,
    );

    return SelectableText.rich(
      key: const ValueKey<String>('files-preview-content'),
      TextSpan(style: syntaxTheme.base, children: spans),
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

List<InlineSpan> _buildHighlightedFilePreviewSpans({
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
      const TextSpan(
        text:
            '\n\n[Syntax highlighting paused for the rest of this preview because the file is very large.]',
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
      const TextSpan(
        text:
            '\n\n[Syntax highlighting paused for the rest of this code block because it is very large.]',
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final decimal = NumberFormat.decimalPattern(locale);
    final currency = NumberFormat.simpleCurrency(locale: locale, name: 'USD');
    final metrics = widget.metrics;
    final snapshot = metrics.context;
    final systemPrompt = widget.systemPrompt;
    final breakdown = widget.breakdown;
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
        value: decimal.format(widget.userMessageCount),
      ),
      _ContextStatEntry(
        label: 'Assistant Messages',
        value: decimal.format(widget.assistantMessageCount),
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
          key: PageStorageKey<String>(
            'context-raw-message-expansion-${message.info.id}',
          ),
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

Color _sessionContextUsageColor(
  int? usagePercent,
  ThemeData theme,
  AppSurfaces surfaces,
) {
  if (usagePercent == null) {
    return surfaces.muted;
  }
  if (usagePercent >= 90) {
    return surfaces.danger;
  }
  if (usagePercent >= 75) {
    return surfaces.warning;
  }
  return theme.colorScheme.primary;
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
