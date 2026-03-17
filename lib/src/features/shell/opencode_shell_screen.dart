import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/event_stream_service.dart';
import '../../core/network/live_event_applier.dart';
import '../../core/network/sse_connection_monitor.dart';
import '../../core/spec/capability_registry.dart';
import '../../core/spec/raw_json_document.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../chat/chat_part_view.dart';
import '../chat/chat_service.dart';
import '../chat/session_action_service.dart';
import '../files/file_browser_service.dart';
import '../files/file_models.dart';
import '../projects/project_models.dart';
import '../requests/request_models.dart';
import '../requests/request_event_applier.dart';
import '../requests/request_service.dart';
import '../settings/config_service.dart';
import '../settings/config_edit_preview.dart';
import '../settings/integration_status_service.dart';
import '../terminal/terminal_service.dart';
import '../tools/todo_models.dart';
import '../tools/todo_service.dart';

class OpenCodeShellScreen extends StatefulWidget {
  const OpenCodeShellScreen({
    required this.profile,
    required this.project,
    required this.capabilities,
    required this.onExit,
    super.key,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;

  @override
  State<OpenCodeShellScreen> createState() => _OpenCodeShellScreenState();
}

class _OpenCodeShellScreenState extends State<OpenCodeShellScreen> {
  final ChatService _chatService = ChatService();
  final SessionActionService _sessionActionService = SessionActionService();
  final EventStreamService _eventStreamService = EventStreamService();
  final FileBrowserService _fileBrowserService = FileBrowserService();
  final RequestService _requestService = RequestService();
  final ConfigService _configService = ConfigService();
  final IntegrationStatusService _integrationStatusService =
      IntegrationStatusService();
  final TerminalService _terminalService = TerminalService();
  final TodoService _todoService = TodoService();
  final SseConnectionMonitor _sseConnectionMonitor = SseConnectionMonitor(
    heartbeatTimeout: const Duration(seconds: 8),
  );
  Timer? _eventHealthTimer;
  bool _recoveringEventStream = false;
  bool _showContextSheet = false;
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

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  @override
  void didUpdateWidget(covariant OpenCodeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.directory != widget.project.directory ||
        oldWidget.profile.storageKey != widget.profile.storageKey ||
        oldWidget.capabilities.asMap().toString() !=
            widget.capabilities.asMap().toString()) {
      _loadBundle();
    }
  }

  @override
  void dispose() {
    _eventHealthTimer?.cancel();
    _chatService.dispose();
    _sessionActionService.dispose();
    _eventStreamService.dispose();
    _fileBrowserService.dispose();
    _requestService.dispose();
    _configService.dispose();
    _integrationStatusService.dispose();
    _terminalService.dispose();
    _todoService.dispose();
    super.dispose();
  }

  Future<void> _loadBundle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = widget.capabilities.hasSessions
          ? await _chatService.fetchBundle(
              profile: widget.profile,
              project: widget.project,
            )
          : const ChatSessionBundle(
              sessions: <SessionSummary>[],
              statuses: <String, SessionStatusSummary>{},
              messages: <ChatMessage>[],
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = bundle.sessions;
        _statuses = bundle.statuses;
        _messages = bundle.messages;
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
        _questionRequests = const <QuestionRequestSummary>[];
        _permissionRequests = const <PermissionRequestSummary>[];
        _configSnapshot = null;
        _integrationStatusSnapshot = null;
        _lastIntegrationAuthUrl = null;
        _recentEvents = const <EventEnvelope>[];
        _todos = const <TodoItem>[];
        _selectedSessionId = bundle.selectedSessionId;
        _loading = false;
      });
      if (widget.capabilities.hasTodos && bundle.selectedSessionId != null) {
        await _loadTodos(bundle.selectedSessionId!);
      }
      if (widget.capabilities.hasFiles) {
        await _loadFiles();
      }
      if (widget.capabilities.hasQuestions ||
          widget.capabilities.hasPermissions) {
        await _loadPendingRequests();
      }
      if (widget.capabilities.hasConfigRead) {
        await _loadConfigSnapshot();
      }
      if (widget.capabilities.hasProviderOAuth ||
          widget.capabilities.hasMcpAuth) {
        await _loadIntegrationStatus();
      }
      if (widget.capabilities.hasEventStream) {
        await _connectEvents();
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

  Future<void> _loadFiles({String searchQuery = ''}) async {
    try {
      final bundle = await _fileBrowserService.fetchBundle(
        profile: widget.profile,
        project: widget.project,
        searchQuery: searchQuery,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _fileNodes = bundle.nodes;
        _fileStatuses = bundle.statuses;
        _fileSearchResults = bundle.searchResults;
        _textMatches = bundle.textMatches;
        _symbols = bundle.symbols;
        _filePreview = bundle.preview;
        _selectedFilePath = bundle.selectedPath;
        _fileSearchQuery = searchQuery;
      });
    } catch (_) {
      if (!mounted) {
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
      });
    }
  }

  Future<void> _selectFile(String path) async {
    final preview = await _fileBrowserService.fetchFileContent(
      profile: widget.profile,
      project: widget.project,
      path: path,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedFilePath = path;
      _filePreview = preview;
    });
  }

  Future<void> _runShellCommand(String command) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || command.trim().isEmpty) {
      return;
    }
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
      await _selectSession(sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastShellResult = result;
        _runningShellCommand = false;
      });
      await _loadPendingRequests();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _runningShellCommand = false;
      });
    }
  }

  Future<bool> _submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return false;
    }
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
        sessionId = created.id;
        if (!mounted) {
          return false;
        }
        setState(() {
          _sessions = <SessionSummary>[created, ..._sessions];
          _selectedSessionId = created.id;
        });
      }

      final reply = await _chatService.sendMessage(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        prompt: trimmed,
      );
      final messages = await _chatService.fetchMessages(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!mounted) {
        return false;
      }
      setState(() {
        _selectedSessionId = sessionId;
        _messages = messages.isEmpty ? <ChatMessage>[reply] : messages;
        _submittingPrompt = false;
      });
      await _loadPendingRequests();
      return true;
    } catch (error) {
      if (!mounted) {
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
    try {
      final bundle = await _requestService.fetchPending(
        profile: widget.profile,
        project: widget.project,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _questionRequests = bundle.questions;
        _permissionRequests = bundle.permissions;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _questionRequests = const <QuestionRequestSummary>[];
        _permissionRequests = const <PermissionRequestSummary>[];
      });
    }
  }

  Future<void> _loadConfigSnapshot() async {
    try {
      final snapshot = await _configService.fetch(
        profile: widget.profile,
        project: widget.project,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _configSnapshot = snapshot;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _configSnapshot = null;
      });
    }
  }

  Future<void> _applyConfigRaw(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Config must be a JSON object.');
    }
    final updated = await _configService.updateConfig(
      profile: widget.profile,
      project: widget.project,
      config: decoded.cast<String, Object?>(),
    );
    if (!mounted) {
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
    try {
      final snapshot = await _integrationStatusService.fetch(
        profile: widget.profile,
        project: widget.project,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _integrationStatusSnapshot = snapshot;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _integrationStatusSnapshot = null;
      });
    }
  }

  Future<void> _startProviderAuth(String providerId) async {
    final url = await _integrationStatusService.startProviderAuth(
      profile: widget.profile,
      project: widget.project,
      providerId: providerId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _lastIntegrationAuthUrl = url;
    });
  }

  Future<void> _startMcpAuth(String name) async {
    final url = await _integrationStatusService.startMcpAuth(
      profile: widget.profile,
      project: widget.project,
      name: name,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _lastIntegrationAuthUrl = url;
    });
  }

  Future<void> _replyPermission(String requestId, String reply) async {
    await _requestService.replyToPermission(
      profile: widget.profile,
      project: widget.project,
      requestId: requestId,
      reply: reply,
    );
    await _loadPendingRequests();
  }

  Future<void> _replyQuestion(
    String requestId,
    List<List<String>> answers,
  ) async {
    await _requestService.replyToQuestion(
      profile: widget.profile,
      project: widget.project,
      requestId: requestId,
      answers: answers,
    );
    await _loadPendingRequests();
  }

  Future<void> _rejectQuestion(String requestId) async {
    await _requestService.rejectQuestion(
      profile: widget.profile,
      project: widget.project,
      requestId: requestId,
    );
    await _loadPendingRequests();
  }

  Future<void> _forkSession(String sessionId) async {
    await _sessionActionService.forkSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
    );
    await _loadBundle();
  }

  Future<void> _abortSession(String sessionId) async {
    await _sessionActionService.abortSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
    );
    await _loadBundle();
  }

  Future<void> _shareSession(String sessionId) async {
    await _sessionActionService.shareSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
    );
  }

  Future<void> _unshareSession(String sessionId) async {
    await _sessionActionService.unshareSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    await _sessionActionService.deleteSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
    );
    await _loadBundle();
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
    await _sessionActionService.updateSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
      title: nextTitle,
    );
    await _loadBundle();
  }

  Future<void> _revertSession(String sessionId) async {
    if (_messages.isEmpty) {
      return;
    }
    await _sessionActionService.revertSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
      messageId: _messages.last.info.id,
    );
    await _loadBundle();
  }

  Future<void> _unrevertSession(String sessionId) async {
    await _sessionActionService.unrevertSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
    );
    await _loadBundle();
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
    await _sessionActionService.initSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
      messageId: info.id,
      providerId: providerId,
      modelId: modelId,
    );
    await _loadBundle();
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
    await _sessionActionService.summarizeSession(
      profile: widget.profile,
      project: widget.project,
      sessionId: sessionId,
      providerId: providerId,
      modelId: modelId,
    );
    await _loadBundle();
  }

  Future<void> _connectEvents() async {
    _eventHealthTimer?.cancel();
    await _eventStreamService.connect(
      profile: widget.profile,
      project: widget.project,
      onEvent: (event) {
        if (!mounted) {
          return;
        }
        final now = DateTime.now();
        _sseConnectionMonitor.recordFrame(now);
        if (event.type == 'server.connected') {
          _sseConnectionMonitor.recordHeartbeat(now);
        }
        setState(() {
          _eventStreamHealth = _sseConnectionMonitor.healthAt(now);
          _recentEvents = <EventEnvelope>[
            event,
            ..._recentEvents,
          ].take(12).toList(growable: false);
        });
        switch (event.type) {
          case 'session.status':
            setState(() {
              _statuses = applySessionStatusEvent(_statuses, event.properties);
            });
          case 'message.updated':
            setState(() {
              _messages = applyMessageUpdatedEvent(
                _messages,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
          case 'message.removed':
            setState(() {
              _messages = applyMessageRemovedEvent(
                _messages,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
          case 'message.part.updated':
            setState(() {
              _messages = applyMessagePartUpdatedEvent(
                _messages,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
          case 'todo.updated':
            setState(() {
              _todos = applyTodoUpdatedEvent(
                _todos,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
            final sessionId = _selectedSessionId;
            final hasSnapshot = event.properties['todos'] is List;
            if (!hasSnapshot && sessionId != null && sessionId.isNotEmpty) {
              _loadTodos(sessionId);
            }
          case 'question.asked':
            setState(() {
              _questionRequests = applyQuestionAskedEvent(
                _questionRequests,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
          case 'permission.asked':
            setState(() {
              _permissionRequests = applyPermissionAskedEvent(
                _permissionRequests,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
          case 'question.rejected':
          case 'question.replied':
            setState(() {
              _questionRequests = applyQuestionResolvedEvent(
                _questionRequests,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
          case 'permission.replied':
            setState(() {
              _permissionRequests = applyPermissionResolvedEvent(
                _permissionRequests,
                event.properties,
                selectedSessionId: _selectedSessionId,
              );
            });
            _loadPendingRequests();
        }
      },
      onDone: _handleEventStreamDropped,
      onError: (error, stackTrace) => _handleEventStreamDropped(),
    );
    _eventHealthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) {
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
    _recoveringEventStream = true;
    _sseConnectionMonitor.markReconnecting();
    setState(() {
      _eventStreamHealth = SseConnectionHealth.reconnecting;
      _eventRecoveryLog = <String>[
        'reconnect requested',
        ..._eventRecoveryLog,
      ].take(8).toList(growable: false);
    });
    unawaited(_recoverEventStream());
  }

  Future<void> _recoverEventStream() async {
    try {
      await _eventStreamService.disconnect();
      await _loadBundle();
      if (!mounted) {
        return;
      }
      setState(() {
        _eventStreamHealth = _sseConnectionMonitor.healthAt(DateTime.now());
        _eventRecoveryLog = <String>[
          'reconnect completed',
          ..._eventRecoveryLog,
        ].take(8).toList(growable: false);
      });
    } finally {
      _recoveringEventStream = false;
    }
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
      );
    }
    if (width >= 960) {
      return _TabletLandscapeShell(
        profile: widget.profile,
        project: widget.project,
        capabilities: widget.capabilities,
        onExit: widget.onExit,
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
      );
    }
    if (width >= 700) {
      return _TabletPortraitShell(
        profile: widget.profile,
        project: widget.project,
        capabilities: widget.capabilities,
        onExit: widget.onExit,
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
      capabilities: widget.capabilities,
      onExit: widget.onExit,
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
    required this.capabilities,
    required this.onExit,
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
    required this.submittingPrompt,
    required this.onSubmitPrompt,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
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
  final bool submittingPrompt;
  final Future<bool> Function(String) onSubmitPrompt;

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
              capabilities: capabilities,
              onExit: onExit,
              sessions: sessions,
              statuses: statuses,
              selectedSessionId: selectedSessionId,
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
            child: _ContextRail(
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
    required this.submittingPrompt,
    required this.onSubmitPrompt,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
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
  final bool submittingPrompt;
  final Future<bool> Function(String) onSubmitPrompt;

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
              capabilities: capabilities,
              onExit: onExit,
              sessions: sessions,
              statuses: statuses,
              selectedSessionId: selectedSessionId,
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
            child: _ContextRail(
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
    required this.submittingPrompt,
    required this.onSubmitPrompt,
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
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
  final bool submittingPrompt;
  final Future<bool> Function(String) onSubmitPrompt;
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
              submittingPrompt: submittingPrompt,
              selectedSessionId: selectedSessionId,
              onSubmitPrompt: onSubmitPrompt,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: showContextSheet
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _BottomUtilitySheet(
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
    required this.capabilities,
    required this.onExit,
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
    required this.submittingPrompt,
    required this.onSubmitPrompt,
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
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
  final bool submittingPrompt;
  final Future<bool> Function(String) onSubmitPrompt;
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
              submittingPrompt: submittingPrompt,
              selectedSessionId: selectedSessionId,
              onSubmitPrompt: onSubmitPrompt,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: showContextSheet
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _BottomUtilitySheet(
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
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Scaffold(
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
              padding: const EdgeInsets.all(AppSpacing.lg),
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

class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.profile,
    required this.project,
    required this.capabilities,
    required this.onExit,
    required this.sessions,
    required this.statuses,
    required this.selectedSessionId,
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
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final String? selectedSessionId;
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
    final activeSessions = statuses.values.where(
      (status) => status.type == 'busy',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PanelCard(
          tone: _PanelTone.subtle,
          eyebrow: 'Workspace',
          title: l10n.shellProjectRailTitle,
          subtitle: project.directory,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                project.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
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
                  _InfoChip(
                    label: l10n.shellActiveCount(activeSessions.length),
                    icon: Icons.bolt_rounded,
                  ),
                ],
              ),
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
            tone: _PanelTone.subtle,
            eyebrow: 'Sessions',
            title: l10n.shellSessionsTitle,
            subtitle: l10n.shellThreadsCount(sessions.length),
            fillChild: true,
            child: ListView(
              padding: EdgeInsets.zero,
              children: sessions.isEmpty
                  ? <Widget>[
                      _SessionTile(
                        title: l10n.shellSessionCurrent,
                        status: l10n.shellStatusIdle,
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
                              status: _statusLabel(l10n, statuses[session.id]),
                              selected: session.id == selectedSessionId,
                              onTap: () => onSelectSession(session.id),
                            ),
                          );
                        })
                        .toList(growable: false),
            ),
          ),
        ),
        if (selectedSessionId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _PanelCard(
            tone: _PanelTone.subtle,
            eyebrow: 'Controls',
            title: 'Actions',
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

class _ChatCanvas extends StatelessWidget {
  const _ChatCanvas({
    required this.messages,
    required this.loading,
    required this.error,
    required this.submittingPrompt,
    required this.selectedSessionId,
    required this.onSubmitPrompt,
    this.compact = false,
  });

  final bool compact;
  final List<ChatMessage> messages;
  final bool loading;
  final String? error;
  final bool submittingPrompt;
  final String? selectedSessionId;
  final Future<bool> Function(String) onSubmitPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parts = _flattenedParts();
    final maxContentWidth = compact ? double.infinity : 840.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact) ...<Widget>[
          _PanelCard(
            tone: _PanelTone.primary,
            eyebrow: 'Primary',
            title: l10n.shellChatHeaderTitle,
            subtitle: selectedSessionId == null
                ? 'New session draft'
                : '${parts.length} timeline parts in focus',
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
                  label: selectedSessionId == null
                      ? l10n.shellReadyToStart
                      : l10n.shellLiveContext,
                  icon: Icons.forum_outlined,
                ),
                _InfoChip(
                  label: l10n.shellPartsCount(parts.length),
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
            eyebrow: compact
                ? l10n.shellFocusedThreadEyebrow
                : l10n.shellTimelineEyebrow,
            title: l10n.shellChatTimelineTitle,
            subtitle: compact ? null : l10n.shellConversationSubtitle,
            fillChild: true,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? _MessageBubble(
                    title: l10n.shellConnectionIssueTitle,
                    body: error!,
                  )
                : Column(
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
                                child: _buildMessageList(l10n, parts),
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
                            compact: compact,
                            label: l10n.shellComposerPlaceholder,
                            submitting: submittingPrompt,
                            startsNewSession:
                                selectedSessionId == null ||
                                selectedSessionId!.isEmpty,
                            onSubmit: onSubmitPrompt,
                          ),
                        ),
                      ),
                    ],
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
      return ListView(
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
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: parts.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final item = parts[index];
        return ChatPartView(message: item.message, part: item.part);
      },
    );
  }

  List<({ChatMessageInfo message, ChatPart part})> _flattenedParts() {
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
      capabilities.hasShellCommands && !compact,
      (capabilities.hasQuestions || capabilities.hasPermissions) && !compact,
      (capabilities.hasConfigRead || capabilities.hasConfigWrite) && !compact,
      (capabilities.hasProviderOAuth || capabilities.hasMcpAuth) && !compact,
    ].where((enabled) => enabled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _PanelCard(
            tone: _PanelTone.subtle,
            eyebrow: compact ? 'Context' : 'Utilities',
            title: l10n.shellContextTitle,
            subtitle: compact
                ? 'Secondary context for the active conversation'
                : 'Support rails for files, tasks, commands, and integrations',
            trailing: _InfoChip(
              label: '$sectionCount modules',
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
                if (!compact) ...<Widget>[
                  if (capabilities.hasShellCommands) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _TerminalPanel(
                      command: terminalCommand,
                      result: lastShellResult,
                      running: runningShellCommand,
                      onRun: onRunShellCommand,
                    ),
                  ],
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
                  if (capabilities.hasConfigRead ||
                      capabilities.hasConfigWrite) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _ConfigPreviewPanel(
                      snapshot: configSnapshot,
                      onApply: onApplyConfig,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RawInspectorPanel(
                      sessions: sessions,
                      messages: messages,
                      selectedSessionId: selectedSessionId,
                    ),
                  ],
                  if (capabilities.hasProviderOAuth ||
                      capabilities.hasMcpAuth) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _IntegrationStatusPanel(
                      snapshot: integrationStatusSnapshot,
                      lastAuthorizationUrl: lastIntegrationAuthUrl,
                      recentEvents: recentEvents,
                      eventStreamHealth: eventStreamHealth,
                      eventRecoveryLog: eventRecoveryLog,
                      onStartProviderAuth: onStartProviderAuth,
                      onStartMcpAuth: onStartMcpAuth,
                    ),
                  ],
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
  const _BottomUtilitySheet({
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
    return SizedBox(
      height: compact ? 260 : 300,
      child: _ContextRail(
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
      tone: _PanelTone.subtle,
      eyebrow: 'Utilities',
      title: l10n.shellUtilitiesToggleTitle,
      subtitle: compact
          ? l10n.shellUtilitiesToggleBodyCompact
          : l10n.shellUtilitiesToggleBody,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _InfoChip(
              label: compact
                  ? 'Swipe utilities into view'
                  : 'Open the utility rail',
              icon: Icons.swipe_up_alt_rounded,
            ),
          ),
        ],
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
    return _PanelCard(
      tone: _PanelTone.subtle,
      eyebrow: 'Workspace',
      title: project.label,
      subtitle: project.directory,
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: <Widget>[
          IconButton(
            onPressed: onToggleUtilities,
            icon: const Icon(Icons.view_sidebar_outlined),
            tooltip: l10n.shellUtilitiesToggleTitle,
          ),
          OutlinedButton.icon(
            onPressed: onExit,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.shellBackToProjectsAction),
          ),
        ],
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _InfoChip(label: 'OpenCode remote', icon: Icons.waves_rounded),
          _InfoChip(label: 'Context nearby', icon: Icons.layers_outlined),
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
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _UtilityListRow(
      title: title,
      subtitle: status,
      selected: selected,
      icon: selected ? Icons.bolt_rounded : Icons.chat_bubble_outline_rounded,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).extension<AppSurfaces>()!.muted,
      ),
      onTap: onTap,
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
        icon: Icons.checklist_rounded,
      );
    }
    final sorted = todos.toList()
      ..sort((a, b) => _todoRank(a.status).compareTo(_todoRank(b.status)));
    return _UtilitySection(
      title: l10n.shellTodoTitle,
      subtitle: l10n.shellTodoSubtitle,
      icon: Icons.checklist_rounded,
      child: Column(
        children: <Widget>[
          for (final todo in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _UtilityListRow(
                title: todo.content,
                subtitle: todo.priority,
                icon: _todoIcon(todo.status),
                emphasis: todo.status == 'in_progress',
                trailing: _InfoChip(
                  label: _todoStatusLabel(todo.status),
                  emphasis: todo.status == 'in_progress',
                ),
              ),
            ),
        ],
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
    this.selected = false,
    this.emphasis = false,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
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
      child: DecoratedBox(
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
              if (icon != null) ...<Widget>[
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
          TextField(
            controller: TextEditingController(text: fileSearchQuery),
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
                subtitle: _statusFor(path, l10n),
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

  String _statusFor(String path, AppLocalizations l10n) {
    final matches = fileStatuses.where((item) => item.path == path);
    if (matches.isEmpty) {
      return l10n.shellTrackedLabel;
    }
    final match = matches.first;
    return '${match.status} +${match.added} -${match.removed}';
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({
    required this.command,
    required this.result,
    required this.running,
    required this.onRun,
  });

  final String command;
  final ShellCommandResult? result;
  final bool running;
  final ValueChanged<String> onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _UtilitySection(
      title: l10n.shellTerminalTitle,
      subtitle: l10n.shellTerminalSubtitle,
      icon: Icons.terminal_rounded,
      child: Column(
        children: <Widget>[
          TextField(
            controller: TextEditingController(text: command),
            onSubmitted: onRun,
            decoration: InputDecoration(
              hintText: l10n.shellTerminalHint,
              isDense: true,
              prefixIcon: const Icon(Icons.keyboard_command_key_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: running ? null : () => onRun(command),
                icon: Icon(
                  running
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  running
                      ? l10n.shellTerminalRunning
                      : l10n.shellTerminalRunAction,
                ),
              ),
            ],
          ),
          if (result != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _UtilityListRow(
              title: result!.messageId,
              subtitle:
                  '${result!.providerId ?? '-'} · ${result!.modelId ?? '-'}',
              icon: Icons.check_circle_outline_rounded,
              emphasis: true,
            ),
          ],
        ],
      ),
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
    if (widget.snapshot == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final preview = buildConfigEditPreview(
      current: widget.snapshot!.config,
      draft: _controller.text,
    );
    final providers = widget.snapshot!.providerConfig.toJson().toString();
    return _UtilitySection(
      title: l10n.shellConfigTitle,
      subtitle: 'Live preview of editable configuration',
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
    );
  }
}

class _RawInspectorPanel extends StatelessWidget {
  const _RawInspectorPanel({
    required this.sessions,
    required this.messages,
    required this.selectedSessionId,
  });

  final List<SessionSummary> sessions;
  final List<ChatMessage> messages;
  final String? selectedSessionId;

  @override
  Widget build(BuildContext context) {
    SessionSummary? selectedSession;
    final l10n = AppLocalizations.of(context)!;
    for (final session in sessions) {
      if (session.id == selectedSessionId) {
        selectedSession = session;
        break;
      }
    }
    final latestMessage = messages.isEmpty ? null : messages.last;

    final sessionJson = selectedSession == null
        ? '{}'
        : const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            'id': selectedSession.id,
            'directory': selectedSession.directory,
            'title': selectedSession.title,
            'version': selectedSession.version,
            'parentID': selectedSession.parentId,
          });
    final messageJson = latestMessage == null
        ? '{}'
        : const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            'id': latestMessage.info.id,
            'role': latestMessage.info.role,
            'providerID': latestMessage.info.providerId,
            'modelID': latestMessage.info.modelId,
            'parts': latestMessage.parts
                .map((part) => part.metadata)
                .toList(growable: false),
          });

    return _UtilitySection(
      title: l10n.shellInspectorTitle,
      subtitle: 'Session and message metadata snapshot',
      icon: Icons.data_object_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(sessionJson, maxLines: 5, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.sm),
          Text(messageJson, maxLines: 6, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _IntegrationStatusPanel extends StatelessWidget {
  const _IntegrationStatusPanel({
    required this.snapshot,
    required this.lastAuthorizationUrl,
    required this.recentEvents,
    required this.eventStreamHealth,
    required this.eventRecoveryLog,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
  });

  final IntegrationStatusSnapshot? snapshot;
  final String? lastAuthorizationUrl;
  final List<EventEnvelope> recentEvents;
  final SseConnectionHealth eventStreamHealth;
  final List<String> eventRecoveryLog;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return _UtilitySection(
      title: l10n.shellIntegrationsTitle,
      subtitle:
          '${l10n.shellIntegrationsStreamHealth}: ${eventStreamHealth.name}',
      icon: Icons.hub_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final entry in snapshot!.providerAuth.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UtilitySection(
                title: entry.key,
                subtitle:
                    '${l10n.shellIntegrationsMethods}: ${entry.value.join(', ')}',
                icon: Icons.cloud_outlined,
                child: OutlinedButton(
                  onPressed: () => onStartProviderAuth(entry.key),
                  child: Text(l10n.shellIntegrationsStartProviderAuth),
                ),
              ),
            ),
          for (final entry in snapshot!.mcpStatus.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UtilitySection(
                title: entry.key,
                subtitle: '${l10n.shellIntegrationsMcp}: ${entry.value}',
                icon: Icons.extension_outlined,
                child: OutlinedButton(
                  onPressed: () => onStartMcpAuth(entry.key),
                  child: Text(l10n.shellIntegrationsStartMcpAuth),
                ),
              ),
            ),
          if (snapshot!.lspStatus.isNotEmpty) ...<Widget>[
            _UtilitySection(
              title: l10n.shellIntegrationsLsp,
              subtitle: 'Language server readiness',
              icon: Icons.memory_rounded,
              child: Column(
                children: snapshot!.lspStatus.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _UtilityListRow(
                          title: entry.key,
                          subtitle: entry.value,
                          icon: Icons.circle_outlined,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (snapshot!.formatterStatus.isNotEmpty) ...<Widget>[
            _UtilitySection(
              title: l10n.shellIntegrationsFormatter,
              subtitle: 'Formatting availability',
              icon: Icons.auto_fix_high_rounded,
              child: Column(
                children: snapshot!.formatterStatus.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _UtilityListRow(
                          title: entry.key,
                          subtitle: entry.value
                              ? l10n.shellIntegrationsEnabled
                              : l10n.shellIntegrationsDisabled,
                          icon: entry.value
                              ? Icons.check_circle_outline_rounded
                              : Icons.remove_circle_outline_rounded,
                          emphasis: entry.value,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (lastAuthorizationUrl != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              lastAuthorizationUrl!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (recentEvents.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _InfoChip(
              label: recentEvents.take(3).map((event) => event.type).join(', '),
              icon: Icons.stream_rounded,
            ),
          ],
          if (eventRecoveryLog.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l10n.shellIntegrationsRecoveryLog}: ${eventRecoveryLog.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
    required this.onSubmit,
  });

  final bool compact;
  final String label;
  final bool submitting;
  final bool startsNewSession;
  final Future<bool> Function(String) onSubmit;

  @override
  State<_ComposerCard> createState() => _ComposerCardState();
}

class _ComposerCardState extends State<_ComposerCard> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    final success = await widget.onSubmit(text);
    if (success && mounted) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
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
                  label: widget.startsNewSession ? 'New session' : 'Replying',
                  icon: widget.startsNewSession
                      ? Icons.add_comment_outlined
                      : Icons.reply_rounded,
                  emphasis: true,
                ),
                _InfoChip(
                  label: widget.compact
                      ? 'Compact composer'
                      : 'Expanded composer',
                  icon: Icons.edit_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: widget.compact ? 3 : 5,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.label,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
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
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.icon, this.emphasis = false});

  final String label;
  final IconData? icon;
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
    return DecoratedBox(
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
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 14,
                color: emphasis
                    ? theme.colorScheme.primary
                    : surfaces.accentSoft,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: emphasis ? theme.colorScheme.primary : null,
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
      if (status?.attempt != null) 'attempt ${status!.attempt}',
      if ((status?.message ?? '').trim().isNotEmpty) status!.message!.trim(),
    ];
    if (details.isNotEmpty) {
      return '$base - ${details.join(' - ')}';
    }
  }
  return base;
}

int _todoRank(String status) {
  return switch (status) {
    'in_progress' => 0,
    'pending' => 1,
    'completed' => 2,
    _ => 3,
  };
}

String _todoStatusLabel(String status) {
  return status.replaceAll('_', ' ');
}

IconData _todoIcon(String status) {
  return switch (status) {
    'in_progress' => Icons.timelapse_rounded,
    'pending' => Icons.radio_button_unchecked_rounded,
    'completed' => Icons.check_circle_rounded,
    _ => Icons.circle_outlined,
  };
}
