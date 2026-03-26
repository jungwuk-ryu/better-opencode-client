import 'dart:convert';
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../core/connection/connection_models.dart';
import '../../core/network/event_stream_service.dart';
import '../../core/network/live_event_applier.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../chat/prompt_attachment_models.dart';
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
  String? _selectedReviewPath;
  FileDiffSummary? _reviewDiff;
  List<TodoItem> _todos = const <TodoItem>[];
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
  FileBrowserBundle? get fileBundle => _fileBundle;
  Set<String> get expandedFileDirectories =>
      UnmodifiableSetView<String>(_expandedFileDirectories);
  String? get selectedReviewPath => _selectedReviewPath;
  FileDiffSummary? get reviewDiff => _reviewDiff;
  List<TodoItem> get todos => _todos;
  PendingRequestBundle get pendingRequests => _pendingRequests;
  QuestionRequestSummary? get currentQuestionRequest =>
      _sessionTreeRequest<QuestionRequestSummary>(
        _pendingRequests.questions,
        (request) => request.sessionId,
      );
  PermissionRequestSummary? get currentPermissionRequest =>
      _sessionTreeRequest<PermissionRequestSummary>(
        _pendingRequests.permissions,
        (request) => request.sessionId,
      );
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

  bool get selectedSessionInterruptible {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null || selectedSessionId.isEmpty) {
      return false;
    }
    return submittingPrompt || _isActiveStatus(selectedStatus);
  }

  SessionSummary? get rootSelectedSession =>
      _rootSessionForId(selectedSessionId);

  List<SessionSummary> get activeChildSessions {
    final root = rootSelectedSession;
    if (root == null) {
      return const <SessionSummary>[];
    }

    final selectedSessionId = this.selectedSessionId;
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
    _selectedReviewPath = null;
    _reviewDiff = null;
    _todos = const <TodoItem>[];
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
    _notify();
  }

  Future<void> selectSession(String? sessionId) async {
    if (_project == null) {
      return;
    }
    _selectedSessionId = sessionId;
    _messages = const <ChatMessage>[];
    _sessionLoading = false;
    _showingCachedSessionMessages = false;
    _sessionLoadError = null;
    _todos = const <TodoItem>[];
    _loadingReviewDiff = false;
    _reviewDiffError = null;
    _reviewDiff = null;
    _notify();

    if (sessionId == null || sessionId.isEmpty) {
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
      _applyDefaultComposerSelection();
      _notify();
      return;
    }

    await _loadSelectedSessionMessages(
      project: _project!,
      sessionId: sessionId,
      loadPanels: true,
      persistHint: true,
    );
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

  Future<void> selectReviewFile(String path) async {
    final project = _project;
    final trimmed = path.trim();
    if (project == null || trimmed.isEmpty) {
      return;
    }
    if (_selectedReviewPath == trimmed &&
        _reviewDiff != null &&
        _reviewDiffError == null &&
        !_loadingReviewDiff) {
      return;
    }
    await _loadReviewDiff(path: trimmed, project: project);
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

  Future<void> _loadReviewDiff({
    required String path,
    required ProjectTarget project,
  }) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _selectedReviewPath = path;
      _reviewDiff = null;
      _reviewDiffError = 'Select a session to review its diff.';
      _loadingReviewDiff = false;
      _notify();
      return;
    }

    FileStatusSummary? status;
    for (final item in _fileBundle?.statuses ?? const <FileStatusSummary>[]) {
      if (item.path == path) {
        status = item;
        break;
      }
    }
    if (status == null) {
      _selectedReviewPath = path;
      _reviewDiff = null;
      _reviewDiffError = 'Could not find diff metadata for this file.';
      _loadingReviewDiff = false;
      _notify();
      return;
    }

    final revision = ++_reviewDiffRevision;
    _selectedReviewPath = path;
    _reviewDiff = null;
    _reviewDiffError = null;
    _loadingReviewDiff = true;
    _notify();

    try {
      final diff = await _reviewDiffService.fetchDiff(
        profile: profile,
        project: project,
        sessionId: sessionId,
        status: status,
      );
      if (_disposed ||
          revision != _reviewDiffRevision ||
          _selectedReviewPath != path) {
        return;
      }
      _reviewDiff = diff;
      _reviewDiffError = null;
    } catch (error) {
      if (_disposed ||
          revision != _reviewDiffRevision ||
          _selectedReviewPath != path) {
        return;
      }
      _reviewDiff = null;
      _reviewDiffError =
          'Couldn\'t load the diff for this file.\n${error.toString().trim()}';
    } finally {
      if (!_disposed &&
          revision == _reviewDiffRevision &&
          _selectedReviewPath == path) {
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
    _todos = const <TodoItem>[];
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
        _saveSessionMessagesCache(
          project: project,
          sessionId: sessionId,
          messages: messages,
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

  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
  }) async {
    final trimmed = prompt.trim();
    final project = _project;
    final selectedAgent = this.selectedAgent;
    final selectedModel = this.selectedModel;
    if (_submittingPrompt ||
        project == null ||
        (trimmed.isEmpty && attachments.isEmpty)) {
      return _selectedSessionId;
    }

    _submittingPrompt = true;
    _notify();

    try {
      var sessionId = _selectedSessionId;
      ChatMessage? optimisticMessage;
      if (sessionId == null || sessionId.isEmpty) {
        final created = await _chatService.createSession(
          profile: profile,
          project: project,
        );
        sessionId = created.id;
        _selectedSessionId = sessionId;
        _sessions = <SessionSummary>[created, ..._sessions];
      }
      optimisticMessage = _appendOptimisticUserMessage(
        project: project,
        sessionId: sessionId,
        prompt: trimmed,
        attachments: attachments,
      );

      final slashCommand = _parseSlashCommand(trimmed);
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
            agent: selectedAgent?.name,
            providerId: selectedModel?.providerId,
            modelId: selectedModel?.modelId,
            variant: _selectedReasoning,
          );
        } else {
          await _chatService.sendMessage(
            profile: profile,
            project: project,
            sessionId: sessionId,
            prompt: trimmed,
            attachments: attachments,
            agent: selectedAgent?.name,
            providerId: selectedModel?.providerId,
            modelId: selectedModel?.modelId,
            variant: _selectedReasoning,
            reasoning: _selectedReasoning,
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
      final refreshRevision = ++_promptRefreshRevision;
      unawaited(
        _refreshAfterPrompt(
          project: project,
          sessionId: sessionId,
          revision: refreshRevision,
        ),
      );
      return sessionId;
    } finally {
      _submittingPrompt = false;
      _notify();
    }
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

    if (_selectedSessionId == sessionId && messages != null) {
      _messages = _mergeSessionMessages(
        project: project,
        sessionId: sessionId,
        serverMessages: messages,
      );
      _sessionLoading = false;
      _showingCachedSessionMessages = false;
      _sessionLoadError = null;
      _restoreComposerSelectionFromMessages();
      unawaited(
        _saveSessionMessagesCache(
          project: project,
          sessionId: sessionId,
          messages: messages,
        ),
      );
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

    _notify();
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
    _todos = const <TodoItem>[];
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
    await _loadSessionPanels();
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
    await _loadSessionPanels();
    _notify();
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
    if (_todos.isEmpty) {
      return;
    }
    _todos = const <TodoItem>[];
    _notify();
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
      final statuses = _fileBundle?.statuses ?? const <FileStatusSummary>[];
      _selectedReviewPath = statuses.isEmpty ? null : statuses.first.path;
      _reviewDiff = null;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
    } catch (_) {
      _fileBundle = null;
      _loadingFilePreview = false;
      _loadingFileDirectoryPath = null;
      _expandedFileDirectories = <String>{};
      _loadedFileDirectories = <String>{};
      _selectedReviewPath = null;
      _reviewDiff = null;
      _reviewDiffError = null;
      _loadingReviewDiff = false;
    }
    await _loadSessionPanels();
    final selectedReviewPath = _selectedReviewPath;
    if (_fileBundle != null &&
        selectedReviewPath != null &&
        _selectedSessionId != null) {
      unawaited(_loadReviewDiff(path: selectedReviewPath, project: project));
    }
  }

  Future<void> _loadSessionPanels() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null) {
      _todos = const <TodoItem>[];
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
      return;
    }

    if (sessionId == null || sessionId.isEmpty) {
      _todos = const <TodoItem>[];
    } else {
      try {
        _todos = await _todoService.fetchTodos(
          profile: profile,
          project: project,
          sessionId: sessionId,
        );
      } catch (_) {
        _todos = const <TodoItem>[];
      }
    }

    try {
      final pending = await _requestService.fetchPending(
        profile: profile,
        project: project,
      );
      _pendingRequests = pending;
    } catch (_) {
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
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
      _sessions = applySessionDeletedEvent(_sessions, event.properties);
      _statuses = removeSessionStatusEvent(_statuses, event.properties);
    } else if (type == 'session.status') {
      _statuses = applySessionStatusEvent(_statuses, event.properties);
    } else if (type == 'message.updated') {
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
        unawaited(_persistSelectedSessionMessagesCache(nextServerMessages));
      }
      _messages = nextMessages;
    } else if (type == 'message.part.updated') {
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
        unawaited(_persistSelectedSessionMessagesCache(nextServerMessages));
      }
      _messages = nextMessages;
    } else if (type == 'todo.updated') {
      _todos = applyTodoUpdatedEvent(
        _todos,
        event.properties,
        selectedSessionId: _selectedSessionId,
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

  T? _sessionTreeRequest<T>(
    List<T> requests,
    String Function(T request) sessionIdOf,
  ) {
    final rootSessionId = selectedSessionId;
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
        'local_user_${timestamp.microsecondsSinceEpoch}_${_optimisticMessageSequence++}';
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
      return ((jsonDecode(entry.payloadJson) as List)
              .cast<Map<String, Object?>>())
          .map(ChatMessage.fromJson)
          .toList(growable: false);
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
    List<ChatMessage> messages,
  ) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || sessionId.isEmpty) {
      return;
    }
    await _saveSessionMessagesCache(
      project: project,
      sessionId: sessionId,
      messages: messages,
    );
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
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
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

class _SlashCommandInvocation {
  const _SlashCommandInvocation({required this.name, required this.arguments});

  final String name;
  final String arguments;
}
