import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/event_stream_service.dart';
import '../../core/network/live_event_applier.dart';
import '../../core/network/sse_connection_monitor.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../../core/spec/capability_registry.dart';
import '../../core/spec/raw_json_document.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../chat/chat_part_view.dart';
import '../chat/chat_service.dart';
import '../chat/session_action_service.dart';
import '../files/file_browser_service.dart';
import '../files/file_models.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import '../requests/pending_request_notification_service.dart';
import '../requests/pending_request_sound_service.dart';
import '../requests/request_alerts.dart';
import '../requests/request_models.dart';
import '../requests/request_event_applier.dart';
import '../requests/request_service.dart';
import '../settings/cache_settings_sheet.dart';
import '../settings/config_service.dart';
import '../settings/config_edit_preview.dart';
import '../settings/integration_status_service.dart';
import 'shell_derived_data.dart';
import '../terminal/terminal_service.dart';
import '../tools/todo_models.dart';
import '../tools/todo_service.dart';

const _motionFast = Duration(milliseconds: 220);
const _motionMedium = Duration(milliseconds: 320);
const _activityCycle = Duration(milliseconds: 1400);
const int _shellFileCacheNodeLimit = 24;
const int _shellFileCacheSearchResultLimit = 12;
const int _shellFileCacheStatusLimit = 24;
const int _shellFileCacheTextMatchLimit = 4;
const int _shellFileCacheTextMatchLineLimit = 280;
const int _shellFileCacheSymbolLimit = 4;
const int _shellFileCachePayloadSoftLimit = 256 * 1024;
const int _shellFilePreviewCharacterLimit = 6000;

class _ComposerSubmissionOptions {
  const _ComposerSubmissionOptions({
    this.providerId,
    this.modelId,
    this.reasoning,
  });

  final String? providerId;
  final String? modelId;
  final String? reasoning;
}

class _ComposerModelOption {
  const _ComposerModelOption({
    required this.key,
    required this.label,
    required this.modelId,
    this.providerId,
    this.reasoningValues = const <String>[],
  });

  final String key;
  final String label;
  final String modelId;
  final String? providerId;
  final List<String> reasoningValues;
}

enum _ShellPrimaryDestination { sessions, chat, context, settings }

Widget _fadeSlideTransition(
  Widget child,
  Animation<double> animation, {
  Offset begin = const Offset(0, 0.04),
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
      child: child,
    ),
  );
}

