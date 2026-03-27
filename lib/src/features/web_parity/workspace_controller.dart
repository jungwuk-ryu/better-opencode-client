import 'dart:convert';
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connection/connection_models.dart';
import '../../core/network/event_stream_service.dart';
import '../../core/network/live_event_applier.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../chat/prompt_attachment_models.dart';
import '../chat/session_context_insights.dart';
import '../chat/session_action_service.dart';
import '../commands/command_service.dart';
import '../files/file_browser_service.dart';
import '../files/file_models.dart';
import '../files/review_diff_service.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import '../requests/request_event_applier.dart';
import '../requests/request_models.dart';
import '../requests/request_service.dart';
import '../settings/agent_service.dart';
import '../settings/config_service.dart';
import '../terminal/terminal_service.dart';
import '../tools/todo_models.dart';
import '../tools/todo_service.dart';

enum WorkspaceSideTab { review, files, context }

enum WorkspaceFollowupMode {
  queue,
  steer;

  static WorkspaceFollowupMode fromStorage(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'steer' => WorkspaceFollowupMode.steer,
      _ => WorkspaceFollowupMode.queue,
    };
  }

  String get storageValue => name;
}

enum WorkspacePromptDispatchMode { queue, steer }

class WorkspaceSessionTimelineState {
  const WorkspaceSessionTimelineState({
    required this.sessionId,
    required this.messages,
    required this.orderedMessages,
    required this.loading,
    required this.showingCachedMessages,
    this.error,
  });

  const WorkspaceSessionTimelineState.empty({this.sessionId})
    : messages = const <ChatMessage>[],
      orderedMessages = const <ChatMessage>[],
      loading = false,
      showingCachedMessages = false,
      error = null;

  final String? sessionId;
  final List<ChatMessage> messages;
  final List<ChatMessage> orderedMessages;
  final bool loading;
  final bool showingCachedMessages;
  final String? error;

