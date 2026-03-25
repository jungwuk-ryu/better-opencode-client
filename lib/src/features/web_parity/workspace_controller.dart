import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/connection/connection_models.dart';
import '../../core/network/event_stream_service.dart';
import '../../core/network/live_event_applier.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import '../chat/session_action_service.dart';
import '../files/file_browser_service.dart';
import '../files/file_models.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
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
    FileBrowserService? fileBrowserService,
    TodoService? todoService,
    RequestService? requestService,
    EventStreamService? eventStreamService,
    TerminalService? terminalService,
    SessionActionService? sessionActionService,
    ConfigService? configService,
    AgentService? agentService,
  }) : _chatService = chatService ?? ChatService(),
       _projectCatalogService =
           projectCatalogService ?? ProjectCatalogService(),
       _projectStore = projectStore ?? ProjectStore(),
       _fileBrowserService = fileBrowserService ?? FileBrowserService(),
       _todoService = todoService ?? TodoService(),
       _requestService = requestService ?? RequestService(),
       _eventStreamService = eventStreamService ?? EventStreamService(),
       _terminalService = terminalService ?? TerminalService(),
       _sessionActionService = sessionActionService ?? SessionActionService(),
       _configService = configService ?? ConfigService(),
       _agentService = agentService ?? AgentService(),
       _ownsChatService = chatService == null,
       _ownsProjectCatalogService = projectCatalogService == null,
       _ownsFileBrowserService = fileBrowserService == null,
       _ownsTodoService = todoService == null,
       _ownsRequestService = requestService == null,
       _ownsEventStreamService = eventStreamService == null,
       _ownsTerminalService = terminalService == null,
       _ownsSessionActionService = sessionActionService == null,
       _ownsConfigService = configService == null,
       _ownsAgentService = agentService == null;

  final ServerProfile profile;
  final String directory;
  final String? initialSessionId;

  final ChatService _chatService;
  final ProjectCatalogService _projectCatalogService;
  final ProjectStore _projectStore;
  final FileBrowserService _fileBrowserService;
  final TodoService _todoService;
  final RequestService _requestService;
  final EventStreamService _eventStreamService;
  final TerminalService _terminalService;
  final SessionActionService _sessionActionService;
  final ConfigService _configService;
  final AgentService _agentService;
  final bool _ownsChatService;
  final bool _ownsProjectCatalogService;
  final bool _ownsFileBrowserService;
  final bool _ownsTodoService;
  final bool _ownsRequestService;
  final bool _ownsEventStreamService;
  final bool _ownsTerminalService;
  final bool _ownsSessionActionService;
  final bool _ownsConfigService;
  final bool _ownsAgentService;

  bool _disposed = false;
  bool _loading = true;
  bool _submittingPrompt = false;
  bool _runningTerminal = false;
  bool _terminalOpen = false;
  WorkspaceSideTab _sideTab = WorkspaceSideTab.review;
  String? _error;
  String? _actionNotice;
  ProjectTarget? _project;
  List<ProjectTarget> _availableProjects = const <ProjectTarget>[];
  List<SessionSummary> _sessions = const <SessionSummary>[];
  Map<String, SessionStatusSummary> _statuses =
      const <String, SessionStatusSummary>{};
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  FileBrowserBundle? _fileBundle;
  List<TodoItem> _todos = const <TodoItem>[];
  PendingRequestBundle _pendingRequests = const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );
  ShellCommandResult? _lastShellResult;
  List<AgentDefinition> _composerAgents = const <AgentDefinition>[];
  List<WorkspaceComposerModelOption> _composerModels =
      const <WorkspaceComposerModelOption>[];
  String? _selectedAgentName;
  String? _selectedModelKey;
  String? _selectedReasoning;
  String? _serverDefaultModelKey;
  String? _serverDefaultReasoning;

  bool get loading => _loading;
  bool get submittingPrompt => _submittingPrompt;
  bool get runningTerminal => _runningTerminal;
  bool get terminalOpen => _terminalOpen;
  WorkspaceSideTab get sideTab => _sideTab;
  String? get error => _error;
  String? get actionNotice => _actionNotice;
  ProjectTarget? get project => _project;
  List<ProjectTarget> get availableProjects => _availableProjects;
  List<SessionSummary> get sessions => _sessions;
  Map<String, SessionStatusSummary> get statuses => _statuses;
  String? get selectedSessionId => _selectedSessionId;
  List<ChatMessage> get messages => _messages;
  FileBrowserBundle? get fileBundle => _fileBundle;
  List<TodoItem> get todos => _todos;
  PendingRequestBundle get pendingRequests => _pendingRequests;
  ShellCommandResult? get lastShellResult => _lastShellResult;
  List<AgentDefinition> get composerAgents => _composerAgents;
  List<WorkspaceComposerModelOption> get composerModels => _composerModels;
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
      final availableProjects = _mergeProjects(catalog, recentProjects);
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
      _selectedSessionId =
          initialSessionId ??
          bundle.selectedSessionId ??
          _sessionIdHintForProject(resolvedProject, bundle.sessions);

      if (_selectedSessionId != null) {
        _messages = await _chatService.fetchMessages(
          profile: profile,
          project: resolvedProject,
          sessionId: _selectedSessionId!,
        );
        _restoreComposerSelectionFromMessages();
      } else {
        _messages = const <ChatMessage>[];
        _applyDefaultComposerSelection();
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
    _todos = const <TodoItem>[];
    _pendingRequests = const PendingRequestBundle(
      questions: <QuestionRequestSummary>[],
      permissions: <PermissionRequestSummary>[],
    );
    _fileBundle = null;
    _actionNotice = null;
    _notify();

    await _projectStore.recordRecentProject(project);
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
    _selectedSessionId =
        bundle.selectedSessionId ??
        _sessionIdHintForProject(project, bundle.sessions);
    if (_selectedSessionId != null) {
      _messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: _selectedSessionId!,
      );
      _restoreComposerSelectionFromMessages();
    } else {
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
    _todos = const <TodoItem>[];
    _pendingRequests = const PendingRequestBundle(
      questions: <QuestionRequestSummary>[],
      permissions: <PermissionRequestSummary>[],
    );
    _notify();

    if (sessionId == null || sessionId.isEmpty) {
      _applyDefaultComposerSelection();
      return;
    }

    _messages = await _chatService.fetchMessages(
      profile: profile,
      project: _project!,
      sessionId: sessionId,
    );
    _restoreComposerSelectionFromMessages();
    await _loadSessionPanels();
    await _persistSessionHint(sessionId);
    _notify();
  }

  Future<String?> submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    final project = _project;
    final selectedAgent = this.selectedAgent;
    final selectedModel = this.selectedModel;
    if (project == null || trimmed.isEmpty) {
      return _selectedSessionId;
    }

    _submittingPrompt = true;
    _notify();

    try {
      var sessionId = _selectedSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        final created = await _chatService.createSession(
          profile: profile,
          project: project,
        );
        sessionId = created.id;
        _selectedSessionId = sessionId;
        _sessions = <SessionSummary>[created, ..._sessions];
      }

      await _chatService.sendMessage(
        profile: profile,
        project: project,
        sessionId: sessionId,
        prompt: trimmed,
        agent: selectedAgent?.name,
        providerId: selectedModel?.providerId,
        modelId: selectedModel?.modelId,
        variant: _selectedReasoning,
        reasoning: _selectedReasoning,
      );
      _messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
      _restoreComposerSelectionFromMessages();
      _statuses = await _reloadStatuses(project);
      await _loadSessionPanels();
      await _persistSessionHint(sessionId);
      return sessionId;
    } finally {
      _submittingPrompt = false;
      _notify();
    }
  }

  Future<void> renameSelectedSession(String title) async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || title.trim().isEmpty) {
      return;
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
  }

  Future<void> forkSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return;
    }
    final forked = await _sessionActionService.forkSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    _sessions = <SessionSummary>[forked, ..._sessions];
    _selectedSessionId = forked.id;
    _messages = await _chatService.fetchMessages(
      profile: profile,
      project: project,
      sessionId: forked.id,
    );
    _actionNotice = 'Forked session into "${forked.title}".';
    await _loadSessionPanels();
    _notify();
  }

  Future<void> shareSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return;
    }
    await _sessionActionService.shareSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    _actionNotice = 'Session share request sent.';
    _notify();
  }

  Future<void> deleteSelectedSession() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null) {
      return;
    }
    await _sessionActionService.deleteSession(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    _sessions = _sessions
        .where((session) => session.id != sessionId)
        .toList(growable: false);
    _selectedSessionId = _sessions.isEmpty ? null : _sessions.first.id;
    _messages = _selectedSessionId == null
        ? const <ChatMessage>[]
        : await _chatService.fetchMessages(
            profile: profile,
            project: project,
            sessionId: _selectedSessionId!,
          );
    await _loadSessionPanels();
    _actionNotice = 'Session deleted.';
    _notify();
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
      _messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
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

  Future<void> _loadComposerState(ProjectTarget project) async {
    ConfigSnapshot? snapshot;
    List<AgentDefinition> agents = const <AgentDefinition>[];

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

    _composerAgents = agents
        .where((agent) => agent.visible)
        .toList(growable: false);
    _composerModels = _buildComposerModelOptions(snapshot);
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
    } catch (_) {
      _fileBundle = null;
    }
    await _loadSessionPanels();
  }

  Future<void> _loadSessionPanels() async {
    final project = _project;
    final sessionId = _selectedSessionId;
    if (project == null || sessionId == null || sessionId.isEmpty) {
      _todos = const <TodoItem>[];
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
      return;
    }

    try {
      _todos = await _todoService.fetchTodos(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
    } catch (_) {
      _todos = const <TodoItem>[];
    }

    try {
      final pending = await _requestService.fetchPending(
        profile: profile,
        project: project,
      );
      _pendingRequests = PendingRequestBundle(
        questions: pending.questions
            .where((item) => item.sessionId == sessionId)
            .toList(growable: false),
        permissions: pending.permissions
            .where((item) => item.sessionId == sessionId)
            .toList(growable: false),
      );
    } catch (_) {
      _pendingRequests = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[],
        permissions: <PermissionRequestSummary>[],
      );
    }
  }

  Future<Map<String, SessionStatusSummary>> _reloadStatuses(
    ProjectTarget project,
  ) async {
    final bundle = await _chatService.fetchBundle(
      profile: profile,
      project: project,
    );
    _sessions = bundle.sessions;
    return bundle.statuses;
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
    switch (event.type) {
      case 'session.status':
        _statuses = applySessionStatusEvent(_statuses, event.properties);
      case 'message.updated':
        _messages = applyMessageUpdatedEvent(
          _messages,
          event.properties,
          selectedSessionId: _selectedSessionId,
        );
      case 'message.part.updated':
        _messages = applyMessagePartUpdatedEvent(
          _messages,
          event.properties,
          selectedSessionId: _selectedSessionId,
        );
      case 'message.removed':
        _messages = applyMessageRemovedEvent(
          _messages,
          event.properties,
          selectedSessionId: _selectedSessionId,
        );
      case 'todo.updated':
        _todos = applyTodoUpdatedEvent(
          _todos,
          event.properties,
          selectedSessionId: _selectedSessionId,
        );
      default:
        return;
    }
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
    List<ProjectTarget> recentProjects,
  ) {
    final byDirectory = <String, ProjectTarget>{};

    void add(ProjectTarget target) {
      final existing = byDirectory[target.directory];
      byDirectory[target.directory] = existing == null
          ? target
          : ProjectTarget(
              directory: target.directory,
              label: existing.label.isNotEmpty ? existing.label : target.label,
              source: target.source ?? existing.source,
              vcs: target.vcs ?? existing.vcs,
              branch: target.branch ?? existing.branch,
              lastSession: existing.lastSession ?? target.lastSession,
            );
    }

    ProjectTarget toTarget(ProjectSummary project, {required String source}) {
      return ProjectTarget(
        directory: project.directory,
        label: project.title,
        source: source,
        vcs: project.vcs,
        branch: catalog.vcsInfo?.branch,
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

  String? _sessionIdHintForProject(
    ProjectTarget project,
    List<SessionSummary> sessions,
  ) {
    final hint = project.lastSession?.title?.trim();
    if (hint == null || hint.isEmpty) {
      return sessions.isEmpty ? null : sessions.first.id;
    }
    for (final session in sessions) {
      if (session.title.trim() == hint) {
        return session.id;
      }
    }
    return sessions.isEmpty ? null : sessions.first.id;
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
        source: project.source,
        vcs: project.vcs,
        branch: project.branch,
        lastSession: ProjectSessionHint(title: session?.title, status: status),
      ),
    );
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

  void _notify() {
    if (_disposed) {
      return;
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
    super.dispose();
  }
}