class OpenCodeShellScreen extends StatefulWidget {
  const OpenCodeShellScreen({
    required this.profile,
    required this.project,
    required this.capabilities,
    required this.onExit,
    this.availableProjects = const <ProjectTarget>[],
    this.projectPanelError,
    this.onSelectProject,
    this.onReloadProjects,
    this.chatService,
    this.todoService,
    this.projectStore,
    this.fileBrowserService,
    this.requestService,
    this.configService,
    this.integrationStatusService,
    this.eventStreamService,
    this.terminalService,
    this.pendingRequestNotificationService,
    this.pendingRequestSoundService,
    super.key,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final ChatService? chatService;
  final TodoService? todoService;
  final ProjectStore? projectStore;
  final FileBrowserService? fileBrowserService;
  final RequestService? requestService;
  final ConfigService? configService;
  final IntegrationStatusService? integrationStatusService;
  final EventStreamService? eventStreamService;
  final TerminalService? terminalService;
  final PendingRequestNotificationService? pendingRequestNotificationService;
  final PendingRequestSoundService? pendingRequestSoundService;

  @override
  State<OpenCodeShellScreen> createState() => _OpenCodeShellScreenState();
}

class _OpenCodeShellScreenState extends State<OpenCodeShellScreen> {
  late ChatService _chatService;
  late bool _ownsChatService;
  final SessionActionService _sessionActionService = SessionActionService();
  late EventStreamService _eventStreamService;
  late bool _ownsEventStreamService;
  late FileBrowserService _fileBrowserService;
  late bool _ownsFileBrowserService;
  late RequestService _requestService;
  late bool _ownsRequestService;
  late ConfigService _configService;
  late bool _ownsConfigService;
  late IntegrationStatusService _integrationStatusService;
  late bool _ownsIntegrationStatusService;
  late TerminalService _terminalService;
  late bool _ownsTerminalService;
  late PendingRequestNotificationService _pendingRequestNotificationService;
  final StaleCacheStore _cacheStore = StaleCacheStore();
  late TodoService _todoService;
  late bool _ownsTodoService;
  late ProjectStore _projectStore;
  late bool _ownsProjectStore;
  late SseConnectionMonitor _sseConnectionMonitor;
  Timer? _eventHealthTimer;
  bool _recoveringEventStream = false;
  _ShellPrimaryDestination _primaryDestination = _ShellPrimaryDestination.chat;
  bool _loading = true;
  String? _error;
  SseConnectionHealth _eventStreamHealth = SseConnectionHealth.stale;
  List<SessionSummary> _sessions = const <SessionSummary>[];
  Map<String, SessionStatusSummary> _statuses =
      const <String, SessionStatusSummary>{};
  List<ChatMessage> _messages = const <ChatMessage>[];
  List<FileNodeSummary> _fileNodes = const <FileNodeSummary>[];
  List<FileStatusSummary> _fileStatuses = const <FileStatusSummary>[];
  List<String> _fileSearchResults = const <String>[];
  List<TextMatchSummary> _textMatches = const <TextMatchSummary>[];
  List<SymbolSummary> _symbols = const <SymbolSummary>[];
  FileContentSummary? _filePreview;
  String? _selectedFilePath;
  String _fileSearchQuery = '';
  String _terminalCommand = 'pwd';
  ShellCommandResult? _lastShellResult;
  bool _runningShellCommand = false;
  bool _submittingPrompt = false;
  List<QuestionRequestSummary> _questionRequests =
      const <QuestionRequestSummary>[];
  List<PermissionRequestSummary> _permissionRequests =
      const <PermissionRequestSummary>[];
  ConfigSnapshot? _configSnapshot;
  IntegrationStatusSnapshot? _integrationStatusSnapshot;
  String? _lastIntegrationAuthUrl;
  List<EventEnvelope> _recentEvents = const <EventEnvelope>[];
  List<String> _eventRecoveryLog = const <String>[];
  List<TodoItem> _todos = const <TodoItem>[];
  String? _selectedSessionId;
  int _bundleLoadRequestToken = 0;
  int _sessionSelectionRequestToken = 0;
  int _todoLoadRequestToken = 0;
  int _fileLoadRequestToken = 0;
  int _filePreviewRequestToken = 0;
  int _pendingRequestsLoadRequestToken = 0;
  int _configSnapshotLoadRequestToken = 0;
  int _integrationStatusLoadRequestToken = 0;
  int _shellCommandRequestToken = 0;
  int _promptSubmissionRequestToken = 0;
  int _guardedActionRequestToken = 0;
  int _integrationAuthRequestToken = 0;
  int _configApplyRequestToken = 0;
  int _eventStreamConnectionToken = 0;
  int _eventStreamRecoveryToken = 0;
  String? _activeEventStreamScopeKey;

  @override
  void initState() {
    super.initState();
    _sseConnectionMonitor = _createSseConnectionMonitor();
    _ownsChatService = widget.chatService == null;
    _chatService = widget.chatService ?? ChatService();
    _ownsEventStreamService = widget.eventStreamService == null;
    _eventStreamService = widget.eventStreamService ?? EventStreamService();
    _ownsTodoService = widget.todoService == null;
    _todoService = widget.todoService ?? TodoService();
    _ownsProjectStore = widget.projectStore == null;
    _projectStore = widget.projectStore ?? ProjectStore();
    _ownsFileBrowserService = widget.fileBrowserService == null;
    _fileBrowserService = widget.fileBrowserService ?? FileBrowserService();
    _ownsRequestService = widget.requestService == null;
    _requestService = widget.requestService ?? RequestService();
    _ownsConfigService = widget.configService == null;
    _configService = widget.configService ?? ConfigService();
    _ownsIntegrationStatusService = widget.integrationStatusService == null;
    _integrationStatusService =
        widget.integrationStatusService ?? IntegrationStatusService();
    _ownsTerminalService = widget.terminalService == null;
    _terminalService = widget.terminalService ?? TerminalService();
    _pendingRequestNotificationService =
        widget.pendingRequestNotificationService ??
        sharedPendingRequestNotificationService;
    _loadBundle();
  }

  @override
  void didUpdateWidget(covariant OpenCodeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chatServiceChanged = oldWidget.chatService != widget.chatService;
    final todoServiceChanged = oldWidget.todoService != widget.todoService;
    final eventStreamServiceChanged =
        oldWidget.eventStreamService != widget.eventStreamService;
    final projectStoreChanged = oldWidget.projectStore != widget.projectStore;
    final fileBrowserServiceChanged =
        oldWidget.fileBrowserService != widget.fileBrowserService;
    final requestServiceChanged =
        oldWidget.requestService != widget.requestService;
    final configServiceChanged =
        oldWidget.configService != widget.configService;
    final integrationStatusServiceChanged =
        oldWidget.integrationStatusService != widget.integrationStatusService;
    final terminalServiceChanged =
        oldWidget.terminalService != widget.terminalService;
    final pendingRequestNotificationServiceChanged =
        oldWidget.pendingRequestNotificationService !=
        widget.pendingRequestNotificationService;
    final capabilitiesChanged =
        oldWidget.capabilities.asMap().toString() !=
        widget.capabilities.asMap().toString();
    final reloadServicesChanged =
        chatServiceChanged ||
        todoServiceChanged ||
        fileBrowserServiceChanged ||
        requestServiceChanged ||
        configServiceChanged ||
        integrationStatusServiceChanged;
    var shouldRefreshShellState = false;
    var retiredEventStream = false;
    if (chatServiceChanged) {
      if (_ownsChatService) {
        _chatService.dispose();
      }
      _ownsChatService = widget.chatService == null;
      _chatService = widget.chatService ?? ChatService();
    }
    if (todoServiceChanged) {
      if (_ownsTodoService) {
        _todoService.dispose();
      }
      _ownsTodoService = widget.todoService == null;
      _todoService = widget.todoService ?? TodoService();
    }
    if (eventStreamServiceChanged) {
      _retireEventStream(disconnect: true);
      retiredEventStream = true;
      shouldRefreshShellState = true;
      if (_ownsEventStreamService) {
        _eventStreamService.dispose();
      }
      _ownsEventStreamService = widget.eventStreamService == null;
      _eventStreamService = widget.eventStreamService ?? EventStreamService();
    }
    if (projectStoreChanged) {
      if (_ownsProjectStore) {
        // ProjectStore does not currently expose dispose; nothing to clean up.
      }
      _ownsProjectStore = widget.projectStore == null;
      _projectStore = widget.projectStore ?? ProjectStore();
    }
    if (fileBrowserServiceChanged) {
      if (_ownsFileBrowserService) {
        _fileBrowserService.dispose();
      }
      _ownsFileBrowserService = widget.fileBrowserService == null;
      _fileBrowserService = widget.fileBrowserService ?? FileBrowserService();
    }
    if (requestServiceChanged) {
      if (_ownsRequestService) {
        _requestService.dispose();
      }
      _ownsRequestService = widget.requestService == null;
      _requestService = widget.requestService ?? RequestService();
    }
    if (configServiceChanged) {
      if (_ownsConfigService) {
        _configService.dispose();
      }
      _ownsConfigService = widget.configService == null;
      _configService = widget.configService ?? ConfigService();
    }
    if (integrationStatusServiceChanged) {
      if (_ownsIntegrationStatusService) {
        _integrationStatusService.dispose();
      }
      _ownsIntegrationStatusService = widget.integrationStatusService == null;
      _integrationStatusService =
          widget.integrationStatusService ?? IntegrationStatusService();
    }
    if (terminalServiceChanged) {
      if (_ownsTerminalService) {
        _terminalService.dispose();
      }
      _ownsTerminalService = widget.terminalService == null;
      _terminalService = widget.terminalService ?? TerminalService();
    }
    if (pendingRequestNotificationServiceChanged) {
      _pendingRequestNotificationService =
          widget.pendingRequestNotificationService ??
          sharedPendingRequestNotificationService;
    }
    final scopeChanged =
        oldWidget.project.directory != widget.project.directory ||
        oldWidget.profile.storageKey != widget.profile.storageKey;
    if (scopeChanged) {
      _retireLoadOperations();
      _retireSessionScopedOperations();
      if (!retiredEventStream) {
        _retireEventStream(disconnect: true);
      }
      shouldRefreshShellState = true;
    } else {
      if (reloadServicesChanged) {
        _retireLoadOperations();
        shouldRefreshShellState = true;
      }
      if (reloadServicesChanged || terminalServiceChanged) {
        _retireSessionScopedOperations();
        shouldRefreshShellState = true;
      }
    }
    if (shouldRefreshShellState && mounted) {
      setState(() {});
    }
    if (scopeChanged || capabilitiesChanged) {
      _loadBundle(clearStaleScopeState: scopeChanged);
    } else if (reloadServicesChanged) {
      _loadBundle(forceRefresh: true);
    } else if (eventStreamServiceChanged &&
        widget.capabilities.hasEventStream) {
      unawaited(_connectEvents());
    }
  }

  @override
  void dispose() {
    _eventHealthTimer?.cancel();
    if (_ownsChatService) {
      _chatService.dispose();
    }
    _sessionActionService.dispose();
    if (_ownsEventStreamService) {
      _eventStreamService.dispose();
    }
    if (_ownsFileBrowserService) {
      _fileBrowserService.dispose();
    }
    if (_ownsRequestService) {
      _requestService.dispose();
    }
    if (_ownsConfigService) {
      _configService.dispose();
    }
    if (_ownsIntegrationStatusService) {
      _integrationStatusService.dispose();
    }
    if (_ownsTerminalService) {
      _terminalService.dispose();
    }
    if (_ownsTodoService) {
      _todoService.dispose();
    }
    super.dispose();
  }

  String _scopeKey([String? leaf]) {
    final base = '${widget.profile.storageKey}::${widget.project.directory}';
    return leaf == null ? base : '$base::$leaf';
  }

  SseConnectionMonitor _createSseConnectionMonitor() {
    return SseConnectionMonitor(heartbeatTimeout: const Duration(seconds: 8));
  }

  bool _isActiveBundleLoad(int requestToken, String scopeKey) {
    return mounted &&
        requestToken == _bundleLoadRequestToken &&
        scopeKey == _scopeKey();
  }

  bool _isActiveSessionSelection(
    int requestToken,
    String scopeKey, {
    String? sessionId,
  }) {
    return mounted &&
        requestToken == _sessionSelectionRequestToken &&
        scopeKey == _scopeKey() &&
        (sessionId == null || _selectedSessionId == sessionId);
  }

  bool _isActiveTodoLoad(
    int requestToken,
    String scopeKey, {
    String? sessionId,
  }) {
    return mounted &&
        requestToken == _todoLoadRequestToken &&
        scopeKey == _scopeKey() &&
        (sessionId == null || _selectedSessionId == sessionId);
  }

  bool _isActiveScopedRequest(
    int requestToken,
    int activeRequestToken,
    String scopeKey,
  ) {
    return mounted &&
        requestToken == activeRequestToken &&
        scopeKey == _scopeKey();
  }

  bool _isActiveFileLoad(int requestToken, String scopeKey) {
    return _isActiveScopedRequest(
      requestToken,
      _fileLoadRequestToken,
      scopeKey,
    );
  }

  bool _isActiveFilePreviewLoad(
    int requestToken,
    String scopeKey, {
    String? path,
  }) {
    return _isActiveScopedRequest(
          requestToken,
          _filePreviewRequestToken,
          scopeKey,
        ) &&
        (path == null || _selectedFilePath == path);
  }

  bool _isActivePendingRequestsLoad(int requestToken, String scopeKey) {
    return _isActiveScopedRequest(
      requestToken,
      _pendingRequestsLoadRequestToken,
      scopeKey,
    );
  }

  bool _isActiveConfigSnapshotLoad(int requestToken, String scopeKey) {
    return _isActiveScopedRequest(
      requestToken,
      _configSnapshotLoadRequestToken,
      scopeKey,
    );
  }

  bool _isActiveIntegrationStatusLoad(int requestToken, String scopeKey) {
    return _isActiveScopedRequest(
      requestToken,
      _integrationStatusLoadRequestToken,
      scopeKey,
    );
  }

  bool _isActiveGuardedAction(int requestToken, String scopeKey) {
    return mounted &&
        requestToken == _guardedActionRequestToken &&
        scopeKey == _scopeKey();
  }

  bool _isActiveIntegrationAuth(int requestToken, String scopeKey) {
    return mounted &&
        requestToken == _integrationAuthRequestToken &&
        scopeKey == _scopeKey();
  }

  bool _isActiveConfigApply(int requestToken, String scopeKey) {
    return mounted &&
        requestToken == _configApplyRequestToken &&
        scopeKey == _scopeKey();
  }

  bool _isActiveSessionScopedOperation(
    int requestToken,
    int activeRequestToken,
    String scopeKey, {
    required String? selectedSessionId,
  }) {
    return mounted &&
        requestToken == activeRequestToken &&
        scopeKey == _scopeKey() &&
        _selectedSessionId == selectedSessionId;
  }

  bool _isActiveShellCommandRequest(
    int requestToken,
    String scopeKey, {
    required String selectedSessionId,
  }) {
    return _isActiveSessionScopedOperation(
      requestToken,
      _shellCommandRequestToken,
      scopeKey,
      selectedSessionId: selectedSessionId,
    );
  }

  bool _isActivePromptSubmission(
    int requestToken,
    String scopeKey, {
    required String? selectedSessionId,
  }) {
    return _isActiveSessionScopedOperation(
      requestToken,
      _promptSubmissionRequestToken,
      scopeKey,
      selectedSessionId: selectedSessionId,
    );
  }

  bool _isActiveEventStreamConnection(int connectionToken, String scopeKey) {
    return mounted &&
        connectionToken == _eventStreamConnectionToken &&
        scopeKey == _scopeKey() &&
        _activeEventStreamScopeKey == scopeKey;
  }

  bool _isActiveEventStreamRecovery(
    int recoveryToken,
    String scopeKey,
    EventStreamService eventStreamService,
  ) {
    return mounted &&
        recoveryToken == _eventStreamRecoveryToken &&
        scopeKey == _scopeKey() &&
        identical(_eventStreamService, eventStreamService);
  }

  void _retireSessionScopedOperations() {
    _shellCommandRequestToken += 1;
    _promptSubmissionRequestToken += 1;
    _guardedActionRequestToken += 1;
    _integrationAuthRequestToken += 1;
    _configApplyRequestToken += 1;
    _runningShellCommand = false;
    _submittingPrompt = false;
  }

  void _retireLoadOperations() {
    _bundleLoadRequestToken += 1;
    _sessionSelectionRequestToken += 1;
    _todoLoadRequestToken += 1;
    _fileLoadRequestToken += 1;
    _filePreviewRequestToken += 1;
    _pendingRequestsLoadRequestToken += 1;
    _configSnapshotLoadRequestToken += 1;
    _integrationStatusLoadRequestToken += 1;
  }

  void _resetEventStreamMonitor() {
    _sseConnectionMonitor = _createSseConnectionMonitor();
    _eventStreamHealth = SseConnectionHealth.stale;
  }

  void _retireEventStream({bool disconnect = false}) {
    _eventHealthTimer?.cancel();
    _eventHealthTimer = null;
    _eventStreamConnectionToken += 1;
    _eventStreamRecoveryToken += 1;
    _activeEventStreamScopeKey = null;
    _recoveringEventStream = false;
    _resetEventStreamMonitor();
    if (disconnect) {
      unawaited(_eventStreamService.disconnect());
    }
  }

  void _clearScopeDependentState({bool clearSessions = false}) {
    _retireSessionScopedOperations();
    if (clearSessions) {
      _sessions = const <SessionSummary>[];
      _statuses = const <String, SessionStatusSummary>{};
    }
    _messages = const <ChatMessage>[];
    _fileNodes = const <FileNodeSummary>[];
    _fileStatuses = const <FileStatusSummary>[];
    _fileSearchResults = const <String>[];
    _textMatches = const <TextMatchSummary>[];
    _symbols = const <SymbolSummary>[];
    _filePreview = null;
    _selectedFilePath = null;
    _fileSearchQuery = '';
    _lastShellResult = null;
    _runningShellCommand = false;
    _submittingPrompt = false;
    _questionRequests = const <QuestionRequestSummary>[];
    _permissionRequests = const <PermissionRequestSummary>[];
    _configSnapshot = null;
    _integrationStatusSnapshot = null;
    _lastIntegrationAuthUrl = null;
    _recentEvents = const <EventEnvelope>[];
    _eventRecoveryLog = const <String>[];
    _eventStreamHealth = SseConnectionHealth.stale;
    _todos = const <TodoItem>[];
    _selectedSessionId = null;
  }

  ProjectTarget _projectWithSessionHint(ProjectSessionHint? session) {
    return ProjectTarget(
      directory: widget.project.directory,
      label: widget.project.label,
      source: widget.project.source,
      vcs: widget.project.vcs,
      branch: widget.project.branch,
      lastSession: session,
    );
  }

  ProjectSessionHint? _sessionHintForId(
    String? sessionId,
    List<SessionSummary> sessions,
    Map<String, SessionStatusSummary> statuses,
  ) {
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    final session = sessions.where((item) => item.id == sessionId).firstOrNull;
    if (session == null) {
      return null;
    }
    final title = session.title.trim();
    final status = statuses[session.id]?.type.trim();
    return ProjectSessionHint(
      title: title.isEmpty ? null : title,
      status: status == null || status.isEmpty ? null : status,
    );
  }

  Future<void> _persistWorkspaceHint(
    String? sessionId,
    List<SessionSummary> sessions,
    Map<String, SessionStatusSummary> statuses,
  ) {
    return _projectStore.saveLastWorkspace(
      serverStorageKey: widget.profile.storageKey,
      target: _projectWithSessionHint(
        _sessionHintForId(sessionId, sessions, statuses),
      ),
    );
  }

  void _showResumeNotice(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ScaffoldMessenger.maybeOf(context) == null) {
        return;
      }
      showAppSnackBar(
        context,
        message: message,
        tone: AppSnackBarTone.info,
        replaceCurrent: true,
      );
    });
  }

  Future<
    ({String? selectedSessionId, List<ChatMessage> messages, String? notice})
  >
  _resolveInitialSelection(ChatSessionBundle bundle) async {
    final l10n = AppLocalizations.of(context)!;
    final hint = widget.project.lastSession;
    if (hint == null) {
      final selectedSessionId = bundle.selectedSessionId;
      if (selectedSessionId == null) {
        return (
          selectedSessionId: null,
          messages: const <ChatMessage>[],
          notice: null,
        );
      }
      if (bundle.messages.isNotEmpty) {
        return (
          selectedSessionId: selectedSessionId,
          messages: bundle.messages,
          notice: null,
        );
      }
      final messages = await _chatService.fetchMessages(
        profile: widget.profile,
        project: widget.project,
        sessionId: selectedSessionId,
      );
      return (
        selectedSessionId: selectedSessionId,
        messages: messages,
        notice: null,
      );
    }

    final normalizedTitle = hint.title?.trim().toLowerCase();
    final normalizedStatus = hint.status?.trim().toLowerCase();
    if (normalizedTitle == null || normalizedTitle.isEmpty) {
      return (
        selectedSessionId: null,
        messages: const <ChatMessage>[],
        notice: l10n.shellNoticeLastSessionUnavailable,
      );
    }

    final matchingSessions = bundle.sessions
        .where(
          (session) => session.title.trim().toLowerCase() == normalizedTitle,
        )
        .toList(growable: false);

    SessionSummary? matchedSession;
    if (matchingSessions.length == 1) {
      matchedSession = matchingSessions.single;
    } else if (matchingSessions.isNotEmpty) {
      if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
        matchedSession = matchingSessions.firstWhere(
          (session) =>
              bundle.statuses[session.id]?.type.trim().toLowerCase() ==
              normalizedStatus,
          orElse: () => matchingSessions.first,
        );
      } else {
        matchedSession = matchingSessions.first;
      }
    }

    if (matchedSession == null) {
      return (
        selectedSessionId: null,
        messages: const <ChatMessage>[],
        notice: l10n.shellNoticeLastSessionUnavailable,
      );
    }

    if (bundle.selectedSessionId == matchedSession.id) {
      if (bundle.messages.isNotEmpty) {
        return (
          selectedSessionId: matchedSession.id,
          messages: bundle.messages,
          notice: null,
        );
      }
      final messages = await _chatService.fetchMessages(
        profile: widget.profile,
        project: widget.project,
        sessionId: matchedSession.id,
      );
      return (
        selectedSessionId: matchedSession.id,
        messages: messages,
        notice: null,
      );
    }

    final messages = await _chatService.fetchMessages(
      profile: widget.profile,
      project: widget.project,
      sessionId: matchedSession.id,
    );
    return (
      selectedSessionId: matchedSession.id,
      messages: messages,
      notice: null,
    );
  }

  Future<void> _openCacheSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CacheSettingsSheet(
        onChanged: () {
          unawaited(_loadBundle());
        },
      ),
    );
  }

  void _selectPrimaryDestination(_ShellPrimaryDestination destination) {
    if (_primaryDestination == destination) {
      return;
    }
    setState(() {
      _primaryDestination = destination;
    });
  }

  Future<void> _loadBundle({
    bool clearStaleScopeState = false,
    bool forceRefresh = false,
  }) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_bundleLoadRequestToken;
    final cacheKey = 'shell.bundle::$scopeKey';
    if (clearStaleScopeState) {
      setState(() {
        _clearScopeDependentState(clearSessions: true);
        _loading = true;
        _error = null;
      });
    }
    final cached = forceRefresh ? null : await _cacheStore.load(cacheKey);
    if (!_isActiveBundleLoad(requestToken, scopeKey)) {
      return;
    }
    if (cached != null &&
        cached.payloadJson.length <= ChatService.maxSessionMessageResponseBytes) {
      setState(() {
        _clearScopeDependentState(clearSessions: clearStaleScopeState);
        _loading = true;
        _error = null;
      });
      final bundle = ChatSessionBundle.fromJson(
        (jsonDecode(cached.payloadJson) as Map).cast<String, Object?>(),
      );
      final initialSelection = await _resolveInitialSelection(bundle);
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _sessions = bundle.sessions;
        _statuses = bundle.statuses;
        _messages = initialSelection.messages;
        _selectedSessionId = initialSelection.selectedSessionId;
        _loading = false;
        _error = null;
      });
      await _persistWorkspaceHint(
        initialSelection.selectedSessionId,
        bundle.sessions,
        bundle.statuses,
      );
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      if (initialSelection.notice != null) {
        _showResumeNotice(initialSelection.notice!);
      }
      if (initialSelection.selectedSessionId != null &&
          widget.capabilities.hasTodos) {
        await _loadTodos(initialSelection.selectedSessionId!);
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasFiles) {
        await _loadFiles();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasQuestions ||
          widget.capabilities.hasPermissions) {
        await _loadPendingRequests();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasConfigRead) {
        await _loadConfigSnapshot();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasProviderOAuth ||
          widget.capabilities.hasMcpAuth) {
        await _loadIntegrationStatus();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      final ttl = await _cacheStore.loadTtl();
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      if (cached.isFresh(ttl, DateTime.now())) {
        if (widget.capabilities.hasEventStream) {
          await _connectEvents();
          if (!_isActiveBundleLoad(requestToken, scopeKey)) {
            return;
          }
        }
        return;
      }
    } else if (cached != null) {
      await _cacheStore.remove(cacheKey);
    } else {
      if (!clearStaleScopeState) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }
    try {
      final bundle = widget.capabilities.hasSessions
          ? await _chatService.fetchBundle(
              profile: widget.profile,
              project: widget.project,
              includeSelectedSessionMessages: false,
            )
          : const ChatSessionBundle(
              sessions: <SessionSummary>[],
              statuses: <String, SessionStatusSummary>{},
              messages: <ChatMessage>[],
            );
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      final initialSelection = await _resolveInitialSelection(bundle);
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      await _cacheStore.save(cacheKey, bundle.toJson());
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _clearScopeDependentState();
        _sessions = bundle.sessions;
        _statuses = bundle.statuses;
        _messages = initialSelection.messages;
        _selectedSessionId = initialSelection.selectedSessionId;
        _loading = false;
      });
      await _persistWorkspaceHint(
        initialSelection.selectedSessionId,
        bundle.sessions,
        bundle.statuses,
      );
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      if (initialSelection.notice != null) {
        _showResumeNotice(initialSelection.notice!);
      }
      if (widget.capabilities.hasTodos &&
          initialSelection.selectedSessionId != null) {
        await _loadTodos(initialSelection.selectedSessionId!);
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasFiles) {
        await _loadFiles();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasQuestions ||
          widget.capabilities.hasPermissions) {
        await _loadPendingRequests();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasConfigRead) {
        await _loadConfigSnapshot();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasProviderOAuth ||
          widget.capabilities.hasMcpAuth) {
        await _loadIntegrationStatus();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
      if (widget.capabilities.hasEventStream) {
        await _connectEvents();
        if (!_isActiveBundleLoad(requestToken, scopeKey)) {
          return;
        }
      }
    } catch (error) {
      if (!_isActiveBundleLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectSession(String sessionId) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_sessionSelectionRequestToken;
    if (sessionId != _selectedSessionId) {
      setState(() {
        _retireSessionScopedOperations();
      });
    }
    final messagesKey = 'shell.messages::${_scopeKey(sessionId)}';
    final todosKey = 'shell.todos::${_scopeKey(sessionId)}';
    final cachedMessages = await _cacheStore.load(messagesKey);
    final cachedTodos = widget.capabilities.hasTodos
        ? await _cacheStore.load(todosKey)
        : null;
    if (!_isActiveSessionSelection(requestToken, scopeKey)) {
      return;
    }
    if (cachedMessages != null &&
        cachedMessages.payloadJson.length <=
            ChatService.maxSessionMessageResponseBytes) {
      final messages =
          ((jsonDecode(cachedMessages.payloadJson) as List)
                  .cast<Map<String, Object?>>())
              .map(ChatMessage.fromJson)
              .toList(growable: false);
      final todos = cachedTodos == null
          ? const <TodoItem>[]
          : TodoItem.listFromJson(jsonDecode(cachedTodos.payloadJson) as List);
      setState(() {
        _selectedSessionId = sessionId;
        _messages = messages;
        _todos = todos;
        _loading = false;
        _error = null;
      });
      await _persistWorkspaceHint(sessionId, _sessions, _statuses);
      if (!_isActiveSessionSelection(
        requestToken,
        scopeKey,
        sessionId: sessionId,
      )) {
        return;
      }
      final ttl = await _cacheStore.loadTtl();
      if (!_isActiveSessionSelection(
        requestToken,
        scopeKey,
        sessionId: sessionId,
      )) {
        return;
      }
      final messagesFresh = cachedMessages.isFresh(ttl, DateTime.now());
      final todosFresh =
          !widget.capabilities.hasTodos ||
          (cachedTodos != null && cachedTodos.isFresh(ttl, DateTime.now()));
      if (widget.capabilities.hasTodos && !todosFresh) {
        unawaited(_loadTodos(sessionId));
      }
      if (messagesFresh) {
        return;
      }
    } else if (cachedMessages != null) {
      await _cacheStore.remove(messagesKey);
    } else {
      setState(() {
        _selectedSessionId = sessionId;
        _loading = true;
        _error = null;
      });
    }
    try {
      final messages = await _chatService.fetchMessages(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!_isActiveSessionSelection(
        requestToken,
        scopeKey,
        sessionId: sessionId,
      )) {
        return;
      }
      await _cacheStore.save(
        messagesKey,
        messages.map((item) => item.toJson()).toList(growable: false),
      );
      if (!_isActiveSessionSelection(
        requestToken,
        scopeKey,
        sessionId: sessionId,
      )) {
        return;
      }
      setState(() {
        _messages = messages;
        if (!widget.capabilities.hasTodos) {
          _todos = const <TodoItem>[];
        }
        _loading = false;
        _error = null;
      });
      await _persistWorkspaceHint(sessionId, _sessions, _statuses);
      if (!_isActiveSessionSelection(
        requestToken,
        scopeKey,
        sessionId: sessionId,
      )) {
        return;
      }
      if (widget.capabilities.hasTodos) {
        unawaited(_loadTodos(sessionId));
      }
    } catch (error) {
      if (!_isActiveSessionSelection(
        requestToken,
        scopeKey,
        sessionId: sessionId,
      )) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadTodos(String sessionId) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_todoLoadRequestToken;
    final cacheKey = 'shell.todos::${_scopeKey(sessionId)}';
    final cached = await _cacheStore.load(cacheKey);
    if (!_isActiveTodoLoad(requestToken, scopeKey, sessionId: sessionId)) {
      return;
    }
    if (cached != null) {
      final todos = TodoItem.listFromJson(
        jsonDecode(cached.payloadJson) as List,
      );
      setState(() {
        _todos = todos;
      });
      final ttl = await _cacheStore.loadTtl();
      if (!_isActiveTodoLoad(requestToken, scopeKey, sessionId: sessionId)) {
        return;
      }
      if (cached.isFresh(ttl, DateTime.now())) {
        return;
      }
    }
    try {
      final todos = await _todoService.fetchTodos(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!_isActiveTodoLoad(requestToken, scopeKey, sessionId: sessionId)) {
        return;
      }
      await _cacheStore.save(
        cacheKey,
        todos.map((item) => item.toJson()).toList(growable: false),
      );
      if (!_isActiveTodoLoad(requestToken, scopeKey, sessionId: sessionId)) {
        return;
      }
      setState(() {
        _todos = todos;
      });
    } catch (_) {
      if (!_isActiveTodoLoad(requestToken, scopeKey, sessionId: sessionId)) {
        return;
      }
      setState(() {
        _todos = const <TodoItem>[];
      });
    }
  }

  Future<void> _loadFiles({String searchQuery = ''}) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_fileLoadRequestToken;
    _filePreviewRequestToken += 1;
    final cacheKey = _shellFilesCacheKey(searchQuery);
    final cached = await _cacheStore.load(cacheKey);
    if (!_isActiveFileLoad(requestToken, scopeKey)) {
      return;
    }
    if (cached != null) {
      final cachedBundle = _decodeShellFileCacheBundle(cached.payloadJson);
      if (cachedBundle == null) {
        await _cacheStore.remove(cacheKey);
      } else {
        setState(() {
          _fileNodes = cachedBundle.nodes;
          _fileStatuses = cachedBundle.statuses;
          _fileSearchResults = cachedBundle.searchResults;
          _textMatches = cachedBundle.textMatches;
          _symbols = cachedBundle.symbols;
          _filePreview = null;
          _selectedFilePath = null;
          _fileSearchQuery = searchQuery;
        });
        final ttl = await _cacheStore.loadTtl();
        if (!_isActiveFileLoad(requestToken, scopeKey)) {
          return;
        }
        if (cached.isFresh(ttl, DateTime.now())) {
          return;
        }
      }
    }
    try {
      final bundle = await _fileBrowserService.fetchBundle(
        profile: widget.profile,
        project: widget.project,
        searchQuery: searchQuery,
      );
      if (!_isActiveFileLoad(requestToken, scopeKey)) {
        return;
      }
      final compactBundle = _compactShellFileCacheBundle(bundle);
      await _cacheStore.save(
        cacheKey,
        compactBundle.toJson(),
        signature: _shellFileCacheSignature(compactBundle),
      );
      if (!_isActiveFileLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _fileNodes = bundle.nodes;
        _fileStatuses = bundle.statuses;
        _fileSearchResults = bundle.searchResults;
        _textMatches = bundle.textMatches;
        _symbols = bundle.symbols;
        _filePreview = null;
        _selectedFilePath = null;
        _fileSearchQuery = searchQuery;
      });
    } catch (_) {
      if (!_isActiveFileLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _fileNodes = const <FileNodeSummary>[];
        _fileStatuses = const <FileStatusSummary>[];
        _fileSearchResults = const <String>[];
        _textMatches = const <TextMatchSummary>[];
        _symbols = const <SymbolSummary>[];
        _filePreview = null;
        _selectedFilePath = null;
        _fileSearchQuery = searchQuery;
      });
    }
  }

  Future<void> _selectFile(String path) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_filePreviewRequestToken;
    if (mounted) {
      setState(() {
        _error = null;
        _selectedFilePath = path;
        _filePreview = null;
      });
    }
    try {
      final preview = await _fileBrowserService.fetchFileContent(
        profile: widget.profile,
        project: widget.project,
        path: path,
      );
      if (!_isActiveFilePreviewLoad(requestToken, scopeKey, path: path)) {
        return;
      }
      setState(() {
        _filePreview = _compactShellFilePreview(preview);
      });
    } catch (error) {
      if (!_isActiveFilePreviewLoad(requestToken, scopeKey, path: path)) {
        return;
      }
      setState(() {
        _error = error.toString();
        _filePreview = null;
      });
    }
  }

  String _shellFilesCacheKey(String searchQuery) {
    return 'shell.files.v2::${_scopeKey(searchQuery)}';
  }

  FileBrowserBundle? _decodeShellFileCacheBundle(String payloadJson) {
    if (payloadJson.isEmpty ||
        payloadJson.length > _shellFileCachePayloadSoftLimit) {
      return null;
    }
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        return null;
      }
      return _compactShellFileCacheBundle(
        FileBrowserBundle.fromJson(decoded.cast<String, Object?>()),
      );
    } catch (_) {
      return null;
    }
  }

  FileBrowserBundle _compactShellFileCacheBundle(FileBrowserBundle bundle) {
    final nodes = bundle.nodes
        .take(_shellFileCacheNodeLimit)
        .toList(growable: false);
    final searchResults = bundle.searchResults
        .take(_shellFileCacheSearchResultLimit)
        .toList(growable: false);
    final visiblePaths = <String>{
      ...searchResults,
      ...nodes.map((item) => item.path).take(5),
    };
    final statuses = bundle.statuses
        .where((item) => visiblePaths.contains(item.path))
        .take(_shellFileCacheStatusLimit)
        .toList(growable: false);
    final textMatches = bundle.textMatches
        .take(_shellFileCacheTextMatchLimit)
        .map(_compactShellTextMatch)
        .toList(growable: false);
    final symbols = bundle.symbols
        .take(_shellFileCacheSymbolLimit)
        .toList(growable: false);
    return FileBrowserBundle(
      nodes: nodes,
      searchResults: searchResults,
      textMatches: textMatches,
      symbols: symbols,
      statuses: statuses,
      preview: null,
      selectedPath: null,
    );
  }

  TextMatchSummary _compactShellTextMatch(TextMatchSummary match) {
    final lines = match.lines.length <= _shellFileCacheTextMatchLineLimit
        ? match.lines
        : '${match.lines.substring(0, _shellFileCacheTextMatchLineLimit)}…';
    return TextMatchSummary(path: match.path, lines: lines);
  }

  FileContentSummary? _compactShellFilePreview(FileContentSummary? preview) {
    if (preview == null) {
      return null;
    }
    final content = preview.content;
    if (content.length <= _shellFilePreviewCharacterLimit) {
      return preview;
    }
    return FileContentSummary(
      type: preview.type,
      content:
          '${content.substring(0, _shellFilePreviewCharacterLimit)}\n\n[Preview shortened in shell mode to keep memory use low.]',
    );
  }

  String _shellFileCacheSignature(FileBrowserBundle bundle) {
    return [
      bundle.nodes.length,
      bundle.statuses.length,
      bundle.searchResults.length,
      bundle.textMatches.length,
      bundle.symbols.length,
    ].join(':');
  }

  Future<void> _runShellCommand(String command) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || command.trim().isEmpty) {
      return;
    }
    final scopeKey = _scopeKey();
    final requestToken = ++_shellCommandRequestToken;
    setState(() {
      _runningShellCommand = true;
      _terminalCommand = command;
    });
    try {
      final result = await _terminalService.runShellCommand(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        command: command,
      );
      if (!_isActiveShellCommandRequest(
        requestToken,
        scopeKey,
        selectedSessionId: sessionId,
      )) {
        return;
      }
      await _selectSession(sessionId);
      if (!_isActiveShellCommandRequest(
        requestToken,
        scopeKey,
        selectedSessionId: sessionId,
      )) {
        return;
      }
      setState(() {
        _lastShellResult = result;
        _runningShellCommand = false;
      });
      await _loadPendingRequests();
    } catch (error) {
      if (!_isActiveShellCommandRequest(
        requestToken,
        scopeKey,
        selectedSessionId: sessionId,
      )) {
        return;
      }
      setState(() {
        _error = error.toString();
        _runningShellCommand = false;
      });
    }
  }

  void _startNewSessionDraft() {
    setState(() {
      _retireSessionScopedOperations();
      _selectedSessionId = null;
      _messages = const <ChatMessage>[];
      _todos = const <TodoItem>[];
      _questionRequests = const <QuestionRequestSummary>[];
      _permissionRequests = const <PermissionRequestSummary>[];
      _lastShellResult = null;
      _runningShellCommand = false;
      _submittingPrompt = false;
      _loading = false;
      _error = null;
      _primaryDestination = _ShellPrimaryDestination.chat;
    });
  }

  Future<bool> _submitPrompt(
    String prompt,
    _ComposerSubmissionOptions options,
  ) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final scopeKey = _scopeKey();
    final requestToken = ++_promptSubmissionRequestToken;
    var expectedSelectedSessionId = _selectedSessionId;
    setState(() {
      _submittingPrompt = true;
      _error = null;
    });
    try {
      var sessionId = _selectedSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        final created = await _chatService.createSession(
          profile: widget.profile,
          project: widget.project,
        );
        if (!_isActivePromptSubmission(
          requestToken,
          scopeKey,
          selectedSessionId: expectedSelectedSessionId,
        )) {
          return false;
        }
        sessionId = created.id;
        final nextSessions = <SessionSummary>[created, ..._sessions];
        setState(() {
          _sessions = nextSessions;
          _selectedSessionId = created.id;
        });
        expectedSelectedSessionId = created.id;
        await _persistWorkspaceHint(created.id, nextSessions, _statuses);
        if (!_isActivePromptSubmission(
          requestToken,
          scopeKey,
          selectedSessionId: expectedSelectedSessionId,
        )) {
          return false;
        }
      }

      final reply = await _chatService.sendMessage(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        prompt: trimmed,
        providerId: options.providerId,
        modelId: options.modelId,
        reasoning: options.reasoning,
      );
      if (!_isActivePromptSubmission(
        requestToken,
        scopeKey,
        selectedSessionId: expectedSelectedSessionId,
      )) {
        return false;
      }
      final messages = await _chatService.fetchMessages(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!_isActivePromptSubmission(
        requestToken,
        scopeKey,
        selectedSessionId: expectedSelectedSessionId,
      )) {
        return false;
      }
      setState(() {
        _selectedSessionId = sessionId;
        _messages = messages.isEmpty ? <ChatMessage>[reply] : messages;
        _submittingPrompt = false;
      });
      await _persistWorkspaceHint(sessionId, _sessions, _statuses);
      await _loadPendingRequests();
      return true;
    } catch (error) {
      if (!_isActivePromptSubmission(
        requestToken,
        scopeKey,
        selectedSessionId: expectedSelectedSessionId,
      )) {
        return false;
      }
      setState(() {
        _error = error.toString();
        _submittingPrompt = false;
      });
      return false;
    }
  }

  Future<void> _loadPendingRequests() async {
    final scopeKey = _scopeKey();
    final requestToken = ++_pendingRequestsLoadRequestToken;
    if (!widget.capabilities.hasQuestions &&
        !widget.capabilities.hasPermissions) {
      if (!_isActivePendingRequestsLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _questionRequests = const <QuestionRequestSummary>[];
        _permissionRequests = const <PermissionRequestSummary>[];
      });
      return;
    }
    try {
      final bundle = await _requestService.fetchPending(
        profile: widget.profile,
        project: widget.project,
        supportsQuestions: widget.capabilities.hasQuestions,
        supportsPermissions: widget.capabilities.hasPermissions,
      );
      if (!_isActivePendingRequestsLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _questionRequests = bundle.questions;
        _permissionRequests = bundle.permissions;
      });
    } catch (_) {
      if (!_isActivePendingRequestsLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _questionRequests = const <QuestionRequestSummary>[];
        _permissionRequests = const <PermissionRequestSummary>[];
      });
    }
  }

  Future<void> _runGuardedAction(Future<void> Function() action) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_guardedActionRequestToken;
    if (mounted && _error != null) {
      setState(() {
        _error = null;
      });
    }
    try {
      await action();
    } catch (error) {
      if (!_isActiveGuardedAction(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _loadConfigSnapshot() async {
    final scopeKey = _scopeKey();
    final requestToken = ++_configSnapshotLoadRequestToken;
    try {
      final snapshot = await _configService.fetch(
        profile: widget.profile,
        project: widget.project,
      );
      if (!_isActiveConfigSnapshotLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _configSnapshot = snapshot;
      });
    } catch (_) {
      if (!_isActiveConfigSnapshotLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _configSnapshot = null;
      });
    }
  }

  Future<void> _applyConfigRaw(String raw) async {
    final l10n = AppLocalizations.of(context)!;
    final scopeKey = _scopeKey();
    final requestToken = ++_configApplyRequestToken;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException(l10n.shellConfigJsonObjectError);
    }
    final updated = await _configService.updateConfig(
      profile: widget.profile,
      project: widget.project,
      config: decoded.cast<String, Object?>(),
    );
    if (!_isActiveConfigApply(requestToken, scopeKey)) {
      return;
    }
    setState(() {
      _configSnapshot = ConfigSnapshot(
        config: updated,
        providerConfig:
            _configSnapshot?.providerConfig ??
            RawJsonDocument(const <String, Object?>{}),
      );
    });
  }

  Future<void> _loadIntegrationStatus() async {
    final scopeKey = _scopeKey();
    final requestToken = ++_integrationStatusLoadRequestToken;
    try {
      final snapshot = await _integrationStatusService.fetch(
        profile: widget.profile,
        project: widget.project,
      );
      if (!_isActiveIntegrationStatusLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _integrationStatusSnapshot = snapshot;
      });
    } catch (_) {
      if (!_isActiveIntegrationStatusLoad(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _integrationStatusSnapshot = null;
      });
    }
  }

  Future<void> _startProviderAuth(String providerId) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_integrationAuthRequestToken;
    await _runGuardedAction(() async {
      final url = await _integrationStatusService.startProviderAuth(
        profile: widget.profile,
        project: widget.project,
        providerId: providerId,
      );
      if (!_isActiveIntegrationAuth(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _lastIntegrationAuthUrl = url;
      });
    });
  }

  Future<void> _startMcpAuth(String name) async {
    final scopeKey = _scopeKey();
    final requestToken = ++_integrationAuthRequestToken;
    await _runGuardedAction(() async {
      final url = await _integrationStatusService.startMcpAuth(
        profile: widget.profile,
        project: widget.project,
        name: name,
      );
      if (!_isActiveIntegrationAuth(requestToken, scopeKey)) {
        return;
      }
      setState(() {
        _lastIntegrationAuthUrl = url;
      });
    });
  }

  Future<void> _replyPermission(String requestId, String reply) async {
    await _runGuardedAction(() async {
      await _requestService.replyToPermission(
        profile: widget.profile,
        project: widget.project,
        requestId: requestId,
        reply: reply,
      );
      await _loadPendingRequests();
    });
  }

  Future<void> _replyQuestion(
    String requestId,
    List<List<String>> answers,
  ) async {
    await _runGuardedAction(() async {
      await _requestService.replyToQuestion(
        profile: widget.profile,
        project: widget.project,
        requestId: requestId,
        answers: answers,
      );
      await _loadPendingRequests();
    });
  }

  Future<void> _rejectQuestion(String requestId) async {
    await _runGuardedAction(() async {
      await _requestService.rejectQuestion(
        profile: widget.profile,
        project: widget.project,
        requestId: requestId,
      );
      await _loadPendingRequests();
    });
  }

  Future<void> _forkSession(String sessionId) async {
    await _runGuardedAction(() async {
      await _sessionActionService.forkSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      await _loadBundle();
    });
  }

  Future<void> _abortSession(String sessionId) async {
    await _runGuardedAction(() async {
      await _sessionActionService.abortSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      await _loadBundle();
    });
  }

  Future<void> _shareSession(String sessionId) async {
    await _runGuardedAction(() async {
      await _sessionActionService.shareSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
    });
  }

  Future<void> _unshareSession(String sessionId) async {
    await _runGuardedAction(() async {
      await _sessionActionService.unshareSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    await _runGuardedAction(() async {
      await _sessionActionService.deleteSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      await _loadBundle();
    });
  }

  Future<void> _renameSession(String sessionId) async {
    final session = _sessions.where((item) => item.id == sessionId).firstOrNull;
    final initialTitle = session?.title ?? '';
    final controller = TextEditingController(text: initialTitle);
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.shellRenameSessionTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.shellSessionTitleHint,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.shellCancelAction),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(AppLocalizations.of(context)!.shellSaveAction),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nextTitle == null || nextTitle.isEmpty) {
      return;
    }
    await _runGuardedAction(() async {
      await _sessionActionService.updateSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        title: nextTitle,
      );
      await _loadBundle();
    });
  }

  Future<void> _revertSession(String sessionId) async {
    if (_messages.isEmpty) {
      return;
    }
    await _runGuardedAction(() async {
      await _sessionActionService.revertSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        messageId: _messages.last.info.id,
      );
      await _loadBundle();
    });
  }

  Future<void> _unrevertSession(String sessionId) async {
    await _runGuardedAction(() async {
      await _sessionActionService.unrevertSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      await _loadBundle();
    });
  }

  Future<void> _initSession(String sessionId) async {
    if (_messages.isEmpty) {
      return;
    }
    final info = _messages.last.info;
    final providerId = info.providerId;
    final modelId = info.modelId;
    if (providerId == null || modelId == null) {
      return;
    }
    await _runGuardedAction(() async {
      await _sessionActionService.initSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        messageId: info.id,
        providerId: providerId,
        modelId: modelId,
      );
      await _loadBundle();
    });
  }

  Future<void> _summarizeSession(String sessionId) async {
    if (_messages.isEmpty) {
      return;
    }
    final info = _messages.last.info;
    final providerId = info.providerId;
    final modelId = info.modelId;
    if (providerId == null || modelId == null) {
      return;
    }
    await _runGuardedAction(() async {
      await _sessionActionService.summarizeSession(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        providerId: providerId,
        modelId: modelId,
      );
      await _loadBundle();
    });
  }

  Future<void> _connectEvents() async {
    _eventHealthTimer?.cancel();
    final scopeKey = _scopeKey();
    final connectionToken = ++_eventStreamConnectionToken;
    _activeEventStreamScopeKey = scopeKey;
    await _eventStreamService.connect(
      profile: widget.profile,
      project: widget.project,
      onEvent: (event) {
        if (!_isActiveEventStreamConnection(connectionToken, scopeKey)) {
          return;
        }
        final now = DateTime.now();
        _sseConnectionMonitor.recordFrame(now);
        if (event.type == 'server.connected') {
          _sseConnectionMonitor.recordHeartbeat(now);
        }
        var nextStatuses = _statuses;
        var nextMessages = _messages;
        var nextTodos = _todos;
        var nextQuestions = _questionRequests;
        var nextPermissions = _permissionRequests;
        PendingRequestAlert? alert;
        var shouldReloadPendingRequests = false;
        var shouldReloadTodos = false;
        final nextEventHealth = _sseConnectionMonitor.healthAt(now);
        final nextRecentEvents = <EventEnvelope>[
          event,
          ..._recentEvents,
        ].take(12).toList(growable: false);
        switch (event.type) {
          case 'session.status':
            nextStatuses = applySessionStatusEvent(_statuses, event.properties);
          case 'message.updated':
            nextMessages = applyMessageUpdatedEvent(
              _messages,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
          case 'message.removed':
            nextMessages = applyMessageRemovedEvent(
              _messages,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
          case 'message.part.updated':
            nextMessages = applyMessagePartUpdatedEvent(
              _messages,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
          case 'todo.updated':
            nextTodos = applyTodoUpdatedEvent(
              _todos,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
            final sessionId = _selectedSessionId;
            final hasSnapshot = event.properties['todos'] is List;
            if (!hasSnapshot && sessionId != null && sessionId.isNotEmpty) {
              shouldReloadTodos = true;
            }
          case 'question.asked':
            nextQuestions = applyQuestionAskedEvent(
              _questionRequests,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
            alert = buildQuestionAskedAlert(
              previous: _questionRequests,
              next: nextQuestions,
            );
          case 'permission.asked':
            nextPermissions = applyPermissionAskedEvent(
              _permissionRequests,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
            alert = buildPermissionAskedAlert(
              previous: _permissionRequests,
              next: nextPermissions,
            );
          case 'question.rejected':
          case 'question.replied':
            nextQuestions = applyQuestionResolvedEvent(
              _questionRequests,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
          case 'permission.replied':
            nextPermissions = applyPermissionResolvedEvent(
              _permissionRequests,
              event.properties,
              selectedSessionId: _selectedSessionId,
            );
            shouldReloadPendingRequests = true;
        }
        setState(() {
          _eventStreamHealth = nextEventHealth;
          _recentEvents = nextRecentEvents;
          _statuses = nextStatuses;
          _messages = nextMessages;
          _todos = nextTodos;
          _questionRequests = nextQuestions;
          _permissionRequests = nextPermissions;
        });
        if (shouldReloadTodos) {
          final sessionId = _selectedSessionId;
          if (sessionId != null && sessionId.isNotEmpty) {
            _loadTodos(sessionId);
          }
        }
        if (shouldReloadPendingRequests) {
          _loadPendingRequests();
        }
        if (alert != null) {
          _showPendingRequestAlert(alert);
        }
      },
      onDone: () {
        if (_isActiveEventStreamConnection(connectionToken, scopeKey)) {
          _handleEventStreamDropped();
        }
      },
      onError: (error, stackTrace) {
        if (_isActiveEventStreamConnection(connectionToken, scopeKey)) {
          _handleEventStreamDropped();
        }
      },
    );
    if (!_isActiveEventStreamConnection(connectionToken, scopeKey)) {
      return;
    }
    _eventHealthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isActiveEventStreamConnection(connectionToken, scopeKey)) {
        _eventHealthTimer?.cancel();
        _eventHealthTimer = null;
        return;
      }
      final health = _sseConnectionMonitor.healthAt(DateTime.now());
      if (_eventStreamHealth != health) {
        setState(() {
          _eventStreamHealth = health;
        });
      }
      if (health == SseConnectionHealth.stale) {
        _handleEventStreamDropped();
      }
    });
  }

  void _handleEventStreamDropped() {
    if (!mounted ||
        _recoveringEventStream ||
        !widget.capabilities.hasEventStream) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final reconnectCompletedLog = l10n.shellRecoveryLogReconnectCompleted;
    final scopeKey = _scopeKey();
    final recoveryToken = ++_eventStreamRecoveryToken;
    final eventStreamService = _eventStreamService;
    _recoveringEventStream = true;
    _sseConnectionMonitor.markReconnecting();
    setState(() {
      _eventStreamHealth = SseConnectionHealth.reconnecting;
      _eventRecoveryLog = <String>[
        l10n.shellRecoveryLogReconnectRequested,
        ..._eventRecoveryLog,
      ].take(8).toList(growable: false);
    });
    unawaited(
      _recoverEventStream(
        recoveryToken: recoveryToken,
        scopeKey: scopeKey,
        eventStreamService: eventStreamService,
        reconnectCompletedLog: reconnectCompletedLog,
      ),
    );
  }

  Future<void> _recoverEventStream({
    required int recoveryToken,
    required String scopeKey,
    required EventStreamService eventStreamService,
    required String reconnectCompletedLog,
  }) async {
    try {
      await eventStreamService.disconnect();
      if (!_isActiveEventStreamRecovery(
        recoveryToken,
        scopeKey,
        eventStreamService,
      )) {
        return;
      }
      await _loadBundle();
      if (!_isActiveEventStreamRecovery(
        recoveryToken,
        scopeKey,
        eventStreamService,
      )) {
        return;
      }
      setState(() {
        _eventStreamHealth = _sseConnectionMonitor.healthAt(DateTime.now());
        _eventRecoveryLog = <String>[
          reconnectCompletedLog,
          ..._eventRecoveryLog,
        ].take(8).toList(growable: false);
      });
    } finally {
      if (_isActiveEventStreamRecovery(
        recoveryToken,
        scopeKey,
        eventStreamService,
      )) {
        _recoveringEventStream = false;
      }
    }
  }

  void _showPendingRequestAlert(PendingRequestAlert alert) {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return;
    }
    final title = pendingRequestAlertTitle(l10n, alert);
    final body = pendingRequestAlertBody(alert);
    final dedupeKey =
        '${widget.profile.storageKey}:${widget.project.directory}:${alert.kind.name}:${alert.requestId}';
    if (alert.kind == PendingRequestAlertKind.permission) {
      unawaited(
        (widget.pendingRequestSoundService ?? sharedPendingRequestSoundService)
            .playPermissionRequestSound(dedupeKey: dedupeKey),
      );
    }
    unawaited(
      _pendingRequestNotificationService.showPendingRequestNotification(
        dedupeKey: dedupeKey,
        title: title,
        body: body,
      ),
    );
    if (ScaffoldMessenger.maybeOf(context) == null) {
      return;
    }
    final compact = MediaQuery.sizeOf(context).width < 960;
    final message = pendingRequestAlertMessage(l10n, alert);
    showAppSnackBar(
      context,
      message: message,
      tone: AppSnackBarTone.warning,
      duration: const Duration(seconds: 6),
      replaceCurrent: true,
      action: compact
          ? AppSnackBarAction(
              label: l10n.shellNotificationOpenAction,
              onPressed: () {
                if (!mounted) {
                  return;
                }
                _selectPrimaryDestination(_ShellPrimaryDestination.context);
              },
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1320) {
      return _DesktopShell(
        profile: widget.profile,
        project: widget.project,
        capabilities: widget.capabilities,
        onExit: widget.onExit,
        availableProjects: widget.availableProjects,
        projectPanelError: widget.projectPanelError,
        onSelectProject: widget.onSelectProject,
        onReloadProjects: widget.onReloadProjects,
        sessions: _sessions,
        statuses: _statuses,
        messages: _messages,
        fileNodes: _fileNodes,
        fileStatuses: _fileStatuses,
        fileSearchResults: _fileSearchResults,
        textMatches: _textMatches,
        symbols: _symbols,
        filePreview: _filePreview,
        selectedFilePath: _selectedFilePath,
        fileSearchQuery: _fileSearchQuery,
        terminalCommand: _terminalCommand,
        lastShellResult: _lastShellResult,
        runningShellCommand: _runningShellCommand,
        questionRequests: _questionRequests,
        permissionRequests: _permissionRequests,
        configSnapshot: _configSnapshot,
        integrationStatusSnapshot: _integrationStatusSnapshot,
        lastIntegrationAuthUrl: _lastIntegrationAuthUrl,
        recentEvents: _recentEvents,
        eventStreamHealth: _eventStreamHealth,
        eventRecoveryLog: _eventRecoveryLog,
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        submittingPrompt: _submittingPrompt,
        onCreateSessionDraft: _startNewSessionDraft,
        onSelectSession: _selectSession,
        onForkSession: _forkSession,
        onAbortSession: _abortSession,
        onShareSession: _shareSession,
        onUnshareSession: _unshareSession,
        onDeleteSession: _deleteSession,
        onRenameSession: _renameSession,
        onRevertSession: _revertSession,
        onUnrevertSession: _unrevertSession,
        onInitSession: _initSession,
        onSummarizeSession: _summarizeSession,
        onSelectFile: _selectFile,
        onSearchFiles: (query) => _loadFiles(searchQuery: query),
        onRunShellCommand: _runShellCommand,
        onReplyQuestion: _replyQuestion,
        onRejectQuestion: _rejectQuestion,
        onReplyPermission: _replyPermission,
        onSubmitPrompt: _submitPrompt,
        onApplyConfig: _applyConfigRaw,
        onStartProviderAuth: _startProviderAuth,
        onStartMcpAuth: _startMcpAuth,
        primaryDestination: _primaryDestination,
        onSelectPrimaryDestination: _selectPrimaryDestination,
        onOpenCacheSettings: _openCacheSettings,
      );
    }
    if (width >= 960) {
      return _TabletLandscapeShell(
        profile: widget.profile,
        project: widget.project,
        capabilities: widget.capabilities,
        onExit: widget.onExit,
        availableProjects: widget.availableProjects,
        projectPanelError: widget.projectPanelError,
        onSelectProject: widget.onSelectProject,
        onReloadProjects: widget.onReloadProjects,
        sessions: _sessions,
        statuses: _statuses,
        messages: _messages,
        fileNodes: _fileNodes,
        fileStatuses: _fileStatuses,
        fileSearchResults: _fileSearchResults,
        textMatches: _textMatches,
        symbols: _symbols,
        filePreview: _filePreview,
        selectedFilePath: _selectedFilePath,
        fileSearchQuery: _fileSearchQuery,
        terminalCommand: _terminalCommand,
        lastShellResult: _lastShellResult,
        runningShellCommand: _runningShellCommand,
        questionRequests: _questionRequests,
        permissionRequests: _permissionRequests,
        configSnapshot: _configSnapshot,
        integrationStatusSnapshot: _integrationStatusSnapshot,
        lastIntegrationAuthUrl: _lastIntegrationAuthUrl,
        recentEvents: _recentEvents,
        eventStreamHealth: _eventStreamHealth,
        eventRecoveryLog: _eventRecoveryLog,
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        submittingPrompt: _submittingPrompt,
        onCreateSessionDraft: _startNewSessionDraft,
        onSelectSession: _selectSession,
        onForkSession: _forkSession,
        onAbortSession: _abortSession,
        onShareSession: _shareSession,
        onUnshareSession: _unshareSession,
        onDeleteSession: _deleteSession,
        onRenameSession: _renameSession,
        onRevertSession: _revertSession,
        onUnrevertSession: _unrevertSession,
        onInitSession: _initSession,
        onSummarizeSession: _summarizeSession,
        onSelectFile: _selectFile,
        onSearchFiles: (query) => _loadFiles(searchQuery: query),
        onRunShellCommand: _runShellCommand,
        onReplyQuestion: _replyQuestion,
        onRejectQuestion: _rejectQuestion,
        onReplyPermission: _replyPermission,
        onSubmitPrompt: _submitPrompt,
        onApplyConfig: _applyConfigRaw,
        onStartProviderAuth: _startProviderAuth,
        onStartMcpAuth: _startMcpAuth,
        primaryDestination: _primaryDestination,
        onSelectPrimaryDestination: _selectPrimaryDestination,
        onOpenCacheSettings: _openCacheSettings,
      );
    }
    if (width >= 700) {
      return _TabletPortraitShell(
        profile: widget.profile,
        project: widget.project,
        capabilities: widget.capabilities,
        onExit: widget.onExit,
        availableProjects: widget.availableProjects,
        projectPanelError: widget.projectPanelError,
        onSelectProject: widget.onSelectProject,
        onReloadProjects: widget.onReloadProjects,
        sessions: _sessions,
        statuses: _statuses,
        messages: _messages,
        fileNodes: _fileNodes,
        fileStatuses: _fileStatuses,
        fileSearchResults: _fileSearchResults,
        textMatches: _textMatches,
        symbols: _symbols,
        filePreview: _filePreview,
        selectedFilePath: _selectedFilePath,
        fileSearchQuery: _fileSearchQuery,
        terminalCommand: _terminalCommand,
        lastShellResult: _lastShellResult,
        runningShellCommand: _runningShellCommand,
        questionRequests: _questionRequests,
        permissionRequests: _permissionRequests,
        configSnapshot: _configSnapshot,
        integrationStatusSnapshot: _integrationStatusSnapshot,
        lastIntegrationAuthUrl: _lastIntegrationAuthUrl,
        recentEvents: _recentEvents,
        eventStreamHealth: _eventStreamHealth,
        eventRecoveryLog: _eventRecoveryLog,
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        submittingPrompt: _submittingPrompt,
        onCreateSessionDraft: _startNewSessionDraft,
        onSelectSession: _selectSession,
        onForkSession: _forkSession,
        onAbortSession: _abortSession,
        onShareSession: _shareSession,
        onUnshareSession: _unshareSession,
        onDeleteSession: _deleteSession,
        onRenameSession: _renameSession,
        onRevertSession: _revertSession,
        onUnrevertSession: _unrevertSession,
        onInitSession: _initSession,
        onSummarizeSession: _summarizeSession,
        onSelectFile: _selectFile,
        onSearchFiles: (query) => _loadFiles(searchQuery: query),
        onRunShellCommand: _runShellCommand,
        onReplyQuestion: _replyQuestion,
        onRejectQuestion: _rejectQuestion,
        onReplyPermission: _replyPermission,
        onSubmitPrompt: _submitPrompt,
        onApplyConfig: _applyConfigRaw,
        onStartProviderAuth: _startProviderAuth,
        onStartMcpAuth: _startMcpAuth,
        primaryDestination: _primaryDestination,
        onSelectPrimaryDestination: _selectPrimaryDestination,
        onOpenCacheSettings: _openCacheSettings,
      );
    }
    return _MobileShell(
      profile: widget.profile,
      project: widget.project,
      capabilities: widget.capabilities,
      onExit: widget.onExit,
      availableProjects: widget.availableProjects,
      projectPanelError: widget.projectPanelError,
      onSelectProject: widget.onSelectProject,
      onReloadProjects: widget.onReloadProjects,
      sessions: _sessions,
      statuses: _statuses,
      messages: _messages,
      fileNodes: _fileNodes,
      fileStatuses: _fileStatuses,
      fileSearchResults: _fileSearchResults,
      textMatches: _textMatches,
      symbols: _symbols,
      filePreview: _filePreview,
      selectedFilePath: _selectedFilePath,
      fileSearchQuery: _fileSearchQuery,
      terminalCommand: _terminalCommand,
      lastShellResult: _lastShellResult,
      runningShellCommand: _runningShellCommand,
      questionRequests: _questionRequests,
      permissionRequests: _permissionRequests,
      configSnapshot: _configSnapshot,
      integrationStatusSnapshot: _integrationStatusSnapshot,
      lastIntegrationAuthUrl: _lastIntegrationAuthUrl,
      recentEvents: _recentEvents,
      eventStreamHealth: _eventStreamHealth,
      eventRecoveryLog: _eventRecoveryLog,
      todos: _todos,
      selectedSessionId: _selectedSessionId,
      loading: _loading,
      error: _error,
      submittingPrompt: _submittingPrompt,
      onCreateSessionDraft: _startNewSessionDraft,
      onSelectSession: _selectSession,
      onForkSession: _forkSession,
      onAbortSession: _abortSession,
      onShareSession: _shareSession,
      onUnshareSession: _unshareSession,
      onDeleteSession: _deleteSession,
      onRenameSession: _renameSession,
      onRevertSession: _revertSession,
      onUnrevertSession: _unrevertSession,
      onInitSession: _initSession,
      onSummarizeSession: _summarizeSession,
      onSelectFile: _selectFile,
      onSearchFiles: (query) => _loadFiles(searchQuery: query),
      onRunShellCommand: _runShellCommand,
      onReplyQuestion: _replyQuestion,
      onRejectQuestion: _rejectQuestion,
      onReplyPermission: _replyPermission,
      onSubmitPrompt: _submitPrompt,
      onApplyConfig: _applyConfigRaw,
      onStartProviderAuth: _startProviderAuth,
      onStartMcpAuth: _startMcpAuth,
      primaryDestination: _primaryDestination,
      onSelectPrimaryDestination: _selectPrimaryDestination,
      onOpenCacheSettings: _openCacheSettings,
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.profile,
    required this.project,
    required this.capabilities,
    required this.onExit,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.fileNodes,
    required this.fileStatuses,
    required this.fileSearchResults,
    required this.textMatches,
    required this.symbols,
    required this.filePreview,
    required this.selectedFilePath,
    required this.fileSearchQuery,
    required this.terminalCommand,
    required this.lastShellResult,
    required this.runningShellCommand,
    required this.questionRequests,
    required this.permissionRequests,
    required this.configSnapshot,
    required this.integrationStatusSnapshot,
    required this.lastIntegrationAuthUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onCreateSessionDraft,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
    required this.onSelectFile,
    required this.onSearchFiles,
    required this.onRunShellCommand,
    required this.onReplyQuestion,
    required this.onRejectQuestion,
    required this.onReplyPermission,
    required this.onApplyConfig,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
    required this.primaryDestination,
    required this.onSelectPrimaryDestination,
    required this.onOpenCacheSettings,
    required this.submittingPrompt,
    required this.onSubmitPrompt,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<FileNodeSummary> fileNodes;
  final List<FileStatusSummary> fileStatuses;
  final List<String> fileSearchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final FileContentSummary? filePreview;
  final String? selectedFilePath;
  final String fileSearchQuery;
  final String terminalCommand;
  final ShellCommandResult? lastShellResult;
  final bool runningShellCommand;
  final List<QuestionRequestSummary> questionRequests;
  final List<PermissionRequestSummary> permissionRequests;
  final ConfigSnapshot? configSnapshot;
  final IntegrationStatusSnapshot? integrationStatusSnapshot;
  final String? lastIntegrationAuthUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSessionDraft;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onSearchFiles;
  final ValueChanged<String> onRunShellCommand;
  final Future<void> Function(String, List<List<String>>) onReplyQuestion;
  final Future<void> Function(String) onRejectQuestion;
  final Future<void> Function(String, String) onReplyPermission;
  final Future<void> Function(String) onApplyConfig;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;
  final _ShellPrimaryDestination primaryDestination;
  final ValueChanged<_ShellPrimaryDestination> onSelectPrimaryDestination;
  final Future<void> Function() onOpenCacheSettings;
  final bool submittingPrompt;
  final Future<bool> Function(String, _ComposerSubmissionOptions)
  onSubmitPrompt;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      child: Column(
        children: <Widget>[
          _ShellPrimaryDestinationStrip(
            selectedDestination: primaryDestination,
            onSelectDestination: onSelectPrimaryDestination,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 300,
                  child: _LeftRail(
                    profile: profile,
                    project: project,
                    capabilities: capabilities,
                    onExit: onExit,
                    availableProjects: availableProjects,
                    projectPanelError: projectPanelError,
                    onSelectProject: onSelectProject,
                    onReloadProjects: onReloadProjects,
                    sessions: sessions,
                    statuses: statuses,
                    selectedSessionId: selectedSessionId,
                    onCreateSessionDraft: onCreateSessionDraft,
                    onSelectSession: onSelectSession,
                    onForkSession: onForkSession,
                    onAbortSession: onAbortSession,
                    onShareSession: onShareSession,
                    onUnshareSession: onUnshareSession,
                    onDeleteSession: onDeleteSession,
                    onRenameSession: onRenameSession,
                    onRevertSession: onRevertSession,
                    onUnrevertSession: onUnrevertSession,
                    onInitSession: onInitSession,
                    onSummarizeSession: onSummarizeSession,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 9,
                  child: _ChatCanvas(
                    messages: messages,
                    configSnapshot: configSnapshot,
                    loading: loading,
                    error: error,
                    submittingPrompt: submittingPrompt,
                    selectedSessionId: selectedSessionId,
                    onSubmitPrompt: onSubmitPrompt,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 340,
                  child: switch (primaryDestination) {
                    _ShellPrimaryDestination.settings => _SettingsRail(
                      capabilities: capabilities,
                      sessions: sessions,
                      messages: messages,
                      selectedSessionId: selectedSessionId,
                      terminalCommand: terminalCommand,
                      lastShellResult: lastShellResult,
                      runningShellCommand: runningShellCommand,
                      configSnapshot: configSnapshot,
                      integrationStatusSnapshot: integrationStatusSnapshot,
                      lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                      recentEvents: recentEvents,
                      eventStreamHealth: eventStreamHealth,
                      eventRecoveryLog: eventRecoveryLog,
                      onApplyConfig: onApplyConfig,
                      onStartProviderAuth: onStartProviderAuth,
                      onStartMcpAuth: onStartMcpAuth,
                      onRunShellCommand: onRunShellCommand,
                      onOpenCacheSettings: onOpenCacheSettings,
                    ),
                    _ => _ContextRail(
                      fileNodes: fileNodes,
                      sessions: sessions,
                      messages: messages,
                      selectedSessionId: selectedSessionId,
                      capabilities: capabilities,
                      fileStatuses: fileStatuses,
                      fileSearchResults: fileSearchResults,
                      textMatches: textMatches,
                      symbols: symbols,
                      filePreview: filePreview,
                      selectedFilePath: selectedFilePath,
                      fileSearchQuery: fileSearchQuery,
                      terminalCommand: terminalCommand,
                      lastShellResult: lastShellResult,
                      runningShellCommand: runningShellCommand,
                      questionRequests: questionRequests,
                      permissionRequests: permissionRequests,
                      configSnapshot: configSnapshot,
                      integrationStatusSnapshot: integrationStatusSnapshot,
                      lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                      recentEvents: recentEvents,
                      eventStreamHealth: eventStreamHealth,
                      eventRecoveryLog: eventRecoveryLog,
                      onApplyConfig: onApplyConfig,
                      onStartProviderAuth: onStartProviderAuth,
                      onStartMcpAuth: onStartMcpAuth,
                      onSelectFile: onSelectFile,
                      onSearchFiles: onSearchFiles,
                      onRunShellCommand: onRunShellCommand,
                      onReplyQuestion: onReplyQuestion,
                      onRejectQuestion: onRejectQuestion,
                      onReplyPermission: onReplyPermission,
                      todos: todos,
                    ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletLandscapeShell extends StatelessWidget {
  const _TabletLandscapeShell({
    required this.profile,
    required this.project,
    required this.capabilities,
    required this.onExit,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.fileNodes,
    required this.fileStatuses,
    required this.fileSearchResults,
    required this.textMatches,
    required this.symbols,
    required this.filePreview,
    required this.selectedFilePath,
    required this.fileSearchQuery,
    required this.terminalCommand,
    required this.lastShellResult,
    required this.runningShellCommand,
    required this.questionRequests,
    required this.permissionRequests,
    required this.configSnapshot,
    required this.integrationStatusSnapshot,
    required this.lastIntegrationAuthUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onCreateSessionDraft,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
    required this.onSelectFile,
    required this.onSearchFiles,
    required this.onRunShellCommand,
    required this.onReplyQuestion,
    required this.onRejectQuestion,
    required this.onReplyPermission,
    required this.onApplyConfig,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
    required this.primaryDestination,
    required this.onSelectPrimaryDestination,
    required this.onOpenCacheSettings,
    required this.submittingPrompt,
    required this.onSubmitPrompt,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<FileNodeSummary> fileNodes;
  final List<FileStatusSummary> fileStatuses;
  final List<String> fileSearchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final FileContentSummary? filePreview;
  final String? selectedFilePath;
  final String fileSearchQuery;
  final String terminalCommand;
  final ShellCommandResult? lastShellResult;
  final bool runningShellCommand;
  final List<QuestionRequestSummary> questionRequests;
  final List<PermissionRequestSummary> permissionRequests;
  final ConfigSnapshot? configSnapshot;
  final IntegrationStatusSnapshot? integrationStatusSnapshot;
  final String? lastIntegrationAuthUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSessionDraft;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onSearchFiles;
  final ValueChanged<String> onRunShellCommand;
  final Future<void> Function(String, List<List<String>>) onReplyQuestion;
  final Future<void> Function(String) onRejectQuestion;
  final Future<void> Function(String, String) onReplyPermission;
  final Future<void> Function(String) onApplyConfig;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;
  final _ShellPrimaryDestination primaryDestination;
  final ValueChanged<_ShellPrimaryDestination> onSelectPrimaryDestination;
  final Future<void> Function() onOpenCacheSettings;
  final bool submittingPrompt;
  final Future<bool> Function(String, _ComposerSubmissionOptions)
  onSubmitPrompt;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      child: Column(
        children: <Widget>[
          _ShellPrimaryDestinationStrip(
            selectedDestination: primaryDestination,
            onSelectDestination: onSelectPrimaryDestination,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: _LeftRail(
                    profile: profile,
                    project: project,
                    capabilities: capabilities,
                    onExit: onExit,
                    availableProjects: availableProjects,
                    projectPanelError: projectPanelError,
                    onSelectProject: onSelectProject,
                    onReloadProjects: onReloadProjects,
                    sessions: sessions,
                    statuses: statuses,
                    selectedSessionId: selectedSessionId,
                    onCreateSessionDraft: onCreateSessionDraft,
                    onSelectSession: onSelectSession,
                    onForkSession: onForkSession,
                    onAbortSession: onAbortSession,
                    onShareSession: onShareSession,
                    onUnshareSession: onUnshareSession,
                    onDeleteSession: onDeleteSession,
                    onRenameSession: onRenameSession,
                    onRevertSession: onRevertSession,
                    onUnrevertSession: onUnrevertSession,
                    onInitSession: onInitSession,
                    onSummarizeSession: onSummarizeSession,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _ChatCanvas(
                    messages: messages,
                    configSnapshot: configSnapshot,
                    loading: loading,
                    error: error,
                    submittingPrompt: submittingPrompt,
                    selectedSessionId: selectedSessionId,
                    onSubmitPrompt: onSubmitPrompt,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 280,
                  child: switch (primaryDestination) {
                    _ShellPrimaryDestination.settings => _SettingsRail(
                      capabilities: capabilities,
                      sessions: sessions,
                      messages: messages,
                      selectedSessionId: selectedSessionId,
                      terminalCommand: terminalCommand,
                      lastShellResult: lastShellResult,
                      runningShellCommand: runningShellCommand,
                      configSnapshot: configSnapshot,
                      integrationStatusSnapshot: integrationStatusSnapshot,
                      lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                      recentEvents: recentEvents,
                      eventStreamHealth: eventStreamHealth,
                      eventRecoveryLog: eventRecoveryLog,
                      onApplyConfig: onApplyConfig,
                      onStartProviderAuth: onStartProviderAuth,
                      onStartMcpAuth: onStartMcpAuth,
                      onRunShellCommand: onRunShellCommand,
                      onOpenCacheSettings: onOpenCacheSettings,
                    ),
                    _ => _ContextRail(
                      compact: true,
                      capabilities: capabilities,
                      sessions: sessions,
                      messages: messages,
                      selectedSessionId: selectedSessionId,
                      fileNodes: fileNodes,
                      fileStatuses: fileStatuses,
                      fileSearchResults: fileSearchResults,
                      textMatches: textMatches,
                      symbols: symbols,
                      filePreview: filePreview,
                      selectedFilePath: selectedFilePath,
                      fileSearchQuery: fileSearchQuery,
                      terminalCommand: terminalCommand,
                      lastShellResult: lastShellResult,
                      runningShellCommand: runningShellCommand,
                      questionRequests: questionRequests,
                      permissionRequests: permissionRequests,
                      configSnapshot: configSnapshot,
                      integrationStatusSnapshot: integrationStatusSnapshot,
                      lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                      recentEvents: recentEvents,
                      eventStreamHealth: eventStreamHealth,
                      eventRecoveryLog: eventRecoveryLog,
                      onApplyConfig: onApplyConfig,
                      onStartProviderAuth: onStartProviderAuth,
                      onStartMcpAuth: onStartMcpAuth,
                      onSelectFile: onSelectFile,
                      onSearchFiles: onSearchFiles,
                      onRunShellCommand: onRunShellCommand,
                      onReplyQuestion: onReplyQuestion,
                      onRejectQuestion: onRejectQuestion,
                      onReplyPermission: onReplyPermission,
                      todos: todos,
                    ),
                  },
                ),
              ],
            ),
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
    required this.capabilities,
    required this.onExit,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.fileNodes,
    required this.fileStatuses,
    required this.fileSearchResults,
    required this.textMatches,
    required this.symbols,
    required this.filePreview,
    required this.selectedFilePath,
    required this.fileSearchQuery,
    required this.terminalCommand,
    required this.lastShellResult,
    required this.runningShellCommand,
    required this.questionRequests,
    required this.permissionRequests,
    required this.configSnapshot,
    required this.integrationStatusSnapshot,
    required this.lastIntegrationAuthUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onCreateSessionDraft,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
    required this.onSelectFile,
    required this.onSearchFiles,
    required this.onRunShellCommand,
    required this.onReplyQuestion,
    required this.onRejectQuestion,
    required this.onReplyPermission,
    required this.onApplyConfig,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
    required this.primaryDestination,
    required this.onSelectPrimaryDestination,
    required this.onOpenCacheSettings,
    required this.submittingPrompt,
    required this.onSubmitPrompt,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<FileNodeSummary> fileNodes;
  final List<FileStatusSummary> fileStatuses;
  final List<String> fileSearchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final FileContentSummary? filePreview;
  final String? selectedFilePath;
  final String fileSearchQuery;
  final String terminalCommand;
  final ShellCommandResult? lastShellResult;
  final bool runningShellCommand;
  final List<QuestionRequestSummary> questionRequests;
  final List<PermissionRequestSummary> permissionRequests;
  final ConfigSnapshot? configSnapshot;
  final IntegrationStatusSnapshot? integrationStatusSnapshot;
  final String? lastIntegrationAuthUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSessionDraft;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onSearchFiles;
  final ValueChanged<String> onRunShellCommand;
  final Future<void> Function(String, List<List<String>>) onReplyQuestion;
  final Future<void> Function(String) onRejectQuestion;
  final Future<void> Function(String, String) onReplyPermission;
  final Future<void> Function(String) onApplyConfig;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;
  final _ShellPrimaryDestination primaryDestination;
  final ValueChanged<_ShellPrimaryDestination> onSelectPrimaryDestination;
  final Future<void> Function() onOpenCacheSettings;
  final bool submittingPrompt;
  final Future<bool> Function(String, _ComposerSubmissionOptions)
  onSubmitPrompt;

  @override
  Widget build(BuildContext context) {
    final workspaceDrawer = _WorkspaceDrawer(
      project: project,
      profile: profile,
      availableProjects: availableProjects,
      projectPanelError: projectPanelError,
      onSelectProject: onSelectProject,
      onReloadProjects: onReloadProjects,
      sessions: sessions,
      statuses: statuses,
      capabilities: capabilities,
      selectedSessionId: selectedSessionId,
      onCreateSessionDraft: onCreateSessionDraft,
      onSelectSession: onSelectSession,
      onForkSession: onForkSession,
      onAbortSession: onAbortSession,
      onShareSession: onShareSession,
      onUnshareSession: onUnshareSession,
      onDeleteSession: onDeleteSession,
      onRenameSession: onRenameSession,
      onRevertSession: onRevertSession,
      onUnrevertSession: onUnrevertSession,
      onInitSession: onInitSession,
      onSummarizeSession: onSummarizeSession,
    );
    return _ShellScaffold(
      drawer: workspaceDrawer,
      child: Column(
        children: <Widget>[
          Builder(
            builder: (innerContext) => _ShellTopBar(
              project: project,
              onExit: onExit,
              onOpenWorkspacePanel: () =>
                  Scaffold.of(innerContext).openDrawer(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ShellPrimaryDestinationStrip(
            compact: true,
            selectedDestination: primaryDestination,
            onSelectDestination: onSelectPrimaryDestination,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AnimatedSwitcher(
              duration: _motionMedium,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  _fadeSlideTransition(child, animation),
              child: KeyedSubtree(
                key: ValueKey<_ShellPrimaryDestination>(primaryDestination),
                child: switch (primaryDestination) {
                  _ShellPrimaryDestination.sessions => _CompactSessionsPanel(
                    project: project,
                    profile: profile,
                    availableProjects: availableProjects,
                    projectPanelError: projectPanelError,
                    onSelectProject: onSelectProject,
                    onReloadProjects: onReloadProjects,
                    statuses: statuses,
                    sessions: sessions,
                    capabilities: capabilities,
                    selectedSessionId: selectedSessionId,
                    onCreateSessionDraft: onCreateSessionDraft,
                    onSelectSession: onSelectSession,
                    onForkSession: onForkSession,
                    onAbortSession: onAbortSession,
                    onShareSession: onShareSession,
                    onUnshareSession: onUnshareSession,
                    onDeleteSession: onDeleteSession,
                    onRenameSession: onRenameSession,
                    onRevertSession: onRevertSession,
                    onUnrevertSession: onUnrevertSession,
                    onInitSession: onInitSession,
                    onSummarizeSession: onSummarizeSession,
                  ),
                  _ShellPrimaryDestination.context => _ContextRail(
                    compact: true,
                    fileNodes: fileNodes,
                    sessions: sessions,
                    messages: messages,
                    selectedSessionId: selectedSessionId,
                    capabilities: capabilities,
                    fileStatuses: fileStatuses,
                    fileSearchResults: fileSearchResults,
                    textMatches: textMatches,
                    symbols: symbols,
                    filePreview: filePreview,
                    selectedFilePath: selectedFilePath,
                    fileSearchQuery: fileSearchQuery,
                    terminalCommand: terminalCommand,
                    lastShellResult: lastShellResult,
                    runningShellCommand: runningShellCommand,
                    questionRequests: questionRequests,
                    permissionRequests: permissionRequests,
                    configSnapshot: configSnapshot,
                    integrationStatusSnapshot: integrationStatusSnapshot,
                    lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                    recentEvents: recentEvents,
                    eventStreamHealth: eventStreamHealth,
                    eventRecoveryLog: eventRecoveryLog,
                    onApplyConfig: onApplyConfig,
                    onStartProviderAuth: onStartProviderAuth,
                    onStartMcpAuth: onStartMcpAuth,
                    onSelectFile: onSelectFile,
                    onSearchFiles: onSearchFiles,
                    onRunShellCommand: onRunShellCommand,
                    onReplyQuestion: onReplyQuestion,
                    onRejectQuestion: onRejectQuestion,
                    onReplyPermission: onReplyPermission,
                    todos: todos,
                  ),
                  _ShellPrimaryDestination.settings => _SettingsRail(
                    capabilities: capabilities,
                    sessions: sessions,
                    messages: messages,
                    selectedSessionId: selectedSessionId,
                    terminalCommand: terminalCommand,
                    lastShellResult: lastShellResult,
                    runningShellCommand: runningShellCommand,
                    configSnapshot: configSnapshot,
                    integrationStatusSnapshot: integrationStatusSnapshot,
                    lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                    recentEvents: recentEvents,
                    eventStreamHealth: eventStreamHealth,
                    eventRecoveryLog: eventRecoveryLog,
                    onApplyConfig: onApplyConfig,
                    onStartProviderAuth: onStartProviderAuth,
                    onStartMcpAuth: onStartMcpAuth,
                    onRunShellCommand: onRunShellCommand,
                    onOpenCacheSettings: onOpenCacheSettings,
                  ),
                  _ShellPrimaryDestination.chat => _ChatCanvas(
                    messages: messages,
                    configSnapshot: configSnapshot,
                    loading: loading,
                    error: error,
                    submittingPrompt: submittingPrompt,
                    selectedSessionId: selectedSessionId,
                    onSubmitPrompt: onSubmitPrompt,
                  ),
                },
              ),
            ),
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
    required this.capabilities,
    required this.onExit,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.sessions,
    required this.statuses,
    required this.messages,
    required this.fileNodes,
    required this.fileStatuses,
    required this.fileSearchResults,
    required this.textMatches,
    required this.symbols,
    required this.filePreview,
    required this.selectedFilePath,
    required this.fileSearchQuery,
    required this.terminalCommand,
    required this.lastShellResult,
    required this.runningShellCommand,
    required this.questionRequests,
    required this.permissionRequests,
    required this.configSnapshot,
    required this.integrationStatusSnapshot,
    required this.lastIntegrationAuthUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onCreateSessionDraft,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
    required this.onSelectFile,
    required this.onSearchFiles,
    required this.onRunShellCommand,
    required this.onReplyQuestion,
    required this.onRejectQuestion,
    required this.onReplyPermission,
    required this.onApplyConfig,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
    required this.primaryDestination,
    required this.onSelectPrimaryDestination,
    required this.onOpenCacheSettings,
    required this.submittingPrompt,
    required this.onSubmitPrompt,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final List<FileNodeSummary> fileNodes;
  final List<FileStatusSummary> fileStatuses;
  final List<String> fileSearchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final FileContentSummary? filePreview;
  final String? selectedFilePath;
  final String fileSearchQuery;
  final String terminalCommand;
  final ShellCommandResult? lastShellResult;
  final bool runningShellCommand;
  final List<QuestionRequestSummary> questionRequests;
  final List<PermissionRequestSummary> permissionRequests;
  final ConfigSnapshot? configSnapshot;
  final IntegrationStatusSnapshot? integrationStatusSnapshot;
  final String? lastIntegrationAuthUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSessionDraft;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onSearchFiles;
  final ValueChanged<String> onRunShellCommand;
  final Future<void> Function(String, List<List<String>>) onReplyQuestion;
  final Future<void> Function(String) onRejectQuestion;
  final Future<void> Function(String, String) onReplyPermission;
  final Future<void> Function(String) onApplyConfig;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;
  final _ShellPrimaryDestination primaryDestination;
  final ValueChanged<_ShellPrimaryDestination> onSelectPrimaryDestination;
  final Future<void> Function() onOpenCacheSettings;
  final bool submittingPrompt;
  final Future<bool> Function(String, _ComposerSubmissionOptions)
  onSubmitPrompt;

  @override
  Widget build(BuildContext context) {
    final workspaceDrawer = _WorkspaceDrawer(
      project: project,
      profile: profile,
      availableProjects: availableProjects,
      projectPanelError: projectPanelError,
      onSelectProject: onSelectProject,
      onReloadProjects: onReloadProjects,
      sessions: sessions,
      statuses: statuses,
      capabilities: capabilities,
      selectedSessionId: selectedSessionId,
      onCreateSessionDraft: onCreateSessionDraft,
      onSelectSession: onSelectSession,
      onForkSession: onForkSession,
      onAbortSession: onAbortSession,
      onShareSession: onShareSession,
      onUnshareSession: onUnshareSession,
      onDeleteSession: onDeleteSession,
      onRenameSession: onRenameSession,
      onRevertSession: onRevertSession,
      onUnrevertSession: onUnrevertSession,
      onInitSession: onInitSession,
      onSummarizeSession: onSummarizeSession,
    );
    return _ShellScaffold(
      drawer: workspaceDrawer,
      child: Column(
        children: <Widget>[
          Builder(
            builder: (innerContext) => _ShellTopBar(
              project: project,
              onExit: onExit,
              onOpenWorkspacePanel: () =>
                  Scaffold.of(innerContext).openDrawer(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ShellPrimaryDestinationStrip(
            compact: true,
            selectedDestination: primaryDestination,
            onSelectDestination: onSelectPrimaryDestination,
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: AnimatedSwitcher(
              duration: _motionMedium,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  _fadeSlideTransition(child, animation),
              child: KeyedSubtree(
                key: ValueKey<_ShellPrimaryDestination>(primaryDestination),
                child: switch (primaryDestination) {
                  _ShellPrimaryDestination.sessions => _CompactSessionsPanel(
                    project: project,
                    profile: profile,
                    availableProjects: availableProjects,
                    projectPanelError: projectPanelError,
                    onSelectProject: onSelectProject,
                    onReloadProjects: onReloadProjects,
                    compact: true,
                    statuses: statuses,
                    sessions: sessions,
                    capabilities: capabilities,
                    selectedSessionId: selectedSessionId,
                    onCreateSessionDraft: onCreateSessionDraft,
                    onSelectSession: onSelectSession,
                    onForkSession: onForkSession,
                    onAbortSession: onAbortSession,
                    onShareSession: onShareSession,
                    onUnshareSession: onUnshareSession,
                    onDeleteSession: onDeleteSession,
                    onRenameSession: onRenameSession,
                    onRevertSession: onRevertSession,
                    onUnrevertSession: onUnrevertSession,
                    onInitSession: onInitSession,
                    onSummarizeSession: onSummarizeSession,
                  ),
                  _ShellPrimaryDestination.context => _ContextRail(
                    compact: true,
                    capabilities: capabilities,
                    sessions: sessions,
                    messages: messages,
                    selectedSessionId: selectedSessionId,
                    fileNodes: fileNodes,
                    fileStatuses: fileStatuses,
                    fileSearchResults: fileSearchResults,
                    textMatches: textMatches,
                    symbols: symbols,
                    filePreview: filePreview,
                    selectedFilePath: selectedFilePath,
                    fileSearchQuery: fileSearchQuery,
                    terminalCommand: terminalCommand,
                    lastShellResult: lastShellResult,
                    runningShellCommand: runningShellCommand,
                    questionRequests: questionRequests,
                    permissionRequests: permissionRequests,
                    configSnapshot: configSnapshot,
                    integrationStatusSnapshot: integrationStatusSnapshot,
                    lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                    recentEvents: recentEvents,
                    eventStreamHealth: eventStreamHealth,
                    eventRecoveryLog: eventRecoveryLog,
                    onApplyConfig: onApplyConfig,
                    onStartProviderAuth: onStartProviderAuth,
                    onStartMcpAuth: onStartMcpAuth,
                    onSelectFile: onSelectFile,
                    onSearchFiles: onSearchFiles,
                    onRunShellCommand: onRunShellCommand,
                    onReplyQuestion: onReplyQuestion,
                    onRejectQuestion: onRejectQuestion,
                    onReplyPermission: onReplyPermission,
                    todos: todos,
                  ),
                  _ShellPrimaryDestination.settings => _SettingsRail(
                    capabilities: capabilities,
                    sessions: sessions,
                    messages: messages,
                    selectedSessionId: selectedSessionId,
                    terminalCommand: terminalCommand,
                    lastShellResult: lastShellResult,
                    runningShellCommand: runningShellCommand,
                    configSnapshot: configSnapshot,
                    integrationStatusSnapshot: integrationStatusSnapshot,
                    lastIntegrationAuthUrl: lastIntegrationAuthUrl,
                    recentEvents: recentEvents,
                    eventStreamHealth: eventStreamHealth,
                    eventRecoveryLog: eventRecoveryLog,
                    onApplyConfig: onApplyConfig,
                    onStartProviderAuth: onStartProviderAuth,
                    onStartMcpAuth: onStartMcpAuth,
                    onRunShellCommand: onRunShellCommand,
                    onOpenCacheSettings: onOpenCacheSettings,
                  ),
                  _ShellPrimaryDestination.chat => _ChatCanvas(
                    compact: true,
                    messages: messages,
                    configSnapshot: configSnapshot,
                    loading: loading,
                    error: error,
                    submittingPrompt: submittingPrompt,
                    selectedSessionId: selectedSessionId,
                    onSubmitPrompt: onSubmitPrompt,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.child, this.drawer});

  final Widget child;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 960;
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Scaffold(
      drawer: drawer,
      body: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  surfaces.background,
                  surfaces.panel,
                  surfaces.background.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          Positioned(
            top: -140,
            left: -100,
            child: _AmbientGlow(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              size: 320,
            ),
          ),
          Positioned(
            right: -110,
            top: 120,
            child: _AmbientGlow(
              color: surfaces.panelEmphasis.withValues(alpha: 0.46),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -180,
            left: MediaQuery.sizeOf(context).width * 0.28,
            child: _AmbientGlow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              size: 360,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color,
              blurRadius: size / 2,
              spreadRadius: size / 6,
            ),
          ],
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}

String _shellPrimaryDestinationLabel(
  AppLocalizations l10n,
  _ShellPrimaryDestination destination,
) {
  return switch (destination) {
    _ShellPrimaryDestination.sessions => l10n.shellDestinationSessions,
    _ShellPrimaryDestination.chat => l10n.shellDestinationChat,
    _ShellPrimaryDestination.context => l10n.shellDestinationContext,
    _ShellPrimaryDestination.settings => l10n.shellDestinationSettings,
  };
}

IconData _shellPrimaryDestinationIcon(_ShellPrimaryDestination destination) {
  return switch (destination) {
    _ShellPrimaryDestination.sessions => Icons.forum_outlined,
    _ShellPrimaryDestination.chat => Icons.chat_bubble_outline_rounded,
    _ShellPrimaryDestination.context => Icons.layers_outlined,
    _ShellPrimaryDestination.settings => Icons.tune_rounded,
  };
}

class _ShellPrimaryDestinationStrip extends StatelessWidget {
  const _ShellPrimaryDestinationStrip({
    required this.selectedDestination,
    required this.onSelectDestination,
    this.compact = false,
  });

  final bool compact;
  final _ShellPrimaryDestination selectedDestination;
  final ValueChanged<_ShellPrimaryDestination> onSelectDestination;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _ShellPrimaryDestination.values
              .map(
                (destination) => _ShellPrimaryDestinationButton(
                  compact: compact,
                  destination: destination,
                  selected: destination == selectedDestination,
                  onTap: () => onSelectDestination(destination),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ShellPrimaryDestinationButton extends StatelessWidget {
  const _ShellPrimaryDestinationButton({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final bool compact;
  final _ShellPrimaryDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    final label = _shellPrimaryDestinationLabel(l10n, destination);
    final fill = selected
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.14),
            surfaces.panelEmphasis.withValues(alpha: 0.92),
          )
        : surfaces.panelMuted.withValues(alpha: 0.78);
    final border = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.28)
        : surfaces.lineSoft;
    final foreground = selected ? theme.colorScheme.primary : null;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: _motionFast,
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minWidth: compact ? 0 : 150),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _shellPrimaryDestinationIcon(destination),
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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

List<ProjectTarget> _projectOptions(
  ProjectTarget currentProject,
  List<ProjectTarget> availableProjects,
) {
  final byDirectory = <String, ProjectTarget>{};

  void add(ProjectTarget target) {
    byDirectory[target.directory] = target;
  }

  add(currentProject);
  for (final project in availableProjects) {
    add(project);
  }
  return byDirectory.values.toList(growable: false);
}

class _ProjectSwitcherPanel extends StatelessWidget {
  const _ProjectSwitcherPanel({
    required this.project,
    required this.profile,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    this.activeSessionsLabel,
    this.activeSessionsIndicator,
    this.onExit,
    this.compact = false,
  });

  final ProjectTarget project;
  final ServerProfile profile;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final String? activeSessionsLabel;
  final Widget? activeSessionsIndicator;
  final VoidCallback? onExit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projects = _projectOptions(project, availableProjects);
    return _PanelCard(
      tone: _PanelTone.subtle,
      eyebrow: l10n.shellWorkspaceEyebrow,
      title: l10n.shellProjectRailTitle,
      subtitle: project.directory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(project.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _InfoChip(
                label: project.branch ?? l10n.shellUnknownLabel,
                icon: Icons.account_tree_outlined,
                emphasis: true,
              ),
              _InfoChip(
                label: profile.effectiveLabel,
                icon: Icons.cloud_outlined,
              ),
              if (activeSessionsLabel != null)
                _InfoChip(
                  label: activeSessionsLabel!,
                  emphasis: activeSessionsIndicator != null,
                  iconChild: activeSessionsIndicator,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < projects.length; index += 1) ...<Widget>[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _ProjectTile(
              project: projects[index],
              selected: projects[index].directory == project.directory,
              onTap: onSelectProject == null
                  ? null
                  : () => onSelectProject!(projects[index]),
            ),
          ],
          if (projectPanelError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.projectCatalogUnavailableBody,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (projectPanelError != null &&
              onReloadProjects != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onReloadProjects!(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.homeActionRetry),
              ),
            ),
          ],
          if (onExit != null) ...<Widget>[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Semantics(
              label: l10n.homeBackToServersAction,
              button: true,
              child: OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l10n.homeBackToServersAction),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.selected,
    this.onTap,
  });

  final ProjectTarget project;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final fill = selected
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.12),
            surfaces.panelEmphasis.withValues(alpha: 0.9),
          )
        : surfaces.panelMuted.withValues(alpha: 0.66);
    final border = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.28)
        : surfaces.lineSoft;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: project.label,
      child: InkWell(
        key: ValueKey<String>('project-tile-${project.directory}'),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: _motionFast,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      project.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(project.directory, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _InfoChip(
                label: project.branch ?? project.vcs ?? project.source ?? 'dir',
                icon: selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.folder_open_rounded,
                emphasis: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceDrawer extends StatelessWidget {
  const _WorkspaceDrawer({
    required this.project,
    required this.profile,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.sessions,
    required this.statuses,
    required this.capabilities,
    required this.selectedSessionId,
    required this.onCreateSessionDraft,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
  });

  final ProjectTarget project;
  final ServerProfile profile;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final CapabilityRegistry capabilities;
  final String? selectedSessionId;
  final VoidCallback onCreateSessionDraft;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Drawer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: surfaces.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _CompactSessionsPanel(
              compact: true,
              project: project,
              profile: profile,
              availableProjects: availableProjects,
              projectPanelError: projectPanelError,
              onSelectProject: (nextProject) {
                Navigator.of(context).maybePop();
                onSelectProject?.call(nextProject);
              },
              onReloadProjects: onReloadProjects,
              statuses: statuses,
              sessions: sessions,
              capabilities: capabilities,
              selectedSessionId: selectedSessionId,
              onCreateSessionDraft: () {
                Navigator.of(context).maybePop();
                onCreateSessionDraft();
              },
              onSelectSession: (sessionId) {
                Navigator.of(context).maybePop();
                onSelectSession(sessionId);
              },
              onForkSession: onForkSession,
              onAbortSession: onAbortSession,
              onShareSession: onShareSession,
              onUnshareSession: onUnshareSession,
              onDeleteSession: onDeleteSession,
              onRenameSession: onRenameSession,
              onRevertSession: onRevertSession,
              onUnrevertSession: onUnrevertSession,
              onInitSession: onInitSession,
              onSummarizeSession: onSummarizeSession,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSessionsPanel extends StatelessWidget {
  const _CompactSessionsPanel({
    required this.project,
    required this.profile,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.statuses,
    required this.sessions,
    required this.capabilities,
    required this.selectedSessionId,
    required this.onCreateSessionDraft,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
    this.compact = false,
  });

  final bool compact;
  final ProjectTarget project;
  final ServerProfile profile;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final Map<String, SessionStatusSummary> statuses;
  final List<SessionSummary> sessions;
  final CapabilityRegistry capabilities;
  final String? selectedSessionId;
  final VoidCallback onCreateSessionDraft;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orderedSessions = _buildSessionTree(sessions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ProjectSwitcherPanel(
          project: project,
          profile: profile,
          availableProjects: availableProjects,
          projectPanelError: projectPanelError,
          onSelectProject: onSelectProject,
          onReloadProjects: onReloadProjects,
          compact: compact,
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
        Expanded(
          child: _PanelCard(
            tone: _PanelTone.subtle,
            eyebrow: l10n.shellSessionsEyebrow,
            title: _shellPrimaryDestinationLabel(
              l10n,
              _ShellPrimaryDestination.sessions,
            ),
            subtitle: l10n.shellThreadsCount(sessions.length),
            fillChild: true,
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: l10n.shellNewSession,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('new-session-button'),
                      onPressed: onCreateSessionDraft,
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(l10n.shellNewSession),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...(sessions.isEmpty
                    ? <Widget>[
                        _SessionTile(
                          title: l10n.shellSessionCurrent,
                          status: l10n.shellStatusIdle,
                          statusType: 'idle',
                        ),
                      ]
                    : sessions
                          .map((session) {
                            final depth = orderedSessions[session.id] ?? 0;
                            return Padding(
                              padding: EdgeInsets.only(
                                left: depth * AppSpacing.sm,
                                bottom: AppSpacing.sm,
                              ),
                              child: _SessionTile(
                                title: session.title,
                                status: _statusLabel(
                                  l10n,
                                  statuses[session.id],
                                ),
                                statusType:
                                    statuses[session.id]?.type ?? 'idle',
                                selected: session.id == selectedSessionId,
                                onTap: () => onSelectSession(session.id),
                              ),
                            );
                          })
                          .toList(growable: false)),
                if (selectedSessionId != null) ...<Widget>[
                  SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                  Text(
                    l10n.shellActionsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.shellActionsSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      if (capabilities.canForkSession)
                        OutlinedButton(
                          onPressed: () => onForkSession(selectedSessionId!),
                          child: Text(l10n.shellActionFork),
                        ),
                      if (capabilities.canShareSession) ...<Widget>[
                        OutlinedButton(
                          onPressed: () => onShareSession(selectedSessionId!),
                          child: Text(l10n.shellActionShare),
                        ),
                        OutlinedButton(
                          onPressed: () => onUnshareSession(selectedSessionId!),
                          child: Text(l10n.shellActionUnshare),
                        ),
                      ],
                      OutlinedButton(
                        onPressed: () => onRenameSession(selectedSessionId!),
                        child: Text(l10n.shellActionRename),
                      ),
                      OutlinedButton(
                        onPressed: () => onDeleteSession(selectedSessionId!),
                        child: Text(l10n.shellActionDelete),
                      ),
                      if (capabilities.hasShellCommands)
                        OutlinedButton(
                          onPressed: () => onAbortSession(selectedSessionId!),
                          child: Text(l10n.shellActionAbort),
                        ),
                      if (capabilities.canRevertSession) ...<Widget>[
                        OutlinedButton(
                          onPressed: () => onRevertSession(selectedSessionId!),
                          child: Text(l10n.shellActionRevert),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              onUnrevertSession(selectedSessionId!),
                          child: Text(l10n.shellActionUnrevert),
                        ),
                      ],
                      if (capabilities.canInitSession)
                        OutlinedButton(
                          onPressed: () => onInitSession(selectedSessionId!),
                          child: Text(l10n.shellActionInit),
                        ),
                      if (capabilities.canSummarizeSession)
                        OutlinedButton(
                          onPressed: () =>
                              onSummarizeSession(selectedSessionId!),
                          child: Text(l10n.shellActionSummarize),
                        ),
                    ],
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

class _SettingsRail extends StatefulWidget {
  const _SettingsRail({
    required this.capabilities,
    required this.sessions,
    required this.messages,
    required this.selectedSessionId,
    required this.terminalCommand,
    required this.lastShellResult,
    required this.runningShellCommand,
    required this.configSnapshot,
    required this.integrationStatusSnapshot,
    required this.lastIntegrationAuthUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.onApplyConfig,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
    required this.onRunShellCommand,
    required this.onOpenCacheSettings,
  });

  final CapabilityRegistry capabilities;
  final List<SessionSummary> sessions;
  final List<ChatMessage> messages;
  final String? selectedSessionId;
  final String terminalCommand;
  final ShellCommandResult? lastShellResult;
  final bool runningShellCommand;
  final ConfigSnapshot? configSnapshot;
  final IntegrationStatusSnapshot? integrationStatusSnapshot;
  final String? lastIntegrationAuthUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final Future<void> Function(String) onApplyConfig;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;
  final ValueChanged<String> onRunShellCommand;
  final Future<void> Function() onOpenCacheSettings;

  @override
  State<_SettingsRail> createState() => _SettingsRailState();
}

class _SettingsRailState extends State<_SettingsRail> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final advancedLabel = _advancedLabel(context);
    final advancedModuleCount = <bool>[
      widget.capabilities.hasShellCommands,
      widget.capabilities.hasConfigRead,
      widget.capabilities.hasProviderOAuth || widget.capabilities.hasMcpAuth,
      widget.capabilities.hasEventStream,
      true,
    ].where((enabled) => enabled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _PanelCard(
            tone: _PanelTone.subtle,
            title: _shellPrimaryDestinationLabel(
              l10n,
              _ShellPrimaryDestination.settings,
            ),
            subtitle: _showAdvanced
                ? '$advancedLabel · ${l10n.shellModulesCount(advancedModuleCount)}'
                : l10n.shellModulesCount(2),
            trailing: _InfoChip(
              label: _showAdvanced ? advancedLabel : l10n.cacheSettingsAction,
              icon: _showAdvanced ? Icons.science_outlined : Icons.tune_rounded,
            ),
            fillChild: true,
            child: ListView(
              key: const ValueKey<String>('settings-rail-scroll'),
              padding: EdgeInsets.zero,
              children: _showAdvanced
                  ? _buildAdvancedContent(context, l10n, advancedLabel)
                  : _buildDefaultContent(context, l10n, advancedLabel),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDefaultContent(
    BuildContext context,
    AppLocalizations l10n,
    String advancedLabel,
  ) {
    return <Widget>[
      _UtilitySection(
        title: l10n.cacheSettingsTitle,
        subtitle: l10n.cacheSettingsSubtitle,
        icon: Icons.storage_rounded,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: l10n.shellA11yOpenCacheSettings,
            button: true,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenCacheSettings,
              icon: const Icon(Icons.tune_rounded),
              label: Text(l10n.cacheSettingsAction),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      _UtilitySection(
        title: advancedLabel,
        subtitle: l10n.shellAdvancedSubtitle,
        icon: Icons.admin_panel_settings_outlined,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: l10n.shellA11yOpenAdvanced,
            button: true,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('settings-open-advanced'),
              onPressed: () {
                setState(() {
                  _showAdvanced = true;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.shellOpenAdvancedAction),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAdvancedContent(
    BuildContext context,
    AppLocalizations l10n,
    String advancedLabel,
  ) {
    return <Widget>[
      _UtilitySection(
        title: advancedLabel,
        subtitle: l10n.shellAdvancedOverviewSubtitle,
        icon: Icons.science_outlined,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: l10n.shellA11yBackToSettings,
            button: true,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showAdvanced = false;
                });
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(l10n.shellBackToSettingsAction),
            ),
          ),
        ),
      ),
      if (widget.capabilities.hasShellCommands) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        _TerminalPanel(
          terminalCommand: widget.terminalCommand,
          selectedSessionId: widget.selectedSessionId,
          running: widget.runningShellCommand,
          lastResult: widget.lastShellResult,
          onRunCommand: widget.onRunShellCommand,
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      _ConfigPreviewPanel(
        snapshot: widget.configSnapshot,
        onApply: widget.onApplyConfig,
      ),
      if (widget.capabilities.hasProviderOAuth ||
          widget.capabilities.hasMcpAuth) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        _IntegrationDiagnosticsPanel(
          snapshot: widget.integrationStatusSnapshot,
          lastAuthUrl: widget.lastIntegrationAuthUrl,
          onStartProviderAuth: widget.onStartProviderAuth,
          onStartMcpAuth: widget.onStartMcpAuth,
        ),
      ],
      if (widget.capabilities.hasEventStream) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        _EventHealthPanel(
          health: widget.eventStreamHealth,
          recentEvents: widget.recentEvents,
          recoveryLog: widget.eventRecoveryLog,
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      _RawInspectorPanel(
        sessions: widget.sessions,
        messages: widget.messages,
        selectedSessionId: widget.selectedSessionId,
      ),
    ];
  }
}

String _advancedLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return l10n.shellAdvancedLabel;
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.profile,
    required this.project,
    required this.capabilities,
    required this.onExit,
    required this.availableProjects,
    required this.projectPanelError,
    required this.onSelectProject,
    required this.onReloadProjects,
    required this.sessions,
    required this.statuses,
    required this.selectedSessionId,
    required this.onCreateSessionDraft,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final List<ProjectTarget> availableProjects;
  final String? projectPanelError;
  final ValueChanged<ProjectTarget>? onSelectProject;
  final Future<void> Function()? onReloadProjects;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final String? selectedSessionId;
  final VoidCallback onCreateSessionDraft;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
  final Future<void> Function(String) onDeleteSession;
  final Future<void> Function(String) onRenameSession;
  final Future<void> Function(String) onRevertSession;
  final Future<void> Function(String) onUnrevertSession;
  final Future<void> Function(String) onInitSession;
  final Future<void> Function(String) onSummarizeSession;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final orderedSessions = _buildSessionTree(sessions);
    final activeSessions = statuses.values.where(
      (status) => status.type == 'busy',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ProjectSwitcherPanel(
          project: project,
          profile: profile,
          availableProjects: availableProjects,
          projectPanelError: projectPanelError,
          onSelectProject: onSelectProject,
          onReloadProjects: onReloadProjects,
          activeSessionsLabel: l10n.shellActiveCount(activeSessions.length),
          activeSessionsIndicator: _AnimatedActivityGlyph(
            active: activeSessions.isNotEmpty,
            icon: Icons.bolt_rounded,
            color: activeSessions.isNotEmpty
                ? theme.colorScheme.primary
                : surfaces.accentSoft,
          ),
          onExit: onExit,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _PanelCard(
            tone: _PanelTone.subtle,
            eyebrow: l10n.shellSessionsEyebrow,
            title: l10n.shellSessionsTitle,
            subtitle: l10n.shellThreadsCount(sessions.length),
            fillChild: true,
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: l10n.shellNewSession,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('new-session-button'),
                      onPressed: onCreateSessionDraft,
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(l10n.shellNewSession),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...(sessions.isEmpty
                    ? <Widget>[
                        _SessionTile(
                          title: l10n.shellSessionCurrent,
                          status: l10n.shellStatusIdle,
                          statusType: 'idle',
                        ),
                      ]
                    : sessions
                          .map((session) {
                            final depth = orderedSessions[session.id] ?? 0;
                            return Padding(
                              padding: EdgeInsets.only(
                                left: depth * AppSpacing.sm,
                                bottom: AppSpacing.sm,
                              ),
                              child: _SessionTile(
                                title: session.title,
                                status: _statusLabel(
                                  l10n,
                                  statuses[session.id],
                                ),
                                statusType:
                                    statuses[session.id]?.type ?? 'idle',
                                selected: session.id == selectedSessionId,
                                onTap: () => onSelectSession(session.id),
                              ),
                            );
                          })
                          .toList(growable: false)),
              ],
            ),
          ),
        ),
        if (selectedSessionId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _PanelCard(
            tone: _PanelTone.subtle,
            eyebrow: l10n.shellControlsEyebrow,
            title: l10n.shellActionsTitle,
            subtitle: l10n.shellActionsSubtitle,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (capabilities.canForkSession)
                  OutlinedButton(
                    onPressed: () => onForkSession(selectedSessionId!),
                    child: Text(l10n.shellActionFork),
                  ),
                if (capabilities.canShareSession) ...<Widget>[
                  OutlinedButton(
                    onPressed: () => onShareSession(selectedSessionId!),
                    child: Text(l10n.shellActionShare),
                  ),
                  OutlinedButton(
                    onPressed: () => onUnshareSession(selectedSessionId!),
                    child: Text(l10n.shellActionUnshare),
                  ),
                ],
                OutlinedButton(
                  onPressed: () => onRenameSession(selectedSessionId!),
                  child: Text(l10n.shellActionRename),
                ),
                OutlinedButton(
                  onPressed: () => onDeleteSession(selectedSessionId!),
                  child: Text(l10n.shellActionDelete),
                ),
                if (capabilities.hasShellCommands)
                  OutlinedButton(
                    onPressed: () => onAbortSession(selectedSessionId!),
                    child: Text(l10n.shellActionAbort),
                  ),
                if (capabilities.canRevertSession) ...<Widget>[
                  OutlinedButton(
                    onPressed: () => onRevertSession(selectedSessionId!),
                    child: Text(l10n.shellActionRevert),
                  ),
                  OutlinedButton(
                    onPressed: () => onUnrevertSession(selectedSessionId!),
                    child: Text(l10n.shellActionUnrevert),
                  ),
                ],
                if (capabilities.canInitSession)
                  OutlinedButton(
                    onPressed: () => onInitSession(selectedSessionId!),
                    child: Text(l10n.shellActionInit),
                  ),
                if (capabilities.canSummarizeSession)
                  OutlinedButton(
                    onPressed: () => onSummarizeSession(selectedSessionId!),
                    child: Text(l10n.shellActionSummarize),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Map<String, double> _buildSessionTree(List<SessionSummary> sessions) {
  final byParent = <String?, List<SessionSummary>>{};
  for (final session in sessions) {
    byParent
        .putIfAbsent(session.parentId, () => <SessionSummary>[])
        .add(session);
  }

  final depths = <String, double>{};

  void visit(String? parentId, double depth) {
    for (final session in byParent[parentId] ?? const <SessionSummary>[]) {
      depths[session.id] = depth;
      visit(session.id, depth + 1);
    }
  }

  visit(null, 0);
  for (final session in sessions) {
    depths.putIfAbsent(session.id, () => 0);
  }
  return depths;
}

List<_ComposerModelOption> _composerModelOptions(ConfigSnapshot? snapshot) {
  final options = <String, _ComposerModelOption>{};

  void addOption(
    String? providerId,
    String? modelId, {
    String? label,
    List<String> reasoningValues = const <String>[],
  }) {
    final normalizedModel = modelId?.trim();
    if (normalizedModel == null || normalizedModel.isEmpty) {
      return;
    }
    final normalizedProvider = providerId?.trim();
    final key = normalizedProvider == null || normalizedProvider.isEmpty
        ? normalizedModel
        : '$normalizedProvider/$normalizedModel';
    options.putIfAbsent(
      key,
      () => _ComposerModelOption(
        key: key,
        label: label?.trim().isNotEmpty == true
            ? label!.trim()
            : normalizedProvider == null || normalizedProvider.isEmpty
            ? normalizedModel
            : '$normalizedProvider / $normalizedModel',
        modelId: normalizedModel,
        providerId: normalizedProvider,
        reasoningValues: List<String>.unmodifiable(reasoningValues),
      ),
    );
  }

  if (snapshot != null) {
    final catalog = snapshot.providerCatalog;
    for (final provider in catalog.providers) {
      final models = provider.models.values.toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));
      for (final model in models) {
        addOption(
          provider.id,
          model.id,
          label: '${provider.id} / ${model.id}',
          reasoningValues: model.reasoningVariants,
        );
      }
    }
    final config = snapshot.config.toJson();
    final configuredModel = config['model']?.toString();
    if (configuredModel != null && configuredModel.trim().isNotEmpty) {
      final normalizedConfiguredModel = configuredModel.trim();
      if (normalizedConfiguredModel.contains('/')) {
        final parts = normalizedConfiguredModel.split('/');
        if (parts.length >= 2) {
          final providerId = parts.first;
          final modelId = parts.sublist(1).join('/');
          addOption(
            providerId,
            modelId,
            reasoningValues:
                catalog
                    .modelForKey('$providerId/$modelId')
                    ?.reasoningVariants ??
                const <String>[],
          );
        }
      } else {
        addOption(null, normalizedConfiguredModel);
      }
    }
  }

  final values = options.values.toList(growable: false);
  values.sort((left, right) => left.label.compareTo(right.label));
  return values;
}

String? _defaultComposerModelKey(
  ConfigSnapshot? snapshot,
  List<_ComposerModelOption> options,
) {
  if (options.isEmpty) {
    return null;
  }
  final configModel = snapshot?.config.toJson()['model']?.toString();
  if (configModel != null && configModel.trim().isNotEmpty) {
    final normalized = configModel.trim();
    for (final option in options) {
      if (option.key == normalized ||
          option.modelId == normalized ||
          (option.providerId != null &&
              '${option.providerId}/${option.modelId}' == normalized)) {
        return option.key;
      }
    }
  }
  final defaults =
      snapshot?.providerCatalog.defaults ?? const <String, String>{};
  if (defaults.isNotEmpty) {
    for (final option in options) {
      final providerId = option.providerId;
      if (providerId == null || providerId.isEmpty) {
        continue;
      }
      if (defaults[providerId] == option.modelId) {
        return option.key;
      }
    }
  }
  return options.first.key;
}

String? _resolveDefaultComposerReasoning(
  ConfigSnapshot? snapshot,
  _ComposerModelOption? modelOption,
) {
  final reasoning = snapshot?.config.toJson()['reasoning']?.toString().trim();
  if (reasoning == null || reasoning.isEmpty) {
    return null;
  }
  if (modelOption == null || modelOption.reasoningValues.contains(reasoning)) {
    return reasoning;
  }
  return null;
}

String _reasoningLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'low' => l10n.shellComposerThinkingLow,
    'medium' => l10n.shellComposerThinkingBalanced,
    'high' => l10n.shellComposerThinkingDeep,
    'xhigh' || 'max' => l10n.shellComposerThinkingMax,
    _ => _titleCaseLabel(value),
  };
}

String _titleCaseLabel(String value) {
  final pieces = value
      .trim()
      .split(RegExp(r'[_\\-]+'))
      .where((piece) => piece.isNotEmpty)
      .toList(growable: false);
  if (pieces.isEmpty) {
    return value;
  }
  return pieces
      .map((piece) => '${piece[0].toUpperCase()}${piece.substring(1)}')
      .join(' ');
}

class _ChatCanvas extends StatefulWidget {
  const _ChatCanvas({
    required this.messages,
    required this.configSnapshot,
    required this.loading,
    required this.error,
    required this.submittingPrompt,
    required this.selectedSessionId,
    required this.onSubmitPrompt,
    this.compact = false,
  });

  final bool compact;
  final List<ChatMessage> messages;
  final ConfigSnapshot? configSnapshot;
  final bool loading;
  final String? error;
  final bool submittingPrompt;
  final String? selectedSessionId;
  final Future<bool> Function(String, _ComposerSubmissionOptions)
  onSubmitPrompt;

  @override
  State<_ChatCanvas> createState() => _ChatCanvasState();
}

class _ChatCanvasState extends State<_ChatCanvas> {
  static const double _bottomSnapThreshold = 72;

  late List<({ChatMessageInfo message, ChatPart part})> _parts;
  final ScrollController _scrollController = ScrollController();
  bool _shouldStickToBottom = true;
  bool _manualScrollInProgress = false;
  bool _deferredAutoScrollToBottom = false;
  double _lastKnownOffset = 0;
  int _programmaticScrollDepth = 0;

  @override
  void initState() {
    super.initState();
    _parts = _flattenedParts(widget.messages);
    _scrollController.addListener(_handleScroll);
    if (_parts.isNotEmpty) {
      _scheduleScrollToBottom();
    }
  }

  @override
  void didUpdateWidget(covariant _ChatCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedSessionChanged =
        oldWidget.selectedSessionId != widget.selectedSessionId;
    final loadingCompleted = oldWidget.loading && !widget.loading;
    final previousPartCount = _parts.length;
    if (!identical(oldWidget.messages, widget.messages)) {
      _parts = _flattenedParts(widget.messages);
    }
    final partCountChanged = previousPartCount != _parts.length;
    final shouldForceScrollToBottom =
        selectedSessionChanged ||
        (loadingCompleted &&
            (oldWidget.selectedSessionId == null ||
                oldWidget.messages.isEmpty));
    if (shouldForceScrollToBottom) {
      _shouldStickToBottom = true;
      _scheduleScrollToBottom();
      return;
    }
    if (loadingCompleted && !_shouldStickToBottom) {
      _scheduleRestoreOffset();
      return;
    }
    if (partCountChanged && _shouldStickToBottom) {
      if (_manualScrollInProgress) {
        _deferredAutoScrollToBottom = true;
      } else {
        _scheduleScrollToBottom(animated: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final position = _activeScrollPosition();
    if (position == null) {
      return;
    }
    _lastKnownOffset = position.pixels;
    _shouldStickToBottom = _isNearBottom();
  }

  bool _isNearBottom() {
    final position = _activeScrollPosition();
    if (position == null) {
      return true;
    }
    if (!position.hasContentDimensions) {
      return true;
    }
    return position.maxScrollExtent - position.pixels <= _bottomSnapThreshold;
  }

  ScrollPosition? _activeScrollPosition() {
    if (!_scrollController.hasClients) {
      return null;
    }
    final positions = _scrollController.positions
        .where((position) => position.hasContentDimensions)
        .toList(growable: false);
    if (positions.isEmpty) {
      return null;
    }
    final position = positions.last;
    if (!position.hasContentDimensions) {
      return null;
    }
    return position;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        _programmaticScrollDepth > 0) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _manualScrollInProgress = true;
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _manualScrollInProgress = true;
      return false;
    }
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _manualScrollInProgress = false;
      _flushDeferredAutoScroll();
      return false;
    }
    if (notification is ScrollEndNotification) {
      _manualScrollInProgress = false;
      _flushDeferredAutoScroll();
    }
    return false;
  }

  void _flushDeferredAutoScroll() {
    if (!_deferredAutoScrollToBottom ||
        _manualScrollInProgress ||
        !_shouldStickToBottom) {
      return;
    }
    _deferredAutoScrollToBottom = false;
    _scheduleScrollToBottom(animated: true);
  }

  void _scheduleScrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _activeScrollPosition();
      if (position == null) {
        return;
      }
      final target = position.maxScrollExtent;
      if (!target.isFinite) {
        return;
      }
      if ((position.pixels - target).abs() <= 1) {
        return;
      }
      _programmaticScrollDepth += 1;
      position.jumpTo(target);
      _completeProgrammaticScroll();
    });
  }

  void _scheduleRestoreOffset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _activeScrollPosition();
      if (position == null) {
        return;
      }
      final target = _lastKnownOffset
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() <= 1) {
        return;
      }
      _programmaticScrollDepth += 1;
      position.jumpTo(target);
      _completeProgrammaticScroll();
    });
  }

  void _completeProgrammaticScroll() {
    if (_programmaticScrollDepth > 0) {
      _programmaticScrollDepth -= 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxContentWidth = widget.compact ? double.infinity : 840.0;
    final composerModels = _composerModelOptions(widget.configSnapshot);
    final defaultComposerModelKey = _defaultComposerModelKey(
      widget.configSnapshot,
      composerModels,
    );
    _ComposerModelOption? defaultComposerModel;
    if (defaultComposerModelKey != null) {
      for (final option in composerModels) {
        if (option.key == defaultComposerModelKey) {
          defaultComposerModel = option;
          break;
        }
      }
    }
    final defaultComposerReasoning = _resolveDefaultComposerReasoning(
      widget.configSnapshot,
      defaultComposerModel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!widget.compact) ...<Widget>[
          _PanelCard(
            tone: _PanelTone.primary,
            eyebrow: l10n.shellPrimaryEyebrow,
            title: l10n.shellChatHeaderTitle,
            subtitle: widget.selectedSessionId == null
                ? l10n.shellNewSessionDraft
                : l10n.shellTimelinePartsInFocus(_parts.length),
            trailing: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _InfoChip(
                  label: l10n.shellThinkingModeLabel,
                  icon: Icons.psychology_alt_outlined,
                ),
                _InfoChip(
                  label: l10n.shellAgentLabel,
                  icon: Icons.auto_awesome_outlined,
                  emphasis: true,
                ),
              ],
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _InfoChip(
                  label: widget.selectedSessionId == null
                      ? l10n.shellReadyToStart
                      : l10n.shellLiveContext,
                  icon: Icons.forum_outlined,
                ),
                _InfoChip(
                  label: l10n.shellPartsCount(_parts.length),
                  icon: Icons.layers_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Expanded(
          child: _PanelCard(
            tone: _PanelTone.primary,
            eyebrow: widget.compact
                ? l10n.shellFocusedThreadEyebrow
                : l10n.shellTimelineEyebrow,
            title: l10n.shellChatTimelineTitle,
            subtitle: widget.compact ? null : l10n.shellConversationSubtitle,
            fillChild: true,
            child: AnimatedSwitcher(
              duration: _motionMedium,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  _fadeSlideTransition(child, animation),
              child: widget.loading
                  ? Center(
                      key: ValueKey<String>(
                        'chat-loading-${widget.selectedSessionId ?? 'draft'}',
                      ),
                      child: const CircularProgressIndicator(),
                    )
                  : widget.error != null
                  ? KeyedSubtree(
                      key: ValueKey<String>(
                        'chat-error-${widget.selectedSessionId ?? 'draft'}',
                      ),
                      child: _MessageBubble(
                        title: l10n.shellConnectionIssueTitle,
                        body: widget.error!,
                      ),
                    )
                  : Column(
                      key: ValueKey<String>(
                        'chat-content-${widget.selectedSessionId ?? 'draft'}',
                      ),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Theme.of(context)
                                      .extension<AppSurfaces>()!
                                      .panelMuted
                                      .withValues(alpha: 0.84),
                                  Theme.of(context)
                                      .extension<AppSurfaces>()!
                                      .panel
                                      .withValues(alpha: 0.96),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius,
                              ),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).extension<AppSurfaces>()!.lineSoft,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxContentWidth,
                                  ),
                                  child: _buildMessageList(l10n, _parts),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: _ComposerCard(
                              compact: widget.compact,
                              label: l10n.shellComposerPlaceholder,
                              submitting: widget.submittingPrompt,
                              startsNewSession:
                                  widget.selectedSessionId == null ||
                                  widget.selectedSessionId!.isEmpty,
                              modelOptions: composerModels,
                              serverDefaultModelKey: defaultComposerModelKey,
                              initialModelKey: defaultComposerModelKey,
                              initialReasoning: defaultComposerReasoning,
                              onSubmit: widget.onSubmitPrompt,
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

  Widget _buildMessageList(
    AppLocalizations l10n,
    List<({ChatMessageInfo message, ChatPart part})> parts,
  ) {
    if (parts.isEmpty) {
      return Listener(
        onPointerSignal: (_) => _manualScrollInProgress = true,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView(
            key: const ValueKey<String>('chat-message-list'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: <Widget>[
              _MessageBubble(
                title: l10n.shellAssistantMessageTitle,
                body: l10n.shellAssistantMessageBody,
                accent: true,
              ),
            ],
          ),
        ),
      );
    }
    return Listener(
      onPointerSignal: (_) => _manualScrollInProgress = true,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView(
          key: const ValueKey<String>('chat-message-list'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          // The shell already keeps the visible chat window in memory.
          // Using eager children here gives desktop scrollbars stable extents.
          children: _buildMessageChildren(parts),
        ),
      ),
    );
  }

  List<Widget> _buildMessageChildren(
    List<({ChatMessageInfo message, ChatPart part})> parts,
  ) {
    final children = <Widget>[];
    for (var index = 0; index < parts.length; index += 1) {
      if (index > 0) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
      final item = parts[index];
      children.add(ChatPartView(message: item.message, part: item.part));
    }
    return children;
  }

  List<({ChatMessageInfo message, ChatPart part})> _flattenedParts(
    List<ChatMessage> messages,
  ) {
    if (messages.isEmpty) {
      return const <({ChatMessageInfo message, ChatPart part})>[];
    }
    return messages
        .expand(
          (message) =>
              message.parts.map((part) => (message: message.info, part: part)),
        )
        .toList(growable: false);
  }
}

class _ContextRail extends StatelessWidget {
  const _ContextRail({
    required this.capabilities,
    required this.sessions,
    required this.messages,
    required this.selectedSessionId,
    required this.fileNodes,
    required this.fileStatuses,
    required this.fileSearchResults,
    required this.textMatches,
    required this.symbols,
    required this.filePreview,
    required this.selectedFilePath,
    required this.fileSearchQuery,
    required this.terminalCommand,
    required this.lastShellResult,
    required this.runningShellCommand,
    required this.questionRequests,
    required this.permissionRequests,
    required this.configSnapshot,
    required this.integrationStatusSnapshot,
    required this.lastIntegrationAuthUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.onApplyConfig,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
    required this.onSelectFile,
    required this.onSearchFiles,
    required this.onRunShellCommand,
    required this.onReplyQuestion,
    required this.onRejectQuestion,
    required this.onReplyPermission,
    required this.todos,
    this.compact = false,
  });

  final bool compact;
  final CapabilityRegistry capabilities;
  final List<SessionSummary> sessions;
  final List<ChatMessage> messages;
  final String? selectedSessionId;
  final List<FileNodeSummary> fileNodes;
  final List<FileStatusSummary> fileStatuses;
  final List<String> fileSearchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final FileContentSummary? filePreview;
  final String? selectedFilePath;
  final String fileSearchQuery;
  final String terminalCommand;
  final ShellCommandResult? lastShellResult;
  final bool runningShellCommand;
  final List<QuestionRequestSummary> questionRequests;
  final List<PermissionRequestSummary> permissionRequests;
  final ConfigSnapshot? configSnapshot;
  final IntegrationStatusSnapshot? integrationStatusSnapshot;
  final String? lastIntegrationAuthUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final Future<void> Function(String) onApplyConfig;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onSearchFiles;
  final ValueChanged<String> onRunShellCommand;
  final Future<void> Function(String, List<List<String>>) onReplyQuestion;
  final Future<void> Function(String) onRejectQuestion;
  final Future<void> Function(String, String) onReplyPermission;
  final List<TodoItem> todos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sectionCount = <bool>[
      capabilities.hasFiles,
      capabilities.hasTodos,
      capabilities.hasQuestions || capabilities.hasPermissions,
    ].where((enabled) => enabled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _PanelCard(
            tone: _PanelTone.subtle,
            eyebrow: compact
                ? l10n.shellContextEyebrow
                : l10n.shellUtilitiesEyebrow,
            title: l10n.shellContextTitle,
            subtitle: compact
                ? l10n.shellSecondaryContextSubtitle
                : l10n.shellSupportRailsSubtitle,
            trailing: _InfoChip(
              label: l10n.shellModulesCount(sectionCount),
              icon: Icons.dashboard_customize_outlined,
            ),
            fillChild: true,
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                if (capabilities.hasFiles) ...<Widget>[
                  _FilePanel(
                    fileNodes: fileNodes,
                    fileStatuses: fileStatuses,
                    fileSearchResults: fileSearchResults,
                    textMatches: textMatches,
                    symbols: symbols,
                    filePreview: filePreview,
                    selectedFilePath: selectedFilePath,
                    fileSearchQuery: fileSearchQuery,
                    onSelectFile: onSelectFile,
                    onSearchFiles: onSearchFiles,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _UtilityTile(
                  title: l10n.shellDiffTitle,
                  subtitle: l10n.shellDiffSubtitle,
                  icon: Icons.difference_outlined,
                ),
                if (capabilities.hasTodos) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _TodoTileList(todos: todos),
                ],
                const SizedBox(height: AppSpacing.sm),
                _UtilityTile(
                  title: l10n.shellToolsTitle,
                  subtitle: l10n.shellToolsSubtitle,
                  icon: Icons.handyman_outlined,
                ),
                if (capabilities.hasQuestions ||
                    capabilities.hasPermissions) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _PendingRequestsPanel(
                    questions: questionRequests,
                    permissions: permissionRequests,
                    onReplyQuestion: onReplyQuestion,
                    onRejectQuestion: onRejectQuestion,
                    onReplyPermission: onReplyPermission,
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

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.project,
    required this.onExit,
    this.onOpenWorkspacePanel,
  });

  final ProjectTarget project;
  final VoidCallback onExit;
  final VoidCallback? onOpenWorkspacePanel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return _PanelCard(
      tone: _PanelTone.subtle,
      eyebrow: l10n.shellWorkspaceEyebrow,
      title: project.label,
      subtitle: project.directory,
      trailing: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (onOpenWorkspacePanel != null)
            Semantics(
              button: true,
              label: l10n.shellProjectRailTitle,
              child: IconButton(
                tooltip: l10n.shellProjectRailTitle,
                onPressed: onOpenWorkspacePanel,
                icon: const Icon(Icons.menu_open_rounded),
              ),
            ),
          Semantics(
            label: l10n.homeBackToServersAction,
            button: true,
            child: compact
                ? OutlinedButton(
                    onPressed: onExit,
                    child: Text(l10n.homeBackToServersAction),
                  )
                : OutlinedButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(l10n.homeBackToServersAction),
                  ),
          ),
        ],
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _InfoChip(label: l10n.shellOpenCodeRemote, icon: Icons.waves_rounded),
          _InfoChip(
            label: l10n.shellContextNearby,
            icon: Icons.layers_outlined,
          ),
        ],
      ),
    );
  }
}

enum _PanelTone { primary, neutral, subtle }

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.fillChild = false,
    this.tone = _PanelTone.neutral,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool fillChild;
  final _PanelTone tone;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final topColor = switch (tone) {
      _PanelTone.primary => Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        surfaces.panelEmphasis.withValues(alpha: 0.98),
      ),
      _PanelTone.neutral => surfaces.panelRaised.withValues(alpha: 0.92),
      _PanelTone.subtle => surfaces.panelMuted.withValues(alpha: 0.88),
    };
    final bottomColor = switch (tone) {
      _PanelTone.primary => surfaces.panel.withValues(alpha: 0.98),
      _PanelTone.neutral => surfaces.panel.withValues(alpha: 0.96),
      _PanelTone.subtle => surfaces.panel.withValues(alpha: 0.92),
    };
    final borderColor = switch (tone) {
      _PanelTone.primary => theme.colorScheme.primary.withValues(alpha: 0.24),
      _PanelTone.neutral => surfaces.line,
      _PanelTone.subtle => surfaces.lineSoft,
    };
    final shadowColor = switch (tone) {
      _PanelTone.primary => theme.colorScheme.primary.withValues(alpha: 0.1),
      _PanelTone.neutral => Colors.black.withValues(alpha: 0.22),
      _PanelTone.subtle => Colors.black.withValues(alpha: 0.14),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[topColor, bottomColor],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadowColor,
            blurRadius: tone == _PanelTone.primary ? 36 : 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                      if (eyebrow != null) ...<Widget>[
                        Text(
                          eyebrow!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary.withValues(
                              alpha: tone == _PanelTone.primary ? 0.88 : 0.72,
                            ),
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Text(
                        title,
                        style:
                            (tone == _PanelTone.primary
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: surfaces.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  Flexible(child: trailing!),
                ],
              ],
            ),
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
    required this.statusType,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String status;
  final String statusType;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return _UtilityListRow(
      title: title,
      subtitle: status,
      selected: selected,
      leading: _SessionStateGlyph(statusType: statusType, selected: selected),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : surfaces.muted,
      ),
      onTap: onTap,
    );
  }
}

class _SessionStateGlyph extends StatelessWidget {
  const _SessionStateGlyph({required this.statusType, required this.selected});

  final String statusType;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final isBusy = statusType == 'busy';
    final isRetry = statusType == 'retry';
    final fill = isBusy || selected
        ? theme.colorScheme.primary.withValues(alpha: 0.16)
        : isRetry
        ? surfaces.warning.withValues(alpha: 0.14)
        : surfaces.panelMuted.withValues(alpha: 0.96);
    final border = isBusy || selected
        ? theme.colorScheme.primary.withValues(alpha: 0.2)
        : isRetry
        ? surfaces.warning.withValues(alpha: 0.2)
        : surfaces.lineSoft;
    final iconColor = isBusy || selected
        ? theme.colorScheme.primary
        : isRetry
        ? surfaces.warning
        : surfaces.accentSoft;
    final icon = isRetry
        ? Icons.sync_problem_rounded
        : selected
        ? Icons.bolt_rounded
        : Icons.chat_bubble_outline_rounded;
    return AnimatedContainer(
      duration: _motionFast,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: isBusy
            ? _AnimatedActivityGlyph(
                active: true,
                icon: Icons.bolt_rounded,
                color: iconColor,
              )
            : Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

class _AnimatedActivityGlyph extends StatefulWidget {
  const _AnimatedActivityGlyph({
    required this.active,
    required this.icon,
    required this.color,
  });

  final bool active;
  final IconData icon;
  final Color color;

  @override
  State<_AnimatedActivityGlyph> createState() => _AnimatedActivityGlyphState();
}

class _AnimatedActivityGlyphState extends State<_AnimatedActivityGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _activityCycle,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedActivityGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Icon(widget.icon, size: 14, color: widget.color);
    }
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = Curves.easeInOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.scale(
                scale: 0.82 + (value * 0.34),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(
                        alpha: 0.26 - (value * 0.18),
                      ),
                    ),
                  ),
                  child: const SizedBox(width: 14, height: 14),
                ),
              ),
              Transform.scale(scale: 0.94 + (value * 0.12), child: child),
            ],
          );
        },
        child: Icon(widget.icon, size: 14, color: widget.color),
      ),
    );
  }
}

class _UtilityTile extends StatelessWidget {
  const _UtilityTile({
    required this.title,
    required this.subtitle,
    this.icon = Icons.widgets_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _UtilitySection(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: _UtilityListRow(
        title: title,
        subtitle: subtitle,
        icon: icon,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Theme.of(context).extension<AppSurfaces>()!.muted,
        ),
      ),
    );
  }
}

class _TodoTileList extends StatefulWidget {
  const _TodoTileList({required this.todos});

  final List<TodoItem> todos;

  @override
  State<_TodoTileList> createState() => _TodoTileListState();
}

class _TodoTileListState extends State<_TodoTileList> {
  late List<TodoItem> _sortedTodos;

  @override
  void initState() {
    super.initState();
    _syncSortedTodos();
  }

  @override
  void didUpdateWidget(covariant _TodoTileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.todos, widget.todos)) {
      _syncSortedTodos();
    }
  }

  void _syncSortedTodos() {
    _sortedTodos = sortTodosForDisplay(widget.todos);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.todos.isEmpty) {
      return _UtilityTile(
        title: l10n.shellTodoTitle,
        subtitle: l10n.shellTodoSubtitle,
        icon: Icons.checklist_rounded,
      );
    }
    return _UtilitySection(
      title: l10n.shellTodoTitle,
      subtitle: l10n.shellTodoSubtitle,
      icon: Icons.checklist_rounded,
      child: AnimatedSize(
        duration: _motionMedium,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          children: <Widget>[
            for (final todo in _sortedTodos)
              Padding(
                key: ValueKey<String>(
                  '${todo.content}-${todo.status}-${todo.priority}',
                ),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _UtilityListRow(
                  title: todo.content,
                  subtitle: todo.priority,
                  icon: _todoIcon(todo.status),
                  emphasis: todo.status == 'in_progress',
                  trailing: _InfoChip(
                    label: _todoStatusLabel(l10n, todo.status),
                    emphasis: todo.status == 'in_progress',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UtilitySection extends StatelessWidget {
  const _UtilitySection({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            surfaces.panelMuted.withValues(alpha: 0.92),
            surfaces.panel.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaces.panelEmphasis.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: Border.all(color: surfaces.lineSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(icon, size: 16, color: surfaces.accentSoft),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
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
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _UtilityListRow extends StatelessWidget {
  const _UtilityListRow({
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    this.selected = false,
    this.emphasis = false,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
  final bool emphasis;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final highlighted = selected || emphasis;
    final fill = highlighted
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.1),
            surfaces.panelEmphasis.withValues(alpha: 0.92),
          )
        : surfaces.panelRaised.withValues(alpha: 0.56);
    final border = highlighted
        ? theme.colorScheme.primary.withValues(alpha: 0.2)
        : surfaces.lineSoft;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: _motionFast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ] else if (icon != null) ...<Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlighted
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : surfaces.panelMuted.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      icon,
                      size: 16,
                      color: highlighted
                          ? theme.colorScheme.primary
                          : surfaces.accentSoft,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePanel extends StatelessWidget {
  const _FilePanel({
    required this.fileNodes,
    required this.fileStatuses,
    required this.fileSearchResults,
    required this.textMatches,
    required this.symbols,
    required this.filePreview,
    required this.selectedFilePath,
    required this.fileSearchQuery,
    required this.onSelectFile,
    required this.onSearchFiles,
  });

  final List<FileNodeSummary> fileNodes;
  final List<FileStatusSummary> fileStatuses;
  final List<String> fileSearchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final FileContentSummary? filePreview;
  final String? selectedFilePath;
  final String fileSearchQuery;
  final ValueChanged<String> onSelectFile;
  final ValueChanged<String> onSearchFiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusByPath = indexFileStatuses(fileStatuses);
    final visiblePaths = fileSearchResults.isNotEmpty
        ? fileSearchResults
        : fileNodes.map((item) => item.path).take(5).toList(growable: false);

    return _UtilitySection(
      title: l10n.shellFilesTitle,
      subtitle: l10n.shellFilesSubtitle,
      icon: Icons.folder_open_outlined,
      trailing: _InfoChip(
        label: '${visiblePaths.length} shown',
        icon: Icons.insert_drive_file_outlined,
      ),
      child: Column(
        children: <Widget>[
          _SyncedTextField(
            value: fileSearchQuery,
            onSubmitted: onSearchFiles,
            decoration: InputDecoration(
              hintText: l10n.shellFilesSearchHint,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final path in visiblePaths)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _UtilityListRow(
                title: path,
                subtitle: _statusFor(path, l10n, statusByPath[path]),
                selected: path == selectedFilePath,
                icon: Icons.description_outlined,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).extension<AppSurfaces>()!.muted,
                ),
                onTap: () => onSelectFile(path),
              ),
            ),
          if (filePreview != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _UtilitySection(
              title: l10n.shellPreviewTitle,
              subtitle: selectedFilePath ?? l10n.shellCurrentSelection,
              icon: Icons.code_rounded,
              child: Text(
                filePreview!.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (textMatches.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _UtilitySection(
              title: l10n.shellMatchesTitle,
              subtitle: l10n.shellMatchesSubtitle,
              icon: Icons.find_in_page_outlined,
              child: Column(
                children: textMatches
                    .take(2)
                    .map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _UtilityListRow(
                          title: match.path,
                          subtitle: match.lines,
                          icon: Icons.short_text_rounded,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (symbols.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _UtilitySection(
              title: l10n.shellSymbolsTitle,
              subtitle: l10n.shellSymbolsSubtitle,
              icon: Icons.hub_outlined,
              child: Column(
                children: symbols
                    .take(2)
                    .map(
                      (symbol) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _UtilityListRow(
                          title: symbol.name,
                          subtitle:
                              '${symbol.kind ?? 'symbol'} · ${symbol.path ?? '-'}',
                          icon: Icons.alternate_email_rounded,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusFor(
    String path,
    AppLocalizations l10n,
    FileStatusSummary? status,
  ) {
    if (status == null) {
      return l10n.shellTrackedLabel;
    }
    return l10n.shellFileStatusSummary(
      status.status,
      status.added,
      status.removed,
    );
  }
}

class _SyncedTextField extends StatefulWidget {
  const _SyncedTextField({
    required this.value,
    required this.onSubmitted,
    required this.decoration,
  });

  final String value;
  final ValueChanged<String> onSubmitted;
  final InputDecoration decoration;

  @override
  State<_SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<_SyncedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onSubmitted: widget.onSubmitted,
      decoration: widget.decoration,
    );
  }
}

class _PendingRequestsPanel extends StatelessWidget {
  const _PendingRequestsPanel({
    required this.questions,
    required this.permissions,
    required this.onReplyQuestion,
    required this.onRejectQuestion,
    required this.onReplyPermission,
  });

  final List<QuestionRequestSummary> questions;
  final List<PermissionRequestSummary> permissions;
  final Future<void> Function(String, List<List<String>>) onReplyQuestion;
  final Future<void> Function(String) onRejectQuestion;
  final Future<void> Function(String, String) onReplyPermission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (questions.isEmpty && permissions.isEmpty) {
      return const SizedBox.shrink();
    }
    final total = questions.length + permissions.length;
    return _UtilitySection(
      title: l10n.shellPendingApprovalsTitle,
      subtitle: l10n.shellPendingApprovalsSubtitle(total),
      icon: Icons.notification_important_outlined,
      child: Column(
        children: <Widget>[
          for (final permission in permissions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UtilitySection(
                title: permission.permission,
                subtitle: permission.patterns.join(', '),
                icon: Icons.lock_open_outlined,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => onReplyPermission(permission.id, 'once'),
                      child: Text(l10n.shellAllowOnceAction),
                    ),
                    TextButton(
                      onPressed: () =>
                          onReplyPermission(permission.id, 'reject'),
                      child: Text(l10n.shellRejectAction),
                    ),
                  ],
                ),
              ),
            ),
          for (final question in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UtilitySection(
                title: question.questions.first.header,
                subtitle: question.questions.first.question,
                icon: Icons.help_outline_rounded,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    TextButton(
                      onPressed: question.questions.first.options.isEmpty
                          ? null
                          : () => onReplyQuestion(question.id, <List<String>>[
                              <String>[
                                question.questions.first.options.first.label,
                              ],
                            ]),
                      child: Text(l10n.shellAnswerAction),
                    ),
                    TextButton(
                      onPressed: () => onRejectQuestion(question.id),
                      child: Text(l10n.shellRejectAction),
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

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({
    required this.terminalCommand,
    required this.selectedSessionId,
    required this.running,
    required this.lastResult,
    required this.onRunCommand,
  });

  final String terminalCommand;
  final String? selectedSessionId;
  final bool running;
  final ShellCommandResult? lastResult;
  final ValueChanged<String> onRunCommand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _UtilitySection(
      title: l10n.shellTerminalTitle,
      subtitle: l10n.shellTerminalSubtitle,
      icon: Icons.terminal_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SyncedTextField(
            value: terminalCommand,
            onSubmitted: (value) {
              final command = value.trim();
              if (command.isNotEmpty) {
                onRunCommand(command);
              }
            },
            decoration: InputDecoration(
              hintText: l10n.shellTerminalHint,
              isDense: true,
              prefixIcon: const Icon(Icons.code_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: running || selectedSessionId == null
                ? null
                : () => onRunCommand(terminalCommand.trim()),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              running ? l10n.shellTerminalRunning : l10n.shellTerminalRunAction,
            ),
          ),
          if (selectedSessionId == null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select a session before running shell commands.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (lastResult != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _UtilityListRow(
              title: 'Last command result',
              subtitle:
                  'session ${lastResult!.sessionId} - message ${lastResult!.messageId}',
              icon: Icons.history_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _IntegrationDiagnosticsPanel extends StatelessWidget {
  const _IntegrationDiagnosticsPanel({
    required this.snapshot,
    required this.lastAuthUrl,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
  });

  final IntegrationStatusSnapshot? snapshot;
  final String? lastAuthUrl;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providerAuth =
        snapshot?.providerAuth ?? const <String, List<String>>{};
    final mcpStatus = snapshot?.mcpStatus ?? const <String, String>{};
    final lspStatus = snapshot?.lspStatus ?? const <String, String>{};
    final formatterStatus = snapshot?.formatterStatus ?? const <String, bool>{};

    return _UtilitySection(
      title: l10n.shellIntegrationsTitle,
      subtitle: 'Provider auth and integration diagnostics.',
      icon: Icons.hub_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (providerAuth.isNotEmpty)
            ...providerAuth.entries
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _UtilityListRow(
                      title: entry.key,
                      subtitle:
                          '${l10n.shellIntegrationsMethods}: ${entry.value.join(', ')}',
                      icon: Icons.key_outlined,
                    ),
                  ),
                )
          else
            _UtilityListRow(
              title: l10n.shellIntegrationsProviders,
              subtitle: 'No provider auth metadata available yet.',
              icon: Icons.key_off_outlined,
            ),
          if (providerAuth.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () => onStartProviderAuth(providerAuth.keys.first),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.shellIntegrationsStartProviderAuth),
            ),
          ],
          if (mcpStatus.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ...mcpStatus.entries
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _UtilityListRow(
                      title: '${l10n.shellIntegrationsMcp}: ${entry.key}',
                      subtitle: entry.value,
                      icon: Icons.extension_outlined,
                    ),
                  ),
                ),
            TextButton.icon(
              onPressed: () => onStartMcpAuth(mcpStatus.keys.first),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.shellIntegrationsStartMcpAuth),
            ),
          ],
          if (lspStatus.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ...lspStatus.entries
                .take(2)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _UtilityListRow(
                      title: '${l10n.shellIntegrationsLsp}: ${entry.key}',
                      subtitle: entry.value,
                      icon: Icons.code_rounded,
                    ),
                  ),
                ),
          ],
          if (formatterStatus.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ...formatterStatus.entries
                .take(2)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _UtilityListRow(
                      title: '${l10n.shellIntegrationsFormatter}: ${entry.key}',
                      subtitle: entry.value
                          ? l10n.shellIntegrationsEnabled
                          : l10n.shellIntegrationsDisabled,
                      icon: Icons.auto_fix_high_outlined,
                    ),
                  ),
                ),
          ],
          if ((lastAuthUrl ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _UtilityListRow(
              title: l10n.shellIntegrationsLastAuthUrlTitle,
              subtitle: lastAuthUrl!,
              icon: Icons.link_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _EventHealthPanel extends StatelessWidget {
  const _EventHealthPanel({
    required this.health,
    required this.recentEvents,
    required this.recoveryLog,
  });

  final SseConnectionHealth health;
  final List<EventEnvelope> recentEvents;
  final List<String> recoveryLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _UtilitySection(
      title: l10n.shellIntegrationsRecentEvents,
      subtitle: l10n.shellIntegrationsEventsSubtitle,
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _UtilityListRow(
            title: l10n.shellIntegrationsStreamHealth,
            subtitle: _eventHealthLabel(l10n, health),
            icon: Icons.wifi_tethering_rounded,
          ),
          if (recentEvents.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            ...recentEvents
                .take(3)
                .map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _UtilityListRow(
                      title: event.type,
                      subtitle: event.properties.toString(),
                      icon: Icons.notifications_active_outlined,
                    ),
                  ),
                ),
          ],
          if (recoveryLog.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _UtilityListRow(
              title: l10n.shellIntegrationsRecoveryLog,
              subtitle: recoveryLog.take(2).join(' | '),
              icon: Icons.restart_alt_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

String _eventHealthLabel(AppLocalizations l10n, SseConnectionHealth health) {
  return switch (health) {
    SseConnectionHealth.connected => l10n.shellStreamHealthConnected,
    SseConnectionHealth.stale => l10n.shellStreamHealthStale,
    SseConnectionHealth.reconnecting => l10n.shellStreamHealthReconnecting,
  };
}

class _ConfigPreviewPanel extends StatefulWidget {
  const _ConfigPreviewPanel({required this.snapshot, required this.onApply});

  final ConfigSnapshot? snapshot;
  final Future<void> Function(String) onApply;

  @override
  State<_ConfigPreviewPanel> createState() => _ConfigPreviewPanelState();
}

class _ConfigPreviewPanelState extends State<_ConfigPreviewPanel> {
  late final TextEditingController _controller = TextEditingController();
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _syncText();
  }

  @override
  void didUpdateWidget(covariant _ConfigPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      _syncText();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncText() {
    final raw = widget.snapshot?.config.toJson();
    _controller.text = raw == null
        ? ''
        : const JsonEncoder.withIndent('  ').convert(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.snapshot == null) {
      return KeyedSubtree(
        key: const ValueKey<String>('advanced-config-panel'),
        child: _UtilitySection(
          title: l10n.shellConfigTitle,
          subtitle: l10n.shellConfigPreviewSubtitle,
          icon: Icons.settings_suggest_outlined,
          child: Text(
            l10n.shellConfigPreviewUnavailable,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final preview = buildConfigEditPreview(
      current: widget.snapshot!.config,
      draft: _controller.text,
    );
    final providers = widget.snapshot!.providerConfig.toJson().toString();
    return KeyedSubtree(
      key: const ValueKey<String>('advanced-config-panel'),
      child: _UtilitySection(
        title: l10n.shellConfigTitle,
        subtitle: l10n.shellConfigPreviewSubtitle,
        icon: Icons.settings_suggest_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _controller,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(isDense: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!preview.isValid) ...<Widget>[
              Text(
                preview.error ?? l10n.shellConfigInvalid,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: surfaces.danger),
              ),
              const SizedBox(height: AppSpacing.xs),
            ] else ...<Widget>[
              _InfoChip(
                label: l10n.shellConfigChangedKeys(preview.changedPaths.length),
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                preview.changedPaths.take(6).join(', '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _applying || !preview.isValid
                    ? null
                    : () async {
                        setState(() {
                          _applying = true;
                        });
                        try {
                          await widget.onApply(_controller.text);
                        } finally {
                          if (mounted) {
                            setState(() {
                              _applying = false;
                            });
                          }
                        }
                      },
                child: Text(
                  _applying
                      ? l10n.shellConfigApplying
                      : l10n.shellConfigApplyAction,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(providers, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _RawInspectorPanel extends StatefulWidget {
  const _RawInspectorPanel({
    required this.sessions,
    required this.messages,
    required this.selectedSessionId,
  });

  final List<SessionSummary> sessions;
  final List<ChatMessage> messages;
  final String? selectedSessionId;

  @override
  State<_RawInspectorPanel> createState() => _RawInspectorPanelState();
}

class _RawInspectorPanelState extends State<_RawInspectorPanel> {
  String _sessionJson = '{}';
  String _messageJson = '{}';

  @override
  void initState() {
    super.initState();
    _syncInspectorJson();
  }

  @override
  void didUpdateWidget(covariant _RawInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessions, widget.sessions) ||
        !identical(oldWidget.messages, widget.messages) ||
        oldWidget.selectedSessionId != widget.selectedSessionId) {
      _syncInspectorJson();
    }
  }

  void _syncInspectorJson() {
    SessionSummary? selectedSession;
    for (final session in widget.sessions) {
      if (session.id == widget.selectedSessionId) {
        selectedSession = session;
        break;
      }
    }
    final latestMessage = widget.messages.isEmpty ? null : widget.messages.last;
    _sessionJson = buildInspectorSessionJson(selectedSession);
    _messageJson = buildInspectorMessageJson(latestMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _UtilitySection(
      title: l10n.shellInspectorTitle,
      subtitle: l10n.shellInspectorSubtitle,
      icon: Icons.data_object_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_sessionJson, maxLines: 5, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.sm),
          Text(_messageJson, maxLines: 6, overflow: TextOverflow.ellipsis),
        ],
      ),
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
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final fill = accent
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.08),
            surfaces.panelEmphasis.withValues(alpha: 0.92),
          )
        : surfaces.panelRaised.withValues(alpha: 0.82);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[fill, surfaces.panel.withValues(alpha: 0.98)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: accent
              ? theme.colorScheme.primary.withValues(alpha: 0.24)
              : surfaces.lineSoft,
        ),
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

class _ComposerCard extends StatefulWidget {
  const _ComposerCard({
    required this.compact,
    required this.label,
    required this.submitting,
    required this.startsNewSession,
    required this.modelOptions,
    required this.serverDefaultModelKey,
    required this.initialModelKey,
    required this.initialReasoning,
    required this.onSubmit,
  });

  final bool compact;
  final String label;
  final bool submitting;
  final bool startsNewSession;
  final List<_ComposerModelOption> modelOptions;
  final String? serverDefaultModelKey;
  final String? initialModelKey;
  final String? initialReasoning;
  final Future<bool> Function(String, _ComposerSubmissionOptions) onSubmit;

  @override
  State<_ComposerCard> createState() => _ComposerCardState();
}

class _ComposerCardState extends State<_ComposerCard> {
  late final TextEditingController _controller = TextEditingController();
  late String? _selectedModelKey = widget.initialModelKey;
  late String? _selectedReasoning = widget.initialReasoning;

  _ComposerModelOption? _modelForKey(String? key) {
    final lookupKey = key ?? widget.serverDefaultModelKey;
    if (lookupKey == null || lookupKey.isEmpty) {
      return null;
    }
    for (final option in widget.modelOptions) {
      if (option.key == lookupKey) {
        return option;
      }
    }
    return null;
  }

  bool _isReasoningAllowed(String? reasoning, String? modelKey) {
    if (reasoning == null || reasoning.isEmpty) {
      return true;
    }
    return _modelForKey(modelKey)?.reasoningValues.contains(reasoning) ?? false;
  }

  @override
  void didUpdateWidget(covariant _ComposerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentModelStillAvailable =
        _selectedModelKey == null ||
        widget.modelOptions.any((option) => option.key == _selectedModelKey);
    if (!currentModelStillAvailable) {
      _selectedModelKey = widget.initialModelKey;
    } else if (_selectedModelKey == null && widget.initialModelKey != null) {
      _selectedModelKey = widget.initialModelKey;
    }
    if (!_isReasoningAllowed(_selectedReasoning, _selectedModelKey)) {
      _selectedReasoning = widget.initialReasoning;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    _ComposerModelOption? selectedModel;
    for (final option in widget.modelOptions) {
      if (option.key == _selectedModelKey) {
        selectedModel = option;
        break;
      }
    }
    final success = await widget.onSubmit(
      text,
      _ComposerSubmissionOptions(
        providerId: selectedModel?.providerId,
        modelId: selectedModel?.modelId,
        reasoning: _selectedReasoning,
      ),
    );
    if (success && mounted) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final selectedModel = _modelForKey(_selectedModelKey);
    final reasoningOptions = <({String? value, String label})>[
      (value: null, label: l10n.shellComposerModelDefault),
      ...?selectedModel?.reasoningValues.map(
        (value) => (value: value, label: _reasoningLabel(l10n, value)),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.06),
              surfaces.panelEmphasis.withValues(alpha: 0.9),
            ),
            surfaces.panel.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? AppSpacing.md : AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _InfoChip(
                  label: widget.startsNewSession
                      ? l10n.shellNewSession
                      : l10n.shellReplying,
                  icon: widget.startsNewSession
                      ? Icons.add_comment_outlined
                      : Icons.reply_rounded,
                  emphasis: true,
                ),
                _InfoChip(
                  label: widget.compact
                      ? l10n.shellCompactComposer
                      : l10n.shellExpandedComposer,
                  icon: Icons.edit_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: l10n.shellA11yComposerField,
              hint: widget.label,
              textField: true,
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: widget.compact ? 3 : 5,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.label,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                SizedBox(
                  width: widget.compact ? 220 : 240,
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey<String>('composer-model-select'),
                    initialValue: _selectedModelKey,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.shellComposerModelLabel,
                    ),
                    items: <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.shellComposerModelDefault),
                      ),
                      ...widget.modelOptions.map(
                        (option) => DropdownMenuItem<String?>(
                          value: option.key,
                          child: Text(
                            option.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: widget.submitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedModelKey = value;
                              if (!_isReasoningAllowed(
                                _selectedReasoning,
                                value,
                              )) {
                                _selectedReasoning = null;
                              }
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: widget.compact ? 180 : 200,
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey<String>('composer-reasoning-select'),
                    initialValue: _selectedReasoning,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.shellComposerThinkingLabel,
                    ),
                    items: reasoningOptions
                        .map(
                          (option) => DropdownMenuItem<String?>(
                            value: option.value,
                            child: Text(option.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.submitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedReasoning = value;
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: l10n.shellA11ySendMessageAction,
                button: true,
                child: ElevatedButton.icon(
                  onPressed: widget.submitting ? null : _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    widget.submitting
                        ? l10n.shellComposerSending
                        : widget.startsNewSession
                        ? l10n.shellComposerCreatingSession
                        : l10n.shellComposerSendAction,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.icon,
    this.iconChild,
    this.emphasis = false,
  });

  final String label;
  final IconData? icon;
  final Widget? iconChild;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final fill = emphasis
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.1),
            surfaces.panelEmphasis.withValues(alpha: 0.92),
          )
        : surfaces.panelMuted.withValues(alpha: 0.9);
    final border = emphasis
        ? theme.colorScheme.primary.withValues(alpha: 0.2)
        : surfaces.lineSoft;
    return AnimatedContainer(
      duration: _motionFast,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (iconChild != null || icon != null) ...<Widget>[
              AnimatedSwitcher(
                duration: _motionFast,
                transitionBuilder: (child, animation) =>
                    _fadeSlideTransition(child, animation),
                child: SizedBox(
                  key: ValueKey<String>(
                    '${iconChild?.runtimeType}-${icon?.codePoint ?? 0}-$emphasis',
                  ),
                  width: 14,
                  height: 14,
                  child:
                      iconChild ??
                      Icon(
                        icon,
                        size: 14,
                        color: emphasis
                            ? theme.colorScheme.primary
                            : surfaces.accentSoft,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: AnimatedSwitcher(
                duration: _motionFast,
                transitionBuilder: (child, animation) =>
                    _fadeSlideTransition(child, animation),
                child: Text(
                  label,
                  key: ValueKey<String>(label),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: emphasis ? theme.colorScheme.primary : null,
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

String _statusLabel(AppLocalizations l10n, SessionStatusSummary? status) {
  final type = status?.type ?? 'idle';
  final base = switch (type) {
    'busy' => l10n.shellStatusActive,
    'retry' => l10n.shellStatusError,
    _ => l10n.shellStatusIdle,
  };
  if (type == 'retry') {
    final details = <String>[
      if (status?.attempt != null) l10n.shellRetryAttempt(status!.attempt!),
      if ((status?.message ?? '').trim().isNotEmpty) status!.message!.trim(),
    ];
    if (details.isNotEmpty) {
      return l10n.shellStatusWithDetails(base, details.join(' · '));
    }
  }
  return base;
}

String _todoStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'in_progress' => l10n.shellTodoStatusInProgress,
    'pending' => l10n.shellTodoStatusPending,
    'completed' => l10n.shellTodoStatusCompleted,
    _ => l10n.shellTodoStatusUnknown,
  };
}

IconData _todoIcon(String status) {
  return switch (status) {
    'in_progress' => Icons.timelapse_rounded,
    'pending' => Icons.radio_button_unchecked_rounded,
    'completed' => Icons.check_circle_rounded,
    _ => Icons.circle_outlined,
  };
}