  WorkspaceSessionTimelineState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    List<ChatMessage>? orderedMessages,
    bool? loading,
    bool? showingCachedMessages,
    String? error,
    bool clearError = false,
  }) {
    return WorkspaceSessionTimelineState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      orderedMessages: orderedMessages ?? this.orderedMessages,
      loading: loading ?? this.loading,
      showingCachedMessages:
          showingCachedMessages ?? this.showingCachedMessages,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WorkspaceQueuedPrompt {
  const WorkspaceQueuedPrompt({
    required this.id,
    required this.sessionId,
    required this.prompt,
    required this.attachments,
    required this.createdAt,
    this.agentName,
    this.modelKey,
    this.providerId,
    this.modelId,
    this.reasoning,
  });

  final String id;
  final String sessionId;
  final String prompt;
  final List<PromptAttachment> attachments;
  final DateTime createdAt;
  final String? agentName;
  final String? modelKey;
  final String? providerId;
  final String? modelId;
  final String? reasoning;

  String get previewText {
    final firstLine = prompt
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isNotEmpty) {
      return firstLine;
    }
    if (attachments.isEmpty) {
      return 'Queued follow-up';
    }
    if (attachments.length == 1) {
      return '[Attachment] ${attachments.first.filename}';
    }
    return '[${attachments.length} attachments]';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sessionId': sessionId,
    'prompt': prompt,
    'createdAtMs': createdAt.millisecondsSinceEpoch,
    'agentName': agentName,
    'modelKey': modelKey,
    'providerId': providerId,
    'modelId': modelId,
    'reasoning': reasoning,
    'attachments': attachments
        .map(
          (attachment) => <String, Object?>{
            'id': attachment.id,
            'filename': attachment.filename,
            'mime': attachment.mime,
            'url': attachment.url,
          },
        )
        .toList(growable: false),
  };

  factory WorkspaceQueuedPrompt.fromJson(Map<String, Object?> json) {
    return WorkspaceQueuedPrompt(
      id: (json['id'] as String?) ?? '',
      sessionId: (json['sessionId'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAtMs'] as num?)?.toInt() ?? 0,
      ),
      agentName: json['agentName'] as String?,
      modelKey: json['modelKey'] as String?,
      providerId: json['providerId'] as String?,
      modelId: json['modelId'] as String?,
      reasoning: json['reasoning'] as String?,
      attachments: ((json['attachments'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) => PromptAttachment(
              id: item['id']?.toString() ?? '',
              filename: item['filename']?.toString() ?? '',
              mime: item['mime']?.toString() ?? '',
              url: item['url']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
    );
  }
}

const int _mainIsolateJsonDecodeThreshold = 32000;

Future<Object?> _decodeJsonPayload(String payloadJson) async {
  if (payloadJson.length < _mainIsolateJsonDecodeThreshold) {
    return jsonDecode(payloadJson);
  }
  return compute(_jsonDecodeEntryPayload, payloadJson);
}

Object? _jsonDecodeEntryPayload(String payloadJson) {
  return jsonDecode(payloadJson);
}

Map<String, List<WorkspaceQueuedPrompt>> _queuedPromptsFromDecodedJson(
  Object? decoded,
) {
  final next = <String, List<WorkspaceQueuedPrompt>>{};
  if (decoded is! Map) {
    return next;
  }
  decoded.forEach((key, value) {
    final sessionId = key.toString().trim();
    if (sessionId.isEmpty) {
      return;
    }
    final items = ((value as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map(
          (item) =>
              WorkspaceQueuedPrompt.fromJson(item.cast<String, Object?>()),
        )
        .where((item) => item.id.isNotEmpty && item.sessionId.isNotEmpty)
        .toList(growable: false);
    if (items.isNotEmpty) {
      next[sessionId] = items;
    }
  });
  return next;
}

List<ChatMessage> _chatMessagesFromDecodedJson(Object? decoded) {
  if (decoded is! List) {
    return const <ChatMessage>[];
  }
  return decoded
      .whereType<Map>()
      .map((item) => ChatMessage.fromJson(item.cast<String, Object?>()))
      .toList(growable: false);
}

const String _permissionAutoAcceptStorageKeyPrefix =
    'workspace.permission_auto_accept';
const String _permissionAutoAcceptProjectScopeKey = '__project__';

String _permissionAutoAcceptStorageKey(
  ServerProfile profile,
  ProjectTarget project,
) {
  final encodedDirectory = base64Url.encode(utf8.encode(project.directory));
  return '$_permissionAutoAcceptStorageKeyPrefix::${profile.storageKey}::$encodedDirectory';
}

Map<String, bool> _permissionAutoAcceptFromDecodedJson(Object? decoded) {
  if (decoded is! Map) {
    return const <String, bool>{};
  }
  final next = <String, bool>{};
  decoded.forEach((key, value) {
    final normalizedKey = key.toString().trim();
    if (normalizedKey.isEmpty || value is! bool) {
      return;
    }
    next[normalizedKey] = value;
  });
  return Map<String, bool>.unmodifiable(next);
}

class WorkspaceComposerModelOption {
  const WorkspaceComposerModelOption({
    required this.key,
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.name,
    this.reasoningValues = const <String>[],
  });

  final String key;
  final String providerId;
  final String providerName;
  final String modelId;
  final String name;
  final List<String> reasoningValues;
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required this.profile,
    required this.directory,
    this.initialSessionId,
    ChatService? chatService,
    ProjectCatalogService? projectCatalogService,
    ProjectStore? projectStore,
    StaleCacheStore? cacheStore,
    FileBrowserService? fileBrowserService,
    ReviewDiffService? reviewDiffService,
    TodoService? todoService,
    RequestService? requestService,
    EventStreamService? eventStreamService,
    TerminalService? terminalService,
    SessionActionService? sessionActionService,
    ConfigService? configService,
    AgentService? agentService,
    CommandService? commandService,
  }) : _chatService = chatService ?? ChatService(),
       _projectCatalogService =
           projectCatalogService ?? ProjectCatalogService(),
       _projectStore = projectStore ?? ProjectStore(),
       _cacheStore = cacheStore ?? StaleCacheStore(),
       _fileBrowserService = fileBrowserService ?? FileBrowserService(),
       _reviewDiffService = reviewDiffService ?? ReviewDiffService(),
       _todoService = todoService ?? TodoService(),
       _requestService = requestService ?? RequestService(),
       _eventStreamService = eventStreamService ?? EventStreamService(),
       _terminalService = terminalService ?? TerminalService(),
       _sessionActionService = sessionActionService ?? SessionActionService(),
       _configService = configService ?? ConfigService(),
       _agentService = agentService ?? AgentService(),
       _commandService = commandService ?? CommandService(),
       _ownsChatService = chatService == null,
       _ownsProjectCatalogService = projectCatalogService == null,
       _ownsFileBrowserService = fileBrowserService == null,
       _ownsReviewDiffService = reviewDiffService == null,
       _ownsTodoService = todoService == null,
       _ownsRequestService = requestService == null,
       _ownsEventStreamService = eventStreamService == null,
       _ownsTerminalService = terminalService == null,
       _ownsSessionActionService = sessionActionService == null,
       _ownsConfigService = configService == null,
       _ownsAgentService = agentService == null,
       _ownsCommandService = commandService == null;

  final ServerProfile profile;
  final String directory;
  final String? initialSessionId;

  final ChatService _chatService;
  final ProjectCatalogService _projectCatalogService;
  final ProjectStore _projectStore;
  final StaleCacheStore _cacheStore;
  final FileBrowserService _fileBrowserService;
  final ReviewDiffService _reviewDiffService;
  final TodoService _todoService;
  final RequestService _requestService;
  final EventStreamService _eventStreamService;
  final TerminalService _terminalService;
  final SessionActionService _sessionActionService;
  final ConfigService _configService;
  final AgentService _agentService;
  final CommandService _commandService;
  final bool _ownsChatService;
  final bool _ownsProjectCatalogService;
  final bool _ownsFileBrowserService;
  final bool _ownsReviewDiffService;
  final bool _ownsTodoService;
  final bool _ownsRequestService;
  final bool _ownsEventStreamService;
  final bool _ownsTerminalService;
  final bool _ownsSessionActionService;
  final bool _ownsConfigService;
  final bool _ownsAgentService;
  final bool _ownsCommandService;

  bool _disposed = false;
  bool _loading = true;
  bool _sessionLoading = false;
  bool _showingCachedSessionMessages = false;
  bool _submittingPrompt = false;
  bool _interruptingSession = false;
  bool _runningTerminal = false;
  bool _terminalOpen = false;
  bool _loadingFilePreview = false;
  String? _loadingFileDirectoryPath;
  bool _loadingReviewDiff = false;
  WorkspaceSideTab _sideTab = WorkspaceSideTab.review;
  String? _error;
  String? _sessionLoadError;
  String? _reviewDiffError;
  String? _actionNotice;
  ProjectTarget? _project;
  List<ProjectTarget> _availableProjects = const <ProjectTarget>[];
  List<SessionSummary> _sessions = const <SessionSummary>[];
  Map<String, SessionStatusSummary> _statuses =
      const <String, SessionStatusSummary>{};
  Set<String> _hiddenProjectDirectories = <String>{};
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  FileBrowserBundle? _fileBundle;
  Set<String> _expandedFileDirectories = <String>{};
  Set<String> _loadedFileDirectories = <String>{};
  ReviewSessionDiffBundle? _reviewBundle;
  String? _selectedReviewPath;
  FileDiffSummary? _reviewDiff;
  List<TodoItem> _todos = const <TodoItem>[];
  Map<String, List<TodoItem>> _todosBySessionId =
      const <String, List<TodoItem>>{};
  PendingRequestBundle _pendingRequests = const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );
  ShellCommandResult? _lastShellResult;
  ConfigSnapshot? _configSnapshot;
  List<AgentDefinition> _composerAgents = const <AgentDefinition>[];
  List<WorkspaceComposerModelOption> _composerModels =
      const <WorkspaceComposerModelOption>[];
  List<CommandDefinition> _composerCommands = const <CommandDefinition>[];
  String? _selectedAgentName;
  String? _selectedModelKey;
  String? _selectedReasoning;
  String? _serverDefaultModelKey;
  String? _serverDefaultReasoning;
  final Map<String, List<ChatMessage>> _optimisticMessagesBySessionKey =
      <String, List<ChatMessage>>{};
  int _optimisticMessageSequence = 0;
  int _promptRefreshRevision = 0;
  int _sessionLoadRevision = 0;
  int _reviewDiffRevision = 0;
  List<ChatMessage>? _derivedMessagesRef;
  ConfigSnapshot? _derivedConfigSnapshotRef;
  String? _derivedRevertMessageId;
  List<ChatMessage> _orderedMessagesCache = const <ChatMessage>[];
  int _timelineContentSignatureCache = 0;
  SessionContextMetrics _sessionContextMetricsCache =
      const SessionContextMetrics(totalCost: 0, context: null);
  String? _sessionSystemPromptCache;
  List<SessionContextBreakdownSegment> _sessionContextBreakdownCache =
      const <SessionContextBreakdownSegment>[];
  int _userMessageCountCache = 0;
  int _assistantMessageCountCache = 0;
  Timer? _sessionMessagesCachePersistTimer;
  ProjectTarget? _queuedSessionMessagesCacheProject;
  String? _queuedSessionMessagesCacheSessionId;
  List<ChatMessage>? _queuedSessionMessagesCacheMessages;
  int _queuedSessionMessagesCacheToken = 0;
  Map<String, String> _activeChildSessionLivePreviewById =
      const <String, String>{};
  Map<String, String> _activeChildSessionCachedPreviewById =
      const <String, String>{};
  Map<String, int> _activeChildSessionCachedPreviewVersionById =
      const <String, int>{};
  int _activeChildSessionPreviewLoadSignature = 0;
  int _activeChildSessionPreviewLoadToken = 0;
  Set<String> _watchedSessionIds = const <String>{};
  Map<String, WorkspaceSessionTimelineState> _watchedSessionTimelineById =
      const <String, WorkspaceSessionTimelineState>{};
  Map<String, int> _watchedSessionLoadRevisionById = const <String, int>{};
  Map<String, List<WorkspaceQueuedPrompt>> _queuedPromptsBySessionId =
      const <String, List<WorkspaceQueuedPrompt>>{};
  Map<String, String> _queuedPromptFailureBySessionId =
      const <String, String>{};
  Map<String, String> _sendingQueuedPromptBySessionId =
      const <String, String>{};
  int _queuedPromptSequence = 0;
  Map<String, bool> _permissionAutoAcceptByKey = const <String, bool>{};
  Set<String> _respondingPermissionRequestIds = const <String>{};

  bool get loading => _loading;
  bool get sessionLoading => _sessionLoading;
  bool get showingCachedSessionMessages => _showingCachedSessionMessages;
  bool get submittingPrompt => _submittingPrompt;
  bool get interruptingSession => _interruptingSession;
  bool get runningTerminal => _runningTerminal;
  bool get terminalOpen => _terminalOpen;
  bool get loadingFilePreview => _loadingFilePreview;
  String? get loadingFileDirectoryPath => _loadingFileDirectoryPath;
  bool get loadingReviewDiff => _loadingReviewDiff;
  WorkspaceSideTab get sideTab => _sideTab;
  String? get error => _error;
  String? get sessionLoadError => _sessionLoadError;
  String? get reviewDiffError => _reviewDiffError;
  String? get actionNotice => _actionNotice;
  ProjectTarget? get project => _project;
  List<ProjectTarget> get availableProjects => _availableProjects;
  List<SessionSummary> get sessions => _sessions;
  List<SessionSummary> get visibleSessions => _visibleRootSessions(sessions);
  Map<String, SessionStatusSummary> get statuses => _statuses;
  String? get selectedSessionId => _selectedSessionId;
  List<ChatMessage> get messages => _messages;
  List<ChatMessage> get orderedMessages {
    _ensureDerivedMessageState();
    return _orderedMessagesCache;
  }

  int get timelineContentSignature {
    _ensureDerivedMessageState();
    return _timelineContentSignatureCache;
  }

  SessionContextMetrics get sessionContextMetrics {
    _ensureDerivedMessageState();
    return _sessionContextMetricsCache;
  }

  String? get sessionSystemPrompt {
    _ensureDerivedMessageState();
    return _sessionSystemPromptCache;
  }

  List<SessionContextBreakdownSegment> get sessionContextBreakdown {
    _ensureDerivedMessageState();
    return _sessionContextBreakdownCache;
  }

  int get userMessageCount {
    _ensureDerivedMessageState();
    return _userMessageCountCache;
  }

  int get assistantMessageCount {
    _ensureDerivedMessageState();
    return _assistantMessageCountCache;
  }

  FileBrowserBundle? get fileBundle => _fileBundle;
  Set<String> get expandedFileDirectories =>
      UnmodifiableSetView<String>(_expandedFileDirectories);
  List<FileStatusSummary> get reviewStatuses =>
      _reviewBundle?.statuses ?? const <FileStatusSummary>[];
  String? get selectedReviewPath => _selectedReviewPath;
  FileDiffSummary? get reviewDiff => _reviewDiff;
  List<TodoItem> get todos => _todos;
  List<TodoItem> todosForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return const <TodoItem>[];
    }
    if (normalizedSessionId == _selectedSessionId) {
      return todos;
    }
    return _todosBySessionId[normalizedSessionId] ?? const <TodoItem>[];
  }

  PendingRequestBundle get pendingRequests => _pendingRequests;
  QuestionRequestSummary? get currentQuestionRequest =>
      currentQuestionRequestForSession(selectedSessionId);
  QuestionRequestSummary? currentQuestionRequestForSession(String? sessionId) =>
      _sessionTreeRequestForSession<QuestionRequestSummary>(
        sessionId,
        pendingRequests.questions,
        (request) => request.sessionId,
      );
  PermissionRequestSummary? get currentPermissionRequest =>
      currentPermissionRequestForSession(selectedSessionId);
  PermissionRequestSummary? currentPermissionRequestForSession(
    String? sessionId,
  ) => _sessionTreeRequestForSession<PermissionRequestSummary>(
    sessionId,
    pendingRequests.permissions,
    (request) => request.sessionId,
  );
  bool get projectPermissionAutoAccepting =>
      _permissionAutoAcceptByKey[_permissionAutoAcceptProjectScopeKey] ?? false;
  bool autoAcceptsPermissionForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return projectPermissionAutoAccepting;
    }
    for (final candidateSessionId in _sessionLineageIds(normalizedSessionId)) {
      final stored = _permissionAutoAcceptByKey[candidateSessionId];
      if (stored != null) {
        return stored;
      }
    }
    return projectPermissionAutoAccepting;
  }

  bool permissionRequestResponding(String? requestId) {
    final normalizedRequestId = requestId?.trim();
    if (normalizedRequestId == null || normalizedRequestId.isEmpty) {
      return false;
    }
    return _respondingPermissionRequestIds.contains(normalizedRequestId);
  }

  ShellCommandResult? get lastShellResult => _lastShellResult;
  ConfigSnapshot? get configSnapshot => _configSnapshot;
  List<AgentDefinition> get composerAgents => _composerAgents;
  List<WorkspaceComposerModelOption> get composerModels => _composerModels;
  List<CommandDefinition> get composerCommands => _composerCommands;
  String? get selectedAgentName => _selectedAgentName;
  String? get selectedModelKey => _selectedModelKey;
  String? get selectedReasoning => _selectedReasoning;

  WorkspaceComposerModelOption? get selectedModel {
    final selectedModelKey = _selectedModelKey;
    if (selectedModelKey == null || selectedModelKey.isEmpty) {
      return _defaultComposerModel;
    }
    for (final option in _composerModels) {
      if (option.key == selectedModelKey) {
        return option;
      }
    }
    return _defaultComposerModel;
  }

  AgentDefinition? get selectedAgent {
    final selectedAgentName = _selectedAgentName;
    if (selectedAgentName == null || selectedAgentName.isEmpty) {
      return _defaultComposerAgent;
    }
    for (final agent in _composerAgents) {
      if (agent.name == selectedAgentName) {
        return agent;
      }
    }
    return _defaultComposerAgent;
  }

  List<String> get availableReasoningValues {
    return List<String>.unmodifiable(
      selectedModel?.reasoningValues ?? const <String>[],
    );
  }

  SessionSummary? get selectedSession {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == selectedSessionId) {
        return session;
      }
    }
    return null;
  }

  SessionStatusSummary? get selectedStatus {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    return _statuses[selectedSessionId];
  }

  bool sessionBusyForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    if (sendingQueuedPromptIdForSession(normalizedSessionId) != null) {
      return true;
    }
    if (submittingPrompt && selectedSessionId == normalizedSessionId) {
      return true;
    }
    final status = normalizedSessionId == selectedSessionId
        ? selectedStatus
        : statuses[normalizedSessionId];
    return _isActiveStatus(status);
  }

  bool get selectedSessionInterruptible {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null || selectedSessionId.isEmpty) {
      return false;
    }
    return sessionInterruptibleForSession(selectedSessionId);
  }

  bool sessionInterruptibleForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    return (_selectedSessionId == normalizedSessionId && submittingPrompt) ||
        _isActiveStatus(_statuses[normalizedSessionId]);
  }

  bool sessionInterruptingForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    return _interruptingSession && _selectedSessionId == normalizedSessionId;
  }

  SessionSummary? get rootSelectedSession =>
      _rootSessionForId(selectedSessionId);
  SessionSummary? rootSessionForSession(String? sessionId) =>
      _rootSessionForId(sessionId);

  List<WorkspaceQueuedPrompt> get selectedSessionQueuedPrompts {
    return queuedPromptsForSession(selectedSessionId);
  }

  String? get selectedSessionFailedQueuedPromptId {
    return failedQueuedPromptIdForSession(selectedSessionId);
  }

  String? get selectedSessionSendingQueuedPromptId {
    return sendingQueuedPromptIdForSession(selectedSessionId);
  }

  List<WorkspaceQueuedPrompt> queuedPromptsForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return const <WorkspaceQueuedPrompt>[];
    }
    return List<WorkspaceQueuedPrompt>.unmodifiable(
      _queuedPromptsBySessionId[normalizedSessionId] ??
          const <WorkspaceQueuedPrompt>[],
    );
  }

  String? failedQueuedPromptIdForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return null;
    }
    return _queuedPromptFailureBySessionId[normalizedSessionId];
  }

  String? sendingQueuedPromptIdForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return null;
    }
    return _sendingQueuedPromptBySessionId[normalizedSessionId];
  }

  List<SessionSummary> get activeChildSessions =>
      activeChildSessionsForSession(selectedSessionId);

  List<SessionSummary> activeChildSessionsForSession(String? sessionId) {
    final root = _rootSessionForId(sessionId);
    if (root == null) {
      return const <SessionSummary>[];
    }

    final selectedSessionId = sessionId?.trim();
    final sessionTreeIds = _sessionTreeIds(root.id).toSet();
    final children = sessions
        .where((session) => session.id != root.id)
        .where((session) => session.archivedAt == null)
        .where((session) => sessionTreeIds.contains(session.id))
        .where((session) => _isActiveStatus(statuses[session.id]))
        .toList(growable: false);

    children.sort((left, right) {
      final leftSelected = left.id == selectedSessionId;
      final rightSelected = right.id == selectedSessionId;
      if (leftSelected != rightSelected) {
        return leftSelected ? -1 : 1;
      }
      final updated = right.updatedAt.compareTo(left.updatedAt);
      if (updated != 0) {
        return updated;
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });
    return children;
  }

  Map<String, String> get activeChildSessionPreviewById =>
      activeChildSessionPreviewByIdForSession(selectedSessionId);

  Map<String, String> activeChildSessionPreviewByIdForSession(
    String? sessionId,
  ) {
    final previews = <String, String>{};
    for (final session in activeChildSessionsForSession(sessionId)) {
      final preview = _resolveActiveChildSessionPreview(session);
      if (preview != null) {
        previews[session.id] = preview;
      }
    }
    return UnmodifiableMapView<String, String>(previews);
  }

  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    if (normalized == _selectedSessionId) {
      return WorkspaceSessionTimelineState(
        sessionId: normalized,
        messages: _messages,
        orderedMessages: orderedMessages,
        loading: _sessionLoading,
        showingCachedMessages: _showingCachedSessionMessages,
        error: _sessionLoadError,
      );
    }
    return _watchedSessionTimelineById[normalized] ??
        WorkspaceSessionTimelineState.empty(sessionId: normalized);
  }

  void updateWatchedSessionIds(Iterable<String?> sessionIds) {
    final normalized = sessionIds
        .map((sessionId) => sessionId?.trim() ?? '')
        .where((sessionId) => sessionId.isNotEmpty)
        .where((sessionId) => sessionId != _selectedSessionId)
        .toSet();

    if (setEquals(normalized, _watchedSessionIds)) {
      return;
    }

    final removed = _watchedSessionIds.difference(normalized);
    final added = normalized.difference(_watchedSessionIds);
    _watchedSessionIds = Set<String>.unmodifiable(normalized);

    var changed = false;
    if (removed.isNotEmpty) {
      final nextTimelineById = Map<String, WorkspaceSessionTimelineState>.from(
        _watchedSessionTimelineById,
      );
      final nextLoadRevisionById = Map<String, int>.from(
        _watchedSessionLoadRevisionById,
      );
      for (final sessionId in removed) {
        changed = nextTimelineById.remove(sessionId) != null || changed;
        nextLoadRevisionById.remove(sessionId);
      }
      _watchedSessionTimelineById =
          Map<String, WorkspaceSessionTimelineState>.unmodifiable(
            nextTimelineById,
          );
      _watchedSessionLoadRevisionById = Map<String, int>.unmodifiable(
        nextLoadRevisionById,
      );
    }

    if (added.isNotEmpty) {
      for (final sessionId in added) {
        _seedWatchedSessionTimeline(sessionId);
        unawaited(_loadWatchedSessionTimeline(sessionId));
      }
      changed = true;
    }

    if (changed) {
      _notify();
    }
  }

  void selectAgent(String? name) {
    final agent = _findAgent(name) ?? _defaultComposerAgent;
    if (agent == null) {
      return;
    }

    _selectedAgentName = agent.name;
    final preferredModelKey = agent.modelKey;
    if (preferredModelKey.isNotEmpty && _findModel(preferredModelKey) != null) {
      _selectedModelKey = preferredModelKey;
    } else if (_findModel(_selectedModelKey) == null) {
      _selectedModelKey =
          _serverDefaultModelKey ??
          (_composerModels.isEmpty ? null : _composerModels.first.key);
    }

    final preferredReasoning = _resolveReasoningForAgent(agent);
    if (preferredReasoning != null) {
      _selectedReasoning = preferredReasoning;
    } else if (!_isReasoningAllowed(_selectedReasoning, _selectedModelKey)) {
      _selectedReasoning = _fallbackReasoningForModel(_selectedModelKey);
    }
    _notify();
  }

  void selectModel(String? key) {
    final normalized = key?.trim();
    final nextKey = normalized != null && normalized.isNotEmpty
        ? normalized
        : null;
    if (nextKey == _selectedModelKey) {
      return;
    }
    _selectedModelKey = nextKey;
    if (!_isReasoningAllowed(_selectedReasoning, nextKey)) {
      _selectedReasoning = _fallbackReasoningForModel(nextKey);
    }
    _notify();
  }

  void selectReasoning(String? value) {
    final normalized = value?.trim();
    final nextValue = normalized != null && normalized.isNotEmpty
        ? normalized
        : null;
    if (!_isReasoningAllowed(nextValue, _selectedModelKey)) {
      return;
    }
    if (_selectedReasoning == nextValue) {
      return;
    }
    _selectedReasoning = nextValue;
    _notify();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _actionNotice = null;
    _notify();

    try {
      final catalog = await _projectCatalogService.fetchCatalog(profile);
      final recentProjects = await _projectStore.loadRecentProjects();
      final hiddenProjects = await _projectStore.loadHiddenProjects();
      _hiddenProjectDirectories = hiddenProjects;
      final availableProjects = _mergeProjects(
        catalog,
        recentProjects,
        hiddenProjects: hiddenProjects,
      );
      var project = _matchProject(availableProjects, directory);
      project ??= await _projectCatalogService.inspectDirectory(
        profile: profile,
        directory: directory,
      );
      final resolvedProject = project;

      _project = resolvedProject;
      _availableProjects =
          availableProjects.any(
            (candidate) => candidate.directory == resolvedProject.directory,
          )
          ? availableProjects
          : <ProjectTarget>[resolvedProject, ...availableProjects];
      await _restorePermissionAutoAccept(resolvedProject);
      await _restoreQueuedPrompts(resolvedProject);

      await _projectStore.recordRecentProject(resolvedProject);
      await _projectStore.saveLastWorkspace(
        serverStorageKey: profile.storageKey,
        target: resolvedProject,
      );

      await _loadComposerState(resolvedProject);
      final bundle = await _chatService.fetchBundle(
        profile: profile,
        project: resolvedProject,
      );
      _sessions = bundle.sessions;
      _statuses = bundle.statuses;
      _selectedSessionId = _resolveSessionSelection(
        requestedSessionId: initialSessionId,
        bundleSelectedSessionId: bundle.selectedSessionId,
        project: resolvedProject,
        sessions: bundle.sessions,
      );
      _loading = false;
      _notify();

      if (_selectedSessionId != null) {
        await _loadSelectedSessionMessages(
          project: resolvedProject,
          sessionId: _selectedSessionId!,
          loadPanels: false,
          persistHint: false,
          notifyOnStart: true,
        );
      } else {
        _messages = const <ChatMessage>[];
        _sessionLoading = false;
        _showingCachedSessionMessages = false;
        _sessionLoadError = null;
        _applyDefaultComposerSelection();
        _notify();
      }

      await _loadProjectPanels();
      await _connectEvents();
      _maybeFlushQueuedPrompts();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> selectProject(ProjectTarget project) async {
    _project = project;
    _selectedSessionId = null;
    _messages = const <ChatMessage>[];
    _sessionLoading = false;
    _showingCachedSessionMessages = false;
    _sessionLoadError = null;
    _loadingFileDirectoryPath = null;
    _expandedFileDirectories = <String>{};
    _loadedFileDirectories = <String>{};
    _loadingReviewDiff = false;
    _reviewDiffError = null;
    _reviewBundle = null;
    _selectedReviewPath = null;
    _reviewDiff = null;
    _replaceSelectedSessionTodos(const <TodoItem>[]);
    _pendingRequests = const PendingRequestBundle(
      questions: <QuestionRequestSummary>[],
      permissions: <PermissionRequestSummary>[],
    );
    _fileBundle = null;
    _actionNotice = null;
    _notify();

    await _projectStore.recordRecentProject(project);
    _hiddenProjectDirectories = await _projectStore.loadHiddenProjects();
    await _projectStore.saveLastWorkspace(
      serverStorageKey: profile.storageKey,
      target: project,
    );
    await _restorePermissionAutoAccept(project);
    await _restoreQueuedPrompts(project);

    await _loadComposerState(project);
    final bundle = await _chatService.fetchBundle(
      profile: profile,
      project: project,
    );
    _sessions = bundle.sessions;
    _statuses = bundle.statuses;
    _selectedSessionId = _resolveSessionSelection(
      requestedSessionId: null,
      bundleSelectedSessionId: bundle.selectedSessionId,
      project: project,
      sessions: bundle.sessions,
    );
    if (_selectedSessionId != null) {
      await _loadSelectedSessionMessages(
        project: project,
        sessionId: _selectedSessionId!,
        loadPanels: false,
        persistHint: false,
        notifyOnStart: false,
      );
    } else {
      _messages = const <ChatMessage>[];
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
      _applyDefaultComposerSelection();
    }
    await _loadProjectPanels();
    await _connectEvents();
    _maybeFlushQueuedPrompts();
    _notify();
  }

  void preserveSelectedSessionTimelineForWatch() {
    _cacheSelectedTimelineForSession(_selectedSessionId, requireWatched: false);
  }

  Future<void> selectSession(String? sessionId) async {
    if (_project == null) {
      return;
    }
    final normalizedSessionId = sessionId?.trim();
    final nextSessionId =
        normalizedSessionId != null && normalizedSessionId.isNotEmpty
        ? normalizedSessionId
        : null;
    final previousSessionId = _selectedSessionId;
    if (previousSessionId == nextSessionId) {
      return;
    }
    _cacheSelectedTimelineForWatchedSession(previousSessionId);
    final promotedWatchedTimeline = nextSessionId == null
        ? null
        : _takeWatchedSessionTimeline(nextSessionId);
    final canReuseWatchedTimeline =
        promotedWatchedTimeline != null &&
        !promotedWatchedTimeline.loading &&
        promotedWatchedTimeline.error == null;

    _selectedSessionId = nextSessionId;
    if (canReuseWatchedTimeline) {
      _messages = promotedWatchedTimeline.messages;
      _sessionLoading = false;
      _showingCachedSessionMessages =
          promotedWatchedTimeline.showingCachedMessages;
      _sessionLoadError = null;
      if (_messages.isEmpty) {
        _applyDefaultComposerSelection();
      } else {
        _restoreComposerSelectionFromMessages();
      }
    } else {
      _messages = const <ChatMessage>[];
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
    }
    _replaceSelectedSessionTodos(const <TodoItem>[]);
    _loadingReviewDiff = false;
    _reviewDiffError = null;
    _reviewBundle = null;
    _selectedReviewPath = null;
    _reviewDiff = null;
    _notify();

    if (nextSessionId == null) {
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
      _applyDefaultComposerSelection();
      _notify();
      _maybeFlushQueuedPrompts();
      return;
    }

    if (canReuseWatchedTimeline) {
      await _loadSessionPanels();
      if (_disposed || _selectedSessionId != nextSessionId) {
        return;
      }
      await _persistSessionHint(nextSessionId);
      if (_disposed || _selectedSessionId != nextSessionId) {
        return;
      }
      _maybeFlushQueuedPrompts(sessionId: nextSessionId);
      _notify();
      return;
    }

    await _loadSelectedSessionMessages(
      project: _project!,
      sessionId: nextSessionId,
      loadPanels: true,
      persistHint: true,
    );
    _maybeFlushQueuedPrompts(sessionId: nextSessionId);
  }

  Future<void> retrySelectedSessionMessages() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || sessionId.isEmpty) {
      return;
    }
    await _loadSelectedSessionMessages(
      project: project,
      sessionId: sessionId,
      loadPanels: true,
      persistHint: true,
    );
  }

  Future<void> refreshTimelineSession(String? sessionId) async {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (normalized == _selectedSessionId) {
      await retrySelectedSessionMessages();
      return;
    }
    if (!_watchedSessionIds.contains(normalized)) {
      return;
    }
    await _loadWatchedSessionTimeline(normalized);
  }

  Future<void> selectReviewFile(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final bundle = _reviewBundle;
    final cachedDiff = bundle?.diffForPath(trimmed);
    if (_selectedReviewPath == trimmed &&
        cachedDiff != null &&
        _reviewDiffError == null &&
        !_loadingReviewDiff) {
      return;
    }
    if (cachedDiff != null) {
      _selectedReviewPath = trimmed;
      _reviewDiff = cachedDiff;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
      _notify();
      return;
    }
    await _loadSelectedSessionReview(pathHint: trimmed);
  }

  Future<void> selectFile(String path) async {
    final project = _project;
    final bundle = _fileBundle;
    final trimmed = path.trim();
    if (project == null || bundle == null || trimmed.isEmpty) {
      return;
    }

    FileNodeSummary? selectedNode;
    for (final node in bundle.nodes) {
      if (node.path == trimmed) {
        selectedNode = node;
        break;
      }
    }

    final selectingDirectory = selectedNode?.type == 'directory';
    final shouldReloadPreview =
        bundle.selectedPath != trimmed ||
        bundle.preview == null ||
        _loadingFilePreview;
    if (!shouldReloadPreview) {
      return;
    }

    _expandedFileDirectories = <String>{
      ..._expandedFileDirectories,
      ..._ancestorDirectories(trimmed),
    };
    _loadingFilePreview = !selectingDirectory;
    _fileBundle = bundle.copyWith(selectedPath: trimmed, clearPreview: true);
    _notify();

    if (selectingDirectory) {
      _loadingFilePreview = false;
      _notify();
      return;
    }

    try {
      final preview = await _fileBrowserService.fetchFileContent(
        profile: profile,
        project: project,
        path: trimmed,
      );
      if (_disposed || _fileBundle?.selectedPath != trimmed) {
        return;
      }
      _fileBundle = _fileBundle?.copyWith(
        selectedPath: trimmed,
        preview: preview,
      );
    } catch (_) {
      if (_disposed || _fileBundle?.selectedPath != trimmed) {
        return;
      }
      _fileBundle = _fileBundle?.copyWith(
        selectedPath: trimmed,
        clearPreview: true,
      );
    } finally {
      if (!_disposed && _fileBundle?.selectedPath == trimmed) {
        _loadingFilePreview = false;
        _notify();
      }
    }
  }

  Future<void> toggleFileDirectory(String path) async {
    final project = _project;
    final bundle = _fileBundle;
    final trimmed = path.trim();
    if (project == null || bundle == null || trimmed.isEmpty) {
      return;
    }

    if (_expandedFileDirectories.contains(trimmed)) {
      _expandedFileDirectories = <String>{..._expandedFileDirectories}
        ..remove(trimmed);
      _notify();
      return;
    }

    _expandedFileDirectories = <String>{
      ..._expandedFileDirectories,
      ..._ancestorDirectories(trimmed),
      trimmed,
    };
    final shouldLoadChildren =
        !_loadedFileDirectories.contains(trimmed) &&
        !_hasKnownChildren(bundle.nodes, trimmed);
    _loadingFileDirectoryPath = shouldLoadChildren ? trimmed : null;
    _notify();

    if (!shouldLoadChildren) {
      return;
    }

    try {
      final children = await _fileBrowserService.fetchNodes(
        profile: profile,
        project: project,
        path: trimmed,
      );
      if (_disposed) {
        return;
      }
      final current = _fileBundle;
      if (current == null) {
        return;
      }
      _fileBundle = current.copyWith(
        nodes: _mergeFileNodes(current.nodes, children),
      );
      _loadedFileDirectories = <String>{..._loadedFileDirectories, trimmed};
    } catch (_) {
      // Keep the folder open even if refreshing its children fails.
    } finally {
      if (!_disposed && _loadingFileDirectoryPath == trimmed) {
        _loadingFileDirectoryPath = null;
        _notify();
      }
    }
  }

  String? _resolveReviewPathSelection(
    List<FileStatusSummary> statuses, {
    String? preferredPath,
  }) {
    final trimmedPreferred = preferredPath?.trim();
    if (trimmedPreferred != null && trimmedPreferred.isNotEmpty) {
      for (final status in statuses) {
        if (status.path == trimmedPreferred) {
          return status.path;
        }
      }
    }
    if (statuses.isEmpty) {
      return null;
    }
    return statuses.first.path;
  }

  void _applyReviewBundle(
    ReviewSessionDiffBundle bundle, {
    String? preferredPath,
  }) {
    _reviewBundle = bundle;
    final resolvedPath = _resolveReviewPathSelection(
      bundle.statuses,
      preferredPath: preferredPath ?? _selectedReviewPath,
    );
    _selectedReviewPath = resolvedPath;
    _reviewDiff = resolvedPath == null
        ? null
        : bundle.diffForPath(resolvedPath);
    _reviewDiffError = null;
  }

  Future<void> _loadSelectedSessionReview({String? pathHint}) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _reviewBundle = null;
      _selectedReviewPath = pathHint;
      _reviewDiff = null;
      _reviewDiffError = 'Select a session to review its diff.';
      _loadingReviewDiff = false;
      _notify();
      return;
    }

    final revision = ++_reviewDiffRevision;
    _selectedReviewPath = pathHint ?? _selectedReviewPath;
    _reviewDiffError = null;
    _loadingReviewDiff = true;
    _notify();

    try {
      final bundle = await _reviewDiffService.fetchSessionDiffs(
        profile: profile,
        sessionId: sessionId,
      );
      if (_disposed ||
          revision != _reviewDiffRevision ||
          _selectedSessionId != sessionId) {
        return;
      }
      _applyReviewBundle(bundle, preferredPath: pathHint);
    } catch (error) {
      if (_disposed ||
          revision != _reviewDiffRevision ||
          _selectedSessionId != sessionId) {
        return;
      }
      _reviewBundle = null;
      _selectedReviewPath = pathHint;
      _reviewDiff = null;
      _reviewDiffError =
          'Couldn\'t load the review diff.\n${error.toString().trim()}';
    } finally {
      if (!_disposed &&
          revision == _reviewDiffRevision &&
          _selectedSessionId == sessionId) {
        _loadingReviewDiff = false;
        _notify();
      }
    }
  }

  Future<void> _loadSelectedSessionMessages({
    required ProjectTarget project,
    required String sessionId,
    required bool loadPanels,
    required bool persistHint,
    bool notifyOnStart = true,
  }) async {
    final revision = ++_sessionLoadRevision;
    _sessionLoading = true;
    _sessionLoadError = null;
    _showingCachedSessionMessages = false;
    _replaceSelectedSessionTodos(const <TodoItem>[]);
    final cachedMessages = await _loadCachedSessionMessages(
      project: project,
      sessionId: sessionId,
    );
    if (_isStaleSessionLoad(revision, sessionId)) {
      return;
    }
    if (cachedMessages != null) {
      _messages = _mergeSessionMessages(
        project: project,
        sessionId: sessionId,
        serverMessages: cachedMessages,
      );
      _showingCachedSessionMessages = cachedMessages.isNotEmpty;
      if (_messages.isEmpty) {
        _applyDefaultComposerSelection();
      } else {
        _restoreComposerSelectionFromMessages();
      }
    }
    if (notifyOnStart) {
      _notify();
    }

    try {
      final messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
      if (_isStaleSessionLoad(revision, sessionId)) {
        return;
      }

      _messages = _mergeSessionMessages(
        project: project,
        sessionId: sessionId,
        serverMessages: messages,
      );
      _showingCachedSessionMessages = false;
      if (_messages.isEmpty) {
        _applyDefaultComposerSelection();
      } else {
        _restoreComposerSelectionFromMessages();
      }
      unawaited(
        _persistSessionMessagesCache(
          project: project,
          sessionId: sessionId,
          messages: messages,
          immediate: true,
        ),
      );

      if (loadPanels) {
        await _loadSessionPanels();
        if (_isStaleSessionLoad(revision, sessionId)) {
          return;
        }
      }

      if (persistHint) {
        await _persistSessionHint(sessionId);
        if (_isStaleSessionLoad(revision, sessionId)) {
          return;
        }
      }

      _sessionLoading = false;
      _sessionLoadError = null;
      _notify();
    } catch (error) {
      if (_isStaleSessionLoad(revision, sessionId)) {
        return;
      }
      _sessionLoading = false;
      _sessionLoadError = _describeSessionLoadError(error);
      if (_messages.isEmpty) {
        _showingCachedSessionMessages = false;
        _applyDefaultComposerSelection();
      }
      _notify();
    }
  }

  bool _isStaleSessionLoad(int revision, String sessionId) {
    return _disposed ||
        revision != _sessionLoadRevision ||
        _selectedSessionId != sessionId;
  }

  String _describeSessionLoadError(Object error) {
    final detail = error.toString().trim();
    if (detail.isEmpty) {
      return 'The server may be offline or responding too slowly. Please try again.';
    }
    return 'The server may be offline or responding too slowly.\n$detail';
  }

  void _seedWatchedSessionTimeline(String sessionId) {
    if (_watchedSessionTimelineById.containsKey(sessionId)) {
      return;
    }
    final next = Map<String, WorkspaceSessionTimelineState>.from(
      _watchedSessionTimelineById,
    );
    next[sessionId] = WorkspaceSessionTimelineState(
      sessionId: sessionId,
      messages: const <ChatMessage>[],
      orderedMessages: const <ChatMessage>[],
      loading: true,
      showingCachedMessages: false,
    );
    _watchedSessionTimelineById =
        Map<String, WorkspaceSessionTimelineState>.unmodifiable(next);
  }

  void _cacheSelectedTimelineForWatchedSession(String? sessionId) {
    _cacheSelectedTimelineForSession(sessionId, requireWatched: true);
  }

  void _cacheSelectedTimelineForSession(
    String? sessionId, {
    required bool requireWatched,
  }) {
    final normalized = sessionId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    _setSessionTimelineState(
      normalized,
      WorkspaceSessionTimelineState(
        sessionId: normalized,
        messages: _messages,
        orderedMessages: orderedMessages,
        loading: false,
        showingCachedMessages: _showingCachedSessionMessages,
        error: _sessionLoadError,
      ),
      requireWatched: requireWatched,
    );
  }

  void _setWatchedSessionTimeline(
    String sessionId,
    WorkspaceSessionTimelineState state,
  ) {
    _setSessionTimelineState(sessionId, state);
  }

  void _setSessionTimelineState(
    String sessionId,
    WorkspaceSessionTimelineState state, {
    bool requireWatched = true,
  }) {
    if (requireWatched && !_watchedSessionIds.contains(sessionId)) {
      return;
    }
    final current = _watchedSessionTimelineById[sessionId];
    if (current != null &&
        identical(current.messages, state.messages) &&
        identical(current.orderedMessages, state.orderedMessages) &&
        current.loading == state.loading &&
        current.showingCachedMessages == state.showingCachedMessages &&
        current.error == state.error) {
      return;
    }
    final next = Map<String, WorkspaceSessionTimelineState>.from(
      _watchedSessionTimelineById,
    )..[sessionId] = state;
    _watchedSessionTimelineById =
        Map<String, WorkspaceSessionTimelineState>.unmodifiable(next);
  }

  WorkspaceSessionTimelineState? _takeWatchedSessionTimeline(String sessionId) {
    final current = _watchedSessionTimelineById[sessionId];
    if (current == null) {
      return null;
    }
    final nextTimelineById = Map<String, WorkspaceSessionTimelineState>.from(
      _watchedSessionTimelineById,
    )..remove(sessionId);
    _watchedSessionTimelineById =
        Map<String, WorkspaceSessionTimelineState>.unmodifiable(
          nextTimelineById,
        );
    final nextLoadRevisionById = Map<String, int>.from(
      _watchedSessionLoadRevisionById,
    )..remove(sessionId);
    _watchedSessionLoadRevisionById = Map<String, int>.unmodifiable(
      nextLoadRevisionById,
    );
    return current;
  }

  WorkspaceSessionTimelineState _buildTimelineState({
    required String sessionId,
    required List<ChatMessage> messages,
    required bool loading,
    required bool showingCachedMessages,
    String? error,
  }) {
    final ordered =
        identical(messages, _messages) && sessionId == _selectedSessionId
        ? orderedMessages
        : _orderedTimelineMessages(messages);
    return WorkspaceSessionTimelineState(
      sessionId: sessionId,
      messages: messages,
      orderedMessages: ordered,
      loading: loading,
      showingCachedMessages: showingCachedMessages,
      error: error,
    );
  }

  bool _isStaleWatchedSessionLoad(int revision, String sessionId) {
    return _disposed ||
        !_watchedSessionIds.contains(sessionId) ||
        revision != _watchedSessionLoadRevisionById[sessionId] ||
        _selectedSessionId == sessionId;
  }

  Future<void> _loadWatchedSessionTimeline(String sessionId) async {
    final project = _project;
    if (project == null ||
        sessionId.isEmpty ||
        !_watchedSessionIds.contains(sessionId)) {
      return;
    }
    final revision = (_watchedSessionLoadRevisionById[sessionId] ?? 0) + 1;
    _watchedSessionLoadRevisionById = Map<String, int>.unmodifiable(
      <String, int>{..._watchedSessionLoadRevisionById, sessionId: revision},
    );

    final current = _watchedSessionTimelineById[sessionId];
    _setWatchedSessionTimeline(
      sessionId,
      _buildTimelineState(
        sessionId: sessionId,
        messages: current?.messages ?? const <ChatMessage>[],
        loading: true,
        showingCachedMessages: current?.showingCachedMessages ?? false,
        error: null,
      ),
    );
    _notify();

    final cachedMessages = await _loadCachedSessionMessages(
      project: project,
      sessionId: sessionId,
    );
    if (_isStaleWatchedSessionLoad(revision, sessionId)) {
      return;
    }
    if (cachedMessages != null) {
      _setWatchedSessionTimeline(
        sessionId,
        _buildTimelineState(
          sessionId: sessionId,
          messages: _mergeSessionMessages(
            project: project,
            sessionId: sessionId,
            serverMessages: cachedMessages,
          ),
          loading: true,
          showingCachedMessages: cachedMessages.isNotEmpty,
          error: null,
        ),
      );
      _notify();
    }

    try {
      final messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
      if (_isStaleWatchedSessionLoad(revision, sessionId)) {
        return;
      }
      _setWatchedSessionTimeline(
        sessionId,
        _buildTimelineState(
          sessionId: sessionId,
          messages: _mergeSessionMessages(
            project: project,
            sessionId: sessionId,
            serverMessages: messages,
          ),
          loading: false,
          showingCachedMessages: false,
          error: null,
        ),
      );
      unawaited(
        _saveSessionMessagesCache(
          project: project,
          sessionId: sessionId,
          messages: messages,
        ),
      );
      _notify();
    } catch (error) {
      if (_isStaleWatchedSessionLoad(revision, sessionId)) {
        return;
      }
      final currentState = _watchedSessionTimelineById[sessionId];
      _setWatchedSessionTimeline(
        sessionId,
        _buildTimelineState(
          sessionId: sessionId,
          messages: currentState?.messages ?? const <ChatMessage>[],
          loading: false,
          showingCachedMessages: currentState?.showingCachedMessages ?? false,
          error: _describeSessionLoadError(error),
        ),
      );
      _notify();
    }
  }

  void _applyWatchedSessionTimelineEvent(
    Map<String, Object?> properties, {
    required String? sessionId,
    required List<ChatMessage> Function(List<ChatMessage> messages) applyEvent,
    bool persistImmediately = false,
  }) {
    final normalized = sessionId?.trim() ?? '';
    if (normalized.isEmpty ||
        normalized == _selectedSessionId ||
        !_watchedSessionIds.contains(normalized)) {
      return;
    }
    final project = _project;
    if (project == null) {
      return;
    }
    final currentState =
        _watchedSessionTimelineById[normalized] ??
        WorkspaceSessionTimelineState.empty(sessionId: normalized);
    final baseMessages = _stripOptimisticMessages(
      project: project,
      sessionId: normalized,
      messages: currentState.messages,
    );
    final nextServerMessages = applyEvent(baseMessages);
    final nextMessages = _mergeSessionMessages(
      project: project,
      sessionId: normalized,
      serverMessages: nextServerMessages,
    );
    if (identical(nextMessages, currentState.messages)) {
      return;
    }
    _setWatchedSessionTimeline(
      normalized,
      _buildTimelineState(
        sessionId: normalized,
        messages: nextMessages,
        loading: false,
        showingCachedMessages: false,
        error: null,
      ),
    );
    if (persistImmediately) {
      unawaited(
        _saveSessionMessagesCache(
          project: project,
          sessionId: normalized,
          messages: nextServerMessages,
        ),
      );
    }
  }

  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    final trimmed = prompt.trim();
    final project = _project;
    final selectedAgent = this.selectedAgent;
    final selectedModel = this.selectedModel;
    if (project == null || (trimmed.isEmpty && attachments.isEmpty)) {
      return _selectedSessionId;
    }

    if (_submittingPrompt) {
      return _selectedSessionId;
    }

    var sessionId = _selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      final created = await _chatService.createSession(
        profile: profile,
        project: project,
      );
      sessionId = created.id;
      _selectedSessionId = sessionId;
      _sessions = <SessionSummary>[created, ..._sessions];
      _statuses = <String, SessionStatusSummary>{
        ..._statuses,
        sessionId:
            _statuses[sessionId] ?? const SessionStatusSummary(type: 'idle'),
      };
      _notify();
    }

    final effectiveMode = mode;
    if (effectiveMode == WorkspacePromptDispatchMode.queue &&
        _isSessionBusyById(sessionId)) {
      _enqueueQueuedPrompt(
        sessionId: sessionId,
        prompt: trimmed,
        attachments: attachments,
        agentName: selectedAgent?.name,
        modelKey: _selectedModelKey,
        providerId: selectedModel?.providerId,
        modelId: selectedModel?.modelId,
        reasoning: _selectedReasoning,
      );
      return sessionId;
    }

    _submittingPrompt = true;
    _notify();

    try {
      await _dispatchPrompt(
        project: project,
        sessionId: sessionId,
        prompt: trimmed,
        attachments: attachments,
        agentName: selectedAgent?.name,
        providerId: selectedModel?.providerId,
        modelId: selectedModel?.modelId,
        reasoning: _selectedReasoning,
        preferAsync:
            effectiveMode == WorkspacePromptDispatchMode.steer &&
            _isSessionBusyById(sessionId),
      );
      return sessionId;
    } finally {
      _submittingPrompt = false;
      _notify();
    }
  }

  Future<WorkspaceQueuedPrompt?> editSelectedQueuedPrompt(
    String queuedPromptId,
  ) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    final queue = _queuedPromptsBySessionId[sessionId];
    if (queue == null || queue.isEmpty) {
      return null;
    }
    if (_sendingQueuedPromptBySessionId.containsKey(sessionId)) {
      return null;
    }
    WorkspaceQueuedPrompt? target;
    final nextQueue = <WorkspaceQueuedPrompt>[];
    for (final item in queue) {
      if (item.id == queuedPromptId && target == null) {
        target = item;
        continue;
      }
      nextQueue.add(item);
    }
    if (target == null) {
      return null;
    }
    _setQueuedPromptsForSession(sessionId, nextQueue);
    if (_queuedPromptFailureBySessionId[sessionId] == queuedPromptId) {
      _queuedPromptFailureBySessionId = Map<String, String>.from(
        _queuedPromptFailureBySessionId,
      )..remove(sessionId);
    }
    await _persistQueuedPrompts();
    _notify();
    _maybeFlushQueuedPrompts(sessionId: sessionId);
    return target;
  }

  Future<void> deleteSelectedQueuedPrompt(String queuedPromptId) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    final queue = _queuedPromptsBySessionId[sessionId];
    if (queue == null || queue.isEmpty) {
      return;
    }
    final nextQueue = queue
        .where((item) => item.id != queuedPromptId)
        .toList(growable: false);
    if (nextQueue.length == queue.length) {
      return;
    }
    _setQueuedPromptsForSession(sessionId, nextQueue);
    if (_queuedPromptFailureBySessionId[sessionId] == queuedPromptId) {
      _queuedPromptFailureBySessionId = Map<String, String>.from(
        _queuedPromptFailureBySessionId,
      )..remove(sessionId);
    }
    await _persistQueuedPrompts();
    _notify();
    _maybeFlushQueuedPrompts(sessionId: sessionId);
  }

  Future<void> sendSelectedQueuedPromptNow(String queuedPromptId) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    await _sendQueuedPrompt(
      sessionId: sessionId,
      queuedPromptId: queuedPromptId,
      manual: true,
    );
  }

  Future<void> _refreshAfterPrompt({
    required ProjectTarget project,
    required String sessionId,
    required int revision,
  }) async {
    List<ChatMessage>? messages;
    try {
      messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
    } catch (_) {
      messages = null;
    }

    if (_disposed || revision != _promptRefreshRevision) {
      return;
    }

    if (messages != null) {
      final mergedMessages = _mergeSessionMessages(
        project: project,
        sessionId: sessionId,
        serverMessages: messages,
      );
      if (_selectedSessionId == sessionId) {
        _messages = mergedMessages;
        _sessionLoading = false;
        _showingCachedSessionMessages = false;
        _sessionLoadError = null;
        _restoreComposerSelectionFromMessages();
        unawaited(
          _persistSessionMessagesCache(
            project: project,
            sessionId: sessionId,
            messages: messages,
            immediate: true,
          ),
        );
      } else if (_watchedSessionIds.contains(sessionId)) {
        _setWatchedSessionTimeline(
          sessionId,
          _buildTimelineState(
            sessionId: sessionId,
            messages: mergedMessages,
            loading: false,
            showingCachedMessages: false,
            error: null,
          ),
        );
        unawaited(
          _saveSessionMessagesCache(
            project: project,
            sessionId: sessionId,
            messages: messages,
          ),
        );
      }
    }

    try {
      final bundle = await _chatService.fetchBundle(
        profile: profile,
        project: project,
      );
      if (_disposed || revision != _promptRefreshRevision) {
        return;
      }
      _sessions = bundle.sessions;
      _statuses = bundle.statuses;
    } catch (_) {
      if (_disposed || revision != _promptRefreshRevision) {
        return;
      }
    }

    if (_disposed || revision != _promptRefreshRevision) {
      return;
    }

    if (_selectedSessionId == sessionId) {
      await _loadSessionPanels();
      await _persistSessionHint(sessionId);
    }

    if (_disposed || revision != _promptRefreshRevision) {
      return;
    }

    _maybeFlushQueuedPrompts();
    _notify();
  }

  Future<void> _dispatchPrompt({
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    required List<PromptAttachment> attachments,
    required String? agentName,
    required String? providerId,
    required String? modelId,
    required String? reasoning,
    bool preferAsync = false,
  }) async {
    ChatMessage? optimisticMessage;
    if (prompt.isNotEmpty || attachments.isNotEmpty) {
      optimisticMessage = _appendOptimisticUserMessage(
        project: project,
        sessionId: sessionId,
        prompt: prompt,
        attachments: attachments,
      );
    }

    final slashCommand = _parseSlashCommand(prompt);
    try {
      if (slashCommand != null &&
          _findComposerCommand(slashCommand.name) != null) {
        await _chatService.sendCommand(
          profile: profile,
          project: project,
          sessionId: sessionId,
          command: slashCommand.name,
          arguments: slashCommand.arguments,
          attachments: attachments,
          agent: agentName,
          providerId: providerId,
          modelId: modelId,
          variant: reasoning,
        );
      } else if (preferAsync) {
        final accepted = await _chatService.sendMessageAsync(
          profile: profile,
          project: project,
          sessionId: sessionId,
          prompt: prompt,
          attachments: attachments,
          messageId: optimisticMessage?.info.id,
          agent: agentName,
          providerId: providerId,
          modelId: modelId,
          variant: reasoning,
          reasoning: reasoning,
        );
        if (!accepted) {
          await _chatService.sendMessage(
            profile: profile,
            project: project,
            sessionId: sessionId,
            prompt: prompt,
            attachments: attachments,
            agent: agentName,
            providerId: providerId,
            modelId: modelId,
            variant: reasoning,
            reasoning: reasoning,
          );
        }
      } else {
        await _chatService.sendMessage(
          profile: profile,
          project: project,
          sessionId: sessionId,
          prompt: prompt,
          attachments: attachments,
          agent: agentName,
          providerId: providerId,
          modelId: modelId,
          variant: reasoning,
          reasoning: reasoning,
        );
      }
    } catch (error) {
      if (optimisticMessage != null) {
        _removeOptimisticMessage(
          project: project,
          sessionId: sessionId,
          messageId: optimisticMessage.info.id,
        );
      }
      rethrow;
    }

    _markSessionBusy(sessionId);
    _schedulePromptRefresh(project: project, sessionId: sessionId);
  }

  void _schedulePromptRefresh({
    required ProjectTarget project,
    required String sessionId,
  }) {
    final refreshRevision = ++_promptRefreshRevision;
    unawaited(
      _refreshAfterPrompt(
        project: project,
        sessionId: sessionId,
        revision: refreshRevision,
      ),
    );
  }

  void _enqueueQueuedPrompt({
    required String sessionId,
    required String prompt,
    required List<PromptAttachment> attachments,
    required String? agentName,
    required String? modelKey,
    required String? providerId,
    required String? modelId,
    required String? reasoning,
  }) {
    final timestamp = DateTime.now();
    final queuedPrompt = WorkspaceQueuedPrompt(
      id: 'queued_${timestamp.microsecondsSinceEpoch}_${_queuedPromptSequence++}',
      sessionId: sessionId,
      prompt: prompt,
      attachments: List<PromptAttachment>.unmodifiable(
        List<PromptAttachment>.from(attachments),
      ),
      createdAt: timestamp,
      agentName: agentName,
      modelKey: modelKey,
      providerId: providerId,
      modelId: modelId,
      reasoning: reasoning,
    );
    final nextQueue = <WorkspaceQueuedPrompt>[
      ...?_queuedPromptsBySessionId[sessionId],
      queuedPrompt,
    ];
    _setQueuedPromptsForSession(sessionId, nextQueue);
    _queuedPromptFailureBySessionId = Map<String, String>.from(
      _queuedPromptFailureBySessionId,
    )..remove(sessionId);
    unawaited(_persistQueuedPrompts());
    _notify();
  }

  Future<void> _sendQueuedPrompt({
    required String sessionId,
    required String queuedPromptId,
    bool manual = false,
  }) async {
    final project = _project;
    if (project == null) {
      return;
    }
    if (_sendingQueuedPromptBySessionId.containsKey(sessionId)) {
      return;
    }
    final queuedPrompt = _findQueuedPrompt(
      sessionId: sessionId,
      queuedPromptId: queuedPromptId,
    );
    if (queuedPrompt == null) {
      return;
    }
    if (!manual && _isSessionBusyById(sessionId)) {
      return;
    }

    _sendingQueuedPromptBySessionId = <String, String>{
      ..._sendingQueuedPromptBySessionId,
      sessionId: queuedPromptId,
    };
    _queuedPromptFailureBySessionId = Map<String, String>.from(
      _queuedPromptFailureBySessionId,
    )..remove(sessionId);
    _notify();

    try {
      await _dispatchPrompt(
        project: project,
        sessionId: sessionId,
        prompt: queuedPrompt.prompt,
        attachments: queuedPrompt.attachments,
        agentName: queuedPrompt.agentName,
        providerId: queuedPrompt.providerId,
        modelId: queuedPrompt.modelId,
        reasoning: queuedPrompt.reasoning,
        preferAsync: true,
      );
      final queue = _queuedPromptsBySessionId[sessionId];
      if (queue != null && queue.isNotEmpty) {
        _setQueuedPromptsForSession(
          sessionId,
          queue
              .where((item) => item.id != queuedPromptId)
              .toList(growable: false),
        );
      }
      await _persistQueuedPrompts();
    } catch (error) {
      _queuedPromptFailureBySessionId = <String, String>{
        ..._queuedPromptFailureBySessionId,
        sessionId: queuedPromptId,
      };
      rethrow;
    } finally {
      _sendingQueuedPromptBySessionId = Map<String, String>.from(
        _sendingQueuedPromptBySessionId,
      )..remove(sessionId);
      _notify();
    }
  }

  WorkspaceQueuedPrompt? _findQueuedPrompt({
    required String sessionId,
    required String queuedPromptId,
  }) {
    final queue = _queuedPromptsBySessionId[sessionId];
    if (queue == null || queue.isEmpty) {
      return null;
    }
    for (final item in queue) {
      if (item.id == queuedPromptId) {
        return item;
      }
    }
    return null;
  }

  void _setQueuedPromptsForSession(
    String sessionId,
    List<WorkspaceQueuedPrompt> queuedPrompts,
  ) {
    final nextMap = Map<String, List<WorkspaceQueuedPrompt>>.from(
      _queuedPromptsBySessionId,
    );
    if (queuedPrompts.isEmpty) {
      nextMap.remove(sessionId);
    } else {
      nextMap[sessionId] = List<WorkspaceQueuedPrompt>.unmodifiable(
        queuedPrompts,
      );
    }
    _queuedPromptsBySessionId = nextMap;
  }

  void _clearQueuedPromptStateForSession(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    _setQueuedPromptsForSession(sessionId, const <WorkspaceQueuedPrompt>[]);
    _queuedPromptFailureBySessionId = Map<String, String>.from(
      _queuedPromptFailureBySessionId,
    )..remove(sessionId);
    _sendingQueuedPromptBySessionId = Map<String, String>.from(
      _sendingQueuedPromptBySessionId,
    )..remove(sessionId);
    unawaited(_persistQueuedPrompts());
  }

  Future<void> _restoreQueuedPrompts(ProjectTarget project) async {
    final entry = await _cacheStore.load(_queuedPromptCacheKey(project));
    if (entry == null || entry.payloadJson.trim().isEmpty) {
      _queuedPromptsBySessionId = const <String, List<WorkspaceQueuedPrompt>>{};
      _queuedPromptFailureBySessionId = const <String, String>{};
      _sendingQueuedPromptBySessionId = const <String, String>{};
      return;
    }
    try {
      final decoded = await _decodeJsonPayload(entry.payloadJson);
      final next = _queuedPromptsFromDecodedJson(decoded);
      _queuedPromptsBySessionId = next;
    } catch (_) {
      _queuedPromptsBySessionId = const <String, List<WorkspaceQueuedPrompt>>{};
      await _cacheStore.remove(_queuedPromptCacheKey(project));
    }
    _queuedPromptFailureBySessionId = const <String, String>{};
    _sendingQueuedPromptBySessionId = const <String, String>{};
  }

  Future<void> _persistQueuedPrompts() async {
    final project = _project;
    if (project == null) {
      return;
    }
    if (_queuedPromptsBySessionId.isEmpty) {
      await _cacheStore.remove(_queuedPromptCacheKey(project));
      return;
    }
    final payload = _queuedPromptsBySessionId.map(
      (sessionId, items) => MapEntry(
        sessionId,
        items.map((item) => item.toJson()).toList(growable: false),
      ),
    );
    await _cacheStore.save(_queuedPromptCacheKey(project), payload);
  }

  void _maybeFlushQueuedPrompts({String? sessionId}) {
    final project = _project;
    if (project == null || _disposed) {
      return;
    }
    final sessionIds = sessionId == null
        ? _queuedPromptsBySessionId.keys.toList(growable: false)
        : <String>[sessionId];
    for (final candidateSessionId in sessionIds) {
      final queue = _queuedPromptsBySessionId[candidateSessionId];
      if (queue == null || queue.isEmpty) {
        continue;
      }
      if (_sendingQueuedPromptBySessionId.containsKey(candidateSessionId)) {
        continue;
      }
      final nextItem = queue.first;
      if (_queuedPromptFailureBySessionId[candidateSessionId] == nextItem.id) {
        continue;
      }
      if (_isSessionBusyById(candidateSessionId)) {
        continue;
      }
      unawaited(
        _sendQueuedPrompt(
          sessionId: candidateSessionId,
          queuedPromptId: nextItem.id,
        ).catchError((_) {}),
      );
    }
  }

  Future<SessionSummary?> createEmptySession({String? title}) async {
    final project = _project;
    if (project == null) {
      return null;
    }

    final created = await _chatService.createSession(
      profile: profile,
      project: project,
      title: title?.trim().isEmpty == false ? title!.trim() : null,
    );
    _replaceSession(created);
    _selectedSessionId = created.id;
    _messages = const <ChatMessage>[];
    _sessionLoading = false;
    _showingCachedSessionMessages = false;
    _sessionLoadError = null;
    _replaceSelectedSessionTodos(const <TodoItem>[]);
    _statuses = <String, SessionStatusSummary>{
      ..._statuses,
      created.id:
          _statuses[created.id] ?? const SessionStatusSummary(type: 'idle'),
    };
    _applyDefaultComposerSelection();
    await _persistSessionHint(created.id);
    _notify();
    return created;
  }

  Future<SessionSummary?> renameSelectedSession(String title) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || title.trim().isEmpty) {
      return null;
    }
    final updated = await _sessionActionService.updateSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
      title: title.trim(),
    );
    _replaceSession(updated);
    _actionNotice = 'Renamed session to "${updated.title}".';
    _notify();
    return updated;
  }

  Future<void> replyToQuestion(
    String requestId,
    List<List<String>> answers,
  ) async {
    final project = _project;
    final trimmed = requestId.trim();
    if (project == null || trimmed.isEmpty) {
      return;
    }
    await _requestService.replyToQuestion(
      profile: profile,
      project: project,
      requestId: trimmed,
      answers: answers,
    );
    await _loadPendingRequests();
    _notify();
  }

  Future<void> rejectQuestion(String requestId) async {
    final project = _project;
    final trimmed = requestId.trim();
    if (project == null || trimmed.isEmpty) {
      return;
    }
    await _requestService.rejectQuestion(
      profile: profile,
      project: project,
      requestId: trimmed,
    );
    await _loadPendingRequests();
    _notify();
  }

  Future<void> replyToPermission(String requestId, String reply) async {
    await _replyToPermissionInternal(
      requestId: requestId,
      reply: reply,
      reloadPendingAfter: true,
    );
  }

  Future<bool> togglePermissionAutoAcceptForSession(String? sessionId) async {
    final project = _project;
    if (project == null) {
      return false;
    }
    final normalizedSessionId = sessionId?.trim();
    final targetKey = normalizedSessionId == null || normalizedSessionId.isEmpty
        ? _permissionAutoAcceptProjectScopeKey
        : normalizedSessionId;
    final currentlyEnabled =
        normalizedSessionId == null || normalizedSessionId.isEmpty
        ? projectPermissionAutoAccepting
        : autoAcceptsPermissionForSession(normalizedSessionId);
    final next = Map<String, bool>.from(_permissionAutoAcceptByKey)
      ..[targetKey] = !currentlyEnabled;
    _permissionAutoAcceptByKey = Map<String, bool>.unmodifiable(next);
    await _persistPermissionAutoAccept(project);
    if (!currentlyEnabled) {
      unawaited(_autoRespondPendingPermissions(project));
    }
    _notify();
    return !currentlyEnabled;
  }

  Future<SessionSummary?> forkSelectedSession({String? messageId}) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return null;
    }
    final forked = await _sessionActionService.forkSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
      messageId: messageId,
    );
    _sessions = <SessionSummary>[
      forked,
      ..._sessions.where((session) => session.id != forked.id),
    ];
    _selectedSessionId = forked.id;
    _messages = const <ChatMessage>[];
    await _loadSelectedSessionMessages(
      project: project,
      sessionId: forked.id,
      loadPanels: true,
      persistHint: true,
    );
    _actionNotice = 'Forked session into "${forked.title}".';
    _notify();
    return forked;
  }

  Future<SessionSummary?> revertSelectedSession({
    required String messageId,
    String? partId,
  }) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    final trimmedMessageId = messageId.trim();
    if (project == null || sessionId == null || trimmedMessageId.isEmpty) {
      return null;
    }
    final updated = await _sessionActionService.revertSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
      messageId: trimmedMessageId,
      partId: partId,
    );
    _replaceSession(updated);
    _selectedSessionId = updated.id;
    _messages = const <ChatMessage>[];
    _showingCachedSessionMessages = false;
    _sessionLoadError = null;
    await _loadSelectedSessionMessages(
      project: project,
      sessionId: updated.id,
      loadPanels: true,
      persistHint: true,
    );
    _actionNotice = 'Reverted the session to this message.';
    _notify();
    return updated;
  }

  Future<SessionSummary?> shareSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return null;
    }
    final shared = await _sessionActionService.shareSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    _replaceSession(shared);
    _actionNotice = shared.shareUrl?.trim().isNotEmpty == true
        ? 'Session share link ready.'
        : 'Session share request sent.';
    _notify();
    return shared;
  }

  Future<SessionSummary?> unshareSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return null;
    }
    final updated = await _sessionActionService.unshareSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    _replaceSession(updated);
    _actionNotice = 'Session share link removed.';
    _notify();
    return updated;
  }

  Future<void> summarizeSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    final selectedModel = this.selectedModel;
    if (project == null || sessionId == null || selectedModel == null) {
      return;
    }
    await _sessionActionService.summarizeSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
      providerId: selectedModel.providerId,
      modelId: selectedModel.modelId,
    );
    _actionNotice = 'Session compaction requested.';
    _notify();
  }

  Future<bool> interruptSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null ||
        sessionId == null ||
        _interruptingSession ||
        !selectedSessionInterruptible) {
      return false;
    }

    _interruptingSession = true;
    _notify();

    var interrupted = false;
    try {
      interrupted = await _sessionActionService.abortSession(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
      if (interrupted) {
        _statuses = <String, SessionStatusSummary>{
          ..._statuses,
          sessionId: const SessionStatusSummary(type: 'idle'),
        };
        _actionNotice = 'Interrupt requested.';
      }
      _notify();
      return interrupted;
    } finally {
      if (!interrupted) {
        _interruptingSession = false;
      }
      _notify();
    }
  }

  Future<SessionSummary?> deleteSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return null;
    }
    final removedSessionIds = _sessionTreeIds(sessionId).toSet();
    await _sessionActionService.deleteSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    _sessions = _sessions
        .where((session) => !removedSessionIds.contains(session.id))
        .toList(growable: false);
    for (final removedSessionId in removedSessionIds) {
      _clearQueuedPromptStateForSession(removedSessionId);
    }
    _selectedSessionId = _sessions.isEmpty ? null : _sessions.first.id;
    if (_selectedSessionId == null) {
      _messages = const <ChatMessage>[];
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
      for (final removedSessionId in removedSessionIds) {
        await _cacheStore.remove(
          _sessionMessagesCacheKey(project, removedSessionId),
        );
      }
      await _projectStore.saveLastWorkspace(
        serverStorageKey: profile.storageKey,
        target: project.copyWith(clearLastSession: true),
      );
      await _loadSessionPanels();
    } else {
      _messages = const <ChatMessage>[];
      _showingCachedSessionMessages = false;
      for (final removedSessionId in removedSessionIds) {
        await _cacheStore.remove(
          _sessionMessagesCacheKey(project, removedSessionId),
        );
      }
      await _loadSelectedSessionMessages(
        project: project,
        sessionId: _selectedSessionId!,
        loadPanels: true,
        persistHint: true,
      );
    }
    _actionNotice = 'Session deleted.';
    _notify();
    return selectedSession;
  }

  Future<void> runTerminalCommand(String command) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || command.trim().isEmpty) {
      return;
    }
    _runningTerminal = true;
    _terminalOpen = true;
    _notify();
    try {
      _lastShellResult = await _terminalService.runShellCommand(
        profile: profile,
        project: project,
        sessionId: sessionId,
        command: command.trim(),
      );
      try {
        _messages = await _chatService.fetchMessages(
          profile: profile,
          project: project,
          sessionId: sessionId,
        );
        _showingCachedSessionMessages = false;
        _sessionLoadError = null;
        unawaited(
          _saveSessionMessagesCache(
            project: project,
            sessionId: sessionId,
            messages: _messages,
          ),
        );
      } catch (error) {
        _sessionLoadError = _describeSessionLoadError(error);
      }
    } finally {
      _runningTerminal = false;
      _notify();
    }
  }

  void setSideTab(WorkspaceSideTab value) {
    if (_sideTab == value) {
      return;
    }
    _sideTab = value;
    _notify();
  }

  void setTerminalOpen(bool value) {
    if (_terminalOpen == value) {
      return;
    }
    _terminalOpen = value;
    _notify();
  }

  void clearActionNotice() {
    if (_actionNotice == null) {
      return;
    }
    _actionNotice = null;
    _notify();
  }

  void clearTodos() {
    clearTodosForSession(_selectedSessionId);
  }

  void clearTodosForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return;
    }
    final hadSelectedTodos =
        normalizedSessionId == _selectedSessionId && _todos.isNotEmpty;
    final hadCachedTodos =
        (_todosBySessionId[normalizedSessionId] ?? const <TodoItem>[])
            .isNotEmpty;
    if (!hadSelectedTodos && !hadCachedTodos) {
      return;
    }
    final nextTodosBySessionId = Map<String, List<TodoItem>>.from(
      _todosBySessionId,
    )..remove(normalizedSessionId);
    _todosBySessionId = Map<String, List<TodoItem>>.unmodifiable(
      nextTodosBySessionId,
    );
    if (normalizedSessionId == _selectedSessionId) {
      _replaceSelectedSessionTodos(const <TodoItem>[]);
    }
    _notify();
  }

  void _replaceSelectedSessionTodos(List<TodoItem> todos) {
    final immutableTodos = List<TodoItem>.unmodifiable(todos);
    _todos = immutableTodos;
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null || selectedSessionId.isEmpty) {
      return;
    }
    final nextTodosBySessionId = Map<String, List<TodoItem>>.from(
      _todosBySessionId,
    );
    if (immutableTodos.isEmpty) {
      nextTodosBySessionId.remove(selectedSessionId);
    } else {
      nextTodosBySessionId[selectedSessionId] = immutableTodos;
    }
    _todosBySessionId = Map<String, List<TodoItem>>.unmodifiable(
      nextTodosBySessionId,
    );
  }

  void _removeCachedTodosForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return;
    }
    final nextTodosBySessionId = Map<String, List<TodoItem>>.from(
      _todosBySessionId,
    )..remove(normalizedSessionId);
    _todosBySessionId = Map<String, List<TodoItem>>.unmodifiable(
      nextTodosBySessionId,
    );
  }

  Future<void> _loadComposerState(ProjectTarget project) async {
    ConfigSnapshot? snapshot;
    List<AgentDefinition> agents = const <AgentDefinition>[];
    List<CommandDefinition> commands = const <CommandDefinition>[];

    try {
      snapshot = await _configService.fetch(profile: profile, project: project);
    } catch (_) {
      snapshot = null;
    }

    try {
      agents = await _agentService.fetchAgents(profile: profile);
    } catch (_) {
      agents = const <AgentDefinition>[];
    }

    try {
      commands = await _commandService.fetchCommands(
        profile: profile,
        project: project,
      );
    } catch (_) {
      commands = const <CommandDefinition>[];
    }

    _configSnapshot = snapshot;
    _composerAgents = agents
        .where((agent) => agent.visible)
        .toList(growable: false);
    _composerModels = _buildComposerModelOptions(snapshot);
    _composerCommands = commands.toList(growable: false)
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
    _serverDefaultModelKey = _resolveDefaultComposerModelKey(snapshot);
    _serverDefaultReasoning = _resolveDefaultComposerReasoning(snapshot);

    if (_findAgent(_selectedAgentName) == null) {
      _selectedAgentName = null;
    }
    if (_findModel(_selectedModelKey) == null) {
      _selectedModelKey = null;
    }
    if (!_isReasoningAllowed(_selectedReasoning, _selectedModelKey)) {
      _selectedReasoning = null;
    }
    _applyDefaultComposerSelection();
  }

  void _applyDefaultComposerSelection() {
    final agent = selectedAgent ?? _defaultComposerAgent;
    if (agent != null) {
      _selectedAgentName = agent.name;
    }

    final preferredModelKey = agent?.modelKey.isNotEmpty == true
        ? agent!.modelKey
        : null;
    if (_findModel(_selectedModelKey) == null) {
      _selectedModelKey =
          _findModel(preferredModelKey)?.key ??
          _findModel(_serverDefaultModelKey)?.key ??
          (_composerModels.isEmpty ? null : _composerModels.first.key);
    }

    if (!_isReasoningAllowed(_selectedReasoning, _selectedModelKey)) {
      _selectedReasoning = _fallbackReasoningForModel(_selectedModelKey);
    }
  }

  void _ensureDerivedMessageState() {
    final currentMessages = messages;
    final configSnapshot = this.configSnapshot;
    final revertMessageId = selectedSession?.revertMessageId;
    if (identical(_derivedMessagesRef, currentMessages) &&
        identical(_derivedConfigSnapshotRef, configSnapshot) &&
        _derivedRevertMessageId == revertMessageId) {
      return;
    }

    final providerCatalog = configSnapshot?.providerCatalog;
    _derivedMessagesRef = currentMessages;
    _derivedConfigSnapshotRef = configSnapshot;
    _derivedRevertMessageId = revertMessageId;
    _orderedMessagesCache = _orderedTimelineMessages(currentMessages);
    _timelineContentSignatureCache = _computeTimelineContentSignature(
      _orderedMessagesCache,
    );
    _sessionContextMetricsCache = getSessionContextMetrics(
      messages: currentMessages,
      providerCatalog: providerCatalog,
    );
    _sessionSystemPromptCache = resolveSessionSystemPrompt(
      messages: currentMessages,
      revertMessageId: revertMessageId,
    );
    final snapshot = _sessionContextMetricsCache.context;
    _sessionContextBreakdownCache = snapshot == null
        ? const <SessionContextBreakdownSegment>[]
        : estimateSessionContextBreakdown(
            messages: currentMessages,
            inputTokens: snapshot.inputTokens,
            systemPrompt: _sessionSystemPromptCache,
          );
    var userCount = 0;
    var assistantCount = 0;
    for (final message in currentMessages) {
      switch (message.info.role) {
        case 'user':
          userCount += 1;
        case 'assistant':
          assistantCount += 1;
      }
    }
    _userMessageCountCache = userCount;
    _assistantMessageCountCache = assistantCount;
  }

  void _restoreComposerSelectionFromMessages() {
    ChatMessage? lastUser;
    for (final message in _messages.reversed) {
      if (message.info.role == 'user') {
        lastUser = message;
        break;
      }
    }

    if (lastUser == null) {
      _applyDefaultComposerSelection();
      return;
    }

    final agent = _findAgent(lastUser.info.agent) ?? _defaultComposerAgent;
    if (agent != null) {
      _selectedAgentName = agent.name;
    }

    final messageModelKey = _normalizeModelKey(
      providerId: lastUser.info.providerId,
      modelId: lastUser.info.modelId,
    );
    _selectedModelKey =
        _findModel(messageModelKey)?.key ??
        _findModel(agent?.modelKey)?.key ??
        _findModel(_serverDefaultModelKey)?.key ??
        (_composerModels.isEmpty ? null : _composerModels.first.key);

    final messageVariant = lastUser.info.variant?.trim();
    if (_isReasoningAllowed(messageVariant, _selectedModelKey)) {
      _selectedReasoning = messageVariant;
    } else {
      _selectedReasoning = _fallbackReasoningForModel(_selectedModelKey);
    }
  }

  List<WorkspaceComposerModelOption> _buildComposerModelOptions(
    ConfigSnapshot? snapshot,
  ) {
    if (snapshot == null) {
      return const <WorkspaceComposerModelOption>[];
    }

    final options = <String, WorkspaceComposerModelOption>{};
    final catalog = snapshot.providerCatalog;
    for (final provider in catalog.providers) {
      final models = provider.models.values.toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));
      for (final model in models) {
        final key = '${provider.id}/${model.id}';
        options[key] = WorkspaceComposerModelOption(
          key: key,
          providerId: provider.id,
          providerName: provider.name,
          modelId: model.id,
          name: model.name,
          reasoningValues: List<String>.unmodifiable(model.reasoningVariants),
        );
      }
    }
    final values = options.values.toList(growable: false)
      ..sort((left, right) {
        final providerCompare = left.providerName.toLowerCase().compareTo(
          right.providerName.toLowerCase(),
        );
        if (providerCompare != 0) {
          return providerCompare;
        }
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return values;
  }

  String? _resolveDefaultComposerModelKey(ConfigSnapshot? snapshot) {
    if (snapshot == null) {
      return _composerModels.isEmpty ? null : _composerModels.first.key;
    }

    final configuredModel = snapshot.config
        .toJson()['model']
        ?.toString()
        .trim();
    if (configuredModel != null && configuredModel.isNotEmpty) {
      final matched = _findModel(configuredModel);
      if (matched != null) {
        return matched.key;
      }
    }

    final defaults = snapshot.providerCatalog.defaults;
    for (final option in _composerModels) {
      if (defaults[option.providerId] == option.modelId) {
        return option.key;
      }
    }

    return _composerModels.isEmpty ? null : _composerModels.first.key;
  }

  String? _resolveDefaultComposerReasoning(ConfigSnapshot? snapshot) {
    final config = snapshot?.config.toJson();
    final variant = config?['variant']?.toString().trim();
    if (variant != null && variant.isNotEmpty) {
      return variant;
    }
    final reasoning = config?['reasoning']?.toString().trim();
    if (reasoning != null && reasoning.isNotEmpty) {
      return reasoning;
    }
    return null;
  }

  AgentDefinition? get _defaultComposerAgent {
    if (_composerAgents.isEmpty) {
      return null;
    }
    return _composerAgents.first;
  }

  WorkspaceComposerModelOption? get _defaultComposerModel {
    final key = _serverDefaultModelKey;
    return key == null ? null : _findModel(key);
  }

  AgentDefinition? _findAgent(String? name) {
    final normalized = name?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final agent in _composerAgents) {
      if (agent.name == normalized) {
        return agent;
      }
    }
    return null;
  }

  WorkspaceComposerModelOption? _findModel(String? key) {
    final normalized = key?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final option in _composerModels) {
      if (option.key == normalized ||
          option.modelId == normalized ||
          '${option.providerId}/${option.modelId}' == normalized) {
        return option;
      }
    }
    return null;
  }

  CommandDefinition? _findComposerCommand(String? name) {
    final normalized = name?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final command in _composerCommands) {
      if (command.name == normalized) {
        return command;
      }
    }
    return null;
  }

  _SlashCommandInvocation? _parseSlashCommand(String prompt) {
    if (!prompt.startsWith('/')) {
      return null;
    }
    final firstLineEnd = prompt.indexOf('\n');
    final firstLine = firstLineEnd == -1
        ? prompt
        : prompt.substring(0, firstLineEnd);
    if (!firstLine.startsWith('/')) {
      return null;
    }
    final token = firstLine.split(RegExp(r'\s+')).first.trim();
    if (token.length <= 1) {
      return null;
    }
    final command = token.substring(1).trim();
    if (command.isEmpty) {
      return null;
    }
    final headArguments = firstLine.substring(token.length).trimLeft();
    final tailArguments = firstLineEnd == -1
        ? ''
        : prompt.substring(firstLineEnd + 1);
    final arguments = <String>[
      if (headArguments.isNotEmpty) headArguments,
      if (tailArguments.isNotEmpty) tailArguments,
    ].join('\n');
    return _SlashCommandInvocation(name: command, arguments: arguments);
  }

  String? _normalizeModelKey({String? providerId, String? modelId}) {
    final normalizedProvider = providerId?.trim();
    final normalizedModel = modelId?.trim();
    if (normalizedProvider == null ||
        normalizedProvider.isEmpty ||
        normalizedModel == null ||
        normalizedModel.isEmpty) {
      return null;
    }
    return '$normalizedProvider/$normalizedModel';
  }

  bool _isReasoningAllowed(String? value, String? modelKey) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return true;
    }
    return _findModel(modelKey)?.reasoningValues.contains(normalized) ?? false;
  }

  String? _resolveReasoningForAgent(AgentDefinition agent) {
    final candidate = agent.variant?.trim();
    if (_isReasoningAllowed(candidate, _selectedModelKey)) {
      return candidate;
    }
    return _fallbackReasoningForModel(_selectedModelKey);
  }

  String? _fallbackReasoningForModel(String? modelKey) {
    final model = _findModel(modelKey);
    if (model == null) {
      return null;
    }

    final agentVariant = selectedAgent?.variant?.trim();
    if (agentVariant != null && model.reasoningValues.contains(agentVariant)) {
      return agentVariant;
    }

    final serverDefaultReasoning = _serverDefaultReasoning?.trim();
    if (serverDefaultReasoning != null &&
        model.reasoningValues.contains(serverDefaultReasoning)) {
      return serverDefaultReasoning;
    }

    return null;
  }

  Future<void> _loadProjectPanels() async {
    final project = _project;
    if (project == null) {
      return;
    }
    try {
      _fileBundle = await _fileBrowserService.fetchBundle(
        profile: profile,
        project: project,
      );
      _loadingFilePreview = false;
      _loadingFileDirectoryPath = null;
      _loadedFileDirectories = <String>{};
      _expandedFileDirectories = _fileBundle?.selectedPath == null
          ? <String>{}
          : _ancestorDirectories(_fileBundle!.selectedPath!);
      _reviewBundle = null;
      _selectedReviewPath = null;
      _reviewDiff = null;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
    } catch (_) {
      _fileBundle = null;
      _loadingFilePreview = false;
      _loadingFileDirectoryPath = null;
      _expandedFileDirectories = <String>{};
      _loadedFileDirectories = <String>{};
      _reviewBundle = null;
      _selectedReviewPath = null;
      _reviewDiff = null;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
    }
    await _loadSessionPanels();
  }

  Future<void> _loadSessionPanels() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null) {
      _reviewBundle = null;
      _selectedReviewPath = null;
      _reviewDiff = null;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
      _replaceSelectedSessionTodos(const <TodoItem>[]);
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
      return;
    }

    if (sessionId == null || sessionId.isEmpty) {
      _reviewBundle = null;
      _selectedReviewPath = null;
      _reviewDiff = null;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
      _replaceSelectedSessionTodos(const <TodoItem>[]);
    } else {
      final todoFuture = _todoService
          .fetchTodos(profile: profile, project: project, sessionId: sessionId)
          .then<Object?>((value) => value)
          .catchError((_) => const <TodoItem>[]);
      final reviewFuture = _reviewDiffService
          .fetchSessionDiffs(profile: profile, sessionId: sessionId)
          .then<Object?>((value) => value)
          .catchError((_) => null);
      _loadingReviewDiff = true;
      try {
        final results = await Future.wait<Object?>(<Future<Object?>>[
          todoFuture,
          reviewFuture,
        ]);
        if (_disposed || _selectedSessionId != sessionId) {
          return;
        }
        _replaceSelectedSessionTodos(
          (results[0] as List<TodoItem>?) ?? const <TodoItem>[],
        );
        final reviewBundle = results[1] as ReviewSessionDiffBundle?;
        if (reviewBundle == null) {
          _reviewBundle = null;
          _selectedReviewPath = null;
          _reviewDiff = null;
          _reviewDiffError = 'Couldn\'t load the review diff.';
        } else {
          _applyReviewBundle(reviewBundle);
        }
      } finally {
        if (!_disposed && _selectedSessionId == sessionId) {
          _loadingReviewDiff = false;
        }
      }
    }

    await _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    final project = _project;
    if (project == null) {
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
      return;
    }
    try {
      final pending = await _requestService.fetchPending(
        profile: profile,
        project: project,
      );
      _pendingRequests = await _resolvePendingRequestsWithAutoAccept(
        project: project,
        pending: pending,
      );
    } catch (_) {
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
    }
  }

  Future<PendingRequestBundle> _resolvePendingRequestsWithAutoAccept({
    required ProjectTarget project,
    required PendingRequestBundle pending,
  }) async {
    if (pending.permissions.isEmpty) {
      return pending;
    }
    final remainingPermissions = <PermissionRequestSummary>[];
    for (final request in pending.permissions) {
      if (!_shouldAutoAcceptPermission(request)) {
        remainingPermissions.add(request);
        continue;
      }
      final responded = await _replyToPermissionInternal(
        requestId: request.id,
        reply: 'once',
        reloadPendingAfter: false,
        request: request,
      );
      if (!responded) {
        remainingPermissions.add(request);
      }
    }
    return PendingRequestBundle(
      questions: pending.questions,
      permissions: remainingPermissions,
    );
  }

  Future<void> _restorePermissionAutoAccept(ProjectTarget project) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _permissionAutoAcceptStorageKey(profile, project),
    );
    if (raw == null || raw.trim().isEmpty) {
      _permissionAutoAcceptByKey = const <String, bool>{};
      return;
    }
    try {
      final decoded = await _decodeJsonPayload(raw);
      _permissionAutoAcceptByKey = _permissionAutoAcceptFromDecodedJson(
        decoded,
      );
    } catch (_) {
      _permissionAutoAcceptByKey = const <String, bool>{};
      await prefs.remove(_permissionAutoAcceptStorageKey(profile, project));
    }
  }

  Future<void> _persistPermissionAutoAccept(ProjectTarget project) async {
    final prefs = await SharedPreferences.getInstance();
    if (_permissionAutoAcceptByKey.isEmpty) {
      await prefs.remove(_permissionAutoAcceptStorageKey(profile, project));
      return;
    }
    await prefs.setString(
      _permissionAutoAcceptStorageKey(profile, project),
      jsonEncode(_permissionAutoAcceptByKey),
    );
  }

  List<String> _sessionLineageIds(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return const <String>[];
    }
    final ids = <String>[normalizedSessionId];
    final seen = <String>{normalizedSessionId};
    var currentId = normalizedSessionId;
    while (true) {
      final session = _sessionById(currentId);
      final parentId = session?.parentId?.trim();
      if (parentId == null || parentId.isEmpty || !seen.add(parentId)) {
        break;
      }
      ids.add(parentId);
      currentId = parentId;
    }
    return ids;
  }

  bool _shouldAutoAcceptPermission(PermissionRequestSummary request) {
    return autoAcceptsPermissionForSession(request.sessionId);
  }

  void _optimisticallyResolvePermissionRequest(String requestId) {
    _pendingRequests = PendingRequestBundle(
      questions: _pendingRequests.questions,
      permissions: applyPermissionResolvedEvent(
        _pendingRequests.permissions,
        <String, Object?>{'requestID': requestId},
        selectedSessionId: null,
      ),
    );
  }

  Future<void> _autoRespondPendingPermissions(ProjectTarget project) async {
    final requests = _pendingRequests.permissions
        .where(_shouldAutoAcceptPermission)
        .toList(growable: false);
    if (requests.isEmpty) {
      return;
    }
    for (final request in requests) {
      await _replyToPermissionInternal(
        requestId: request.id,
        reply: 'once',
        reloadPendingAfter: false,
        request: request,
      );
    }
    if (!_disposed && _project?.directory == project.directory) {
      await _loadPendingRequests();
      _notify();
    }
  }

  Future<bool> _replyToPermissionInternal({
    required String requestId,
    required String reply,
    required bool reloadPendingAfter,
    PermissionRequestSummary? request,
  }) async {
    final project = _project;
    final trimmedRequestId = requestId.trim();
    final normalizedReply = reply.trim();
    if (project == null ||
        trimmedRequestId.isEmpty ||
        normalizedReply.isEmpty ||
        _respondingPermissionRequestIds.contains(trimmedRequestId)) {
      return false;
    }
    final nextResponding = Set<String>.from(_respondingPermissionRequestIds)
      ..add(trimmedRequestId);
    _respondingPermissionRequestIds = Set<String>.unmodifiable(nextResponding);
    _optimisticallyResolvePermissionRequest(trimmedRequestId);
    _notify();
    try {
      await _requestService.replyToPermission(
        profile: profile,
        project: project,
        requestId: trimmedRequestId,
        reply: normalizedReply,
      );
      if (reloadPendingAfter) {
        await _loadPendingRequests();
      }
      return true;
    } catch (_) {
      if (reloadPendingAfter) {
        await _loadPendingRequests();
      } else if (request != null) {
        _pendingRequests = PendingRequestBundle(
          questions: _pendingRequests.questions,
          permissions: List<PermissionRequestSummary>.unmodifiable(
            <PermissionRequestSummary>[
              ..._pendingRequests.permissions,
              request,
            ],
          ),
        );
      }
      return false;
    } finally {
      final next = Set<String>.from(_respondingPermissionRequestIds)
        ..remove(trimmedRequestId);
      _respondingPermissionRequestIds = Set<String>.unmodifiable(next);
      _notify();
    }
  }

  Future<void> _connectEvents() async {
    final project = _project;
    if (project == null) {
      return;
    }
    try {
      await _eventStreamService.connect(
        profile: profile,
        project: project,
        onEvent: _handleEvent,
        onError: (_, _) {},
      );
    } catch (_) {
      // Best-effort parity path: fall back to manual refresh flows.
    }
  }

  void _handleEvent(EventEnvelope event) {
    if (_disposed) {
      return;
    }
    final type = event.type;
    if (type == 'session.created' || type == 'session.updated') {
      _sessions = applySessionUpsertEvent(_sessions, event.properties);
    } else if (type == 'session.deleted') {
      final removedSessionId =
          event.properties['sessionID']?.toString() ??
          (event.properties['info'] as Map?)?['id']?.toString();
      _sessions = applySessionDeletedEvent(_sessions, event.properties);
      _statuses = removeSessionStatusEvent(_statuses, event.properties);
      if (removedSessionId != null && removedSessionId.isNotEmpty) {
        final nextWatchedIds = Set<String>.from(_watchedSessionIds)
          ..remove(removedSessionId);
        _watchedSessionIds = Set<String>.unmodifiable(nextWatchedIds);
        final nextTimelineById =
            Map<String, WorkspaceSessionTimelineState>.from(
              _watchedSessionTimelineById,
            )..remove(removedSessionId);
        _watchedSessionTimelineById =
            Map<String, WorkspaceSessionTimelineState>.unmodifiable(
              nextTimelineById,
            );
        final nextLoadRevisionById = Map<String, int>.from(
          _watchedSessionLoadRevisionById,
        )..remove(removedSessionId);
        _watchedSessionLoadRevisionById = Map<String, int>.unmodifiable(
          nextLoadRevisionById,
        );
      }
      _removeActiveChildPreviewState(removedSessionId);
      _clearQueuedPromptStateForSession(removedSessionId);
      _removeCachedTodosForSession(removedSessionId);
    } else if (type == 'session.status') {
      _statuses = applySessionStatusEvent(_statuses, event.properties);
      _maybeFlushQueuedPrompts(
        sessionId: event.properties['sessionID']?.toString(),
      );
    } else if (type == 'session.diff') {
      final sessionId = event.properties['sessionID']?.toString();
      if (sessionId == _selectedSessionId) {
        _applyReviewBundle(
          ReviewSessionDiffBundle.fromPayload(event.properties['diff']),
        );
        _loadingReviewDiff = false;
      }
    } else if (type == 'message.updated') {
      final infoJson = event.properties['info'] as Map?;
      _applyWatchedSessionTimelineEvent(
        event.properties,
        sessionId: infoJson?['sessionID']?.toString(),
        applyEvent: (messages) => applyMessageUpdatedEvent(
          messages,
          event.properties,
          selectedSessionId: infoJson?['sessionID']?.toString(),
        ),
        persistImmediately: true,
      );
      final project = _project;
      final sessionId = _selectedSessionId;
      final baseMessages =
          project != null && sessionId != null && sessionId.isNotEmpty
          ? _stripOptimisticMessages(
              project: project,
              sessionId: sessionId,
              messages: _messages,
            )
          : _messages;
      final nextServerMessages = applyMessageUpdatedEvent(
        baseMessages,
        event.properties,
        selectedSessionId: _selectedSessionId,
      );
      final nextMessages =
          project != null && sessionId != null && sessionId.isNotEmpty
          ? _mergeSessionMessages(
              project: project,
              sessionId: sessionId,
              serverMessages: nextServerMessages,
            )
          : nextServerMessages;
      if (!identical(nextMessages, _messages)) {
        _sessionLoading = false;
        _showingCachedSessionMessages = false;
        _sessionLoadError = null;
        unawaited(
          _persistSelectedSessionMessagesCache(
            nextServerMessages,
            immediate: true,
          ),
        );
      }
      _messages = nextMessages;
    } else if (type == 'message.part.updated') {
      _applyActiveChildLivePreviewPartEvent(event.properties);
      final partJson = event.properties['part'] as Map?;
      _applyWatchedSessionTimelineEvent(
        event.properties,
        sessionId: partJson?['sessionID']?.toString(),
        applyEvent: (messages) => applyMessagePartUpdatedEvent(
          messages,
          event.properties,
          selectedSessionId: partJson?['sessionID']?.toString(),
        ),
      );
      final project = _project;
      final sessionId = _selectedSessionId;
      final baseMessages =
          project != null && sessionId != null && sessionId.isNotEmpty
          ? _stripOptimisticMessages(
              project: project,
              sessionId: sessionId,
              messages: _messages,
            )
          : _messages;
      final nextServerMessages = applyMessagePartUpdatedEvent(
        baseMessages,
        event.properties,
        selectedSessionId: _selectedSessionId,
      );
      final nextMessages =
          project != null && sessionId != null && sessionId.isNotEmpty
          ? _mergeSessionMessages(
              project: project,
              sessionId: sessionId,
              serverMessages: nextServerMessages,
            )
          : nextServerMessages;
      if (!identical(nextMessages, _messages)) {
        _sessionLoading = false;
        _showingCachedSessionMessages = false;
        _sessionLoadError = null;
        unawaited(_persistSelectedSessionMessagesCache(nextServerMessages));
      }
      _messages = nextMessages;
    } else if (type == 'message.removed') {
      _clearActiveChildLivePreviewForMessageEvent(event.properties);
      _applyWatchedSessionTimelineEvent(
        event.properties,
        sessionId: event.properties['sessionID']?.toString(),
        applyEvent: (messages) => applyMessageRemovedEvent(
          messages,
          event.properties,
          selectedSessionId: event.properties['sessionID']?.toString(),
        ),
        persistImmediately: true,
      );
      final project = _project;
      final sessionId = _selectedSessionId;
      final baseMessages =
          project != null && sessionId != null && sessionId.isNotEmpty
          ? _stripOptimisticMessages(
              project: project,
              sessionId: sessionId,
              messages: _messages,
            )
          : _messages;
      final nextServerMessages = applyMessageRemovedEvent(
        baseMessages,
        event.properties,
        selectedSessionId: _selectedSessionId,
      );
      final nextMessages =
          project != null && sessionId != null && sessionId.isNotEmpty
          ? _mergeSessionMessages(
              project: project,
              sessionId: sessionId,
              serverMessages: nextServerMessages,
            )
          : nextServerMessages;
      if (!identical(nextMessages, _messages)) {
        _sessionLoading = false;
        _showingCachedSessionMessages = false;
        _sessionLoadError = null;
        unawaited(
          _persistSelectedSessionMessagesCache(
            nextServerMessages,
            immediate: true,
          ),
        );
      }
      _messages = nextMessages;
    } else if (type == 'todo.updated') {
      _replaceSelectedSessionTodos(
        applyTodoUpdatedEvent(
          _todos,
          event.properties,
          selectedSessionId: _selectedSessionId,
        ),
      );
    } else if (type == 'question.asked') {
      _pendingRequests = PendingRequestBundle(
        questions: applyQuestionAskedEvent(
          _pendingRequests.questions,
          event.properties,
          selectedSessionId: null,
        ),
        permissions: _pendingRequests.permissions,
      );
    } else if (type == 'question.replied' || type == 'question.rejected') {
      _pendingRequests = PendingRequestBundle(
        questions: applyQuestionResolvedEvent(
          _pendingRequests.questions,
          event.properties,
          selectedSessionId: null,
        ),
        permissions: _pendingRequests.permissions,
      );
    } else if (type == 'permission.asked') {
      _pendingRequests = PendingRequestBundle(
        questions: _pendingRequests.questions,
        permissions: applyPermissionAskedEvent(
          _pendingRequests.permissions,
          event.properties,
          selectedSessionId: null,
        ),
      );
      final request = PermissionRequestSummary.fromJson(event.properties);
      if (_shouldAutoAcceptPermission(request)) {
        unawaited(
          _replyToPermissionInternal(
            requestId: request.id,
            reply: 'once',
            reloadPendingAfter: false,
            request: request,
          ),
        );
      }
    } else if (type == 'permission.replied' || type == 'permission.rejected') {
      _pendingRequests = PendingRequestBundle(
        questions: _pendingRequests.questions,
        permissions: applyPermissionResolvedEvent(
          _pendingRequests.permissions,
          event.properties,
          selectedSessionId: null,
        ),
      );
    } else if (type == 'project.updated') {
      final nextProject = _projectTargetFromEvent(event.properties);
      if (nextProject == null) {
        return;
      }
      applyProjectTargetUpdate(nextProject, notify: false);
    } else {
      return;
    }
    _notify();
  }

  void applyProjectTargetUpdate(ProjectTarget target, {bool notify = true}) {
    _hiddenProjectDirectories = _hiddenProjectDirectories
        .where((directory) => directory != target.directory)
        .toSet();
    if (target.directory == directory) {
      _project = target;
    }
    _availableProjects = _availableProjects
        .map(
          (project) => project.directory == target.directory ? target : project,
        )
        .toList(growable: false);
    final exists = _availableProjects.any(
      (project) => project.directory == target.directory,
    );
    if (!exists && !_hiddenProjectDirectories.contains(target.directory)) {
      _availableProjects = <ProjectTarget>[
        target,
        ..._availableProjects,
      ].toList(growable: false);
    }
    if (notify) {
      _notify();
    }
  }

  void applyProjectRemoval(String directory, {bool notify = true}) {
    _hiddenProjectDirectories = <String>{
      ..._hiddenProjectDirectories,
      directory,
    };
    _availableProjects = _availableProjects
        .where((project) => project.directory != directory)
        .toList(growable: false);
    if (notify) {
      _notify();
    }
  }

  void applyProjectOrder(
    List<ProjectTarget> orderedProjects, {
    bool notify = true,
  }) {
    if (_availableProjects.length <= 1 || orderedProjects.isEmpty) {
      return;
    }

    final rankByDirectory = <String, int>{
      for (var index = 0; index < orderedProjects.length; index += 1)
        orderedProjects[index].directory: index,
    };
    final replacementByDirectory = <String, ProjectTarget>{
      for (final project in orderedProjects) project.directory: project,
    };
    final originalIndexByDirectory = <String, int>{
      for (var index = 0; index < _availableProjects.length; index += 1)
        _availableProjects[index].directory: index,
    };

    ProjectTarget mergeProject(ProjectTarget current) {
      final replacement = replacementByDirectory[current.directory];
      if (replacement == null) {
        return current;
      }
      return current.copyWith(
        label: replacement.label,
        id: replacement.id,
        name: replacement.name,
        source: replacement.source,
        vcs: replacement.vcs,
        branch: replacement.branch,
        icon: replacement.icon,
        commands: replacement.commands,
        lastSession: current.lastSession ?? replacement.lastSession,
        clearId: replacement.id == null,
        clearName: replacement.name == null,
        clearIcon: replacement.icon == null,
        clearCommands: replacement.commands == null,
        clearLastSession:
            replacement.lastSession == null && current.lastSession == null,
      );
    }

    final nextProjects = _availableProjects
        .map(mergeProject)
        .toList(growable: false);
    nextProjects.sort((left, right) {
      final leftRank = rankByDirectory[left.directory];
      final rightRank = rankByDirectory[right.directory];
      if (leftRank != null && rightRank != null) {
        return leftRank.compareTo(rightRank);
      }
      if (leftRank != null) {
        return -1;
      }
      if (rightRank != null) {
        return 1;
      }
      return (originalIndexByDirectory[left.directory] ?? 0).compareTo(
        originalIndexByDirectory[right.directory] ?? 0,
      );
    });

    _availableProjects = List<ProjectTarget>.unmodifiable(nextProjects);
    final currentProject = _project;
    if (currentProject != null) {
      _project = nextProjects.cast<ProjectTarget?>().firstWhere(
        (project) => project?.directory == currentProject.directory,
        orElse: () => currentProject,
      );
    }
    if (notify) {
      _notify();
    }
  }

  T? _sessionTreeRequestForSession<T>(
    String? sessionId,
    List<T> requests,
    String Function(T request) sessionIdOf,
  ) {
    final rootSessionId = sessionId?.trim();
    if (rootSessionId == null || rootSessionId.isEmpty || requests.isEmpty) {
      return null;
    }

    final ids = _sessionTreeIds(rootSessionId);
    for (final sessionId in ids) {
      for (final request in requests) {
        if (sessionIdOf(request) == sessionId) {
          return request;
        }
      }
    }
    return null;
  }

  SessionSummary? _rootSessionForId(String? sessionId) {
    final session = _sessionById(sessionId);
    if (session == null) {
      return null;
    }

    var current = session;
    final seen = <String>{current.id};
    while (current.parentId != null && current.parentId!.isNotEmpty) {
      final parent = _sessionById(current.parentId);
      if (parent == null || !seen.add(parent.id)) {
        break;
      }
      current = parent;
    }
    return current;
  }

  SessionSummary? _sessionById(String? sessionId) {
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

  List<String> _sessionTreeIds(String rootSessionId) {
    final childrenByParent = <String, List<String>>{};
    for (final session in sessions) {
      final parentId = session.parentId;
      if (parentId == null || parentId.isEmpty) {
        continue;
      }
      final children = childrenByParent.putIfAbsent(parentId, () => <String>[]);
      children.add(session.id);
    }

    final seen = <String>{rootSessionId};
    final ids = <String>[rootSessionId];
    for (var index = 0; index < ids.length; index += 1) {
      final sessionId = ids[index];
      final children = childrenByParent[sessionId];
      if (children == null) {
        continue;
      }
      for (final childId in children) {
        if (seen.add(childId)) {
          ids.add(childId);
        }
      }
    }
    return ids;
  }

  bool _isActiveStatus(SessionStatusSummary? status) {
    return (status?.type.trim().toLowerCase() ?? 'idle') != 'idle';
  }

  bool _isSessionBusyById(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    if (_sendingQueuedPromptBySessionId.containsKey(normalized)) {
      return true;
    }
    if (_submittingPrompt && _selectedSessionId == normalized) {
      return true;
    }
    return _isActiveStatus(_statuses[normalized]);
  }

  void _markSessionBusy(String sessionId) {
    final existing = _statuses[sessionId];
    if (_isActiveStatus(existing)) {
      return;
    }
    _statuses = <String, SessionStatusSummary>{
      ..._statuses,
      sessionId: const SessionStatusSummary(type: 'busy'),
    };
    _notify();
  }

  ProjectTarget? _matchProject(List<ProjectTarget> projects, String directory) {
    for (final project in projects) {
      if (project.directory == directory) {
        return project;
      }
    }
    return null;
  }

  List<ProjectTarget> _mergeProjects(
    ProjectCatalog catalog,
    List<ProjectTarget> recentProjects, {
    required Set<String> hiddenProjects,
  }) {
    final byDirectory = <String, ProjectTarget>{};

    void add(ProjectTarget target) {
      if (target.directory != directory &&
          hiddenProjects.contains(target.directory)) {
        return;
      }
      final existing = byDirectory[target.directory];
      byDirectory[target.directory] = existing == null
          ? target
          : ProjectTarget(
              directory: target.directory,
              label: existing.label.isNotEmpty ? existing.label : target.label,
              id: target.id ?? existing.id,
              name: target.name ?? existing.name,
              source: target.source ?? existing.source,
              vcs: target.vcs ?? existing.vcs,
              branch: target.branch ?? existing.branch,
              icon: target.icon ?? existing.icon,
              commands: target.commands ?? existing.commands,
              lastSession: existing.lastSession ?? target.lastSession,
            );
    }

    ProjectTarget toTarget(ProjectSummary project, {required String source}) {
      return ProjectTarget(
        id: project.id,
        directory: project.directory,
        label: project.title,
        name: project.name,
        source: source,
        vcs: project.vcs,
        branch: catalog.vcsInfo?.branch,
        icon: project.icon,
        commands: project.commands,
      );
    }

    if (catalog.currentProject != null) {
      add(toTarget(catalog.currentProject!, source: 'current'));
    }
    for (final item in catalog.projects) {
      add(toTarget(item, source: 'server'));
    }
    for (final item in recentProjects) {
      add(item);
    }

    final values = byDirectory.values.toList(growable: false);
    values.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return values;
  }

  String? _resolveSessionSelection({
    required String? requestedSessionId,
    required String? bundleSelectedSessionId,
    required ProjectTarget project,
    required List<SessionSummary> sessions,
  }) {
    bool exists(String? sessionId) {
      if (sessionId == null || sessionId.isEmpty) {
        return false;
      }
      return sessions.any(
        (session) => session.id == sessionId && session.archivedAt == null,
      );
    }

    if (exists(requestedSessionId)) {
      return requestedSessionId;
    }
    if (exists(bundleSelectedSessionId)) {
      return bundleSelectedSessionId;
    }
    return _sessionIdHintForProject(project, sessions);
  }

  String? _sessionIdHintForProject(
    ProjectTarget project,
    List<SessionSummary> sessions,
  ) {
    final activeSessions = sessions
        .where((session) => session.archivedAt == null)
        .toList(growable: false);
    final visibleSessions = _visibleRootSessions(sessions);
    final hintId = project.lastSession?.id?.trim();
    if (hintId != null && hintId.isNotEmpty) {
      for (final session in activeSessions) {
        if (session.id == hintId) {
          return session.id;
        }
      }
    }
    final hint = project.lastSession?.title?.trim();
    if (hint == null || hint.isEmpty) {
      if (visibleSessions.isNotEmpty) {
        return visibleSessions.first.id;
      }
      return activeSessions.isEmpty ? null : activeSessions.first.id;
    }
    for (final session in activeSessions) {
      if (session.title.trim() == hint) {
        return session.id;
      }
    }
    if (visibleSessions.isNotEmpty) {
      return visibleSessions.first.id;
    }
    return activeSessions.isEmpty ? null : activeSessions.first.id;
  }

  List<SessionSummary> _visibleRootSessions(List<SessionSummary> sessions) {
    return sessions
        .where(
          (session) => session.parentId == null && (session.archivedAt == null),
        )
        .toList(growable: false);
  }

  Future<void> _persistSessionHint(String sessionId) async {
    final project = _project;
    if (project == null) {
      return;
    }
    final session = selectedSession;
    final status = selectedStatus?.type;
    await _projectStore.saveLastWorkspace(
      serverStorageKey: profile.storageKey,
      target: ProjectTarget(
        directory: project.directory,
        label: project.label,
        id: project.id,
        name: project.name,
        source: project.source,
        vcs: project.vcs,
        branch: project.branch,
        icon: project.icon,
        commands: project.commands,
        lastSession: ProjectSessionHint(
          id: sessionId,
          title: session?.title,
          status: status,
        ),
      ),
    );
  }

  String _sessionMessagesCacheKey(ProjectTarget project, String sessionId) {
    return 'workspace.messages::${profile.storageKey}::${project.directory}::$sessionId';
  }

  String _queuedPromptCacheKey(ProjectTarget project) {
    return 'workspace.followups::${profile.storageKey}::${project.directory}';
  }

  String _optimisticSessionKey(ProjectTarget project, String sessionId) {
    return '${project.directory}::$sessionId';
  }

  ChatMessage? _appendOptimisticUserMessage({
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    required List<PromptAttachment> attachments,
  }) {
    if (prompt.trim().isEmpty && attachments.isEmpty) {
      return null;
    }
    final timestamp = DateTime.now();
    final messageId =
        'msg_local_${timestamp.microsecondsSinceEpoch}_${_optimisticMessageSequence++}';
    final parts = <ChatPart>[
      if (prompt.trim().isNotEmpty)
        ChatPart(
          id: '${messageId}_text',
          type: 'text',
          text: prompt.trim(),
          messageId: messageId,
          sessionId: sessionId,
          metadata: <String, Object?>{
            'id': '${messageId}_text',
            'type': 'text',
            'text': prompt.trim(),
            'messageID': messageId,
            'sessionID': sessionId,
          },
        ),
      for (var index = 0; index < attachments.length; index += 1)
        ChatPart(
          id: '${messageId}_file_$index',
          type: 'file',
          filename: attachments[index].filename,
          messageId: messageId,
          sessionId: sessionId,
          metadata: <String, Object?>{
            'id': '${messageId}_file_$index',
            'type': 'file',
            'filename': attachments[index].filename,
            'mime': attachments[index].mime,
            'url': attachments[index].url,
            'messageID': messageId,
            'sessionID': sessionId,
          },
        ),
    ];
    final message = ChatMessage(
      info: ChatMessageInfo(
        id: messageId,
        role: 'user',
        sessionId: sessionId,
        createdAt: timestamp,
        completedAt: timestamp,
        metadata: <String, Object?>{
          'id': messageId,
          'role': 'user',
          'sessionID': sessionId,
          'time': <String, Object?>{
            'created': timestamp.millisecondsSinceEpoch,
            'completed': timestamp.millisecondsSinceEpoch,
          },
          '_optimistic': true,
        },
      ),
      parts: parts,
    );
    final key = _optimisticSessionKey(project, sessionId);
    final optimistic = <ChatMessage>[
      ...?_optimisticMessagesBySessionKey[key],
      message,
    ];
    _optimisticMessagesBySessionKey[key] = optimistic;
    if (_selectedSessionId == sessionId) {
      _messages = _mergeSessionMessages(
        project: project,
        sessionId: sessionId,
        serverMessages: _stripOptimisticMessages(
          project: project,
          sessionId: sessionId,
          messages: _messages,
        ),
      );
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
      _notify();
    } else if (_watchedSessionIds.contains(sessionId)) {
      final currentState =
          _watchedSessionTimelineById[sessionId] ??
          WorkspaceSessionTimelineState.empty(sessionId: sessionId);
      _setWatchedSessionTimeline(
        sessionId,
        _buildTimelineState(
          sessionId: sessionId,
          messages: _mergeSessionMessages(
            project: project,
            sessionId: sessionId,
            serverMessages: _stripOptimisticMessages(
              project: project,
              sessionId: sessionId,
              messages: currentState.messages,
            ),
          ),
          loading: currentState.loading,
          showingCachedMessages: currentState.showingCachedMessages,
          error: currentState.error,
        ),
      );
      _notify();
    }
    return message;
  }

  void _removeOptimisticMessage({
    required ProjectTarget project,
    required String sessionId,
    required String messageId,
  }) {
    final key = _optimisticSessionKey(project, sessionId);
    final optimistic = _optimisticMessagesBySessionKey[key];
    if (optimistic == null || optimistic.isEmpty) {
      return;
    }
    final next = optimistic
        .where((message) => message.info.id != messageId)
        .toList(growable: false);
    if (next.isEmpty) {
      _optimisticMessagesBySessionKey.remove(key);
    } else {
      _optimisticMessagesBySessionKey[key] = next;
    }
    if (_selectedSessionId == sessionId) {
      _messages = _mergeSessionMessages(
        project: project,
        sessionId: sessionId,
        serverMessages: _stripOptimisticMessages(
          project: project,
          sessionId: sessionId,
          messages: _messages,
        ),
      );
      _notify();
    } else if (_watchedSessionIds.contains(sessionId)) {
      final currentState =
          _watchedSessionTimelineById[sessionId] ??
          WorkspaceSessionTimelineState.empty(sessionId: sessionId);
      _setWatchedSessionTimeline(
        sessionId,
        _buildTimelineState(
          sessionId: sessionId,
          messages: _mergeSessionMessages(
            project: project,
            sessionId: sessionId,
            serverMessages: _stripOptimisticMessages(
              project: project,
              sessionId: sessionId,
              messages: currentState.messages,
            ),
          ),
          loading: currentState.loading,
          showingCachedMessages: currentState.showingCachedMessages,
          error: currentState.error,
        ),
      );
      _notify();
    }
  }

  List<ChatMessage> _mergeSessionMessages({
    required ProjectTarget project,
    required String sessionId,
    required List<ChatMessage> serverMessages,
  }) {
    final key = _optimisticSessionKey(project, sessionId);
    final optimistic = _optimisticMessagesBySessionKey[key];
    if (optimistic == null || optimistic.isEmpty) {
      return serverMessages;
    }
    final unresolved = _resolveOptimisticMessages(
      serverMessages: serverMessages,
      optimisticMessages: optimistic,
    );
    if (unresolved.isEmpty) {
      _optimisticMessagesBySessionKey.remove(key);
      return serverMessages;
    }
    _optimisticMessagesBySessionKey[key] = unresolved;
    return <ChatMessage>[...serverMessages, ...unresolved];
  }

  List<ChatMessage> _stripOptimisticMessages({
    required ProjectTarget project,
    required String sessionId,
    required List<ChatMessage> messages,
  }) {
    final optimistic =
        _optimisticMessagesBySessionKey[_optimisticSessionKey(
          project,
          sessionId,
        )];
    if (optimistic == null || optimistic.isEmpty) {
      return messages;
    }
    final optimisticIds = optimistic.map((message) => message.info.id).toSet();
    return messages
        .where((message) => !optimisticIds.contains(message.info.id))
        .toList(growable: false);
  }

  List<ChatMessage> _resolveOptimisticMessages({
    required List<ChatMessage> serverMessages,
    required List<ChatMessage> optimisticMessages,
  }) {
    final serverCounts = <String, int>{};
    for (final message in serverMessages) {
      final signature = _userMessageSignature(message);
      if (signature == null) {
        continue;
      }
      serverCounts[signature] = (serverCounts[signature] ?? 0) + 1;
    }

    final consumed = <String, int>{};
    final unresolved = <ChatMessage>[];
    for (final message in optimisticMessages) {
      final signature = _userMessageSignature(message);
      if (signature == null) {
        unresolved.add(message);
        continue;
      }
      final matched = consumed[signature] ?? 0;
      final available = serverCounts[signature] ?? 0;
      if (matched < available) {
        consumed[signature] = matched + 1;
        continue;
      }
      unresolved.add(message);
    }
    return unresolved;
  }

  String? _userMessageSignature(ChatMessage message) {
    if (message.info.role != 'user') {
      return null;
    }
    final encodedParts = <String>[];
    for (final part in message.parts) {
      if (part.type == 'text') {
        encodedParts.add('text:${_partSignatureText(part)}');
        continue;
      }
      if (part.type == 'file') {
        encodedParts.add(
          'file:${part.filename ?? ''}:${part.metadata['mime'] ?? ''}:${part.metadata['url'] ?? ''}',
        );
      }
    }
    if (encodedParts.isEmpty) {
      return null;
    }
    return encodedParts.join('|');
  }

  List<ChatMessage> _orderedTimelineMessages(List<ChatMessage> messages) {
    if (messages.length <= 1) {
      return messages;
    }
    final indexed = <_IndexedTimelineMessage>[
      for (var index = 0; index < messages.length; index += 1)
        _IndexedTimelineMessage(index: index, message: messages[index]),
    ];
    indexed.sort(_compareTimelineMessages);
    var changed = false;
    for (var index = 0; index < indexed.length; index += 1) {
      if (indexed[index].index != index) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return messages;
    }
    return indexed.map((entry) => entry.message).toList(growable: false);
  }

  int _computeTimelineContentSignature(List<ChatMessage> messages) {
    var signature = messages.length;
    for (final message in messages) {
      signature = Object.hash(
        signature,
        message.info.id,
        message.info.role,
        message.info.agent,
        message.info.variant,
        message.info.modelId,
        message.info.providerId,
        message.info.createdAt?.millisecondsSinceEpoch,
        message.info.completedAt?.millisecondsSinceEpoch,
        message.info.cost,
        message.info.totalTokens,
        message.info.inputTokens,
        message.info.outputTokens,
        message.info.reasoningTokens,
        message.info.cacheReadTokens,
        message.info.cacheWriteTokens,
        message.parts.length,
      );
      for (final part in message.parts) {
        signature = Object.hash(
          signature,
          part.id,
          part.type,
          part.tool,
          part.filename,
          _stringSignature(part.text),
          _stringSignature(part.metadata['summary']?.toString()),
          _stringSignature(part.metadata['content']?.toString()),
          _stringSignature(part.metadata['command']?.toString()),
          _stringSignature(part.metadata['output']?.toString()),
          _stringSignature(part.metadata['title']?.toString()),
          _stringSignature(part.metadata['status']?.toString()),
        );
      }
    }
    return signature;
  }

  int _stringSignature(String? value) {
    if (value == null || value.isEmpty) {
      return 0;
    }
    return Object.hash(value.length, value.hashCode);
  }

  String _partSignatureText(ChatPart part) {
    final text = part.text?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    final metadataText = part.metadata['text']?.toString().trim();
    if (metadataText != null && metadataText.isNotEmpty) {
      return metadataText;
    }
    return '';
  }

  Future<List<ChatMessage>?> _loadCachedSessionMessages({
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final entry = await _cacheStore.load(
      _sessionMessagesCacheKey(project, sessionId),
    );
    if (entry == null) {
      return null;
    }
    try {
      final decoded = await _decodeJsonPayload(entry.payloadJson);
      return _chatMessagesFromDecodedJson(decoded);
    } catch (_) {
      await _cacheStore.remove(_sessionMessagesCacheKey(project, sessionId));
      return null;
    }
  }

  Future<void> _saveSessionMessagesCache({
    required ProjectTarget project,
    required String sessionId,
    required List<ChatMessage> messages,
  }) async {
    await _cacheStore.save(
      _sessionMessagesCacheKey(project, sessionId),
      messages.map((message) => message.toJson()).toList(growable: false),
    );
  }

  Future<void> _persistSelectedSessionMessagesCache(
    List<ChatMessage> messages, {
    bool immediate = false,
  }) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || sessionId.isEmpty) {
      return;
    }
    await _persistSessionMessagesCache(
      project: project,
      sessionId: sessionId,
      messages: messages,
      immediate: immediate,
    );
  }

  Future<void> _persistSessionMessagesCache({
    required ProjectTarget project,
    required String sessionId,
    required List<ChatMessage> messages,
    bool immediate = true,
  }) async {
    if (_disposed || sessionId.isEmpty) {
      return;
    }
    _queuedSessionMessagesCacheProject = project;
    _queuedSessionMessagesCacheSessionId = sessionId;
    _queuedSessionMessagesCacheMessages = messages;
    final token = ++_queuedSessionMessagesCacheToken;
    _sessionMessagesCachePersistTimer?.cancel();
    _sessionMessagesCachePersistTimer = null;

    if (immediate) {
      await _flushQueuedSessionMessagesCache(token);
      return;
    }

    _sessionMessagesCachePersistTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        _sessionMessagesCachePersistTimer = null;
        unawaited(_flushQueuedSessionMessagesCache(token));
      },
    );
  }

  Future<void> _flushQueuedSessionMessagesCache(int token) async {
    if (_disposed || token != _queuedSessionMessagesCacheToken) {
      return;
    }
    final project = _queuedSessionMessagesCacheProject;
    final sessionId = _queuedSessionMessagesCacheSessionId;
    final messages = _queuedSessionMessagesCacheMessages;
    if (project == null ||
        sessionId == null ||
        sessionId.isEmpty ||
        messages == null) {
      return;
    }
    await _saveSessionMessagesCache(
      project: project,
      sessionId: sessionId,
      messages: messages,
    );
    if (_disposed || token != _queuedSessionMessagesCacheToken) {
      return;
    }
    _queuedSessionMessagesCacheProject = null;
    _queuedSessionMessagesCacheSessionId = null;
    _queuedSessionMessagesCacheMessages = null;
  }

  void _applyActiveChildLivePreviewPartEvent(Map<String, Object?> properties) {
    final partJson = properties['part'];
    if (partJson is! Map) {
      return;
    }
    final part = ChatPart.fromJson(partJson.cast<String, Object?>());
    final sessionId = part.sessionId?.trim() ?? '';
    if (!_shouldTrackActiveChildLivePreview(sessionId)) {
      return;
    }
    _setActiveChildLivePreview(sessionId, _partActivityPreviewText(part));
  }

  void _clearActiveChildLivePreviewForMessageEvent(
    Map<String, Object?> properties,
  ) {
    final sessionId = properties['sessionID']?.toString().trim() ?? '';
    if (!_shouldTrackActiveChildLivePreview(sessionId)) {
      return;
    }
    _setActiveChildLivePreview(sessionId, null);
  }

  bool _shouldTrackActiveChildLivePreview(String sessionId) {
    if (sessionId.isEmpty || sessionId == _selectedSessionId) {
      return false;
    }
    final root = rootSelectedSession;
    if (root == null || sessionId == root.id) {
      return false;
    }
    final session = _sessionById(sessionId);
    if (session == null || session.archivedAt != null) {
      return false;
    }
    return _sessionTreeIds(root.id).contains(sessionId);
  }

  void _setActiveChildLivePreview(String sessionId, String? preview) {
    final trimmed = preview?.trim();
    final current = _activeChildSessionLivePreviewById[sessionId];
    if (trimmed == null || trimmed.isEmpty) {
      if (current == null) {
        return;
      }
      final next = Map<String, String>.from(_activeChildSessionLivePreviewById)
        ..remove(sessionId);
      _activeChildSessionLivePreviewById = Map<String, String>.unmodifiable(
        next,
      );
      return;
    }
    if (current == trimmed) {
      return;
    }
    final next = Map<String, String>.from(_activeChildSessionLivePreviewById)
      ..[sessionId] = trimmed;
    _activeChildSessionLivePreviewById = Map<String, String>.unmodifiable(next);
  }

  void _removeActiveChildPreviewState(String? sessionId) {
    final normalized = sessionId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    if (_activeChildSessionLivePreviewById.containsKey(normalized)) {
      final next = Map<String, String>.from(_activeChildSessionLivePreviewById)
        ..remove(normalized);
      _activeChildSessionLivePreviewById = Map<String, String>.unmodifiable(
        next,
      );
    }
    if (_activeChildSessionCachedPreviewById.containsKey(normalized)) {
      final next = Map<String, String>.from(
        _activeChildSessionCachedPreviewById,
      )..remove(normalized);
      _activeChildSessionCachedPreviewById = Map<String, String>.unmodifiable(
        next,
      );
    }
    if (_activeChildSessionCachedPreviewVersionById.containsKey(normalized)) {
      final next = Map<String, int>.from(
        _activeChildSessionCachedPreviewVersionById,
      )..remove(normalized);
      _activeChildSessionCachedPreviewVersionById =
          Map<String, int>.unmodifiable(next);
    }
  }

  String? _resolveActiveChildSessionPreview(SessionSummary session) {
    final livePreview = session.id == _selectedSessionId
        ? _sessionActivityPreviewText(_messages)
        : _activeChildSessionLivePreviewById[session.id];
    final cachedPreview = _activeChildSessionCachedPreviewById[session.id];
    final statusPreview = _statusActivityPreviewText(_statuses[session.id]);
    return _firstNonEmptyText(<String?>[
      livePreview,
      cachedPreview,
      statusPreview,
      _genericActiveStatusPreviewText(_statuses[session.id]),
    ]);
  }

  void _ensureActiveChildSessionPreviewCache() {
    final activeSessions = activeChildSessions;
    final activeIds = activeSessions.map((session) => session.id).toSet();
    if (_activeChildSessionLivePreviewById.isNotEmpty) {
      _activeChildSessionLivePreviewById = Map<String, String>.unmodifiable(
        Map<String, String>.fromEntries(
          _activeChildSessionLivePreviewById.entries.where(
            (entry) => activeIds.contains(entry.key),
          ),
        ),
      );
    }
    if (_activeChildSessionCachedPreviewById.isNotEmpty ||
        _activeChildSessionCachedPreviewVersionById.isNotEmpty) {
      _activeChildSessionCachedPreviewById = Map<String, String>.unmodifiable(
        Map<String, String>.fromEntries(
          _activeChildSessionCachedPreviewById.entries.where(
            (entry) => activeIds.contains(entry.key),
          ),
        ),
      );
      _activeChildSessionCachedPreviewVersionById =
          Map<String, int>.unmodifiable(
            Map<String, int>.fromEntries(
              _activeChildSessionCachedPreviewVersionById.entries.where(
                (entry) => activeIds.contains(entry.key),
              ),
            ),
          );
    }

    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId != null && activeIds.contains(selectedSessionId)) {
      final livePreview = _sessionActivityPreviewText(_messages);
      if (livePreview != null) {
        final nextPreviewById = Map<String, String>.from(
          _activeChildSessionCachedPreviewById,
        );
        nextPreviewById[selectedSessionId] = livePreview;
        _activeChildSessionCachedPreviewById = Map<String, String>.unmodifiable(
          nextPreviewById,
        );
      }
      for (final session in activeSessions) {
        if (session.id != selectedSessionId) {
          continue;
        }
        final nextVersionById = Map<String, int>.from(
          _activeChildSessionCachedPreviewVersionById,
        );
        nextVersionById[selectedSessionId] =
            session.updatedAt.millisecondsSinceEpoch;
        _activeChildSessionCachedPreviewVersionById =
            Map<String, int>.unmodifiable(nextVersionById);
        break;
      }
    }

    final project = _project;
    final loadSignature = _activeChildSessionPreviewCacheSignature(
      activeSessions,
      project: project,
    );
    if (loadSignature == _activeChildSessionPreviewLoadSignature) {
      return;
    }
    _activeChildSessionPreviewLoadSignature = loadSignature;
    if (project == null || activeSessions.isEmpty) {
      return;
    }

    final sessionsToLoad = activeSessions
        .where((session) => session.id != selectedSessionId)
        .where(
          (session) =>
              _activeChildSessionCachedPreviewVersionById[session.id] !=
              session.updatedAt.millisecondsSinceEpoch,
        )
        .toList(growable: false);
    if (sessionsToLoad.isEmpty) {
      return;
    }

    final token = ++_activeChildSessionPreviewLoadToken;
    unawaited(
      _loadActiveChildSessionPreviewCache(
        project: project,
        sessions: sessionsToLoad,
        token: token,
      ),
    );
  }

  int _activeChildSessionPreviewCacheSignature(
    List<SessionSummary> sessions, {
    required ProjectTarget? project,
  }) {
    var signature = Object.hash(project?.directory, _selectedSessionId);
    for (final session in sessions) {
      if (session.id == _selectedSessionId) {
        continue;
      }
      signature = Object.hash(
        signature,
        session.id,
        session.updatedAt.millisecondsSinceEpoch,
      );
    }
    return signature;
  }

  Future<void> _loadActiveChildSessionPreviewCache({
    required ProjectTarget project,
    required List<SessionSummary> sessions,
    required int token,
  }) async {
    final nextPreviewById = Map<String, String>.from(
      _activeChildSessionCachedPreviewById,
    );
    final nextVersionById = Map<String, int>.from(
      _activeChildSessionCachedPreviewVersionById,
    );

    for (final session in sessions) {
      if (_disposed || token != _activeChildSessionPreviewLoadToken) {
        return;
      }

      final cachedMessages = await _loadCachedSessionMessages(
        project: project,
        sessionId: session.id,
      );
      if (_disposed || token != _activeChildSessionPreviewLoadToken) {
        return;
      }

      final preview = cachedMessages == null
          ? null
          : _sessionActivityPreviewText(cachedMessages);
      nextVersionById[session.id] = session.updatedAt.millisecondsSinceEpoch;
      if (preview == null) {
        nextPreviewById.remove(session.id);
      } else {
        nextPreviewById[session.id] = preview;
      }
    }

    if (mapEquals(nextPreviewById, _activeChildSessionCachedPreviewById) &&
        mapEquals(
          nextVersionById,
          _activeChildSessionCachedPreviewVersionById,
        )) {
      return;
    }

    _activeChildSessionCachedPreviewById = Map<String, String>.unmodifiable(
      nextPreviewById,
    );
    _activeChildSessionCachedPreviewVersionById = Map<String, int>.unmodifiable(
      nextVersionById,
    );
    _notify();
  }

  String? _sessionActivityPreviewText(List<ChatMessage> messages) {
    for (var index = messages.length - 1; index >= 0; index -= 1) {
      final message = messages[index];
      if (message.info.role != 'assistant') {
        continue;
      }
      final preview = _messageActivityPreviewText(message);
      if (preview != null) {
        return preview;
      }
    }

    for (var index = messages.length - 1; index >= 0; index -= 1) {
      final preview = _messageActivityPreviewText(messages[index]);
      if (preview != null) {
        return preview;
      }
    }
    return null;
  }

  String? _messageActivityPreviewText(ChatMessage message) {
    for (var index = message.parts.length - 1; index >= 0; index -= 1) {
      final preview = _partActivityPreviewText(message.parts[index]);
      if (preview != null) {
        return preview;
      }
    }
    return null;
  }

  String? _partActivityPreviewText(ChatPart part) {
    final type = part.type.trim().toLowerCase();
    return switch (type) {
      'tool' => _toolActivityPreviewText(part),
      'text' => _previewSnippet(_partPreviewSourceText(part)),
      'reasoning' => _previewSnippet(
        _firstNonEmptyText(<String?>[
              _previewNestedString(part.metadata, const <String>['summary']),
              part.text,
            ]) ??
            'Thinking through the task',
      ),
      'step-start' => _previewSnippet(
        _firstNonEmptyText(<String?>[
              _previewNestedString(part.metadata, const <String>['title']),
              _previewNestedString(part.metadata, const <String>[
                'description',
              ]),
              part.text,
            ]) ??
            'Starting the next step',
      ),
      'step-finish' => _previewSnippet(
        _firstNonEmptyText(<String?>[
              _previewNestedString(part.metadata, const <String>['message']),
              _previewNestedString(part.metadata, const <String>['reason']),
              part.text,
            ]) ??
            'Step finished',
      ),
      'agent' || 'subtask' => _previewSnippet(
        _firstNonEmptyText(<String?>[
              _previewNestedString(part.metadata, const <String>[
                'description',
              ]),
              _previewNestedString(part.metadata, const <String>['summary']),
              part.text,
            ]) ??
            'Delegating work',
      ),
      'patch' => _previewSnippet(
        _firstNonEmptyText(<String?>[
              _previewNestedString(part.metadata, const <String>['summary']),
              _previewNestedString(part.metadata, const <String>[
                'description',
              ]),
              part.text,
            ]) ??
            'Preparing changes',
      ),
      _ => _previewSnippet(
        _firstNonEmptyText(<String?>[
          _previewNestedString(part.metadata, const <String>['summary']),
          _previewNestedString(part.metadata, const <String>['description']),
          _previewNestedString(part.metadata, const <String>['message']),
          _partPreviewSourceText(part),
        ]),
      ),
    };
  }

  String? _toolActivityPreviewText(ChatPart part) {
    final label = _toolPreviewLabel(part.tool);
    final detail = _firstNonEmptyText(<String?>[
      _previewNestedString(part.metadata, const <String>['state', 'title']),
      _previewNestedString(part.metadata, const <String>[
        'state',
        'input',
        'description',
      ]),
      _previewNestedString(part.metadata, const <String>[
        'input',
        'description',
      ]),
      _previewNestedString(part.metadata, const <String>['description']),
      _previewNestedString(part.metadata, const <String>[
        'state',
        'input',
        'command',
      ]),
      _previewNestedString(part.metadata, const <String>['input', 'command']),
      _previewNestedString(part.metadata, const <String>['command']),
      _previewNestedString(part.metadata, const <String>[
        'state',
        'input',
        'query',
      ]),
      _previewNestedString(part.metadata, const <String>['input', 'query']),
      _previewNestedString(part.metadata, const <String>['query']),
      _previewNestedString(part.metadata, const <String>[
        'state',
        'input',
        'path',
      ]),
      _previewNestedString(part.metadata, const <String>['input', 'path']),
      _previewNestedString(part.metadata, const <String>['path']),
      _previewNestedString(part.metadata, const <String>[
        'state',
        'input',
        'url',
      ]),
      _previewNestedString(part.metadata, const <String>['input', 'url']),
      _previewNestedString(part.metadata, const <String>['url']),
      _partPreviewSourceText(part),
    ]);
    if (detail != null) {
      return _previewSnippet('$label: $detail');
    }
    return _previewSnippet('Running $label');
  }

  String _toolPreviewLabel(String? tool) {
    final normalized = tool?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 'Tool';
    }
    return switch (normalized) {
      'bash' => 'Shell',
      'task' => 'Task',
      'todowrite' => 'Todo',
      'websearch' => 'Web Search',
      'codesearch' => 'Code Search',
      'webfetch' => 'Web Fetch',
      _ =>
        normalized
            .split(RegExp(r'[_\\-]+'))
            .where((segment) => segment.trim().isNotEmpty)
            .map(
              (segment) => '${segment[0].toUpperCase()}${segment.substring(1)}',
            )
            .join(' '),
    };
  }

  String? _partPreviewSourceText(ChatPart part) {
    return _firstNonEmptyText(<String?>[
      part.text,
      part.metadata['summary']?.toString(),
      part.metadata['content']?.toString(),
      part.metadata['description']?.toString(),
      part.metadata['text']?.toString(),
    ]);
  }

  String? _statusActivityPreviewText(SessionStatusSummary? status) {
    return _previewSnippet(status?.message);
  }

  String? _genericActiveStatusPreviewText(SessionStatusSummary? status) {
    final type = status?.type.trim().toLowerCase();
    return switch (type) {
      'pending' => 'Queued and waiting to start',
      'busy' || 'running' => 'Working on the latest step',
      _ => null,
    };
  }

  String? _previewNestedString(Map<String, Object?> source, List<String> path) {
    Object? current = source;
    for (final segment in path) {
      if (current is! Map) {
        return null;
      }
      current = current[segment];
    }
    final value = current?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? _firstNonEmptyText(Iterable<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? _previewSnippet(String? value) {
    final normalized = value
        ?.replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])'), '')
        .trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= 120) {
      return normalized;
    }
    return '${normalized.substring(0, 117).trimRight()}...';
  }

  ProjectTarget? _projectTargetFromEvent(Map<String, Object?> properties) {
    try {
      final summary = ProjectSummary.fromJson(properties);
      final existing = _availableProjects
          .where((project) => project.directory == summary.directory)
          .cast<ProjectTarget?>()
          .firstOrNull;
      return ProjectTarget(
        id: summary.id,
        directory: summary.directory,
        label: summary.title,
        name: summary.name,
        source: existing?.source ?? 'server',
        vcs: summary.vcs ?? existing?.vcs,
        branch: existing?.branch,
        icon: summary.icon,
        commands: summary.commands,
        lastSession: existing?.lastSession,
      );
    } catch (_) {
      return null;
    }
  }

  void _replaceSession(SessionSummary updated) {
    final next = List<SessionSummary>.from(_sessions);
    final index = next.indexWhere((session) => session.id == updated.id);
    if (index >= 0) {
      next[index] = updated;
    } else {
      next.insert(0, updated);
    }
    _sessions = next.toList(growable: false);
  }

  Set<String> _ancestorDirectories(String path) {
    final ancestors = <String>{};
    var current = _parentDirectory(path);
    while (current != null && current.isNotEmpty) {
      ancestors.add(current);
      current = _parentDirectory(current);
    }
    return ancestors;
  }

  String? _parentDirectory(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return null;
    }
    return normalized.substring(0, index);
  }

  bool _hasKnownChildren(List<FileNodeSummary> nodes, String directoryPath) {
    final prefix = '$directoryPath/';
    for (final node in nodes) {
      if (node.path.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  List<FileNodeSummary> _mergeFileNodes(
    List<FileNodeSummary> existing,
    List<FileNodeSummary> incoming,
  ) {
    final byPath = <String, FileNodeSummary>{
      for (final node in existing) node.path: node,
      for (final node in incoming) node.path: node,
    };
    final merged = byPath.values.toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
    return merged;
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    if (_interruptingSession && !selectedSessionInterruptible) {
      _interruptingSession = false;
    }
    _ensureActiveChildSessionPreviewCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionMessagesCachePersistTimer?.cancel();
    _sessionMessagesCachePersistTimer = null;
    unawaited(_eventStreamService.disconnect());
    if (_ownsChatService) {
      _chatService.dispose();
    }
    if (_ownsProjectCatalogService) {
      _projectCatalogService.dispose();
    }
    if (_ownsFileBrowserService) {
      _fileBrowserService.dispose();
    }
    if (_ownsReviewDiffService) {
      _reviewDiffService.dispose();
    }
    if (_ownsTodoService) {
      _todoService.dispose();
    }
    if (_ownsRequestService) {
      _requestService.dispose();
    }
    if (_ownsEventStreamService) {
      _eventStreamService.dispose();
    }
    if (_ownsTerminalService) {
      _terminalService.dispose();
    }
    if (_ownsSessionActionService) {
      _sessionActionService.dispose();
    }
    if (_ownsConfigService) {
      _configService.dispose();
    }
    if (_ownsAgentService) {
      _agentService.dispose();
    }
    if (_ownsCommandService) {
      _commandService.dispose();
    }
    super.dispose();
  }
}

int _compareTimelineMessages(
  _IndexedTimelineMessage left,
  _IndexedTimelineMessage right,
) {
  final timestamp = _compareMessageTimestamp(left.message, right.message);
  if (timestamp != 0) {
    return timestamp;
  }
  final completed = _compareNullableDateTimes(
    left.message.info.completedAt,
    right.message.info.completedAt,
  );
  if (completed != 0) {
    return completed;
  }
  return left.index.compareTo(right.index);
}

int _compareMessageTimestamp(ChatMessage left, ChatMessage right) {
  return _compareNullableDateTimes(
    left.info.createdAt ?? left.info.completedAt,
    right.info.createdAt ?? right.info.completedAt,
  );
}

int _compareNullableDateTimes(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return 0;
  }
  return left.compareTo(right);
}

class _IndexedTimelineMessage {
  const _IndexedTimelineMessage({required this.index, required this.message});

  final int index;
  final ChatMessage message;
}

class _SlashCommandInvocation {
  const _SlashCommandInvocation({required this.name, required this.arguments});

  final String name;
  final String arguments;
}
