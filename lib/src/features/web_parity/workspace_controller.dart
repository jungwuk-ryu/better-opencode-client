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
import '../terminal/terminal_service.dart';
import '../tools/todo_models.dart';
import '../tools/todo_service.dart';

enum WorkspaceSideTab { review, files, context }

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
  }) : _chatService = chatService ?? ChatService(),
       _projectCatalogService = projectCatalogService ?? ProjectCatalogService(),
       _projectStore = projectStore ?? ProjectStore(),
       _fileBrowserService = fileBrowserService ?? FileBrowserService(),
       _todoService = todoService ?? TodoService(),
       _requestService = requestService ?? RequestService(),
       _eventStreamService = eventStreamService ?? EventStreamService(),
       _terminalService = terminalService ?? TerminalService(),
       _sessionActionService = sessionActionService ?? SessionActionService(),
       _ownsChatService = chatService == null,
       _ownsProjectCatalogService = projectCatalogService == null,
       _ownsFileBrowserService = fileBrowserService == null,
       _ownsTodoService = todoService == null,
       _ownsRequestService = requestService == null,
       _ownsEventStreamService = eventStreamService == null,
       _ownsTerminalService = terminalService == null,
       _ownsSessionActionService = sessionActionService == null;

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
  final bool _ownsChatService;
  final bool _ownsProjectCatalogService;
  final bool _ownsFileBrowserService;
  final bool _ownsTodoService;
  final bool _ownsRequestService;
  final bool _ownsEventStreamService;
  final bool _ownsTerminalService;
  final bool _ownsSessionActionService;

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
      _availableProjects = availableProjects.any(
            (candidate) => candidate.directory == resolvedProject.directory,
          )
          ? availableProjects
          : <ProjectTarget>[resolvedProject, ...availableProjects];

      await _projectStore.recordRecentProject(resolvedProject);
      await _projectStore.saveLastWorkspace(
        serverStorageKey: profile.storageKey,
        target: resolvedProject,
      );

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
      } else {
        _messages = const <ChatMessage>[];
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

    final bundle = await _chatService.fetchBundle(profile: profile, project: project);
    _sessions = bundle.sessions;
    _statuses = bundle.statuses;
    _selectedSessionId =
        bundle.selectedSessionId ?? _sessionIdHintForProject(project, bundle.sessions);
    if (_selectedSessionId != null) {
      _messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: _selectedSessionId!,
      );
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
      return;
    }

    _messages = await _chatService.fetchMessages(
      profile: profile,
      project: _project!,
      sessionId: sessionId,
    );
    await _loadSessionPanels();
    await _persistSessionHint(sessionId);
    _notify();
  }

  Future<String?> submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    final project = _project;
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
      );
      _messages = await _chatService.fetchMessages(
        profile: profile,
        project: project,
        sessionId: sessionId,
      );
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
    final bundle = await _chatService.fetchBundle(profile: profile, project: project);
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
    values.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
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
        lastSession: ProjectSessionHint(
          title: session?.title,
          status: status,
        ),
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
    super.dispose();
  }
}
