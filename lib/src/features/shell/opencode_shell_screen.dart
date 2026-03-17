import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/event_stream_service.dart';
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
import '../requests/request_service.dart';
import '../settings/config_service.dart';
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
  bool _showContextSheet = false;
  bool _loading = true;
  String? _error;
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
  List<QuestionRequestSummary> _questionRequests =
      const <QuestionRequestSummary>[];
  List<PermissionRequestSummary> _permissionRequests =
      const <PermissionRequestSummary>[];
  ConfigSnapshot? _configSnapshot;
  IntegrationStatusSnapshot? _integrationStatusSnapshot;
  String? _lastIntegrationAuthUrl;
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
    await _eventStreamService.connect(
      profile: widget.profile,
      project: widget.project,
      onEvent: (event) {
        if (!mounted) {
          return;
        }
        switch (event.type) {
          case 'session.status':
            final sessionId = event.properties['sessionID']?.toString();
            final status = event.properties['status']?.toString();
            if (sessionId != null && status != null) {
              setState(() {
                _statuses = Map<String, SessionStatusSummary>.from(_statuses)
                  ..[sessionId] = SessionStatusSummary(type: status);
              });
            }
          case 'todo.updated':
            final sessionId = _selectedSessionId;
            if (sessionId != null && sessionId.isNotEmpty) {
              _loadTodos(sessionId);
            }
          case 'question.asked':
          case 'permission.asked':
            _loadPendingRequests();
        }
      },
    );
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
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        onSelectSession: _selectSession,
        onForkSession: _forkSession,
        onAbortSession: _abortSession,
        onShareSession: _shareSession,
        onUnshareSession: _unshareSession,
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
        onApplyConfig: _applyConfigRaw,
        onStartProviderAuth: _startProviderAuth,
        onStartMcpAuth: _startMcpAuth,
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
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        onSelectSession: _selectSession,
        onForkSession: _forkSession,
        onAbortSession: _abortSession,
        onShareSession: _shareSession,
        onUnshareSession: _unshareSession,
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
        onApplyConfig: _applyConfigRaw,
        onStartProviderAuth: _startProviderAuth,
        onStartMcpAuth: _startMcpAuth,
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
        todos: _todos,
        selectedSessionId: _selectedSessionId,
        loading: _loading,
        error: _error,
        onSelectSession: _selectSession,
        onForkSession: _forkSession,
        onAbortSession: _abortSession,
        onShareSession: _shareSession,
        onUnshareSession: _unshareSession,
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
      todos: _todos,
      selectedSessionId: _selectedSessionId,
      loading: _loading,
      error: _error,
      onSelectSession: _selectSession,
      onForkSession: _forkSession,
      onAbortSession: _abortSession,
      onShareSession: _shareSession,
      onUnshareSession: _unshareSession,
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
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
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
  });

  final ServerProfile profile;
  final ProjectTarget project;
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
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
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
              onForkSession: onForkSession,
              onAbortSession: onAbortSession,
              onShareSession: onShareSession,
              onUnshareSession: onUnshareSession,
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
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 340,
            child: _ContextRail(
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
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
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
  });

  final ServerProfile profile;
  final ProjectTarget project;
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
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
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
              onForkSession: onForkSession,
              onAbortSession: onAbortSession,
              onShareSession: onShareSession,
              onUnshareSession: onUnshareSession,
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
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 280,
            child: _ContextRail(
              compact: true,
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
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
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
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
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
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
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
            firstChild: _BottomUtilitySheet(
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
    required this.todos,
    required this.selectedSessionId,
    required this.loading,
    required this.error,
    required this.onSelectSession,
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
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
    required this.showContextSheet,
    required this.onToggleContextSheet,
  });

  final ServerProfile profile;
  final ProjectTarget project;
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
  final List<TodoItem> todos;
  final String? selectedSessionId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
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
            firstChild: _BottomUtilitySheet(
              compact: true,
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
    required this.onForkSession,
    required this.onAbortSession,
    required this.onShareSession,
    required this.onUnshareSession,
    required this.onRevertSession,
    required this.onUnrevertSession,
    required this.onInitSession,
    required this.onSummarizeSession,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final VoidCallback onExit;
  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final String? selectedSessionId;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String) onForkSession;
  final Future<void> Function(String) onAbortSession;
  final Future<void> Function(String) onShareSession;
  final Future<void> Function(String) onUnshareSession;
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
                        .map((session) {
                          final depth = orderedSessions[session.id] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: depth * AppSpacing.sm,
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
                          );
                        })
                        .toList(growable: false),
            ),
          ),
        ),
        if (selectedSessionId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _PanelCard(
            title: 'Actions',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => onForkSession(selectedSessionId!),
                  child: const Text('Fork'),
                ),
                OutlinedButton(
                  onPressed: () => onShareSession(selectedSessionId!),
                  child: const Text('Share'),
                ),
                OutlinedButton(
                  onPressed: () => onUnshareSession(selectedSessionId!),
                  child: const Text('Unshare'),
                ),
                OutlinedButton(
                  onPressed: () => onAbortSession(selectedSessionId!),
                  child: const Text('Abort'),
                ),
                OutlinedButton(
                  onPressed: () => onRevertSession(selectedSessionId!),
                  child: const Text('Revert'),
                ),
                OutlinedButton(
                  onPressed: () => onUnrevertSession(selectedSessionId!),
                  child: const Text('Unrevert'),
                ),
                OutlinedButton(
                  onPressed: () => onInitSession(selectedSessionId!),
                  child: const Text('Init'),
                ),
                OutlinedButton(
                  onPressed: () => onSummarizeSession(selectedSessionId!),
                  child: const Text('Summarize'),
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
  const _ContextRail({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _PanelCard(
            title: l10n.shellContextTitle,
            child: Column(
              children: <Widget>[
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
                  _TerminalPanel(
                    command: terminalCommand,
                    result: lastShellResult,
                    running: runningShellCommand,
                    onRun: onRunShellCommand,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PendingRequestsPanel(
                    questions: questionRequests,
                    permissions: permissionRequests,
                    onReplyQuestion: onReplyQuestion,
                    onRejectQuestion: onRejectQuestion,
                    onReplyPermission: onReplyPermission,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ConfigPreviewPanel(
                    snapshot: configSnapshot,
                    onApply: onApplyConfig,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _IntegrationStatusPanel(
                    snapshot: integrationStatusSnapshot,
                    lastAuthorizationUrl: lastIntegrationAuthUrl,
                    onStartProviderAuth: onStartProviderAuth,
                    onStartMcpAuth: onStartMcpAuth,
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
  const _BottomUtilitySheet({
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
      height: compact ? 220 : 260,
      child: _ContextRail(
        compact: true,
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

    return Column(
      children: <Widget>[
        ListTile(
          title: Text(l10n.shellFilesTitle),
          subtitle: Text(l10n.shellFilesSubtitle),
        ),
        TextField(
          controller: TextEditingController(text: fileSearchQuery),
          onSubmitted: onSearchFiles,
          decoration: const InputDecoration(
            hintText: 'Search files, text, or symbols',
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final path in visiblePaths)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ListTile(
              selected: path == selectedFilePath,
              title: Text(path),
              subtitle: Text(_statusFor(path)),
              onTap: () => onSelectFile(path),
            ),
          ),
        if (filePreview != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            filePreview!.content,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (textMatches.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          for (final match in textMatches.take(2))
            ListTile(title: Text(match.path), subtitle: Text(match.lines)),
        ],
        if (symbols.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          for (final symbol in symbols.take(2))
            ListTile(
              title: Text(symbol.name),
              subtitle: Text(
                '${symbol.kind ?? 'symbol'} · ${symbol.path ?? '-'}',
              ),
            ),
        ],
      ],
    );
  }

  String _statusFor(String path) {
    final matches = fileStatuses.where((item) => item.path == path);
    if (matches.isEmpty) {
      return 'tracked';
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
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(l10n.shellTerminalTitle),
          subtitle: Text(l10n.shellTerminalSubtitle),
        ),
        TextField(
          controller: TextEditingController(text: command),
          onSubmitted: onRun,
          decoration: const InputDecoration(hintText: 'pwd', isDense: true),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: running ? null : () => onRun(command),
            child: Text(running ? 'Running...' : 'Run'),
          ),
        ),
        if (result != null)
          ListTile(
            title: Text(result!.messageId),
            subtitle: Text(
              '${result!.providerId ?? '-'} · ${result!.modelId ?? '-'}',
            ),
          ),
      ],
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
    if (questions.isEmpty && permissions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        for (final permission in permissions)
          ListTile(
            title: Text(permission.permission),
            subtitle: Text(permission.patterns.join(', ')),
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                TextButton(
                  onPressed: () => onReplyPermission(permission.id, 'once'),
                  child: const Text('Once'),
                ),
                TextButton(
                  onPressed: () => onReplyPermission(permission.id, 'reject'),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ),
        for (final question in questions)
          ListTile(
            title: Text(question.questions.first.header),
            subtitle: Text(question.questions.first.question),
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                TextButton(
                  onPressed: question.questions.first.options.isEmpty
                      ? null
                      : () => onReplyQuestion(question.id, <List<String>>[
                          <String>[
                            question.questions.first.options.first.label,
                          ],
                        ]),
                  child: const Text('Answer'),
                ),
                TextButton(
                  onPressed: () => onRejectQuestion(question.id),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ),
      ],
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
    final providers = widget.snapshot!.providerConfig.toJson().toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Config'),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _controller,
          maxLines: 8,
          decoration: const InputDecoration(isDense: true),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: _applying
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
            child: Text(_applying ? 'Applying...' : 'Apply config'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(providers, maxLines: 3, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _IntegrationStatusPanel extends StatelessWidget {
  const _IntegrationStatusPanel({
    required this.snapshot,
    required this.lastAuthorizationUrl,
    required this.onStartProviderAuth,
    required this.onStartMcpAuth,
  });

  final IntegrationStatusSnapshot? snapshot;
  final String? lastAuthorizationUrl;
  final Future<void> Function(String) onStartProviderAuth;
  final Future<void> Function(String) onStartMcpAuth;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Integrations'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Providers: ${snapshot!.providerAuth.keys.join(', ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'MCP: ${snapshot!.mcpStatus.entries.map((entry) => '${entry.key}:${entry.value}').join(', ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'LSP: ${snapshot!.lspStatus.entries.map((entry) => '${entry.key}:${entry.value}').join(', ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Formatter: ${snapshot!.formatterStatus.entries.map((entry) => '${entry.key}:${entry.value ? 'enabled' : 'disabled'}').join(', ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (snapshot!.providerAuth.isNotEmpty)
              OutlinedButton(
                onPressed: () =>
                    onStartProviderAuth(snapshot!.providerAuth.keys.first),
                child: const Text('Start provider auth'),
              ),
            if (snapshot!.mcpStatus.isNotEmpty)
              OutlinedButton(
                onPressed: () => onStartMcpAuth(snapshot!.mcpStatus.keys.first),
                child: const Text('Start MCP auth'),
              ),
          ],
        ),
        if (lastAuthorizationUrl != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            lastAuthorizationUrl!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
