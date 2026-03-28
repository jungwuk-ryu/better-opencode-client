import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_controller.dart';
import '../../app/app_release_notes_dialog.dart';
import '../../app/app_scope.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../chat/chat_models.dart';
import '../chat/clipboard_image_service.dart';
import '../chat/prompt_attachment_models.dart';
import '../chat/prompt_attachment_service.dart';
import '../chat/session_context_insights.dart';
import '../commands/command_service.dart';
import '../files/file_models.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../requests/pending_request_notification_service.dart';
import '../requests/pending_request_sound_service.dart';
import '../requests/request_alerts.dart';
import '../requests/request_models.dart';
import '../settings/agent_service.dart';
import '../settings/config_service.dart';
import '../settings/integration_status_service.dart';
import '../terminal/pty_models.dart';
import '../terminal/pty_service.dart';
import '../terminal/pty_terminal_panel.dart';
import '../tools/todo_models.dart';
import 'project_picker_sheet.dart';
import 'workspace_controller.dart';
import 'workspace_layout_store.dart';

enum _CompactWorkspacePane { session, side }

typedef WorkspaceComposerDropFilesHandler =
    Future<void> Function(List<XFile> files);

typedef WorkspaceComposerDropRegionBuilder =
    Widget Function({
      required Widget child,
      required bool enabled,
      required ValueChanged<bool> onHoverChanged,
      required WorkspaceComposerDropFilesHandler onFilesDropped,
    });

_WorkspaceDensity _workspaceDensity(BuildContext context) {
  return _WorkspaceDensity(AppScope.of(context).layoutDensity);
}

class _WorkspaceDensity {
  const _WorkspaceDensity(this.layoutDensity);

  final WorkspaceLayoutDensity layoutDensity;

  bool get compact => layoutDensity == WorkspaceLayoutDensity.compact;

  double inset(double value, {double min = 2}) {
    if (!compact) {
      return value;
    }
    return math.max(min, value * 0.82).toDouble();
  }

  double sidebarWidth(double value) => compact ? 308 : value;
  double sidebarRailWidth(double value) => compact ? 64 : value;
  double sidePanelWidth(double value) => compact ? 320 : value;
  double maxContentWidth(double value) => compact ? value + 80 : value;
}

class _WorkspaceSessionPaneSpec {
  static const Object _sessionIdUnset = Object();

  const _WorkspaceSessionPaneSpec({
    required this.id,
    required this.directory,
    this.sessionId,
  });

  final String id;
  final String directory;
  final String? sessionId;

  _WorkspaceSessionPaneSpec copyWith({
    String? id,
    String? directory,
    Object? sessionId = _sessionIdUnset,
  }) {
    return _WorkspaceSessionPaneSpec(
      id: id ?? this.id,
      directory: directory ?? this.directory,
      sessionId: identical(sessionId, _sessionIdUnset)
          ? this.sessionId
          : sessionId as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'directory': directory,
    'sessionId': sessionId,
  };
}

class _WorkspaceSessionPaneLayoutSnapshot {
  const _WorkspaceSessionPaneLayoutSnapshot({
    required this.panes,
    required this.activePaneId,
  });

  final List<_WorkspaceSessionPaneSpec> panes;
  final String activePaneId;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'activePaneId': activePaneId,
    'panes': panes.map((pane) => pane.toJson()).toList(growable: false),
  };

  _WorkspaceSessionPaneLayoutSnapshot retargetActivePane({
    required String directory,
    String? sessionId,
  }) {
    return _WorkspaceSessionPaneLayoutSnapshot(
      panes: panes
          .map(
            (pane) => pane.id == activePaneId
                ? pane.copyWith(
                    directory: directory,
                    sessionId: _normalizePaneSessionId(sessionId),
                  )
                : pane,
          )
          .toList(growable: false),
      activePaneId: activePaneId,
    );
  }
}

String? _normalizePaneSessionId(String? sessionId) {
  final normalized = sessionId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _workspaceScopedSessionKey({
  required String directory,
  String? sessionId,
}) {
  final normalizedSessionId = sessionId?.trim();
  return '$directory::${normalizedSessionId == null || normalizedSessionId.isEmpty ? 'new' : normalizedSessionId}';
}

class _ResolvedChatSearchState {
  const _ResolvedChatSearchState({
    required this.query,
    required this.sessionId,
    required this.matchMessageIds,
    required this.activeMatchIndex,
    required this.revision,
  });

  final String query;
  final String? sessionId;
  final List<String> matchMessageIds;
  final int activeMatchIndex;
  final int revision;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasMatches => matchMessageIds.isNotEmpty;
  String? get activeMessageId =>
      hasMatches ? matchMessageIds[activeMatchIndex] : null;

  String get statusText {
    if (!hasQuery) {
      return 'Type to search';
    }
    if (!hasMatches) {
      return 'No matches';
    }
    return '${activeMatchIndex + 1} / ${matchMessageIds.length}';
  }
}

class WebParityWorkspaceScreen extends StatefulWidget {
  const WebParityWorkspaceScreen({
    required this.directory,
    this.sessionId,
    this.ptyServiceFactory,
    this.attachmentPicker,
    this.clipboardImageAttachmentLoader,
    this.composerDropRegionBuilder,
    this.projectCatalogService,
    this.integrationStatusService,
    this.pendingRequestNotificationService,
    this.pendingRequestSoundService,
    super.key,
  });

  final String directory;
  final String? sessionId;
  final PtyService Function()? ptyServiceFactory;
  final Future<List<PromptAttachment>> Function()? attachmentPicker;
  final Future<PromptAttachment?> Function()? clipboardImageAttachmentLoader;
  final WorkspaceComposerDropRegionBuilder? composerDropRegionBuilder;
  final ProjectCatalogService? projectCatalogService;
  final IntegrationStatusService? integrationStatusService;
  final PendingRequestNotificationService? pendingRequestNotificationService;
  final PendingRequestSoundService? pendingRequestSoundService;

  @override
  State<WebParityWorkspaceScreen> createState() =>
      _WebParityWorkspaceScreenState();
}

class _WebParityWorkspaceScreenState extends State<WebParityWorkspaceScreen> {
  static const int _maxDesktopSessionPanes = 8;
  static const String _composerDraftKeyPrefix = 'workspace.composerDraft';
  static const String _composerHistoryKeyPrefix = 'workspace.composerHistory';
  static const String _desktopSidebarWidthKeyPrefix =
      'workspace.desktopSidebarWidth';
  static const String _desktopSidePanelWidthKeyPrefix =
      'workspace.desktopSidePanelWidth';
  static const int _maxComposerHistoryEntries = 100;
  static const double _desktopSidebarDefaultWidth = 340;
  static const double _desktopSidebarMinWidth = 260;
  static const double _desktopSidebarMaxWidth = 520;
  static const double _desktopSidePanelDefaultWidth = 360;
  static const double _desktopSidePanelMinWidth = 260;
  static const double _desktopSidePanelMaxWidth = 520;
  static const double _desktopCenterMinWidth = 480;
  static const double _desktopResizeHandleWidth = 12;
  static const Duration _composerDraftPersistDebounce = Duration(
    milliseconds: 250,
  );
  static final PromptAttachmentService _attachmentService =
      PromptAttachmentService();
  static final ClipboardImageService _clipboardImageService =
      ClipboardImageService();
  static const Object _composerRecentDraftUnset = Object();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  WorkspaceController? _controller;
  ServerProfile? _profile;
  final TextEditingController _promptController = TextEditingController();
  final Map<String, TextEditingController> _inactiveComposerControllersByScope =
      <String, TextEditingController>{};
  final Map<String, VoidCallback> _inactiveComposerControllerListenersByScope =
      <String, VoidCallback>{};
  final TextEditingController _chatSearchController = TextEditingController();
  final FocusNode _chatSearchFocusNode = FocusNode();
  List<PromptAttachment> _composerAttachments = const <PromptAttachment>[];
  Map<String, _WorkspaceComposerScopeState> _composerStatesByScope =
      const <String, _WorkspaceComposerScopeState>{};
  bool _pickingComposerAttachments = false;
  bool _chatSearchVisible = false;
  int _chatSearchActiveMatchIndex = 0;
  int _chatSearchRevision = 0;
  String? _chatSearchScopeKey;
  _CompactWorkspacePane _compactPane = _CompactWorkspacePane.session;
  PtyService? _ptyService;
  List<PtySessionInfo> _ptySessions = const <PtySessionInfo>[];
  String? _activePtyId;
  String? _terminalError;
  bool _terminalPanelOpen = false;
  bool _terminalPanelMounted = false;
  bool _loadingPtySessions = false;
  bool _creatingPtySession = false;
  bool _desktopSidebarVisible = true;
  bool _desktopSidePanelVisible = true;
  double _desktopSidebarWidth = _desktopSidebarDefaultWidth;
  double _desktopSidePanelWidth = _desktopSidePanelDefaultWidth;
  int _terminalEpoch = 0;
  bool _hasPendingSessionRouteSync = false;
  bool _sessionRouteSyncInFlight = false;
  String? _pendingSessionRouteId;
  int _sessionRouteSyncRevision = 0;
  Set<String> _promptSubmitInFlightScopeKeys = const <String>{};
  int _promptSubmitEpoch = 0;
  String? _recentSubmittedPromptDraft;
  String? _activeComposerScopeKey;
  Timer? _composerDraftPersistTimer;
  Map<String, String?> _pendingComposerDraftByStorageKey =
      const <String, String?>{};
  Map<String, List<String>> _composerHistoryByScope =
      const <String, List<String>>{};
  Set<String> _loadedComposerHistoryScopeKeys = const <String>{};
  Map<String, int> _composerDraftRevisionByScope = const <String, int>{};
  Map<String, int> _promptComposerFocusTokensByScope = const <String, int>{};
  int _sessionPaneSequence = 0;
  List<_WorkspaceSessionPaneSpec> _desktopSessionPanes =
      const <_WorkspaceSessionPaneSpec>[];
  String? _activeDesktopSessionPaneId;
  int _timelineJumpEpoch = 0;
  Map<String, String> _focusedTimelineMessageIdByScope =
      const <String, String>{};
  Map<String, int> _focusedTimelineMessageRevisionByScope =
      const <String, int>{};
  Map<WorkspaceController, Set<String>> _pendingWatchedSessionIdsByController =
      const <WorkspaceController, Set<String>>{};
  Map<WorkspaceController, Set<String>> _syncedWatchedSessionIdsByController =
      const <WorkspaceController, Set<String>>{};
  Set<WorkspaceController> _observedPaneControllers =
      const <WorkspaceController>{};
  Map<WorkspaceController, PendingRequestBundle>
  _observedPendingRequestsByController =
      const <WorkspaceController, PendingRequestBundle>{};
  Set<WorkspaceController> _primedPendingRequestNotificationControllers =
      const <WorkspaceController>{};
  bool _watchedSessionSyncScheduled = false;
  int _desktopSessionPaneLayoutRevision = 0;
  late String _activeDirectory;
  String? _activeRouteSessionId;
  _WorkspaceProjectLoadingShellState? _projectLoadingShellState;
  late final ProjectCatalogService _projectCatalogService;
  late final bool _ownsProjectCatalogService;
  late IntegrationStatusService _integrationStatusService;
  late bool _ownsIntegrationStatusService;

  PendingRequestNotificationService get _pendingRequestNotificationService =>
      widget.pendingRequestNotificationService ??
      sharedPendingRequestNotificationService;
  PendingRequestSoundService get _pendingRequestSoundService =>
      widget.pendingRequestSoundService ?? sharedPendingRequestSoundService;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_handlePromptControllerChanged);
    _activeDirectory = widget.directory;
    _activeRouteSessionId = widget.sessionId;
    _resetDesktopSessionPanes(
      initialDirectory: widget.directory,
      initialSessionId: widget.sessionId,
    );
    _projectCatalogService =
        widget.projectCatalogService ?? ProjectCatalogService();
    _ownsProjectCatalogService = widget.projectCatalogService == null;
    _integrationStatusService =
        widget.integrationStatusService ?? IntegrationStatusService();
    _ownsIntegrationStatusService = widget.integrationStatusService == null;
  }

  String get _currentDirectory => _activeDirectory;

  bool get _activePromptSubmitInFlight =>
      _activeComposerScopeKey != null &&
      _promptSubmitInFlightScopeKeys.contains(_activeComposerScopeKey);

  String _composerScopeKey({required String directory, String? sessionId}) {
    return _workspaceScopedSessionKey(
      directory: directory,
      sessionId: sessionId,
    );
  }

  String _resolvedActiveComposerScopeKey(WorkspaceController? controller) {
    return _activeComposerScopeKey ??
        _composerScopeKey(
          directory: controller?.directory ?? _activeDirectory,
          sessionId: controller?.selectedSessionId ?? _activeRouteSessionId,
        );
  }

  bool _isActiveComposerScope(String scopeKey) {
    return scopeKey == _resolvedActiveComposerScopeKey(_controller);
  }

  String _timelineFocusScopeKey({
    required String directory,
    String? sessionId,
  }) {
    return _composerScopeKey(directory: directory, sessionId: sessionId);
  }

  String? _focusedTimelineMessageIdForScope(String scopeKey) {
    return _focusedTimelineMessageIdByScope[scopeKey];
  }

  int _focusedTimelineMessageRevisionForScope(String scopeKey) {
    return _focusedTimelineMessageRevisionByScope[scopeKey] ?? 0;
  }

  void _requestTimelineMessageFocus({
    required String directory,
    required String? sessionId,
    required String messageId,
  }) {
    final normalizedMessageId = messageId.trim();
    if (normalizedMessageId.isEmpty) {
      return;
    }
    final scopeKey = _timelineFocusScopeKey(
      directory: directory,
      sessionId: sessionId,
    );
    setState(() {
      _focusedTimelineMessageIdByScope = Map<String, String>.unmodifiable(
        <String, String>{
          ..._focusedTimelineMessageIdByScope,
          scopeKey: normalizedMessageId,
        },
      );
      _focusedTimelineMessageRevisionByScope = Map<String, int>.unmodifiable(
        <String, int>{
          ..._focusedTimelineMessageRevisionByScope,
          scopeKey: (_focusedTimelineMessageRevisionByScope[scopeKey] ?? 0) + 1,
        },
      );
    });
  }

  TextEditingController _composerControllerForScope(String scopeKey) {
    if (_isActiveComposerScope(scopeKey)) {
      return _promptController;
    }
    final existing = _inactiveComposerControllersByScope[scopeKey];
    if (existing != null) {
      return existing;
    }
    final controller = TextEditingController(
      text: _composerScopeState(scopeKey).draft,
    );
    late final VoidCallback listener;
    listener = () {
      if (!mounted ||
          !identical(
            _inactiveComposerControllersByScope[scopeKey],
            controller,
          )) {
        return;
      }
      _updateComposerScopeState(scopeKey, draft: controller.text);
    };
    controller.addListener(listener);
    _inactiveComposerControllersByScope[scopeKey] = controller;
    _inactiveComposerControllerListenersByScope[scopeKey] = listener;
    return controller;
  }

  void _disposeInactiveComposerController(String scopeKey) {
    final controller = _inactiveComposerControllersByScope.remove(scopeKey);
    final listener = _inactiveComposerControllerListenersByScope.remove(
      scopeKey,
    );
    if (controller == null) {
      return;
    }
    if (listener != null) {
      controller.removeListener(listener);
    }
    controller.dispose();
  }

  void _syncInactiveComposerController(String scopeKey, String draft) {
    if (_isActiveComposerScope(scopeKey)) {
      return;
    }
    final controller = _inactiveComposerControllersByScope[scopeKey];
    if (controller == null || controller.text == draft) {
      return;
    }
    controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
      composing: TextRange.empty,
    );
  }

  int _promptComposerFocusTokenForScope(String scopeKey) =>
      _promptComposerFocusTokensByScope[scopeKey] ?? 0;

  int _submittedDraftEpochForScope(String scopeKey) {
    if (_isActiveComposerScope(scopeKey)) {
      return _promptSubmitEpoch;
    }
    return _composerScopeState(scopeKey).submittedDraftEpoch;
  }

  String? _recentSubmittedDraftForScope(String scopeKey) {
    if (_isActiveComposerScope(scopeKey)) {
      return _recentSubmittedPromptDraft;
    }
    return _composerScopeState(scopeKey).recentSubmittedDraft;
  }

  String _composerScopeKeyForPane(_WorkspacePaneViewModel paneViewModel) {
    return _composerScopeKey(
      directory: paneViewModel.pane.directory,
      sessionId: paneViewModel.pane.sessionId,
    );
  }

  void _requestPromptComposerFocusForScope(String scopeKey) {
    final next = Map<String, int>.from(_promptComposerFocusTokensByScope);
    next[scopeKey] = (next[scopeKey] ?? 0) + 1;
    _promptComposerFocusTokensByScope = Map<String, int>.unmodifiable(next);
  }

  Future<WorkspaceController?> _activatePaneComposer(
    _WorkspacePaneViewModel paneViewModel, {
    bool requestFocus = false,
  }) async {
    final pane = paneViewModel.pane;
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    final activeController = _controller;
    if (_activeDesktopSessionPaneId != pane.id && activeController != null) {
      await _activateDesktopSessionPane(activeController, pane.id);
    } else if (_controller?.selectedSessionId != pane.sessionId) {
      await _controller?.selectSession(pane.sessionId);
    }
    if (!mounted) {
      return null;
    }
    final targetController = _controller;
    if (requestFocus) {
      setState(() {
        _requestPromptComposerFocusForScope(scopeKey);
      });
    }
    return targetController;
  }

  Future<void> _pickComposerAttachmentsForScope(String scopeKey) async {
    if (_promptSubmitInFlightScopeKeys.contains(scopeKey) ||
        _pickingComposerAttachments) {
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
      final nextAttachments = <PromptAttachment>[
        ..._composerAttachmentsForScope(scopeKey),
        ...attachments,
      ];
      setState(() {
        _updateComposerScopeState(scopeKey, attachments: nextAttachments);
        if (_activeComposerScopeKey == scopeKey) {
          _composerAttachments = List<PromptAttachment>.unmodifiable(
            nextAttachments,
          );
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to attach files: $error',
        tone: AppSnackBarTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingComposerAttachments = false;
        });
      }
    }
  }

  Future<PromptAttachment?> _loadClipboardImageAttachment() async {
    final loader = widget.clipboardImageAttachmentLoader;
    if (loader != null) {
      return loader();
    }
    return _clipboardImageService.loadClipboardImageAttachment(
      _attachmentService,
    );
  }

  Future<bool> _tryPasteComposerClipboardImageForScope(String scopeKey) async {
    if (_promptSubmitInFlightScopeKeys.contains(scopeKey)) {
      return false;
    }
    try {
      final attachment = await _loadClipboardImageAttachment();
      if (!mounted || attachment == null) {
        return false;
      }
      return _appendComposerAttachmentsForScope(scopeKey, <PromptAttachment>[
        attachment,
      ], requestFocus: true);
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          'Failed to paste image: $error',
          tone: AppSnackBarTone.danger,
        );
      }
      return false;
    }
  }

  Future<void> _handleComposerContentInsertionForScope(
    String scopeKey,
    KeyboardInsertedContent content,
  ) async {
    if (_promptSubmitInFlightScopeKeys.contains(scopeKey)) {
      return;
    }
    final attachment = _attachmentService.attachmentFromInsertedContent(
      content,
    );
    if (attachment == null) {
      if (mounted && content.mimeType.startsWith('image/')) {
        _showSnackBar(
          'This image format is not supported for chat attachments.',
          tone: AppSnackBarTone.warning,
        );
      }
      return;
    }
    _appendComposerAttachmentsForScope(scopeKey, <PromptAttachment>[
      attachment,
    ], requestFocus: true);
  }

  bool _appendComposerAttachmentsForScope(
    String scopeKey,
    List<PromptAttachment> attachments, {
    bool requestFocus = false,
  }) {
    if (attachments.isEmpty) {
      return false;
    }
    final nextAttachments = List<PromptAttachment>.from(
      _composerAttachmentsForScope(scopeKey),
    );
    final existingIds = nextAttachments
        .map((attachment) => attachment.id)
        .toSet();
    var added = false;
    for (final attachment in attachments) {
      if (!existingIds.add(attachment.id)) {
        continue;
      }
      nextAttachments.add(attachment);
      added = true;
    }
    if (!added) {
      return false;
    }
    final frozen = List<PromptAttachment>.unmodifiable(nextAttachments);
    setState(() {
      _updateComposerScopeState(scopeKey, attachments: frozen);
      if (_activeComposerScopeKey == scopeKey) {
        _composerAttachments = frozen;
      }
      if (requestFocus) {
        _requestPromptComposerFocusForScope(scopeKey);
      }
    });
    return true;
  }

  void _removeComposerAttachmentForScope(String scopeKey, String attachmentId) {
    final nextAttachments = _composerAttachmentsForScope(scopeKey)
        .where((attachment) => attachment.id != attachmentId)
        .toList(growable: false);
    setState(() {
      if (_activeComposerScopeKey == scopeKey) {
        _composerAttachments = List<PromptAttachment>.unmodifiable(
          nextAttachments,
        );
      }
      _updateComposerScopeState(scopeKey, attachments: nextAttachments);
    });
  }

  String _composerDraftStorageKey(String profileStorageKey, String scopeKey) =>
      '$_composerDraftKeyPrefix::$profileStorageKey::$scopeKey';

  int _composerDraftRevision(String scopeKey) =>
      _composerDraftRevisionByScope[scopeKey] ?? 0;

  void _bumpComposerDraftRevision(String scopeKey) {
    final updated = Map<String, int>.from(_composerDraftRevisionByScope);
    updated[scopeKey] = (updated[scopeKey] ?? 0) + 1;
    _composerDraftRevisionByScope = Map<String, int>.unmodifiable(updated);
  }

  void _queueComposerDraftPersist(String scopeKey, String draft) {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final storageKey = _composerDraftStorageKey(profile.storageKey, scopeKey);
    final next = Map<String, String?>.from(_pendingComposerDraftByStorageKey);
    next[storageKey] = draft.isEmpty ? null : draft;
    _pendingComposerDraftByStorageKey = Map<String, String?>.unmodifiable(next);
    _composerDraftPersistTimer?.cancel();
    _composerDraftPersistTimer = Timer(_composerDraftPersistDebounce, () {
      _composerDraftPersistTimer = null;
      unawaited(_flushPendingComposerDraftPersists());
    });
  }

  Future<void> _flushPendingComposerDraftPersists() async {
    final pending = _pendingComposerDraftByStorageKey;
    if (pending.isEmpty) {
      return;
    }
    _composerDraftPersistTimer?.cancel();
    _composerDraftPersistTimer = null;
    _pendingComposerDraftByStorageKey = const <String, String?>{};
    final prefs = await SharedPreferences.getInstance();
    for (final entry in pending.entries) {
      final draft = entry.value;
      if (draft == null || draft.isEmpty) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, draft);
      }
    }
  }

  _WorkspaceComposerScopeState _composerScopeState(String scopeKey) {
    return _composerStatesByScope[scopeKey] ??
        const _WorkspaceComposerScopeState();
  }

  List<PromptAttachment> _composerAttachmentsForScope(String scopeKey) {
    if (_isActiveComposerScope(scopeKey)) {
      return _composerAttachments;
    }
    return _composerScopeState(scopeKey).attachments;
  }

  void _updateComposerScopeState(
    String scopeKey, {
    String? draft,
    List<PromptAttachment>? attachments,
    int? submittedDraftEpoch,
    Object? recentSubmittedDraft = _composerRecentDraftUnset,
    bool persistDraft = true,
  }) {
    final current = _composerScopeState(scopeKey);
    final nextDraft = draft ?? current.draft;
    final nextAttachments = attachments == null
        ? current.attachments
        : List<PromptAttachment>.unmodifiable(attachments);
    final nextSubmittedDraftEpoch =
        submittedDraftEpoch ?? current.submittedDraftEpoch;
    final nextRecentSubmittedDraft =
        identical(recentSubmittedDraft, _composerRecentDraftUnset)
        ? current.recentSubmittedDraft
        : recentSubmittedDraft as String?;
    final next = _WorkspaceComposerScopeState(
      draft: nextDraft,
      attachments: nextAttachments,
      submittedDraftEpoch: nextSubmittedDraftEpoch,
      recentSubmittedDraft: nextRecentSubmittedDraft,
    );
    final draftChanged = nextDraft != current.draft;
    final attachmentsChanged = !listEquals(
      nextAttachments,
      current.attachments,
    );
    final submittedDraftEpochChanged =
        nextSubmittedDraftEpoch != current.submittedDraftEpoch;
    final recentSubmittedDraftChanged =
        nextRecentSubmittedDraft != current.recentSubmittedDraft;
    if (!draftChanged &&
        !attachmentsChanged &&
        !submittedDraftEpochChanged &&
        !recentSubmittedDraftChanged) {
      return;
    }
    final updated = Map<String, _WorkspaceComposerScopeState>.from(
      _composerStatesByScope,
    );
    if (next.isEmpty) {
      updated.remove(scopeKey);
    } else {
      updated[scopeKey] = next;
    }
    _composerStatesByScope =
        Map<String, _WorkspaceComposerScopeState>.unmodifiable(updated);
    if (draftChanged) {
      _bumpComposerDraftRevision(scopeKey);
      if (persistDraft) {
        _queueComposerDraftPersist(scopeKey, nextDraft);
      }
      _syncInactiveComposerController(scopeKey, nextDraft);
    }
  }

  void _persistActiveComposerScope() {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null) {
      return;
    }
    _updateComposerScopeState(
      scopeKey,
      draft: _promptController.text,
      attachments: _composerAttachments,
      submittedDraftEpoch: _promptSubmitEpoch,
      recentSubmittedDraft: _recentSubmittedPromptDraft,
    );
  }

  void _activateComposerScope(String scopeKey) {
    if (_activeComposerScopeKey == scopeKey) {
      unawaited(_restorePersistedComposerDraft(scopeKey));
      unawaited(_restorePersistedComposerHistory(scopeKey));
      return;
    }
    _persistActiveComposerScope();
    _disposeInactiveComposerController(scopeKey);
    _activeComposerScopeKey = scopeKey;
    final state = _composerScopeState(scopeKey);
    _composerAttachments = List<PromptAttachment>.unmodifiable(
      state.attachments,
    );
    _promptSubmitEpoch = state.submittedDraftEpoch;
    _recentSubmittedPromptDraft = state.recentSubmittedDraft;
    final draft = state.draft;
    _promptController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
      composing: TextRange.empty,
    );
    unawaited(_restorePersistedComposerDraft(scopeKey));
    unawaited(_restorePersistedComposerHistory(scopeKey));
  }

  void _syncComposerScopeForController(WorkspaceController controller) {
    final scopeKey = _composerScopeKey(
      directory: controller.directory,
      sessionId: controller.selectedSessionId,
    );
    _activateComposerScope(scopeKey);
  }

  void _handlePromptControllerChanged() {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null) {
      return;
    }
    _updateComposerScopeState(scopeKey, draft: _promptController.text);
  }

  Future<void> _restorePersistedComposerDraft(String scopeKey) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    if (_composerScopeState(scopeKey).draft.isNotEmpty) {
      return;
    }
    final revision = _composerDraftRevision(scopeKey);
    final storageKey = _composerDraftStorageKey(profile.storageKey, scopeKey);
    if (_pendingComposerDraftByStorageKey.containsKey(storageKey)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final persistedDraft = prefs.getString(storageKey);
    if (persistedDraft == null || persistedDraft.isEmpty) {
      return;
    }
    if (!mounted ||
        _profile?.storageKey != profile.storageKey ||
        _composerDraftRevision(scopeKey) != revision ||
        _composerScopeState(scopeKey).draft.isNotEmpty) {
      return;
    }
    setState(() {
      _updateComposerScopeState(
        scopeKey,
        draft: persistedDraft,
        persistDraft: false,
      );
      if (_activeComposerScopeKey == scopeKey &&
          _promptController.text.isEmpty) {
        _promptController.value = TextEditingValue(
          text: persistedDraft,
          selection: TextSelection.collapsed(offset: persistedDraft.length),
          composing: TextRange.empty,
        );
      }
    });
  }

  String _composerHistoryStorageKey(
    String profileStorageKey,
    String scopeKey,
  ) => '$_composerHistoryKeyPrefix::$profileStorageKey::$scopeKey';

  List<String> _composerHistoryForScope(String scopeKey) {
    return _composerHistoryByScope[scopeKey] ?? const <String>[];
  }

  void _setComposerHistoryForScope(String scopeKey, List<String> entries) {
    final nextEntries = List<String>.unmodifiable(entries);
    final updated = Map<String, List<String>>.from(_composerHistoryByScope);
    if (nextEntries.isEmpty) {
      updated.remove(scopeKey);
    } else {
      updated[scopeKey] = nextEntries;
    }
    _composerHistoryByScope = Map<String, List<String>>.unmodifiable(updated);
  }

  Future<void> _persistComposerHistoryForScope(String scopeKey) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _composerHistoryStorageKey(profile.storageKey, scopeKey);
    final entries = _composerHistoryForScope(scopeKey);
    if (entries.isEmpty) {
      await prefs.remove(storageKey);
      return;
    }
    await prefs.setStringList(storageKey, entries);
  }

  Future<void> _restorePersistedComposerHistory(String scopeKey) async {
    final profile = _profile;
    if (profile == null || _loadedComposerHistoryScopeKeys.contains(scopeKey)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(
      _composerHistoryStorageKey(profile.storageKey, scopeKey),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      final loaded = Set<String>.from(_loadedComposerHistoryScopeKeys)
        ..add(scopeKey);
      _loadedComposerHistoryScopeKeys = Set<String>.unmodifiable(loaded);
      if (entries == null || entries.isEmpty) {
        return;
      }
      _setComposerHistoryForScope(
        scopeKey,
        entries
            .map((item) => item.trimRight())
            .where((item) => item.trim().isNotEmpty)
            .take(_maxComposerHistoryEntries)
            .toList(growable: false),
      );
    });
  }

  Future<void> _appendComposerHistoryEntry(
    String scopeKey,
    String draft,
  ) async {
    final trimmed = draft.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final current = _composerHistoryForScope(scopeKey);
    final next = <String>[trimmed];
    for (final entry in current) {
      if (entry == trimmed) {
        continue;
      }
      next.add(entry);
      if (next.length >= _maxComposerHistoryEntries) {
        break;
      }
    }
    if (listEquals(current, next)) {
      return;
    }
    if (mounted) {
      setState(() {
        _setComposerHistoryForScope(scopeKey, next);
      });
    } else {
      _setComposerHistoryForScope(scopeKey, next);
    }
    await _persistComposerHistoryForScope(scopeKey);
  }

  void _handleActiveWorkspaceControllerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    final paneLayoutChanged = _commitSelectedSessionToActivePane(controller);
    final scopeKey = _composerScopeKey(
      directory: controller.directory,
      sessionId: controller.selectedSessionId,
    );
    if (scopeKey == _activeComposerScopeKey) {
      if (paneLayoutChanged) {
        unawaited(_persistDesktopSessionPaneLayout());
      }
      return;
    }
    setState(() {
      _activateComposerScope(scopeKey);
    });
    if (paneLayoutChanged) {
      unawaited(_persistDesktopSessionPaneLayout());
    }
  }

  void _showSnackBar(
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.info,
    Duration duration = const Duration(seconds: 4),
    AppSnackBarAction? action,
    bool replaceCurrent = false,
  }) {
    showAppSnackBar(
      context,
      message: message,
      tone: tone,
      duration: duration,
      action: action,
      replaceCurrent: replaceCurrent,
    );
  }

  int _nextSessionPaneSequenceFor(Iterable<_WorkspaceSessionPaneSpec> panes) {
    final pattern = RegExp(r'^pane_(\d+)$');
    var nextSequence = 0;
    for (final pane in panes) {
      final match = pattern.firstMatch(pane.id);
      final value = match == null ? null : int.tryParse(match.group(1)!);
      if (value != null && value >= nextSequence) {
        nextSequence = value + 1;
      }
    }
    return math.max(nextSequence, panes.length);
  }

  bool _sameDesktopSessionPaneSpecs(
    List<_WorkspaceSessionPaneSpec> left,
    List<_WorkspaceSessionPaneSpec> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      final leftPane = left[index];
      final rightPane = right[index];
      if (leftPane.id != rightPane.id ||
          leftPane.directory != rightPane.directory ||
          leftPane.sessionId != rightPane.sessionId) {
        return false;
      }
    }
    return true;
  }

  _WorkspaceSessionPaneLayoutSnapshot? _desktopSessionPaneLayoutSnapshot() {
    if (_desktopSessionPanes.isEmpty) {
      return null;
    }
    final activePaneId =
        _activeDesktopSessionPaneId ??
        (_desktopSessionPanes.isNotEmpty
            ? _desktopSessionPanes.first.id
            : null);
    if (activePaneId == null) {
      return null;
    }
    final normalizedPanes = _desktopSessionPanes
        .map(
          (pane) => pane.id == activePaneId
              ? pane.copyWith(
                  directory: _activeDirectory,
                  sessionId: _normalizePaneSessionId(
                    _controller?.selectedSessionId ?? pane.sessionId,
                  ),
                )
              : pane.copyWith(
                  sessionId: _normalizePaneSessionId(pane.sessionId),
                ),
        )
        .toList(growable: false);
    final resolvedActivePaneId =
        normalizedPanes.any((pane) => pane.id == activePaneId)
        ? activePaneId
        : normalizedPanes.first.id;
    return _WorkspaceSessionPaneLayoutSnapshot(
      panes: List<_WorkspaceSessionPaneSpec>.unmodifiable(normalizedPanes),
      activePaneId: resolvedActivePaneId,
    );
  }

  WorkspacePaneLayoutSnapshot _persistedPaneLayoutSnapshot(
    _WorkspaceSessionPaneLayoutSnapshot snapshot,
  ) {
    return WorkspacePaneLayoutSnapshot(
      panes: snapshot.panes
          .map(
            (pane) => WorkspacePaneLayoutPane(
              id: pane.id,
              directory: pane.directory,
              sessionId: pane.sessionId,
            ),
          )
          .toList(growable: false),
      activePaneId: snapshot.activePaneId,
    );
  }

  _WorkspaceSessionPaneLayoutSnapshot _workspacePaneLayoutSnapshotFromStore(
    WorkspacePaneLayoutSnapshot snapshot,
  ) {
    return _WorkspaceSessionPaneLayoutSnapshot(
      panes: snapshot.panes
          .map(
            (pane) => _WorkspaceSessionPaneSpec(
              id: pane.id,
              directory: pane.directory,
              sessionId: pane.sessionId,
            ),
          )
          .toList(growable: false),
      activePaneId: snapshot.activePaneId,
    );
  }

  void _recordDesktopSessionPaneLayoutChange() {
    _desktopSessionPaneLayoutRevision += 1;
  }

  Future<void> _persistDesktopSessionPaneLayout() async {
    final profile = _profile;
    final snapshot = _desktopSessionPaneLayoutSnapshot();
    if (profile == null || snapshot == null) {
      return;
    }
    final appController = AppScope.of(context);
    await appController.persistWorkspacePaneLayout(
      profile: profile,
      snapshot: _persistedPaneLayoutSnapshot(snapshot),
    );
  }

  String _desktopSidebarWidthStorageKey(ServerProfile profile) =>
      '$_desktopSidebarWidthKeyPrefix::${profile.storageKey}';

  String _desktopSidePanelWidthStorageKey(ServerProfile profile) =>
      '$_desktopSidePanelWidthKeyPrefix::${profile.storageKey}';

  Future<void> _restorePersistedDesktopColumnWidths(
    ServerProfile profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final restoredSidebarWidth = prefs.getDouble(
      _desktopSidebarWidthStorageKey(profile),
    );
    final restoredSidePanelWidth = prefs.getDouble(
      _desktopSidePanelWidthStorageKey(profile),
    );
    if (!mounted || _profile?.storageKey != profile.storageKey) {
      return;
    }
    setState(() {
      _desktopSidebarWidth = restoredSidebarWidth?.isFinite == true
          ? restoredSidebarWidth!
                .clamp(_desktopSidebarMinWidth, _desktopSidebarMaxWidth)
                .toDouble()
          : _desktopSidebarDefaultWidth;
      _desktopSidePanelWidth = restoredSidePanelWidth?.isFinite == true
          ? restoredSidePanelWidth!
                .clamp(_desktopSidePanelMinWidth, _desktopSidePanelMaxWidth)
                .toDouble()
          : _desktopSidePanelDefaultWidth;
    });
  }

  Future<void> _persistDesktopColumnWidths() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      _desktopSidebarWidthStorageKey(profile),
      _desktopSidebarWidth,
    );
    await prefs.setDouble(
      _desktopSidePanelWidthStorageKey(profile),
      _desktopSidePanelWidth,
    );
  }

  ({double sidebarWidth, double sidePanelWidth}) _resolvedDesktopColumnWidths({
    required double totalWidth,
    required bool sidebarVisible,
    required bool sidePanelVisible,
  }) {
    final visibleHandleCount =
        (sidebarVisible ? 1 : 0) + (sidePanelVisible ? 1 : 0);
    final reservedHandleWidth = visibleHandleCount * _desktopResizeHandleWidth;

    var sidebarWidth = 0.0;
    if (sidebarVisible) {
      final maxSidebarWidth = math.min(
        _desktopSidebarMaxWidth,
        totalWidth -
            _desktopCenterMinWidth -
            reservedHandleWidth -
            (sidePanelVisible ? _desktopSidePanelMinWidth : 0),
      );
      sidebarWidth = _desktopSidebarWidth
          .clamp(
            _desktopSidebarMinWidth,
            math.max(_desktopSidebarMinWidth, maxSidebarWidth),
          )
          .toDouble();
    }

    var sidePanelWidth = 0.0;
    if (sidePanelVisible) {
      final maxSidePanelWidth = math.min(
        _desktopSidePanelMaxWidth,
        totalWidth -
            _desktopCenterMinWidth -
            reservedHandleWidth -
            (sidebarVisible ? sidebarWidth : 0),
      );
      sidePanelWidth = _desktopSidePanelWidth
          .clamp(
            _desktopSidePanelMinWidth,
            math.max(_desktopSidePanelMinWidth, maxSidePanelWidth),
          )
          .toDouble();
    }

    return (sidebarWidth: sidebarWidth, sidePanelWidth: sidePanelWidth);
  }

  double _maxDesktopSidebarWidth({
    required double totalWidth,
    required bool sidePanelVisible,
  }) {
    final reservedHandleWidth =
        _desktopResizeHandleWidth +
        (sidePanelVisible ? _desktopResizeHandleWidth : 0);
    return math.min(
      _desktopSidebarMaxWidth,
      totalWidth -
          _desktopCenterMinWidth -
          reservedHandleWidth -
          (sidePanelVisible ? _desktopSidePanelMinWidth : 0),
    );
  }

  double _maxDesktopSidePanelWidth({
    required double totalWidth,
    required bool sidebarVisible,
    required double sidebarWidth,
  }) {
    final reservedHandleWidth =
        _desktopResizeHandleWidth +
        (sidebarVisible ? _desktopResizeHandleWidth : 0);
    return math.min(
      _desktopSidePanelMaxWidth,
      totalWidth -
          _desktopCenterMinWidth -
          reservedHandleWidth -
          (sidebarVisible ? sidebarWidth : 0),
    );
  }

  void _resizeDesktopSidebar({
    required double widthDelta,
    required double totalWidth,
    required bool sidePanelVisible,
    required double currentWidth,
  }) {
    final maxWidth = _maxDesktopSidebarWidth(
      totalWidth: totalWidth,
      sidePanelVisible: sidePanelVisible,
    );
    final clampedWidth = (currentWidth + widthDelta)
        .clamp(
          _desktopSidebarMinWidth,
          math.max(_desktopSidebarMinWidth, maxWidth),
        )
        .toDouble();
    if ((clampedWidth - currentWidth).abs() < 0.01) {
      return;
    }
    setState(() {
      _desktopSidebarWidth = clampedWidth;
    });
  }

  void _resizeDesktopSidePanel({
    required double widthDelta,
    required double totalWidth,
    required bool sidebarVisible,
    required double currentWidth,
  }) {
    final resolvedSidebarWidth = sidebarVisible
        ? _resolvedDesktopColumnWidths(
            totalWidth: totalWidth,
            sidebarVisible: true,
            sidePanelVisible: true,
          ).sidebarWidth
        : 0.0;
    final maxWidth = _maxDesktopSidePanelWidth(
      totalWidth: totalWidth,
      sidebarVisible: sidebarVisible,
      sidebarWidth: resolvedSidebarWidth,
    );
    final clampedWidth = (currentWidth + widthDelta)
        .clamp(
          _desktopSidePanelMinWidth,
          math.max(_desktopSidePanelMinWidth, maxWidth),
        )
        .toDouble();
    if ((clampedWidth - currentWidth).abs() < 0.01) {
      return;
    }
    setState(() {
      _desktopSidePanelWidth = clampedWidth;
    });
  }

  void _finishDesktopColumnResize() {
    unawaited(_persistDesktopColumnWidths());
  }

  Future<void> _restorePersistedDesktopSessionPaneLayout({
    required ServerProfile profile,
    required String initialDirectory,
    String? initialSessionId,
  }) async {
    final startingRevision = _desktopSessionPaneLayoutRevision;
    final appController = AppScope.of(context);
    final storedSnapshot =
        appController.workspacePaneLayoutFor(profile) ??
        await appController.ensureWorkspacePaneLayout(profile);
    final stillCurrentProfile =
        mounted &&
        _profile?.storageKey == profile.storageKey &&
        _desktopSessionPaneLayoutRevision == startingRevision;
    if (!stillCurrentProfile) {
      return;
    }
    if (storedSnapshot == null) {
      await _persistDesktopSessionPaneLayout();
      return;
    }
    final snapshot = _workspacePaneLayoutSnapshotFromStore(storedSnapshot);
    final restored = snapshot.retargetActivePane(
      directory: initialDirectory,
      sessionId: initialSessionId,
    );
    if (!_sameDesktopSessionPaneSpecs(_desktopSessionPanes, restored.panes) ||
        _activeDesktopSessionPaneId != restored.activePaneId) {
      setState(() {
        _desktopSessionPanes = restored.panes;
        _activeDesktopSessionPaneId = restored.activePaneId;
        _sessionPaneSequence = _nextSessionPaneSequenceFor(restored.panes);
        _timelineJumpEpoch += 1;
      });
      _recordDesktopSessionPaneLayoutChange();
    } else {
      _sessionPaneSequence = _nextSessionPaneSequenceFor(restored.panes);
    }
    await _persistDesktopSessionPaneLayout();
  }

  void _resetDesktopSessionPanes({
    required String initialDirectory,
    String? initialSessionId,
  }) {
    final pane = _WorkspaceSessionPaneSpec(
      id: 'pane_${_sessionPaneSequence++}',
      directory: initialDirectory,
      sessionId: initialSessionId,
    );
    _desktopSessionPanes = <_WorkspaceSessionPaneSpec>[pane];
    _activeDesktopSessionPaneId = pane.id;
    _timelineJumpEpoch += 1;
    _recordDesktopSessionPaneLayoutChange();
  }

  void _retargetActivePane({required String directory, String? sessionId}) {
    final activePaneId = _activeDesktopSessionPaneId;
    if (activePaneId == null || _desktopSessionPanes.isEmpty) {
      _resetDesktopSessionPanes(
        initialDirectory: directory,
        initialSessionId: sessionId,
      );
      return;
    }
    var foundActivePane = false;
    _desktopSessionPanes = _desktopSessionPanes
        .map((pane) {
          if (pane.id != activePaneId) {
            return pane;
          }
          foundActivePane = true;
          return pane.copyWith(directory: directory, sessionId: sessionId);
        })
        .toList(growable: false);
    if (!foundActivePane) {
      _resetDesktopSessionPanes(
        initialDirectory: directory,
        initialSessionId: sessionId,
      );
      return;
    }
    _recordDesktopSessionPaneLayoutChange();
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
    if (oldWidget.integrationStatusService != widget.integrationStatusService) {
      if (_ownsIntegrationStatusService) {
        _integrationStatusService.dispose();
      }
      _integrationStatusService =
          widget.integrationStatusService ?? IntegrationStatusService();
      _ownsIntegrationStatusService = widget.integrationStatusService == null;
    }
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
    _persistActiveComposerScope();
    _composerDraftPersistTimer?.cancel();
    if (_pendingComposerDraftByStorageKey.isNotEmpty) {
      unawaited(_flushPendingComposerDraftPersists());
    }
    _disposeController();
    for (final scopeKey in _inactiveComposerControllersByScope.keys.toList()) {
      _disposeInactiveComposerController(scopeKey);
    }
    _promptController.removeListener(_handlePromptControllerChanged);
    _promptController.dispose();
    _chatSearchController.dispose();
    _chatSearchFocusNode.dispose();
    _ptyService?.dispose();
    if (_ownsProjectCatalogService) {
      _projectCatalogService.dispose();
    }
    if (_ownsIntegrationStatusService) {
      _integrationStatusService.dispose();
    }
    super.dispose();
  }

  void _disposeController() {
    _clearWatchedSessionSync();
    _clearObservedPaneControllers();
    _controller?.removeListener(_handleActiveWorkspaceControllerChanged);
    _controller = null;
    _projectLoadingShellState = null;
  }

  void _bindWorkspace({
    required WebParityAppController appController,
    required ServerProfile profile,
    required String directory,
    String? routeSessionId,
    bool resetPaneDeck = false,
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
    final previousController = _controller;
    final profileChanged = _profile?.storageKey != profile.storageKey;
    final directoryChanged = _activeDirectory != directory;
    final bindingChanged =
        !identical(_controller, nextController) ||
        profileChanged ||
        directoryChanged;

    if (!identical(previousController, nextController)) {
      previousController?.removeListener(
        _handleActiveWorkspaceControllerChanged,
      );
      nextController.addListener(_handleActiveWorkspaceControllerChanged);
    }
    _controller = nextController;
    _profile = profile;
    _activeDirectory = directory;
    _activeRouteSessionId = routeSessionId;
    _syncComposerScopeForController(nextController);

    if (profileChanged || resetPaneDeck) {
      _compactPane = _CompactWorkspacePane.session;
      _resetDesktopSessionPanes(
        initialDirectory: directory,
        initialSessionId: routeSessionId,
      );
      _resetTerminalState(profile);
      unawaited(_restorePersistedDesktopColumnWidths(profile));
      unawaited(
        _restorePersistedDesktopSessionPaneLayout(
          profile: profile,
          initialDirectory: directory,
          initialSessionId: routeSessionId,
        ),
      );
    } else if (bindingChanged) {
      _compactPane = _CompactWorkspacePane.session;
      _retargetActivePane(
        directory: directory,
        sessionId: routeSessionId ?? nextController.selectedSessionId,
      );
      if (directoryChanged) {
        _resetTerminalState(profile);
      }
      unawaited(_persistDesktopSessionPaneLayout());
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

  void _setDesktopSidebarVisible(bool visible) {
    if (_desktopSidebarVisible == visible) {
      return;
    }
    setState(() {
      _desktopSidebarVisible = visible;
    });
  }

  void _toggleDesktopSidebarVisibility() {
    _setDesktopSidebarVisible(!_desktopSidebarVisible);
  }

  void _setDesktopSidePanelVisible(bool visible) {
    if (_desktopSidePanelVisible == visible) {
      return;
    }
    setState(() {
      _desktopSidePanelVisible = visible;
    });
  }

  void _toggleDesktopSidePanelVisibility() {
    _setDesktopSidePanelVisible(!_desktopSidePanelVisible);
  }

  bool get _isAppleShortcutPlatform =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool _matchesWorkspaceShortcut(
    KeyEvent event, {
    required LogicalKeyboardKey key,
    bool mod = false,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    final keyboard = HardwareKeyboard.instance;
    final expectedMeta = mod && _isAppleShortcutPlatform;
    final expectedCtrl = ctrl || (mod && !_isAppleShortcutPlatform);
    return event.logicalKey == key &&
        keyboard.isMetaPressed == expectedMeta &&
        keyboard.isControlPressed == expectedCtrl &&
        keyboard.isAltPressed == alt &&
        keyboard.isShiftPressed == shift;
  }

  bool _canHandleWorkspaceShortcuts() {
    final route = ModalRoute.of(context);
    return mounted && (route == null || route.isCurrent);
  }

  bool _canInterruptWithShortcut(WorkspaceController controller) {
    return !_activePromptSubmitInFlight &&
        _promptController.text.trim().isEmpty &&
        _composerAttachments.isEmpty &&
        controller.selectedSessionId != null &&
        controller.selectedSessionInterruptible &&
        !controller.interruptingSession;
  }

  bool _isCompactLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width < AppSpacing.wideLayoutBreakpoint;
  }

  void _requestPromptComposerFocus() {
    final scopeKey = _resolvedActiveComposerScopeKey(_controller);
    setState(() {
      _requestPromptComposerFocusForScope(scopeKey);
    });
  }

  void _toggleSessionsSurface({required bool compact}) {
    if (compact) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) {
        return;
      }
      if (scaffoldState.isDrawerOpen) {
        Navigator.of(context).maybePop();
        return;
      }
      scaffoldState.openDrawer();
      return;
    }
    _toggleDesktopSidebarVisibility();
  }

  void _toggleSideTab(
    WorkspaceController controller,
    WorkspaceSideTab tab, {
    required bool compact,
  }) {
    if (compact) {
      final alreadyShowing =
          _compactPane == _CompactWorkspacePane.side &&
          controller.sideTab == tab;
      if (alreadyShowing) {
        setState(() {
          _compactPane = _CompactWorkspacePane.session;
        });
        return;
      }
      setState(() {
        _compactPane = _CompactWorkspacePane.side;
      });
      controller.setSideTab(tab);
      return;
    }

    final alreadyShowing =
        _desktopSidePanelVisible && controller.sideTab == tab;
    if (alreadyShowing) {
      _setDesktopSidePanelVisible(false);
      return;
    }
    _setDesktopSidePanelVisible(true);
    controller.setSideTab(tab);
  }

  Future<void> _navigateSessionByOffset(
    WorkspaceController controller,
    int offset, {
    required bool compact,
  }) async {
    final sessions = controller.visibleSessions;
    if (sessions.length <= 1) {
      return;
    }
    var currentIndex = sessions.indexWhere(
      (session) => session.id == controller.selectedSessionId,
    );
    if (currentIndex < 0) {
      currentIndex = 0;
    }
    final nextIndex = (currentIndex + offset) % sessions.length;
    final normalizedIndex = nextIndex < 0
        ? nextIndex + sessions.length
        : nextIndex;
    final nextSession = sessions[normalizedIndex];
    if (nextSession.id == controller.selectedSessionId) {
      return;
    }
    await _selectSessionInPlace(controller, nextSession.id, compact: compact);
  }

  Future<void> _navigateProjectByOffset(
    WorkspaceController controller,
    int offset, {
    required bool compact,
  }) async {
    final projects = controller.availableProjects;
    if (projects.length <= 1) {
      return;
    }
    var currentIndex = projects.indexWhere(
      (project) => project.directory == _currentDirectory,
    );
    if (currentIndex < 0) {
      currentIndex = 0;
    }
    final nextIndex = (currentIndex + offset) % projects.length;
    final normalizedIndex = nextIndex < 0
        ? nextIndex + projects.length
        : nextIndex;
    final nextProject = projects[normalizedIndex];
    if (nextProject.directory == _currentDirectory) {
      return;
    }
    final profile = _profile;
    if (profile != null) {
      await AppScope.of(
        context,
      ).persistProjectUpdate(profile: profile, target: nextProject);
    }
    await _selectProjectInPlace(nextProject, compact: compact);
  }

  void _cycleSelectedAgent(WorkspaceController controller, int offset) {
    final agents = controller.composerAgents;
    if (agents.isEmpty) {
      return;
    }
    var currentIndex = agents.indexWhere(
      (agent) => agent.name == controller.selectedAgentName,
    );
    if (currentIndex < 0) {
      currentIndex = offset >= 0 ? -1 : 0;
    }
    final nextIndex = (currentIndex + offset) % agents.length;
    final normalizedIndex = nextIndex < 0
        ? nextIndex + agents.length
        : nextIndex;
    controller.selectAgent(agents[normalizedIndex].name);
  }

  void _cycleSelectedReasoning(WorkspaceController controller) {
    final options = <String?>[null, ...controller.availableReasoningValues];
    if (options.length <= 1) {
      return;
    }
    var currentIndex = options.indexOf(controller.selectedReasoning);
    if (currentIndex < 0) {
      currentIndex = 0;
    }
    final nextIndex = (currentIndex + 1) % options.length;
    controller.selectReasoning(options[nextIndex]);
  }

  Future<void> _showModelShortcutPicker(WorkspaceController controller) async {
    final models = controller.composerModels;
    if (models.isEmpty) {
      return;
    }
    final grouped = <String, List<WorkspaceComposerModelOption>>{};
    for (final model in models) {
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

    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _GroupedSelectionSheet<WorkspaceComposerModelOption>(
            title: 'Select Model',
            searchHint: 'Search models',
            groups: items,
            selectedValue: controller.selectedModel?.key,
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
    if (selection != null) {
      controller.selectModel(selection);
    }
  }

  Future<void> _showAgentShortcutPicker(WorkspaceController controller) async {
    final agents = controller.composerAgents;
    if (agents.isEmpty) {
      return;
    }
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SearchableSelectionSheet<_AgentChoice>(
        title: 'Select Agent',
        searchHint: 'Search agents',
        items: agents
            .map(
              (agent) => _AgentChoice(
                value: agent.name,
                title: agent.name,
                subtitle: agent.description,
              ),
            )
            .toList(growable: false),
        selectedValue: controller.selectedAgentName,
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
    if (selection != null) {
      controller.selectAgent(selection);
    }
  }

  Future<void> _showReasoningShortcutPicker(
    WorkspaceController controller,
  ) async {
    final options = <_ReasoningChoice>[
      const _ReasoningChoice(
        value: _PromptComposer._defaultReasoningSentinel,
        label: 'Default',
      ),
      ...controller.availableReasoningValues.map(
        (value) =>
            _ReasoningChoice(value: value, label: _reasoningLabel(value)),
      ),
    ];
    if (options.length <= 1) {
      return;
    }
    final selection = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableSelectionSheet<_ReasoningChoice>(
        title: 'Reasoning',
        searchHint: 'Search variants',
        items: options,
        selectedValue:
            controller.selectedReasoning ??
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
    if (selection == null) {
      return;
    }
    controller.selectReasoning(
      selection == _PromptComposer._defaultReasoningSentinel ? null : selection,
    );
  }

  Future<void> _persistAndSelectProjectTarget(
    ProjectTarget target, {
    required bool compact,
  }) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    await AppScope.of(
      context,
    ).persistProjectUpdate(profile: profile, target: target);
    if (!mounted) {
      return;
    }
    await _selectProjectInPlace(target, compact: compact);
  }

  void _primeActiveComposerWithSlashCommand(String trigger) {
    final normalizedTrigger = trigger.trim();
    if (normalizedTrigger.isEmpty) {
      return;
    }
    final scopeKey = _resolvedActiveComposerScopeKey(_controller);
    final text = '/$normalizedTrigger ';
    setState(() {
      _updateComposerScopeState(scopeKey, draft: text);
      _promptController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
      _requestPromptComposerFocusForScope(scopeKey);
    });
  }

  Future<void> _openProjectPickerShortcut() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final target = await showModalBottomSheet<ProjectTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ProjectPickerSheet(
          profile: profile,
          projectCatalogService: _projectCatalogService,
        ),
      ),
    );
    if (target == null || !mounted) {
      return;
    }
    await _persistAndSelectProjectTarget(
      target,
      compact: _isCompactLayout(context),
    );
  }

  Future<void> _openMcpPicker(WorkspaceController controller) async {
    final profile = _profile;
    final project = controller.project;
    if (profile == null || project == null) {
      _showSnackBar(
        'Wait for the workspace project to finish loading before managing MCPs.',
        tone: AppSnackBarTone.info,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: _WorkspaceMcpPickerSheet(
          profile: profile,
          project: project,
          service: _integrationStatusService,
        ),
      ),
    );
  }

  List<_WorkspaceCommandPaletteCommand> _buildCommandPaletteCommands(
    WebParityAppController appController,
    WorkspaceController controller, {
    required bool compact,
  }) {
    final commands = <_WorkspaceCommandPaletteCommand>[
      _WorkspaceCommandPaletteCommand(
        id: 'navigation.home',
        title: 'Back Home',
        category: 'Navigation',
        description: 'Return to the server and project home screen.',
        onSelected: () async {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'composer.focus',
        title: 'Focus Composer',
        category: 'View',
        description: 'Jump straight to the active prompt input.',
        shortcut: 'ctrl+l',
        onSelected: () async {
          _requestPromptComposerFocus();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: _chatSearchVisible ? 'chat-search.close' : 'chat-search.open',
        title: _chatSearchVisible ? 'Close Chat Search' : 'Search Chat',
        category: 'View',
        description: _chatSearchVisible
            ? 'Hide the in-session search bar.'
            : 'Search messages in the active session.',
        onSelected: () async {
          if (_chatSearchVisible) {
            _closeChatSearch();
          } else {
            _openChatSearch();
          }
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'project.open',
        title: 'Open Project',
        category: 'Project',
        description: 'Choose another project on this server.',
        shortcut: 'mod+o',
        onSelected: () async {
          await _openProjectPickerShortcut();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'settings.open',
        title: 'Open Settings',
        category: 'Settings',
        description:
            'Show workspace appearance, layout, and shortcut settings.',
        shortcut: 'mod+comma',
        onSelected: () async {
          await _openWorkspaceSettingsSheet(appController, controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'mcp.toggle',
        title: 'Toggle MCPs',
        category: 'MCP',
        description: 'Connect, disconnect, and authenticate MCP servers.',
        shortcut: 'mod+;',
        onSelected: () async {
          await _openMcpPicker(controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'sidebar.toggle',
        title: 'Toggle Sessions Panel',
        category: 'Panels',
        description: 'Collapse or reveal the sessions sidebar.',
        shortcut: 'mod+b',
        onSelected: () async {
          _toggleSessionsSurface(compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'panel.review',
        title: 'Toggle Review Panel',
        category: 'Panels',
        description: 'Open or hide the review side panel.',
        shortcut: 'mod+shift+r',
        onSelected: () async {
          _toggleSideTab(controller, WorkspaceSideTab.review, compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'panel.files',
        title: 'Toggle Files Panel',
        category: 'Panels',
        description: 'Open or hide the files side panel.',
        shortcut: 'mod+backslash',
        onSelected: () async {
          _toggleSideTab(controller, WorkspaceSideTab.files, compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'panel.context',
        title: 'Open Context Panel',
        category: 'Panels',
        description: 'Inspect context usage and token breakdown.',
        onSelected: () async {
          _toggleSideTab(
            controller,
            WorkspaceSideTab.context,
            compact: compact,
          );
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: _terminalPanelOpen ? 'terminal.hide' : 'terminal.show',
        title: _terminalPanelOpen ? 'Hide Terminal' : 'Show Terminal',
        category: 'Terminal',
        description: _terminalPanelOpen
            ? 'Collapse the terminal drawer.'
            : 'Open the terminal drawer for this project.',
        shortcut: 'ctrl+backquote',
        onSelected: () async {
          await _toggleTerminalPanel();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'terminal.new',
        title: 'New Terminal Session',
        category: 'Terminal',
        description: 'Create a fresh terminal tab for this project.',
        shortcut: 'ctrl+alt+t',
        onSelected: () async {
          await _createPtySession();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'session.new',
        title: 'New Session',
        category: 'Session',
        description: 'Create a fresh chat session in this project.',
        shortcut: 'mod+shift+s',
        onSelected: () async {
          await _createNewSession(controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'session.previous',
        title: 'Previous Session',
        category: 'Session',
        description: 'Move to the previous visible session.',
        shortcut: 'alt+arrowup',
        onSelected: () async {
          await _navigateSessionByOffset(controller, -1, compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'session.next',
        title: 'Next Session',
        category: 'Session',
        description: 'Move to the next visible session.',
        shortcut: 'alt+arrowdown',
        onSelected: () async {
          await _navigateSessionByOffset(controller, 1, compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'project.previous',
        title: 'Previous Project',
        category: 'Project',
        description: 'Move to the previous project in the sidebar rail.',
        shortcut: 'mod+alt+arrowup',
        onSelected: () async {
          await _navigateProjectByOffset(controller, -1, compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'project.next',
        title: 'Next Project',
        category: 'Project',
        description: 'Move to the next project in the sidebar rail.',
        shortcut: 'mod+alt+arrowdown',
        onSelected: () async {
          await _navigateProjectByOffset(controller, 1, compact: compact);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'attachments.pick',
        title: 'Attach Files',
        category: 'Composer',
        description: 'Pick files and add them to the active prompt.',
        shortcut: 'mod+u',
        onSelected: () async {
          await _pickComposerAttachments();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'permissions.toggle',
        title: 'Toggle Permission Auto-Accept',
        category: 'Composer',
        description:
            'Enable or disable permission auto-accept for the active session.',
        onSelected: () async {
          await _toggleSelectedPermissionAutoAccept();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'model.choose',
        title: 'Choose Model',
        category: 'Model',
        description: 'Open the grouped model picker.',
        shortcut: 'mod+quote',
        onSelected: () async {
          await _showModelShortcutPicker(controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'agent.choose',
        title: 'Choose Agent',
        category: 'Agent',
        description: 'Open the agent picker for the active composer.',
        onSelected: () async {
          await _showAgentShortcutPicker(controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'agent.previous',
        title: 'Previous Agent',
        category: 'Agent',
        description: 'Cycle backward through available agents.',
        shortcut: 'mod+shift+period',
        onSelected: () async {
          _cycleSelectedAgent(controller, -1);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'agent.next',
        title: 'Next Agent',
        category: 'Agent',
        description: 'Cycle forward through available agents.',
        shortcut: 'mod+period',
        onSelected: () async {
          _cycleSelectedAgent(controller, 1);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'reasoning.choose',
        title: 'Choose Reasoning',
        category: 'Reasoning',
        description: 'Open the reasoning depth picker.',
        onSelected: () async {
          await _showReasoningShortcutPicker(controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'reasoning.cycle',
        title: 'Cycle Reasoning Depth',
        category: 'Reasoning',
        description: 'Rotate through the available reasoning options.',
        shortcut: 'mod+shift+d',
        onSelected: () async {
          _cycleSelectedReasoning(controller);
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'theme.cycle',
        title: 'Cycle Theme',
        category: 'Theme',
        description: 'Rotate through the installed theme presets.',
        onSelected: () async {
          await appController.cycleThemePreset();
        },
      ),
      _WorkspaceCommandPaletteCommand(
        id: 'theme.color-mode.cycle',
        title: 'Cycle Color Mode',
        category: 'Theme',
        description: 'Rotate between system, light, and dark color modes.',
        onSelected: () async {
          await appController.cycleColorSchemeMode();
        },
      ),
    ];

    if (!compact && _desktopSessionPanes.length < _maxDesktopSessionPanes) {
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'pane.split',
          title: 'Split Session Pane',
          category: 'View',
          description: 'Open another session pane in the desktop layout.',
          onSelected: () async {
            _splitDesktopSessionPane(controller);
          },
        ),
      );
    }

    if (_canInterruptWithShortcut(controller)) {
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'session.interrupt',
          title: 'Interrupt Active Session',
          category: 'Session',
          description: 'Stop the active model response.',
          shortcut: 'escape',
          onSelected: () async {
            await _interruptSelectedSession();
          },
        ),
      );
    }

    final selectedSession = controller.selectedSession;
    if (selectedSession != null) {
      commands.addAll(<_WorkspaceCommandPaletteCommand>[
        _WorkspaceCommandPaletteCommand(
          id: 'session.rename',
          title: 'Rename Session',
          category: 'Session',
          description:
              'Rename "${_sessionHeaderTitle(selectedSession, controller.project)}".',
          onSelected: () async {
            await _renameSelectedSession(controller);
          },
        ),
        _WorkspaceCommandPaletteCommand(
          id: 'session.fork',
          title: 'Fork Session',
          category: 'Session',
          description: 'Create a branched copy of the current session.',
          onSelected: () async {
            await _forkSelectedSession(controller);
          },
        ),
        _WorkspaceCommandPaletteCommand(
          id: 'session.share',
          title: selectedSession.shareUrl?.trim().isNotEmpty == true
              ? 'Copy Share Link'
              : 'Share Session',
          category: 'Session',
          description: selectedSession.shareUrl?.trim().isNotEmpty == true
              ? 'Copy the existing share link for this session.'
              : 'Create and copy a share link for this session.',
          onSelected: () async {
            if (selectedSession.shareUrl?.trim().isNotEmpty == true) {
              await Clipboard.setData(
                ClipboardData(text: selectedSession.shareUrl!.trim()),
              );
              if (!mounted) {
                return;
              }
              _showSnackBar(
                'Share link copied to clipboard.',
                tone: AppSnackBarTone.success,
              );
              return;
            }
            await _shareSelectedSession(controller);
          },
        ),
        if (selectedSession.shareUrl?.trim().isNotEmpty == true)
          _WorkspaceCommandPaletteCommand(
            id: 'session.unshare',
            title: 'Unshare Session',
            category: 'Session',
            description: 'Remove the current share link.',
            onSelected: () async {
              await _unshareSelectedSession(controller);
            },
          ),
        _WorkspaceCommandPaletteCommand(
          id: 'session.compact',
          title: 'Compact Session',
          category: 'Session',
          description: 'Summarize the current session to reduce context size.',
          onSelected: () async {
            await _summarizeSelectedSession(controller);
          },
        ),
        _WorkspaceCommandPaletteCommand(
          id: 'session.delete',
          title: 'Delete Session',
          category: 'Session',
          description: 'Delete the current session after confirmation.',
          onSelected: () async {
            await _deleteSelectedSession(controller);
          },
        ),
      ]);
    }

    for (final project in controller.availableProjects) {
      final isCurrentProject = project.directory == _currentDirectory;
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'project.open.${project.directory}',
          title: 'Open ${project.title}',
          category: 'Project',
          description: isCurrentProject
              ? '${project.directory} • Current project'
              : project.directory,
          searchTerms: <String>[
            project.title,
            project.directory,
            project.branch ?? '',
            project.source ?? '',
          ],
          onSelected: () async {
            await _persistAndSelectProjectTarget(project, compact: compact);
          },
        ),
      );
    }

    for (final session in controller.visibleSessions) {
      final sessionTitle = _sessionHeaderTitle(session, controller.project);
      final isCurrentSession = session.id == controller.selectedSessionId;
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'session.open.${session.id}',
          title: 'Open $sessionTitle',
          category: 'Session',
          description: isCurrentSession
              ? 'Current session'
              : 'Switch to session ${session.id}',
          searchTerms: <String>[session.id, session.title],
          onSelected: () async {
            await _selectSessionInPlace(
              controller,
              session.id,
              compact: compact,
            );
          },
        ),
      );
    }

    for (final model in controller.composerModels) {
      final isCurrentModel = model.key == controller.selectedModel?.key;
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'model.set.${model.key}',
          title: 'Use ${model.name}',
          category: 'Model',
          description: isCurrentModel
              ? '${model.providerName} • Current model'
              : '${model.providerName} • ${model.modelId}',
          searchTerms: <String>[
            model.key,
            model.providerId,
            model.providerName,
            model.modelId,
            model.name,
          ],
          onSelected: () async {
            controller.selectModel(model.key);
          },
        ),
      );
    }

    for (final agent in controller.composerAgents) {
      final isCurrentAgent = agent.name == controller.selectedAgent?.name;
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'agent.set.${agent.name}',
          title: 'Use ${agent.name}',
          category: 'Agent',
          description: isCurrentAgent
              ? '${agent.description ?? agent.mode} • Current agent'
              : agent.description ?? 'Mode: ${agent.mode}',
          searchTerms: <String>[
            agent.name,
            agent.mode,
            agent.description ?? '',
            agent.modelProviderId ?? '',
            agent.modelId ?? '',
            agent.variant ?? '',
          ],
          onSelected: () async {
            controller.selectAgent(agent.name);
          },
        ),
      );
    }

    for (final reasoning in <String?>[
      null,
      ...controller.availableReasoningValues,
    ]) {
      final label = _reasoningLabel(reasoning);
      final isCurrentReasoning = reasoning == controller.selectedReasoning;
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'reasoning.set.${reasoning ?? 'default'}',
          title: 'Use $label Reasoning',
          category: 'Reasoning',
          description: isCurrentReasoning
              ? '${reasoning ?? 'Default'} • Current selection'
              : reasoning ?? 'Use the model default reasoning depth.',
          searchTerms: <String>[label, reasoning ?? 'default'],
          onSelected: () async {
            controller.selectReasoning(reasoning);
          },
        ),
      );
    }

    for (final preset in AppThemePreset.values) {
      final definition = AppTheme.definition(preset);
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'theme.set.${preset.storageValue}',
          title: 'Switch to ${definition.label}',
          category: 'Theme',
          description: appController.themePreset == preset
              ? '${definition.summary} • Current theme'
              : definition.summary,
          searchTerms: <String>[
            definition.label,
            definition.summary,
            preset.storageValue,
          ],
          onSelected: () async {
            await appController.setThemePreset(preset);
          },
        ),
      );
    }

    for (final mode in AppColorSchemeMode.values) {
      final label = switch (mode) {
        AppColorSchemeMode.system => 'System',
        AppColorSchemeMode.light => 'Light',
        AppColorSchemeMode.dark => 'Dark',
      };
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'theme.color-mode.${mode.storageValue}',
          title: 'Use $label Color Mode',
          category: 'Theme',
          description: appController.colorSchemeMode == mode
              ? '$label palette selection • Current mode'
              : 'Switch the app to $label color mode.',
          searchTerms: <String>[label, mode.storageValue, 'theme scheme'],
          onSelected: () async {
            await appController.setColorSchemeMode(mode);
          },
        ),
      );
    }

    for (final command in controller.composerCommands) {
      commands.add(
        _WorkspaceCommandPaletteCommand(
          id: 'command.${command.name}',
          title: '/${command.name}',
          category: 'Commands',
          description: command.description?.trim().isNotEmpty == true
              ? command.description!.trim()
              : 'Insert /${command.name} into the composer.',
          searchTerms: <String>[
            command.name,
            command.source ?? '',
            ...command.hints,
          ],
          onSelected: () async {
            _primeActiveComposerWithSlashCommand(command.name);
          },
        ),
      );
    }

    return List<_WorkspaceCommandPaletteCommand>.unmodifiable(commands);
  }

  Future<void> _openCommandPalette(WorkspaceController controller) async {
    final appController = AppScope.of(context);
    final command = await showDialog<_WorkspaceCommandPaletteCommand>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => _WorkspaceCommandPaletteSheet(
        commands: _buildCommandPaletteCommands(
          appController,
          controller,
          compact: _isCompactLayout(this.context),
        ),
      ),
    );
    if (command == null || !mounted) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    await command.onSelected();
  }

  KeyEventResult _handleWorkspaceShortcutKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (!_canHandleWorkspaceShortcuts() || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final controller = _controller;
    if (controller == null) {
      return KeyEventResult.ignored;
    }
    final compact = _isCompactLayout(context);

    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyK,
      mod: true,
    )) {
      unawaited(_openCommandPalette(controller));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyL,
      ctrl: true,
    )) {
      _requestPromptComposerFocus();
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.comma,
      mod: true,
    )) {
      unawaited(_openWorkspaceSettingsSheet(AppScope.of(context), controller));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyO,
      mod: true,
    )) {
      unawaited(_openProjectPickerShortcut());
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.semicolon,
      mod: true,
    )) {
      unawaited(_openMcpPicker(controller));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyB,
      mod: true,
    )) {
      _toggleSessionsSurface(compact: compact);
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyR,
      mod: true,
      shift: true,
    )) {
      _toggleSideTab(controller, WorkspaceSideTab.review, compact: compact);
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.backslash,
      mod: true,
    )) {
      _toggleSideTab(controller, WorkspaceSideTab.files, compact: compact);
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.backquote,
      ctrl: true,
    )) {
      unawaited(_toggleTerminalPanel());
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyT,
      ctrl: true,
      alt: true,
    )) {
      unawaited(_createPtySession());
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyS,
      mod: true,
      shift: true,
    )) {
      unawaited(_createNewSession(controller));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.arrowUp,
      alt: true,
    )) {
      unawaited(_navigateSessionByOffset(controller, -1, compact: compact));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.arrowDown,
      alt: true,
    )) {
      unawaited(_navigateSessionByOffset(controller, 1, compact: compact));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.arrowUp,
      mod: true,
      alt: true,
    )) {
      unawaited(_navigateProjectByOffset(controller, -1, compact: compact));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.arrowDown,
      mod: true,
      alt: true,
    )) {
      unawaited(_navigateProjectByOffset(controller, 1, compact: compact));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyU,
      mod: true,
    )) {
      unawaited(_pickComposerAttachments());
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.quote,
      mod: true,
    )) {
      unawaited(_showModelShortcutPicker(controller));
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.period,
      mod: true,
      shift: true,
    )) {
      _cycleSelectedAgent(controller, -1);
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.period,
      mod: true,
    )) {
      _cycleSelectedAgent(controller, 1);
      return KeyEventResult.handled;
    }
    if (_matchesWorkspaceShortcut(
      event,
      key: LogicalKeyboardKey.keyD,
      mod: true,
      shift: true,
    )) {
      _cycleSelectedReasoning(controller);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_chatSearchVisible) {
        _closeChatSearch();
        return KeyEventResult.handled;
      }
      if (_canInterruptWithShortcut(controller)) {
        unawaited(_interruptSelectedSession());
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _focusChatSearchField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _chatSearchFocusNode.requestFocus();
      final value = _chatSearchController.value;
      _chatSearchController.value = value.copyWith(
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: value.text.length,
        ),
      );
    });
  }

  void _openChatSearch() {
    if (_chatSearchVisible) {
      _focusChatSearchField();
      return;
    }
    setState(() {
      _chatSearchVisible = true;
      _chatSearchRevision += 1;
    });
    _focusChatSearchField();
  }

  void _closeChatSearch() {
    if (!_chatSearchVisible && _chatSearchController.text.isEmpty) {
      return;
    }
    _chatSearchController.clear();
    setState(() {
      _chatSearchVisible = false;
      _chatSearchActiveMatchIndex = 0;
      _chatSearchScopeKey = null;
      _chatSearchRevision += 1;
    });
  }

  void _handleChatSearchChanged(String value) {
    final controller = _controller;
    setState(() {
      _chatSearchActiveMatchIndex = 0;
      _chatSearchScopeKey = controller == null
          ? null
          : _chatSearchWorkspaceScopeKey(controller);
      _chatSearchRevision += 1;
    });
  }

  void _moveChatSearchMatch(int delta) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final searchState = _resolveChatSearchState(controller);
    if (!searchState.hasMatches) {
      return;
    }
    final count = searchState.matchMessageIds.length;
    final nextIndex = (searchState.activeMatchIndex + delta + count) % count;
    setState(() {
      _chatSearchActiveMatchIndex = nextIndex;
      _chatSearchScopeKey = _chatSearchWorkspaceScopeKey(controller);
      _chatSearchRevision += 1;
    });
    _focusChatSearchField();
  }

  String _chatSearchWorkspaceScopeKey(WorkspaceController controller) {
    final sessionId = controller.selectedSessionId?.trim() ?? '';
    return '${controller.directory}::$sessionId';
  }

  _ResolvedChatSearchState _resolveChatSearchState(
    WorkspaceController controller,
  ) {
    final rawQuery = _chatSearchController.text;
    final query = rawQuery.trim();
    final sessionId = controller.selectedSessionId;
    final scopeKey = _chatSearchWorkspaceScopeKey(controller);
    if (query.isEmpty) {
      return _ResolvedChatSearchState(
        query: rawQuery,
        sessionId: sessionId,
        matchMessageIds: const <String>[],
        activeMatchIndex: 0,
        revision: _chatSearchRevision,
      );
    }

    final terms = _normalizedSearchTerms(query);
    final messages = controller
        .timelineStateForSession(sessionId)
        .orderedMessages;
    final matches = <String>[];
    for (final message in messages) {
      if (_messageMatchesSearch(message, terms)) {
        matches.add(message.info.id);
      }
    }

    final baseIndex = _chatSearchScopeKey == scopeKey
        ? _chatSearchActiveMatchIndex
        : 0;
    final activeIndex = matches.isEmpty
        ? 0
        : baseIndex.clamp(0, matches.length - 1);
    return _ResolvedChatSearchState(
      query: rawQuery,
      sessionId: sessionId,
      matchMessageIds: List<String>.unmodifiable(matches),
      activeMatchIndex: activeIndex,
      revision: _chatSearchRevision,
    );
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

  WorkspaceController _workspaceControllerForDirectory(
    WebParityAppController appController,
    ServerProfile profile,
    String directory, {
    String? initialSessionId,
  }) {
    final currentController = _controller;
    if (currentController != null &&
        _profile?.storageKey == profile.storageKey &&
        currentController.directory == directory) {
      return currentController;
    }
    return appController.obtainWorkspaceController(
      profile: profile,
      directory: directory,
      initialSessionId: initialSessionId,
    );
  }

  List<_WorkspaceSessionPaneSpec> _resolvedDesktopSessionPanes(
    WebParityAppController appController,
    ServerProfile profile,
    WorkspaceController controller,
  ) {
    final activePaneId =
        _activeDesktopSessionPaneId ??
        (_desktopSessionPanes.isNotEmpty
            ? _desktopSessionPanes.first.id
            : null);

    final resolved = <_WorkspaceSessionPaneSpec>[];
    for (final pane in _desktopSessionPanes) {
      final effectiveDirectory = pane.id == activePaneId
          ? _activeDirectory
          : pane.directory;
      final paneController = _workspaceControllerForDirectory(
        appController,
        profile,
        effectiveDirectory,
        initialSessionId: pane.sessionId,
      );
      final sessionsById = <String, SessionSummary>{
        for (final session in paneController.sessions) session.id: session,
      };
      final effectiveSessionId = pane.id == activePaneId
          ? paneController.selectedSessionId
          : pane.sessionId;
      final normalized = effectiveSessionId?.trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          !paneController.loading &&
          paneController.error == null &&
          !sessionsById.containsKey(normalized)) {
        continue;
      }
      resolved.add(
        _WorkspaceSessionPaneSpec(
          id: pane.id,
          directory: effectiveDirectory,
          sessionId: effectiveSessionId,
        ),
      );
    }

    if (resolved.isEmpty) {
      final fallback = _WorkspaceSessionPaneSpec(
        id: 'pane_${_sessionPaneSequence++}',
        directory: _activeDirectory,
        sessionId: controller.selectedSessionId,
      );
      _desktopSessionPanes = <_WorkspaceSessionPaneSpec>[fallback];
      _activeDesktopSessionPaneId = fallback.id;
      _recordDesktopSessionPaneLayoutChange();
      unawaited(_persistDesktopSessionPaneLayout());
      return <_WorkspaceSessionPaneSpec>[fallback];
    }

    if (!resolved.any((pane) => pane.id == activePaneId)) {
      _activeDesktopSessionPaneId = resolved.first.id;
    }

    return List<_WorkspaceSessionPaneSpec>.unmodifiable(resolved);
  }

  bool _commitSelectedSessionToActivePane(WorkspaceController controller) {
    final activePaneId = _activeDesktopSessionPaneId;
    if (activePaneId == null) {
      return false;
    }
    final selectedSessionId = controller.selectedSessionId;
    var changed = false;
    final next = _desktopSessionPanes
        .map((pane) {
          if (pane.id != activePaneId) {
            return pane;
          }
          if (pane.sessionId == selectedSessionId &&
              pane.directory == controller.directory) {
            return pane;
          }
          changed = true;
          return pane.copyWith(
            directory: controller.directory,
            sessionId: selectedSessionId,
          );
        })
        .toList(growable: false);
    if (!changed) {
      return false;
    }
    _desktopSessionPanes = next;
    _recordDesktopSessionPaneLayoutChange();
    return true;
  }

  bool _sameWatchedSessionMap(
    Map<WorkspaceController, Set<String>> left,
    Map<WorkspaceController, Set<String>> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      final other = right[entry.key];
      if (other == null || !setEquals(entry.value, other)) {
        return false;
      }
    }
    return true;
  }

  void _clearWatchedSessionSync() {
    final controllers = <WorkspaceController>{
      ..._pendingWatchedSessionIdsByController.keys,
      ..._syncedWatchedSessionIdsByController.keys,
    };
    for (final controller in controllers) {
      controller.updateWatchedSessionIds(const <String?>[]);
    }
    _pendingWatchedSessionIdsByController =
        const <WorkspaceController, Set<String>>{};
    _syncedWatchedSessionIdsByController =
        const <WorkspaceController, Set<String>>{};
    _watchedSessionSyncScheduled = false;
  }

  void _handleObservedPaneControllerChanged() {
    if (!mounted) {
      return;
    }
    _dispatchObservedPendingRequestNotifications();
    setState(() {});
  }

  void _clearObservedPaneControllers() {
    for (final controller in _observedPaneControllers) {
      controller.removeListener(_handleObservedPaneControllerChanged);
    }
    _observedPaneControllers = const <WorkspaceController>{};
    _observedPendingRequestsByController =
        const <WorkspaceController, PendingRequestBundle>{};
    _primedPendingRequestNotificationControllers =
        const <WorkspaceController>{};
  }

  void _syncObservedPaneControllers(Iterable<WorkspaceController> controllers) {
    final next = Set<WorkspaceController>.unmodifiable(controllers.toSet());
    if (setEquals(next, _observedPaneControllers)) {
      return;
    }
    for (final controller in _observedPaneControllers.difference(next)) {
      controller.removeListener(_handleObservedPaneControllerChanged);
    }
    for (final controller in next.difference(_observedPaneControllers)) {
      controller.addListener(_handleObservedPaneControllerChanged);
    }
    _observedPaneControllers = next;
    _observedPendingRequestsByController =
        <WorkspaceController, PendingRequestBundle>{
          for (final entry
              in _observedPendingRequestsByController.entries.where(
                (entry) => next.contains(entry.key),
              ))
            entry.key: entry.value,
          for (final controller in next.difference(
            _observedPendingRequestsByController.keys.toSet(),
          ))
            controller: controller.pendingRequests,
        };
    _primedPendingRequestNotificationControllers =
        Set<WorkspaceController>.unmodifiable(<WorkspaceController>{
          for (final controller
              in _primedPendingRequestNotificationControllers.where(
                next.contains,
              ))
            controller,
          for (final controller in next.where(
            (controller) => !controller.loading,
          ))
            controller,
        });
  }

  void _dispatchObservedPendingRequestNotifications() {
    if (_observedPaneControllers.isEmpty) {
      return;
    }
    final nextTracked = <WorkspaceController, PendingRequestBundle>{
      ..._observedPendingRequestsByController,
    };
    final nextPrimed = <WorkspaceController>{
      ..._primedPendingRequestNotificationControllers,
    };
    for (final controller in _observedPaneControllers) {
      final previous =
          _observedPendingRequestsByController[controller] ??
          controller.pendingRequests;
      final current = controller.pendingRequests;
      nextTracked[controller] = current;
      final primed = nextPrimed.contains(controller);
      if (!primed) {
        if (!controller.loading) {
          nextPrimed.add(controller);
        }
        continue;
      }

      final questionAlert = buildQuestionAskedAlert(
        previous: previous.questions,
        next: current.questions,
      );
      if (questionAlert != null) {
        _showPendingRequestNotification(controller, questionAlert);
      }

      final permissionAlert = buildPermissionAskedAlert(
        previous: previous.permissions,
        next: current.permissions,
      );
      if (permissionAlert != null &&
          !controller.autoAcceptsPermissionForSession(
            permissionAlert.sessionId,
          )) {
        _showPendingRequestNotification(controller, permissionAlert);
      }
    }
    _observedPendingRequestsByController =
        Map<WorkspaceController, PendingRequestBundle>.unmodifiable(
          nextTracked,
        );
    _primedPendingRequestNotificationControllers =
        Set<WorkspaceController>.unmodifiable(nextPrimed);
  }

  void _showPendingRequestNotification(
    WorkspaceController controller,
    PendingRequestAlert alert,
  ) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return;
    }
    final dedupeKey =
        '${controller.profile.storageKey}:${controller.directory}:${alert.kind.name}:${alert.requestId}';
    if (alert.kind == PendingRequestAlertKind.permission) {
      unawaited(
        _pendingRequestSoundService.playPermissionRequestSound(
          dedupeKey: dedupeKey,
        ),
      );
    }
    unawaited(
      _pendingRequestNotificationService.showPendingRequestNotification(
        dedupeKey: dedupeKey,
        title: pendingRequestAlertTitle(l10n, alert),
        body: pendingRequestAlertBody(alert),
      ),
    );
  }

  void _scheduleWatchedSessionSync(
    Map<WorkspaceController, Set<String>> sessionIdsByController,
  ) {
    final normalized = <WorkspaceController, Set<String>>{
      for (final entry in sessionIdsByController.entries)
        entry.key: Set<String>.unmodifiable(
          entry.value
              .map((sessionId) => sessionId.trim())
              .where((sessionId) => sessionId.isNotEmpty)
              .toSet(),
        ),
    };
    if (_sameWatchedSessionMap(
          normalized,
          _pendingWatchedSessionIdsByController,
        ) &&
        _watchedSessionSyncScheduled) {
      return;
    }
    _pendingWatchedSessionIdsByController = normalized;
    if (_watchedSessionSyncScheduled) {
      return;
    }
    _watchedSessionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchedSessionSyncScheduled = false;
      if (!mounted) {
        return;
      }
      final nextMap = _pendingWatchedSessionIdsByController;
      final controllers = <WorkspaceController>{
        ..._syncedWatchedSessionIdsByController.keys,
        ...nextMap.keys,
      };
      for (final controller in controllers) {
        controller.updateWatchedSessionIds(
          nextMap[controller] ?? const <String>{},
        );
      }
      _syncedWatchedSessionIdsByController = nextMap;
    });
  }

  Future<void> _activateDesktopSessionPane(
    WorkspaceController controller,
    String paneId,
  ) async {
    if (_activeDesktopSessionPaneId == paneId) {
      return;
    }
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final appController = AppScope.of(context);
    _commitSelectedSessionToActivePane(controller);
    final targetPane = _desktopSessionPanes
        .cast<_WorkspaceSessionPaneSpec?>()
        .firstWhere((pane) => pane?.id == paneId, orElse: () => null);
    if (targetPane == null) {
      return;
    }
    controller.preserveSelectedSessionTimelineForWatch();
    setState(() {
      _activeDesktopSessionPaneId = paneId;
      _timelineJumpEpoch += 1;
    });
    _recordDesktopSessionPaneLayoutChange();
    _bindWorkspace(
      appController: appController,
      profile: profile,
      directory: targetPane.directory,
      routeSessionId: targetPane.sessionId,
    );
    final targetController = _controller;
    if (targetController == null ||
        targetController.selectedSessionId == targetPane.sessionId) {
      unawaited(_persistDesktopSessionPaneLayout());
      return;
    }
    await targetController.selectSession(targetPane.sessionId);
    unawaited(_persistDesktopSessionPaneLayout());
  }

  void _splitDesktopSessionPane(WorkspaceController controller) {
    if (_desktopSessionPanes.length >= _maxDesktopSessionPanes) {
      _showSnackBar(
        'You can open up to 8 session panes.',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    _commitSelectedSessionToActivePane(controller);
    final activePaneId = _activeDesktopSessionPaneId;
    final activeIndex = _desktopSessionPanes.indexWhere(
      (pane) => pane.id == activePaneId,
    );
    final insertIndex = activeIndex >= 0
        ? activeIndex + 1
        : _desktopSessionPanes.length;
    final newPane = _WorkspaceSessionPaneSpec(
      id: 'pane_${_sessionPaneSequence++}',
      directory: controller.directory,
      sessionId: controller.selectedSessionId,
    );
    final next = List<_WorkspaceSessionPaneSpec>.from(_desktopSessionPanes)
      ..insert(insertIndex, newPane);
    setState(() {
      _desktopSessionPanes = next;
      _activeDesktopSessionPaneId = newPane.id;
      _timelineJumpEpoch += 1;
    });
    _recordDesktopSessionPaneLayoutChange();
    unawaited(_persistDesktopSessionPaneLayout());
  }

  Future<void> _closeDesktopSessionPane(
    WorkspaceController controller,
    String paneId,
  ) async {
    if (_desktopSessionPanes.length <= 1) {
      return;
    }
    final profile = _profile;
    _commitSelectedSessionToActivePane(controller);
    if (_paneSessionVisibleElsewhere(
      directory: controller.directory,
      sessionId: controller.selectedSessionId,
      excludingPaneId: paneId,
    )) {
      controller.preserveSelectedSessionTimelineForWatch();
    }
    final current = List<_WorkspaceSessionPaneSpec>.from(_desktopSessionPanes);
    final removedIndex = current.indexWhere((pane) => pane.id == paneId);
    if (removedIndex < 0) {
      return;
    }
    final removedPane = current.removeAt(removedIndex);
    final wasActive = removedPane.id == _activeDesktopSessionPaneId;
    _WorkspaceSessionPaneSpec? nextActivePane;
    if (wasActive) {
      final nextIndex = math.min(removedIndex, current.length - 1);
      nextActivePane = current[nextIndex];
    }
    setState(() {
      _desktopSessionPanes = current;
      if (wasActive) {
        _activeDesktopSessionPaneId = nextActivePane?.id;
        _timelineJumpEpoch += 1;
      }
    });
    _recordDesktopSessionPaneLayoutChange();
    if (wasActive && nextActivePane != null && profile != null) {
      final appController = AppScope.of(context);
      _bindWorkspace(
        appController: appController,
        profile: profile,
        directory: nextActivePane.directory,
        routeSessionId: nextActivePane.sessionId,
      );
      final nextController = _controller;
      if (nextController != null &&
          nextController.selectedSessionId != nextActivePane.sessionId) {
        await nextController.selectSession(nextActivePane.sessionId);
      }
    }
    unawaited(_persistDesktopSessionPaneLayout());
  }

  bool _paneSessionVisibleElsewhere({
    required String directory,
    required String? sessionId,
    required String excludingPaneId,
  }) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    for (final pane in _desktopSessionPanes) {
      if (pane.id == excludingPaneId) {
        continue;
      }
      if (pane.directory == directory &&
          pane.sessionId == normalizedSessionId) {
        return true;
      }
    }
    return false;
  }

  ProjectTarget _projectTargetForDirectory(
    WorkspaceController controller,
    String directory, {
    ProjectTarget? fallbackProject,
  }) {
    final currentProject = controller.project;
    if (currentProject != null && currentProject.directory == directory) {
      return currentProject;
    }
    for (final project in controller.availableProjects) {
      if (project.directory == directory) {
        return project;
      }
    }
    return fallbackProject ??
        ProjectTarget(
          directory: directory,
          label: projectDisplayLabel(directory),
          source: 'session-pane',
        );
  }

  List<_WorkspacePaneViewModel> _resolvedDesktopPaneViewModels({
    required WebParityAppController appController,
    required ServerProfile profile,
    required WorkspaceController activeController,
    required _WorkspaceProjectLoadingShellState? projectLoadingShell,
  }) {
    final panes = _resolvedDesktopSessionPanes(
      appController,
      profile,
      activeController,
    );
    return List<_WorkspacePaneViewModel>.unmodifiable(
      panes.map((pane) {
        final paneController = _workspaceControllerForDirectory(
          appController,
          profile,
          pane.directory,
          initialSessionId: pane.sessionId,
        );
        final fallbackProject =
            pane.id == _activeDesktopSessionPaneId &&
                projectLoadingShell?.targetProject.directory == pane.directory
            ? projectLoadingShell?.targetProject
            : null;
        return _WorkspacePaneViewModel(
          pane: pane,
          controller: paneController,
          project: _projectTargetForDirectory(
            paneController,
            pane.directory,
            fallbackProject: fallbackProject,
          ),
        );
      }),
    );
  }

  Map<WorkspaceController, Set<String>> _watchedSessionIdsByController(
    Iterable<_WorkspacePaneViewModel> paneViewModels,
  ) {
    final watched = <WorkspaceController, Set<String>>{};
    for (final paneViewModel in paneViewModels) {
      if (paneViewModel.pane.id == _activeDesktopSessionPaneId) {
        continue;
      }
      final sessionId = paneViewModel.pane.sessionId?.trim();
      if (sessionId == null || sessionId.isEmpty) {
        continue;
      }
      watched
          .putIfAbsent(paneViewModel.controller, () => <String>{})
          .add(sessionId);
    }
    return watched;
  }

  Future<void> _pickComposerAttachments() async {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null || _activePromptSubmitInFlight) {
      return;
    }
    await _pickComposerAttachmentsForScope(scopeKey);
  }

  Future<bool> _tryPasteComposerClipboardImage() async {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null || _activePromptSubmitInFlight) {
      return false;
    }
    return _tryPasteComposerClipboardImageForScope(scopeKey);
  }

  Future<void> _handleComposerContentInsertion(
    KeyboardInsertedContent content,
  ) async {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null || _activePromptSubmitInFlight) {
      return;
    }
    await _handleComposerContentInsertionForScope(scopeKey, content);
  }

  Future<PromptAttachmentLoadResult> _loadPromptAttachmentsFromFiles(
    List<XFile> files,
  ) async {
    final result = await _attachmentService.loadFiles(files);
    if (!mounted) {
      return result;
    }
    if (result.rejectedNames.isNotEmpty) {
      final names = result.rejectedNames.take(3).join(', ');
      final overflow = result.rejectedNames.length > 3
          ? ' and ${result.rejectedNames.length - 3} more'
          : '';
      _showSnackBar(
        'Only images, PDFs, and text files are supported. Skipped: $names$overflow',
        tone: AppSnackBarTone.warning,
      );
    }
    return result;
  }

  Future<List<PromptAttachment>> _pickSystemAttachments() async {
    final files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[PromptAttachmentService.pickerTypeGroup],
    );
    if (files.isEmpty) {
      return const <PromptAttachment>[];
    }
    final result = await _loadPromptAttachmentsFromFiles(files);
    return result.attachments;
  }

  Future<void> _dropComposerFiles(List<XFile> files) async {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null || _activePromptSubmitInFlight) {
      return;
    }
    await _dropComposerFilesForScope(scopeKey, files);
  }

  Future<void> _dropComposerFilesForScope(
    String scopeKey,
    List<XFile> files,
  ) async {
    if (files.isEmpty || _promptSubmitInFlightScopeKeys.contains(scopeKey)) {
      return;
    }
    try {
      final result = await _loadPromptAttachmentsFromFiles(files);
      if (!mounted || result.attachments.isEmpty) {
        return;
      }
      _appendComposerAttachmentsForScope(
        scopeKey,
        result.attachments,
        requestFocus: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to attach dropped files: $error',
        tone: AppSnackBarTone.danger,
      );
    }
  }

  Widget _buildComposerDropRegion({
    required Widget child,
    required bool enabled,
    required ValueChanged<bool> onHoverChanged,
    required WorkspaceComposerDropFilesHandler onFilesDropped,
  }) {
    final customBuilder = widget.composerDropRegionBuilder;
    if (customBuilder != null) {
      return customBuilder(
        child: child,
        enabled: enabled,
        onHoverChanged: onHoverChanged,
        onFilesDropped: onFilesDropped,
      );
    }
    if (!enabled) {
      return child;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return child;
      case TargetPlatform.android:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        break;
    }
    return DropTarget(
      onDragDone: (detail) {
        onHoverChanged(false);
        unawaited(onFilesDropped(detail.files));
      },
      onDragEntered: (_) => onHoverChanged(true),
      onDragExited: (_) => onHoverChanged(false),
      child: child,
    );
  }

  void _removeComposerAttachment(String attachmentId) {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null) {
      return;
    }
    _removeComposerAttachmentForScope(scopeKey, attachmentId);
  }

  void _addReviewCommentToComposerContext(
    _ReviewLineCommentSubmission submission,
  ) {
    final scopeKey = _activeComposerScopeKey;
    if (scopeKey == null) {
      _showSnackBar(
        'Open a session composer before adding review context.',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    final attachment = _buildReviewCommentAttachment(submission);
    final added = _appendComposerAttachmentsForScope(
      scopeKey,
      <PromptAttachment>[attachment],
      requestFocus: true,
    );
    if (!added) {
      _showSnackBar(
        'This review comment is already in the composer context.',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    if (_compactPane != _CompactWorkspacePane.session) {
      setState(() {
        _compactPane = _CompactWorkspacePane.session;
      });
    }
    _showSnackBar('Added review comment to composer context.');
  }

  PromptAttachment _buildReviewCommentAttachment(
    _ReviewLineCommentSubmission submission,
  ) {
    final comment = submission.comment.trim();
    final target = submission.target;
    final payload = StringBuffer()
      ..writeln('Review comment context')
      ..writeln()
      ..writeln('File: ${target.path}')
      ..writeln('Location: ${target.locationLabel}')
      ..writeln()
      ..writeln('Comment:')
      ..writeln(comment)
      ..writeln()
      ..writeln('Diff excerpt:')
      ..writeln(target.preview.trimRight());
    final digest = base64Url
        .encode(
          utf8.encode(
            '${target.path}|${target.oldLineNumber ?? ''}|${target.newLineNumber ?? ''}|$comment',
          ),
        )
        .replaceAll('=', '');
    return PromptAttachment(
      id: 'review-comment-$digest',
      filename: 'Review · ${target.path} · ${target.locationLabel}.txt',
      mime: 'text/plain',
      url:
          'data:text/plain;base64,${base64Encode(utf8.encode(payload.toString().trimRight()))}',
    );
  }

  Future<void> _focusComposerForPane(
    _WorkspacePaneViewModel paneViewModel,
  ) async {
    await _activatePaneComposer(paneViewModel, requestFocus: true);
  }

  Future<void> _pickComposerAttachmentsForPane(
    _WorkspacePaneViewModel paneViewModel,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    await _pickComposerAttachmentsForScope(scopeKey);
  }

  Future<void> _submitPromptForPane(
    _WorkspacePaneViewModel paneViewModel,
    WorkspacePromptDispatchMode? mode,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    await _submitPrompt(mode);
  }

  Future<void> _editQueuedPromptForPane(
    _WorkspacePaneViewModel paneViewModel,
    String queuedPromptId,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    await _editQueuedPrompt(queuedPromptId);
  }

  Future<void> _deleteQueuedPromptForPane(
    _WorkspacePaneViewModel paneViewModel,
    String queuedPromptId,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    await _deleteQueuedPrompt(queuedPromptId);
  }

  Future<void> _sendQueuedPromptNowForPane(
    _WorkspacePaneViewModel paneViewModel,
    String queuedPromptId,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    await _sendQueuedPromptNow(queuedPromptId);
  }

  Future<void> _interruptPaneSession(
    _WorkspacePaneViewModel paneViewModel,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    await _interruptSelectedSession();
  }

  Future<void> _createSessionFromPane(
    _WorkspacePaneViewModel paneViewModel,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    await _createNewSession(controller);
  }

  Future<void> _selectSideTabForPane(
    _WorkspacePaneViewModel paneViewModel,
    WorkspaceSideTab tab,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey != scopeKey ||
        _activeDesktopSessionPaneId != paneViewModel.pane.id) {
      await _activatePaneComposer(paneViewModel);
    }
    if (!mounted) {
      return;
    }
    _controller?.setSideTab(tab);
  }

  void _selectAgentForPane(
    _WorkspacePaneViewModel paneViewModel,
    String? agentName,
  ) {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey == scopeKey &&
        _activeDesktopSessionPaneId == paneViewModel.pane.id) {
      paneViewModel.controller.selectAgent(agentName);
      return;
    }
    unawaited(() async {
      final controller = await _activatePaneComposer(paneViewModel);
      if (!mounted || controller == null) {
        return;
      }
      controller.selectAgent(agentName);
    }());
  }

  void _selectModelForPane(
    _WorkspacePaneViewModel paneViewModel,
    String? modelKey,
  ) {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey == scopeKey &&
        _activeDesktopSessionPaneId == paneViewModel.pane.id) {
      paneViewModel.controller.selectModel(modelKey);
      return;
    }
    unawaited(() async {
      final controller = await _activatePaneComposer(paneViewModel);
      if (!mounted || controller == null) {
        return;
      }
      controller.selectModel(modelKey);
    }());
  }

  void _selectReasoningForPane(
    _WorkspacePaneViewModel paneViewModel,
    String? reasoning,
  ) {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey == scopeKey &&
        _activeDesktopSessionPaneId == paneViewModel.pane.id) {
      paneViewModel.controller.selectReasoning(reasoning);
      return;
    }
    unawaited(() async {
      final controller = await _activatePaneComposer(paneViewModel);
      if (!mounted || controller == null) {
        return;
      }
      controller.selectReasoning(reasoning);
    }());
  }

  Future<void> _togglePermissionAutoAcceptForController(
    WorkspaceController controller, {
    required String? sessionId,
  }) async {
    try {
      final enabled = await controller.togglePermissionAutoAcceptForSession(
        sessionId,
      );
      if (!mounted) {
        return;
      }
      final targetLabel = sessionId == null || sessionId.trim().isEmpty
          ? 'this project'
          : 'this session';
      _showSnackBar(
        enabled
            ? 'Permission auto-accept enabled for $targetLabel.'
            : 'Permission auto-accept disabled for $targetLabel.',
        tone: enabled ? AppSnackBarTone.success : AppSnackBarTone.info,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to update permission auto-accept: $error',
        tone: AppSnackBarTone.danger,
      );
    }
  }

  Future<void> _toggleSelectedPermissionAutoAccept() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await _togglePermissionAutoAcceptForController(
      controller,
      sessionId: controller.selectedSessionId,
    );
  }

  Future<void> _togglePermissionAutoAcceptForPane(
    _WorkspacePaneViewModel paneViewModel,
  ) async {
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    if (_activeComposerScopeKey == scopeKey &&
        _activeDesktopSessionPaneId == paneViewModel.pane.id) {
      await _togglePermissionAutoAcceptForController(
        paneViewModel.controller,
        sessionId: paneViewModel.pane.sessionId,
      );
      return;
    }
    final controller = await _activatePaneComposer(paneViewModel);
    if (!mounted || controller == null) {
      return;
    }
    await _togglePermissionAutoAcceptForController(
      controller,
      sessionId: paneViewModel.pane.sessionId,
    );
  }

  Future<void> _submitPrompt(WorkspacePromptDispatchMode? mode) async {
    final controller = _controller;
    final scopeKey = _activeComposerScopeKey;
    final draft = _promptController.text;
    final attachments = List<PromptAttachment>.from(_composerAttachments);
    if (controller == null ||
        scopeKey == null ||
        _promptSubmitInFlightScopeKeys.contains(scopeKey) ||
        controller.submittingPrompt ||
        (draft.trim().isEmpty && attachments.isEmpty)) {
      return;
    }

    final appController = AppScope.of(context);
    final effectiveMode =
        mode ??
        (_isActiveSessionStatus(controller.selectedStatus)
            ? switch (appController.busyFollowupMode) {
                WorkspaceFollowupMode.queue =>
                  WorkspacePromptDispatchMode.queue,
                WorkspaceFollowupMode.steer =>
                  WorkspacePromptDispatchMode.steer,
              }
            : null);
    final nextSubmitEpoch = _promptSubmitEpoch + 1;

    setState(() {
      _promptSubmitInFlightScopeKeys = <String>{
        ..._promptSubmitInFlightScopeKeys,
        scopeKey,
      };
      _composerAttachments = const <PromptAttachment>[];
      _promptSubmitEpoch = nextSubmitEpoch;
      _recentSubmittedPromptDraft = draft;
      _updateComposerScopeState(
        scopeKey,
        draft: '',
        attachments: const <PromptAttachment>[],
        submittedDraftEpoch: nextSubmitEpoch,
        recentSubmittedDraft: draft,
      );
    });
    _promptController.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );

    try {
      await controller.submitPrompt(
        draft,
        attachments: attachments,
        mode: effectiveMode,
      );
      await _appendComposerHistoryEntry(scopeKey, draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final restoredEpoch = nextSubmitEpoch + 1;
      setState(() {
        _updateComposerScopeState(
          scopeKey,
          draft: draft,
          attachments: attachments,
          submittedDraftEpoch: restoredEpoch,
          recentSubmittedDraft: null,
        );
        if (_activeComposerScopeKey == scopeKey) {
          _composerAttachments = List<PromptAttachment>.unmodifiable(
            attachments,
          );
          _recentSubmittedPromptDraft = null;
          _promptSubmitEpoch = restoredEpoch;
        }
      });
      if (_activeComposerScopeKey == scopeKey) {
        _promptController.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length),
        );
      }
      _showSnackBar(
        'Failed to send message: $error',
        tone: AppSnackBarTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          final nextInFlight = Set<String>.from(_promptSubmitInFlightScopeKeys)
            ..remove(scopeKey);
          _promptSubmitInFlightScopeKeys = Set<String>.unmodifiable(
            nextInFlight,
          );
        });
      }
    }
  }

  Future<void> _editQueuedPrompt(String queuedPromptId) async {
    final controller = _controller;
    final scopeKey = _activeComposerScopeKey;
    if (controller == null || scopeKey == null) {
      return;
    }
    final queuedPrompt = await controller.editSelectedQueuedPrompt(
      queuedPromptId,
    );
    if (!mounted || queuedPrompt == null) {
      return;
    }
    if (queuedPrompt.agentName != null) {
      controller.selectAgent(queuedPrompt.agentName);
    }
    controller.selectModel(queuedPrompt.modelKey);
    controller.selectReasoning(queuedPrompt.reasoning);
    final nextAttachments = List<PromptAttachment>.from(
      queuedPrompt.attachments,
    );
    setState(() {
      _updateComposerScopeState(
        scopeKey,
        draft: queuedPrompt.prompt,
        attachments: nextAttachments,
        recentSubmittedDraft: null,
      );
      if (_activeComposerScopeKey == scopeKey) {
        _composerAttachments = nextAttachments;
        _recentSubmittedPromptDraft = null;
      }
    });
    if (_activeComposerScopeKey == scopeKey) {
      _promptController.value = TextEditingValue(
        text: queuedPrompt.prompt,
        selection: TextSelection.collapsed(offset: queuedPrompt.prompt.length),
        composing: TextRange.empty,
      );
    }
  }

  Future<void> _deleteQueuedPrompt(String queuedPromptId) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.deleteSelectedQueuedPrompt(queuedPromptId);
  }

  Future<void> _sendQueuedPromptNow(String queuedPromptId) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.sendSelectedQueuedPromptNow(queuedPromptId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to send queued message: $error',
        tone: AppSnackBarTone.danger,
      );
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
      _showSnackBar(
        'Failed to interrupt the session: $error',
        tone: AppSnackBarTone.danger,
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
      _showSnackBar(
        'Renamed session to "${updated.title}".',
        tone: AppSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to rename session: $error',
        tone: AppSnackBarTone.danger,
      );
    }
  }

  Future<void> _forkSelectedSession(WorkspaceController controller) async {
    _preserveSelectedSessionIfVisibleElsewhere(controller);
    try {
      final forked = await controller.forkSelectedSession();
      if (!mounted || forked == null) {
        return;
      }
      _showSnackBar(
        'Forked into "${forked.title}".',
        tone: AppSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to fork session: $error',
        tone: AppSnackBarTone.danger,
      );
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
    _preserveSelectedSessionIfVisibleElsewhere(controller);
    try {
      final forked = await controller.forkSelectedSession(messageId: messageId);
      if (!mounted || forked == null) {
        return;
      }
      setState(() {
        _timelineJumpEpoch += 1;
      });
      _showSnackBar(
        'Forked from this message into "${forked.title}".',
        tone: AppSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to fork from this message: $error',
        tone: AppSnackBarTone.danger,
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
    _preserveSelectedSessionIfVisibleElsewhere(controller);
    try {
      final updated = await controller.revertSelectedSession(
        messageId: messageId,
      );
      if (!mounted || updated == null) {
        return;
      }
      setState(() {
        _timelineJumpEpoch += 1;
      });
      _showSnackBar(
        'Reverted the session to this message.',
        tone: AppSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to revert to this message: $error',
        tone: AppSnackBarTone.danger,
      );
    }
  }

  void _preserveSelectedSessionIfVisibleElsewhere(
    WorkspaceController controller,
  ) {
    if (_selectedSessionVisibleOutsideActivePane(controller)) {
      controller.preserveSelectedSessionTimelineForWatch();
    }
  }

  Future<void> _createNewSession(WorkspaceController controller) async {
    _preserveSelectedSessionIfVisibleElsewhere(controller);
    try {
      await controller.createEmptySession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to create session: $error',
        tone: AppSnackBarTone.danger,
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
        _showSnackBar(
          'Share link copied to clipboard.',
          tone: AppSnackBarTone.success,
        );
        return;
      }
      _showSnackBar('Session shared.', tone: AppSnackBarTone.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to share session: $error',
        tone: AppSnackBarTone.danger,
      );
    }
  }

  Future<void> _unshareSelectedSession(WorkspaceController controller) async {
    try {
      final updated = await controller.unshareSelectedSession();
      if (!mounted || updated == null) {
        return;
      }
      _showSnackBar('Share link removed.', tone: AppSnackBarTone.info);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to unshare session: $error',
        tone: AppSnackBarTone.danger,
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
      _showSnackBar(
        'Failed to compact session: $error',
        tone: AppSnackBarTone.danger,
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

    _preserveSelectedSessionIfVisibleElsewhere(controller);
    try {
      final nextSession = await controller.deleteSelectedSession();
      if (!mounted) {
        return;
      }
      final message = nextSession == null
          ? 'Session deleted.'
          : 'Session deleted. Opened "${nextSession.title}".';
      _showSnackBar(message, tone: AppSnackBarTone.warning);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Failed to delete session: $error',
        tone: AppSnackBarTone.danger,
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
          controller: controller,
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
    String? focusMessageId,
  }) async {
    if (!compact && _selectedSessionVisibleOutsideActivePane(controller)) {
      controller.preserveSelectedSessionTimelineForWatch();
    }
    if (!compact) {
      setState(() {
        _timelineJumpEpoch += 1;
      });
    }
    if (compact && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
    }
    await controller.selectSession(sessionId);
    if (!mounted) {
      return;
    }
    final targetMessageId = focusMessageId?.trim();
    if (targetMessageId != null && targetMessageId.isNotEmpty) {
      _requestTimelineMessageFocus(
        directory: controller.directory,
        sessionId: sessionId,
        messageId: targetMessageId,
      );
    }
  }

  bool _selectedSessionVisibleOutsideActivePane(
    WorkspaceController controller,
  ) {
    final selectedSessionId = controller.selectedSessionId?.trim();
    if (selectedSessionId == null || selectedSessionId.isEmpty) {
      return false;
    }
    final profile = _profile;
    if (profile == null) {
      return false;
    }
    final appController = AppScope.of(context);
    final activePaneId = _activeDesktopSessionPaneId;
    for (final pane in _resolvedDesktopSessionPanes(
      appController,
      profile,
      controller,
    )) {
      if (pane.id == activePaneId) {
        continue;
      }
      if (pane.directory == controller.directory &&
          pane.sessionId == selectedSessionId) {
        return true;
      }
    }
    return false;
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
    final currentController = _controller;
    final shouldPreserveShell =
        currentController != null &&
        !appController.hasWorkspaceController(
          profile: profile,
          directory: project.directory,
        );
    if (currentController != null &&
        _selectedSessionVisibleOutsideActivePane(currentController)) {
      currentController.preserveSelectedSessionTimelineForWatch();
    }

    setState(() {
      _projectLoadingShellState = shouldPreserveShell
          ? _WorkspaceProjectLoadingShellState(
              targetProject: project,
              projects: _mergedProjectsWithTarget(
                currentController.availableProjects,
                project,
              ),
            )
          : null;
      _bindWorkspace(
        appController: appController,
        profile: profile,
        directory: project.directory,
        routeSessionId: null,
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
    var nextIcon =
        draft.icon?.effectiveImage == null &&
            (draft.icon?.color?.trim().isEmpty ?? true)
        ? null
        : draft.icon;
    final clearedExistingIconImage =
        project.icon?.effectiveImage != null &&
        nextIcon != null &&
        nextIcon.effectiveImage == null;
    if (clearedExistingIconImage) {
      nextIcon = nextIcon.copyWith(url: '', override: '');
    }
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
        _showSnackBar(
          'Failed to update project: $error',
          tone: AppSnackBarTone.danger,
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

  Future<void> _reorderProjects(
    WebParityAppController appController,
    List<ProjectTarget> orderedProjects,
  ) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    await appController.reorderProjects(
      profile: profile,
      orderedProjects: orderedProjects,
    );
  }

  Widget _buildPaneComposer(
    WebParityAppController appController,
    _WorkspacePaneViewModel paneViewModel, {
    required bool compact,
    required bool selected,
  }) {
    final density = _workspaceDensity(context);
    final pane = paneViewModel.pane;
    final controller = paneViewModel.controller;
    final sessionId = pane.sessionId?.trim();
    final scopeKey = _composerScopeKeyForPane(paneViewModel);
    final questionRequest = controller.currentQuestionRequestForSession(
      sessionId,
    );
    final permissionRequest = controller.currentPermissionRequestForSession(
      sessionId,
    );

    if (sessionId == null && controller.loading) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          density.inset(compact ? AppSpacing.sm : AppSpacing.lg),
          density.inset(compact ? AppSpacing.xs : AppSpacing.md),
          density.inset(compact ? AppSpacing.sm : AppSpacing.lg),
          density.inset(compact ? AppSpacing.sm : AppSpacing.lg),
        ),
        child: _PromptComposerLoadingPlaceholder(compact: compact),
      );
    }

    if (sessionId == null && controller.error != null) {
      return const SizedBox.shrink();
    }

    if (questionRequest != null || permissionRequest != null) {
      return const SizedBox.shrink();
    }

    return _PromptComposer(
      key: ValueKey<String>('pane-composer-${pane.id}::$scopeKey'),
      controller: _composerControllerForScope(scopeKey),
      compact: compact,
      scopeKey: scopeKey,
      textFieldKey: ValueKey<String>('composer-text-field-${pane.id}'),
      focusRequestToken: _promptComposerFocusTokenForScope(scopeKey),
      submitting:
          _promptSubmitInFlightScopeKeys.contains(scopeKey) ||
          (selected && controller.submittingPrompt),
      busyFollowupMode: appController.busyFollowupMode,
      interruptible:
          _promptSubmitInFlightScopeKeys.contains(scopeKey) ||
          controller.sessionInterruptibleForSession(sessionId),
      interrupting: controller.sessionInterruptingForSession(sessionId),
      pickingAttachments:
          _pickingComposerAttachments && _activeComposerScopeKey == scopeKey,
      attachments: _composerAttachmentsForScope(scopeKey),
      queuedPrompts: controller.queuedPromptsForSession(sessionId),
      failedQueuedPromptId: controller.failedQueuedPromptIdForSession(
        sessionId,
      ),
      sendingQueuedPromptId: controller.sendingQueuedPromptIdForSession(
        sessionId,
      ),
      agents: controller.composerAgents,
      models: controller.composerModels,
      selectedAgentName: controller.selectedAgentName,
      selectedModel: controller.selectedModel,
      selectedReasoning: controller.selectedReasoning,
      reasoningValues: controller.availableReasoningValues,
      customCommands: controller.composerCommands,
      historyEntries: _composerHistoryForScope(scopeKey),
      permissionAutoAccepting: controller.autoAcceptsPermissionForSession(
        sessionId,
      ),
      onSelectAgent: (value) => _selectAgentForPane(paneViewModel, value),
      onSelectModel: (value) => _selectModelForPane(paneViewModel, value),
      onSelectReasoning: (value) =>
          _selectReasoningForPane(paneViewModel, value),
      onTogglePermissionAutoAccept: () =>
          _togglePermissionAutoAcceptForPane(paneViewModel),
      onCreateSession: () => _createSessionFromPane(paneViewModel),
      onInterrupt: () => _interruptPaneSession(paneViewModel),
      onPickAttachments: () => _pickComposerAttachmentsForPane(paneViewModel),
      onDropFiles: (files) => _dropComposerFilesForScope(scopeKey, files),
      onPasteClipboardImage: () =>
          _tryPasteComposerClipboardImageForScope(scopeKey),
      onContentInserted: (content) =>
          _handleComposerContentInsertionForScope(scopeKey, content),
      dropRegionBuilder: _buildComposerDropRegion,
      onRemoveAttachment: (attachmentId) =>
          _removeComposerAttachmentForScope(scopeKey, attachmentId),
      onEditQueuedPrompt: (queuedPromptId) =>
          _editQueuedPromptForPane(paneViewModel, queuedPromptId),
      onDeleteQueuedPrompt: (queuedPromptId) =>
          _deleteQueuedPromptForPane(paneViewModel, queuedPromptId),
      onSendQueuedPromptNow: (queuedPromptId) =>
          _sendQueuedPromptNowForPane(paneViewModel, queuedPromptId),
      onShareSession: selected ? () => _shareSelectedSession(controller) : null,
      onUnshareSession: selected
          ? () => _unshareSelectedSession(controller)
          : null,
      onSummarizeSession: selected
          ? () => _summarizeSelectedSession(controller)
          : null,
      submittedDraftEpoch: _submittedDraftEpochForScope(scopeKey),
      recentSubmittedDraft: _recentSubmittedDraftForScope(scopeKey),
      onOpenMcpPicker: () => _openMcpPicker(controller),
      onToggleTerminal: _toggleTerminalPanel,
      onSelectSideTab: (tab) {
        unawaited(() async {
          await _selectSideTabForPane(paneViewModel, tab);
          if (!compact && !_desktopSidePanelVisible) {
            _setDesktopSidePanelVisible(true);
          }
        }());
      },
      onSubmit: (mode) => _submitPromptForPane(paneViewModel, mode),
      onActivateComposer: () {
        unawaited(_focusComposerForPane(paneViewModel));
      },
    );
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

    return Focus(
      autofocus: true,
      onKeyEvent: _handleWorkspaceShortcutKeyEvent,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
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
              MediaQuery.sizeOf(context).width <
              AppSpacing.wideLayoutBreakpoint;
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
          final profile = _profile!;
          final paneViewModels = compact
              ? <_WorkspacePaneViewModel>[
                  _WorkspacePaneViewModel(
                    pane: _WorkspaceSessionPaneSpec(
                      id: 'compact-pane',
                      directory: controller.directory,
                      sessionId: controller.selectedSessionId,
                    ),
                    controller: controller,
                    project: displayProject,
                  ),
                ]
              : _resolvedDesktopPaneViewModels(
                  appController: appController,
                  profile: profile,
                  activeController: controller,
                  projectLoadingShell: projectLoadingShell,
                );
          final activePaneId = compact
              ? paneViewModels.first.pane.id
              : (_activeDesktopSessionPaneId ??
                    (paneViewModels.isNotEmpty
                        ? paneViewModels.first.pane.id
                        : null));
          final desktopSidebarVisible = !compact && _desktopSidebarVisible;
          final desktopSidePanelVisible = !compact && _desktopSidePanelVisible;
          final desktopSessionPanes = compact
              ? const <_WorkspaceSessionPaneSpec>[]
              : List<_WorkspaceSessionPaneSpec>.unmodifiable(
                  paneViewModels.map((paneViewModel) => paneViewModel.pane),
                );
          _syncObservedPaneControllers(
            paneViewModels.map((paneViewModel) => paneViewModel.controller),
          );
          _scheduleWatchedSessionSync(
            compact
                ? const <WorkspaceController, Set<String>>{}
                : _watchedSessionIdsByController(paneViewModels),
          );
          final multiPaneDesktop = !compact && paneViewModels.length > 1;
          final usePerPaneComposer =
              multiPaneDesktop &&
              appController.multiPaneComposerMode ==
                  WorkspaceMultiPaneComposerMode.perPane;
          final activeComposerScopeKey = _resolvedActiveComposerScopeKey(
            controller,
          );
          final showBodyProjectLoadingShell =
              showProjectLoadingShell && !multiPaneDesktop;
          final showBodyInitialLoading =
              controller.loading &&
              projectLoadingShell == null &&
              !multiPaneDesktop;
          final showBodyError = controller.error != null && !multiPaneDesktop;
          final mainSession = _rootSessionFor(
            displayAllSessions,
            selectedSession,
          );
          final chatSearch = _resolveChatSearchState(controller);
          return Scaffold(
            key: _scaffoldKey,
            drawer: compact
                ? Drawer(
                    child: _WorkspaceSidebar(
                      width: _desktopSidebarDefaultWidth,
                      currentDirectory: _currentDirectory,
                      currentSessionId: showProjectLoadingShell
                          ? null
                          : controller.selectedSessionId,
                      project: displayProject,
                      projects: displayProjects,
                      sessions: displaySessions,
                      allSessions: displayAllSessions,
                      statuses: displayStatuses,
                      showSubsessions:
                          appController.sidebarChildSessionsVisible,
                      loadingProjectContents: showProjectLoadingShell,
                      onSelectProject: (project) => unawaited(
                        _selectProjectInPlace(project, compact: compact),
                      ),
                      onEditProject: (project) =>
                          unawaited(_editProject(project)),
                      onRemoveProject: (project) => unawaited(
                        _removeProject(controller, project, compact: compact),
                      ),
                      onReorderProjects: (projects) =>
                          _reorderProjects(appController, projects),
                      onSelectSession: (sessionId) {
                        unawaited(
                          _selectSessionInPlace(
                            controller,
                            sessionId,
                            compact: compact,
                          ),
                        );
                      },
                      projectNotificationStateForDirectory:
                          controller.projectNotificationForDirectory,
                      sessionNotificationStateForSession:
                          controller.sessionNotificationForSession,
                      hoverPreviewStateForSession:
                          controller.sessionHoverPreviewForSession,
                      onPrefetchSessionHoverPreview:
                          controller.prefetchSessionHoverPreview,
                      onFocusSessionMessage: (sessionId, messageId) {
                        unawaited(
                          _selectSessionInPlace(
                            controller,
                            sessionId,
                            compact: compact,
                            focusMessageId: messageId,
                          ),
                        );
                      },
                      onAddProject: () {
                        unawaited(_openProjectPickerShortcut());
                      },
                      onNewSession: () => _createNewSession(controller),
                      onOpenSettings: () => _openWorkspaceSettingsSheet(
                        appController,
                        controller,
                      ),
                    ),
                  )
                : null,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final resolvedDesktopWidths = compact
                      ? (sidebarWidth: 0.0, sidePanelWidth: 0.0)
                      : _resolvedDesktopColumnWidths(
                          totalWidth: totalWidth,
                          sidebarVisible: desktopSidebarVisible,
                          sidePanelVisible: desktopSidePanelVisible,
                        );
                  final sidebar = _WorkspaceSidebar(
                    width: resolvedDesktopWidths.sidebarWidth,
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
                    onSelectProject: (project) => unawaited(
                      _selectProjectInPlace(project, compact: compact),
                    ),
                    onEditProject: (project) =>
                        unawaited(_editProject(project)),
                    onRemoveProject: (project) => unawaited(
                      _removeProject(controller, project, compact: compact),
                    ),
                    onReorderProjects: (projects) =>
                        _reorderProjects(appController, projects),
                    onSelectSession: (sessionId) {
                      unawaited(
                        _selectSessionInPlace(
                          controller,
                          sessionId,
                          compact: compact,
                        ),
                      );
                    },
                    projectNotificationStateForDirectory:
                        controller.projectNotificationForDirectory,
                    sessionNotificationStateForSession:
                        controller.sessionNotificationForSession,
                    hoverPreviewStateForSession:
                        controller.sessionHoverPreviewForSession,
                    onPrefetchSessionHoverPreview:
                        controller.prefetchSessionHoverPreview,
                    onFocusSessionMessage: (sessionId, messageId) {
                      unawaited(
                        _selectSessionInPlace(
                          controller,
                          sessionId,
                          compact: compact,
                          focusMessageId: messageId,
                        ),
                      );
                    },
                    onAddProject: () {
                      unawaited(_openProjectPickerShortcut());
                    },
                    onNewSession: () => _createNewSession(controller),
                    onOpenSettings: () =>
                        _openWorkspaceSettingsSheet(appController, controller),
                  );

                  return Row(
                    children: <Widget>[
                      if (!compact)
                        _HorizontalReveal(
                          key: const ValueKey<String>(
                            'workspace-desktop-sidebar-reveal',
                          ),
                          visible: desktopSidebarVisible,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              KeyedSubtree(
                                key: const ValueKey<String>(
                                  'workspace-desktop-sidebar-pane',
                                ),
                                child: sidebar,
                              ),
                              Container(
                                width: 1,
                                color: Theme.of(context).dividerColor,
                              ),
                              _DesktopResizeHandle(
                                key: const ValueKey<String>(
                                  'workspace-desktop-sidebar-resize-handle',
                                ),
                                onDragUpdate: (delta) {
                                  _resizeDesktopSidebar(
                                    widthDelta: delta,
                                    totalWidth: totalWidth,
                                    sidePanelVisible: desktopSidePanelVisible,
                                    currentWidth:
                                        resolvedDesktopWidths.sidebarWidth,
                                  );
                                },
                                onDragEnd: _finishDesktopColumnResize,
                              ),
                            ],
                          ),
                        ),
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
                              onSetTimelineProgressDetailsVisible: appController
                                  .setTimelineProgressDetailsVisible,
                              terminalOpen: _terminalPanelOpen,
                              chatSearchVisible: _chatSearchVisible,
                              chatSearchController: _chatSearchController,
                              chatSearchFocusNode: _chatSearchFocusNode,
                              chatSearchStatusText: chatSearch.statusText,
                              chatSearchNavigationEnabled:
                                  chatSearch.hasMatches,
                              onOpenCommandPalette: () {
                                unawaited(_openCommandPalette(controller));
                              },
                              onOpenMcpPicker: () {
                                unawaited(_openMcpPicker(controller));
                              },
                              onOpenChatSearch: _openChatSearch,
                              onCloseChatSearch: _closeChatSearch,
                              onChatSearchChanged: _handleChatSearchChanged,
                              onPreviousChatSearchMatch: () =>
                                  _moveChatSearchMatch(-1),
                              onNextChatSearchMatch: () =>
                                  _moveChatSearchMatch(1),
                              onBackHome: () => Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/', (route) => false),
                              sessionsPanelVisible: desktopSidebarVisible,
                              sidePanelVisible: desktopSidePanelVisible,
                              sidePanelLabel: _desktopSidePanelLabel(
                                controller,
                              ),
                              onToggleSessionsPanel: compact
                                  ? null
                                  : _toggleDesktopSidebarVisibility,
                              onToggleSidePanel: compact
                                  ? null
                                  : _toggleDesktopSidePanelVisibility,
                              sessionPaneCount: compact
                                  ? 1
                                  : desktopSessionPanes.length,
                              canSplitSessionPane:
                                  !compact &&
                                  !controller.loading &&
                                  controller.error == null &&
                                  desktopSessionPanes.length <
                                      _maxDesktopSessionPanes,
                              onSplitSessionPane:
                                  compact ||
                                      controller.loading ||
                                      controller.error != null
                                  ? null
                                  : () => _splitDesktopSessionPane(controller),
                              onOpenDrawer: compact
                                  ? () =>
                                        _scaffoldKey.currentState?.openDrawer()
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
                              onRename: () =>
                                  _renameSelectedSession(controller),
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
                              child: showBodyProjectLoadingShell
                                  ? _WorkspaceProjectLoadingView(
                                      key: ValueKey<String>(
                                        'workspace-project-loading-${displayProject?.directory ?? _currentDirectory}',
                                      ),
                                      project: displayProject,
                                      compact: compact,
                                    )
                                  : showBodyInitialLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : showBodyError
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
                                      paneViewModels: paneViewModels,
                                      activePaneId: activePaneId,
                                      activeWorkspaceLoading:
                                          controller.loading,
                                      activeWorkspaceError: controller.error,
                                      sidePanelVisible: desktopSidePanelVisible,
                                      sidePanelWidth:
                                          resolvedDesktopWidths.sidePanelWidth,
                                      submittingPrompt:
                                          _activePromptSubmitInFlight ||
                                          controller.submittingPrompt,
                                      pickingAttachments:
                                          _pickingComposerAttachments,
                                      attachments: _composerAttachmentsForScope(
                                        activeComposerScopeKey,
                                      ),
                                      historyEntries: _composerHistoryForScope(
                                        activeComposerScopeKey,
                                      ),
                                      promptController:
                                          _composerControllerForScope(
                                            activeComposerScopeKey,
                                          ),
                                      promptFocusRequestToken:
                                          _promptComposerFocusTokenForScope(
                                            activeComposerScopeKey,
                                          ),
                                      submittedDraftEpoch:
                                          _submittedDraftEpochForScope(
                                            activeComposerScopeKey,
                                          ),
                                      recentSubmittedDraft:
                                          _recentSubmittedDraftForScope(
                                            activeComposerScopeKey,
                                          ),
                                      compactPane: _compactPane,
                                      busyFollowupMode:
                                          appController.busyFollowupMode,
                                      shellToolDefaultExpanded:
                                          appController.shellToolPartsExpanded,
                                      timelineProgressDetailsVisible:
                                          appController
                                              .timelineProgressDetailsVisible,
                                      chatSearchQuery: chatSearch.query,
                                      chatSearchMatchMessageIds:
                                          chatSearch.matchMessageIds,
                                      chatSearchActiveMessageId:
                                          chatSearch.activeMessageId,
                                      chatSearchRevision: chatSearch.revision,
                                      timelineJumpEpoch: _timelineJumpEpoch,
                                      focusedTimelineMessageIdForScope:
                                          _focusedTimelineMessageIdForScope,
                                      focusedTimelineMessageRevisionForScope:
                                          _focusedTimelineMessageRevisionForScope,
                                      onForkMessage: (message) =>
                                          _forkMessageIntoSession(
                                            controller,
                                            message,
                                          ),
                                      onRevertMessage: (message) =>
                                          _revertToMessage(controller, message),
                                      interruptiblePrompt:
                                          controller.selectedSessionId !=
                                              null &&
                                          (_activePromptSubmitInFlight ||
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
                                      onEditQueuedPrompt: _editQueuedPrompt,
                                      onDeleteQueuedPrompt: _deleteQueuedPrompt,
                                      onSendQueuedPromptNow:
                                          _sendQueuedPromptNow,
                                      onInterruptPrompt:
                                          _interruptSelectedSession,
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
                                      onSelectSessionPane: (paneId) =>
                                          _activateDesktopSessionPane(
                                            controller,
                                            paneId,
                                          ),
                                      onCloseSessionPane: (paneId) {
                                        unawaited(
                                          _closeDesktopSessionPane(
                                            controller,
                                            paneId,
                                          ),
                                        );
                                      },
                                      onPickAttachments:
                                          _pickComposerAttachments,
                                      onDropFiles: _dropComposerFiles,
                                      onPasteClipboardImage:
                                          _tryPasteComposerClipboardImage,
                                      onContentInserted:
                                          _handleComposerContentInsertion,
                                      onRemoveAttachment:
                                          _removeComposerAttachment,
                                      onAddReviewCommentToComposerContext:
                                          _addReviewCommentToComposerContext,
                                      onTogglePermissionAutoAccept:
                                          _toggleSelectedPermissionAutoAccept,
                                      onOpenMcpPicker: () =>
                                          _openMcpPicker(controller),
                                      dropRegionBuilder:
                                          _buildComposerDropRegion,
                                      inlineComposerBuilder: usePerPaneComposer
                                          ? (
                                              paneViewModel,
                                              selected,
                                              compact,
                                            ) => _buildPaneComposer(
                                              appController,
                                              paneViewModel,
                                              compact: compact,
                                              selected: selected,
                                            )
                                          : null,
                                      onShowSidePanel: compact
                                          ? null
                                          : () => _setDesktopSidePanelVisible(
                                              true,
                                            ),
                                      onResizeSidePanel:
                                          compact || !desktopSidePanelVisible
                                          ? null
                                          : (delta) {
                                              _resizeDesktopSidePanel(
                                                widthDelta: -delta,
                                                totalWidth: totalWidth,
                                                sidebarVisible:
                                                    desktopSidebarVisible,
                                                currentWidth:
                                                    resolvedDesktopWidths
                                                        .sidePanelWidth,
                                              );
                                            },
                                      onFinishResizeSidePanel:
                                          compact || !desktopSidePanelVisible
                                          ? null
                                          : _finishDesktopColumnResize,
                                      onShareSession:
                                          controller.selectedSession == null
                                          ? null
                                          : () => _shareSelectedSession(
                                              controller,
                                            ),
                                      onUnshareSession:
                                          controller.selectedSession == null
                                          ? null
                                          : () => _unshareSelectedSession(
                                              controller,
                                            ),
                                      onSummarizeSession:
                                          controller.selectedSession == null
                                          ? null
                                          : () => _summarizeSelectedSession(
                                              controller,
                                            ),
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
                                              onCreateSession:
                                                  _createPtySession,
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
                  );
                },
              ),
            ),
          );
        },
      ),
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

class _WorkspacePaneViewModel {
  const _WorkspacePaneViewModel({
    required this.pane,
    required this.controller,
    required this.project,
  });

  final _WorkspaceSessionPaneSpec pane;
  final WorkspaceController controller;
  final ProjectTarget? project;
}

class _WorkspaceComposerScopeState {
  const _WorkspaceComposerScopeState({
    this.draft = '',
    this.attachments = const <PromptAttachment>[],
    this.submittedDraftEpoch = 0,
    this.recentSubmittedDraft,
  });

  final String draft;
  final List<PromptAttachment> attachments;
  final int submittedDraftEpoch;
  final String? recentSubmittedDraft;

  bool get isEmpty =>
      draft.isEmpty &&
      attachments.isEmpty &&
      submittedDraftEpoch == 0 &&
      (recentSubmittedDraft == null || recentSubmittedDraft!.isEmpty);

  _WorkspaceComposerScopeState copyWith({
    String? draft,
    List<PromptAttachment>? attachments,
    int? submittedDraftEpoch,
    String? recentSubmittedDraft,
  }) {
    return _WorkspaceComposerScopeState(
      draft: draft ?? this.draft,
      attachments: attachments ?? this.attachments,
      submittedDraftEpoch: submittedDraftEpoch ?? this.submittedDraftEpoch,
      recentSubmittedDraft: recentSubmittedDraft,
    );
  }
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
    required this.chatSearchVisible,
    required this.chatSearchController,
    required this.chatSearchFocusNode,
    required this.chatSearchStatusText,
    required this.chatSearchNavigationEnabled,
    required this.onOpenCommandPalette,
    required this.onOpenMcpPicker,
    required this.onOpenChatSearch,
    required this.onCloseChatSearch,
    required this.onChatSearchChanged,
    required this.onPreviousChatSearchMatch,
    required this.onNextChatSearchMatch,
    required this.sessionsPanelVisible,
    required this.sidePanelVisible,
    required this.sidePanelLabel,
    required this.sessionPaneCount,
    required this.onBackHome,
    required this.onToggleTerminal,
    this.onToggleSessionsPanel,
    this.onToggleSidePanel,
    this.canSplitSessionPane = false,
    this.onSplitSessionPane,
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
  final bool chatSearchVisible;
  final TextEditingController chatSearchController;
  final FocusNode chatSearchFocusNode;
  final String chatSearchStatusText;
  final bool chatSearchNavigationEnabled;
  final VoidCallback onOpenCommandPalette;
  final VoidCallback onOpenMcpPicker;
  final VoidCallback onOpenChatSearch;
  final VoidCallback onCloseChatSearch;
  final ValueChanged<String> onChatSearchChanged;
  final VoidCallback onPreviousChatSearchMatch;
  final VoidCallback onNextChatSearchMatch;
  final bool sessionsPanelVisible;
  final bool sidePanelVisible;
  final String sidePanelLabel;
  final int sessionPaneCount;
  final VoidCallback onBackHome;
  final VoidCallback onToggleTerminal;
  final VoidCallback? onToggleSessionsPanel;
  final VoidCallback? onToggleSidePanel;
  final bool canSplitSessionPane;
  final VoidCallback? onSplitSessionPane;
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
    final density = _workspaceDensity(context);
    final desktopHorizontal = density.inset(AppSpacing.md, min: AppSpacing.sm);
    final desktopVertical = density.inset(AppSpacing.sm, min: AppSpacing.xs);
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
    final profileLabel = profile?.effectiveLabel.trim() ?? '';
    final projectDirectory = project?.directory.trim() ?? '';
    final searchBar = chatSearchVisible
        ? Padding(
            padding: compact
                ? EdgeInsets.fromLTRB(
                    density.inset(AppSpacing.sm, min: AppSpacing.xs),
                    0,
                    density.inset(AppSpacing.sm, min: AppSpacing.xs),
                    density.inset(AppSpacing.xs, min: 4),
                  )
                : EdgeInsets.fromLTRB(
                    desktopHorizontal,
                    0,
                    desktopHorizontal,
                    desktopVertical,
                  ),
            child: _WorkspaceChatSearchBar(
              compact: compact,
              controller: chatSearchController,
              focusNode: chatSearchFocusNode,
              statusText: chatSearchStatusText,
              navigationEnabled: chatSearchNavigationEnabled,
              onChanged: onChatSearchChanged,
              onPreviousMatch: onPreviousChatSearchMatch,
              onNextMatch: onNextChatSearchMatch,
              onClose: onCloseChatSearch,
            ),
          )
        : const SizedBox.shrink();
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
          label: 'Show to-do details in timeline',
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
          id: 'mcp',
          label: 'Toggle MCPs',
          icon: Icons.extension_rounded,
          onSelected: onOpenMcpPicker,
        ),
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
    final headerActionChips = <Widget>[
      if (onToggleSessionsPanel != null)
        _WorkspacePanelToggleChip(
          key: const ValueKey<String>('workspace-toggle-sessions-panel-button'),
          label: 'Sessions',
          icon: Icons.view_sidebar_rounded,
          active: sessionsPanelVisible,
          tooltip:
              '${sessionsPanelVisible ? 'Hide sessions panel' : 'Show sessions panel'} (${_formatWorkspaceShortcutLabel('mod+b')})',
          onTap: onToggleSessionsPanel!,
        ),
      if (onToggleSidePanel != null)
        _WorkspacePanelToggleChip(
          key: const ValueKey<String>('workspace-toggle-side-panel-button'),
          label: sidePanelLabel,
          icon: Icons.dashboard_rounded,
          active: sidePanelVisible,
          tooltip: sidePanelVisible
              ? 'Hide $sidePanelLabel panel'
              : 'Show $sidePanelLabel panel',
          onTap: onToggleSidePanel!,
        ),
      if (onSplitSessionPane != null)
        _WorkspaceActionChip(
          key: const ValueKey<String>('workspace-split-session-pane-button'),
          label: sessionPaneCount > 1 ? 'Split ($sessionPaneCount)' : 'Split',
          icon: Icons.splitscreen_rounded,
          enabled: canSplitSessionPane,
          tooltip: canSplitSessionPane
              ? 'Split the chat area into another session pane'
              : 'Maximum number of session panes open',
          onTap: onSplitSessionPane,
        ),
    ];
    final hasSessionMeta =
        canReturnToMain ||
        profileLabel.isNotEmpty ||
        projectDirectory.isNotEmpty ||
        headerActionChips.isNotEmpty;
    if (compact) {
      return Material(
        color: surfaces.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              constraints: BoxConstraints(
                minHeight: density.inset(54, min: 46),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: density.inset(AppSpacing.xxs, min: 2),
                vertical: 2,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: density.inset(AppSpacing.xxs, min: 2),
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
                      padding: EdgeInsets.only(
                        right: density.inset(AppSpacing.xxs, min: 2),
                      ),
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
                    key: const ValueKey<String>(
                      'workspace-command-palette-button',
                    ),
                    onPressed: onOpenCommandPalette,
                    icon: const Icon(Icons.apps_rounded, size: 18),
                    tooltip:
                        'Command palette (${_formatWorkspaceShortcutLabel('mod+k')})',
                    splashRadius: 18,
                  ),
                  IconButton(
                    key: const ValueKey<String>('workspace-mcp-picker-button'),
                    onPressed: onOpenMcpPicker,
                    icon: const Icon(Icons.extension_rounded, size: 18),
                    tooltip:
                        'Toggle MCPs (${_formatWorkspaceShortcutLabel('mod+;')})',
                    splashRadius: 18,
                  ),
                  IconButton(
                    key: const ValueKey<String>('workspace-chat-search-button'),
                    onPressed: onOpenChatSearch,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    tooltip: 'Search chat',
                    splashRadius: 18,
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
                  _SessionOverflowMenuButton(
                    compact: true,
                    sections: menuSections,
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: searchBar,
            ),
          ],
        ),
      );
    }
    return Material(
      color: surfaces.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: desktopHorizontal,
              vertical: desktopVertical,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
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
                    SizedBox(width: density.inset(AppSpacing.sm, min: 6)),
                    Expanded(
                      child: _SessionIdentity(
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
                    ),
                    if (session != null)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: _SessionContextUsageRing(
                          key: ValueKey<String>(
                            'session-header-context-ring-${session!.id}',
                          ),
                          usagePercent: contextSnapshot?.usagePercent,
                          totalTokens: contextSnapshot?.totalTokens,
                          contextLimit: contextSnapshot?.contextLimit,
                        ),
                      ),
                    SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
                    IconButton(
                      key: const ValueKey<String>(
                        'workspace-command-palette-button',
                      ),
                      onPressed: onOpenCommandPalette,
                      icon: const Icon(Icons.apps_rounded),
                      tooltip:
                          'Command palette (${_formatWorkspaceShortcutLabel('mod+k')})',
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'workspace-mcp-picker-button',
                      ),
                      onPressed: onOpenMcpPicker,
                      icon: const Icon(Icons.extension_rounded),
                      tooltip:
                          'Toggle MCPs (${_formatWorkspaceShortcutLabel('mod+;')})',
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'workspace-chat-search-button',
                      ),
                      onPressed: onOpenChatSearch,
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Search chat',
                    ),
                    IconButton(
                      onPressed: onToggleTerminal,
                      icon: Icon(
                        terminalOpen
                            ? Icons.terminal_rounded
                            : Icons.terminal_outlined,
                      ),
                      tooltip: terminalOpen ? 'Hide terminal' : 'Show terminal',
                    ),
                    _SessionOverflowMenuButton(sections: menuSections),
                  ],
                ),
                if (hasSessionMeta) ...<Widget>[
                  SizedBox(height: density.inset(AppSpacing.sm, min: 6)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _WorkspaceSessionHeaderMetaBlock(
                          profileLabel: profileLabel,
                          projectDirectory: projectDirectory,
                          canReturnToMain: canReturnToMain,
                          rootSessionTitle: rootSession?.title ?? '',
                          onBackToMainSession: onBackToMainSession,
                        ),
                      ),
                      if (headerActionChips.isNotEmpty) ...<Widget>[
                        SizedBox(width: density.inset(AppSpacing.md, min: 10)),
                        Flexible(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Wrap(
                              key: const ValueKey<String>(
                                'workspace-session-header-action-chips',
                              ),
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: density.inset(AppSpacing.xs, min: 4),
                              runSpacing: density.inset(AppSpacing.xs, min: 4),
                              children: headerActionChips,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: searchBar,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSessionHeaderMetaBlock extends StatelessWidget {
  const _WorkspaceSessionHeaderMetaBlock({
    required this.profileLabel,
    required this.projectDirectory,
    required this.canReturnToMain,
    required this.rootSessionTitle,
    required this.onBackToMainSession,
  });

  final String profileLabel;
  final String projectDirectory;
  final bool canReturnToMain;
  final String rootSessionTitle;
  final VoidCallback? onBackToMainSession;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    final hasMetaBadges = canReturnToMain || profileLabel.isNotEmpty;
    final hasDirectory = projectDirectory.isNotEmpty;
    if (!hasMetaBadges && !hasDirectory) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasMetaBadges)
          Wrap(
            spacing: density.inset(AppSpacing.xs, min: 4),
            runSpacing: density.inset(AppSpacing.xs, min: 4),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (canReturnToMain && onBackToMainSession != null)
                _WorkspaceSessionHeaderBackLink(
                  key: const ValueKey<String>(
                    'workspace-back-to-main-session-link',
                  ),
                  rootSessionTitle: rootSessionTitle,
                  onTap: onBackToMainSession!,
                ),
              if (profileLabel.isNotEmpty)
                _WorkspaceSessionHeaderMetaChip(
                  icon: Icons.dns_rounded,
                  label: profileLabel,
                ),
            ],
          ),
        if (hasDirectory)
          Padding(
            padding: EdgeInsets.only(
              top: hasMetaBadges ? density.inset(AppSpacing.xs, min: 4) : 0,
            ),
            child: _WorkspaceSessionHeaderPathLine(directory: projectDirectory),
          ),
      ],
    );
  }
}

class _WorkspaceSessionHeaderBackLink extends StatelessWidget {
  const _WorkspaceSessionHeaderBackLink({
    required this.rootSessionTitle,
    required this.onTap,
    super.key,
  });

  final String rootSessionTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: density.inset(AppSpacing.sm, min: 8),
            vertical: density.inset(AppSpacing.xxs, min: 4),
          ),
          decoration: BoxDecoration(
            color: surfaces.panelMuted.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            border: Border.all(color: surfaces.lineSoft),
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
              Text(
                rootSessionTitle.isNotEmpty ? rootSessionTitle : 'Main session',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSessionHeaderMetaChip extends StatelessWidget {
  const _WorkspaceSessionHeaderMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.sm, min: 8),
        vertical: density.inset(AppSpacing.xxs, min: 4),
      ),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: surfaces.muted),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: surfaces.muted,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSessionHeaderPathLine extends StatelessWidget {
  const _WorkspaceSessionHeaderPathLine({required this.directory});

  final String directory;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      key: const ValueKey<String>('session-header-project-path'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.sm, min: 8),
        vertical: density.inset(AppSpacing.xs, min: 6),
      ),
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.folder_open_rounded, size: 16, color: surfaces.muted),
          SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
          Expanded(
            child: Text(
              directory,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: surfaces.muted,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceChatSearchBar extends StatelessWidget {
  const _WorkspaceChatSearchBar({
    required this.compact,
    required this.controller,
    required this.focusNode,
    required this.statusText,
    required this.navigationEnabled,
    required this.onChanged,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onClose,
  });

  final bool compact;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String statusText;
  final bool navigationEnabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onPreviousMatch;
  final VoidCallback onNextMatch;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      key: const ValueKey<String>('workspace-chat-search-panel'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(compact ? AppSpacing.sm : AppSpacing.md),
        vertical: density.inset(compact ? AppSpacing.xs : AppSpacing.sm),
      ),
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, size: 18, color: surfaces.muted),
          SizedBox(width: density.inset(AppSpacing.sm, min: 6)),
          Expanded(
            child: TextField(
              key: const ValueKey<String>('workspace-chat-search-field'),
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onNextMatch(),
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search this chat',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: surfaces.muted,
                ),
              ),
            ),
          ),
          SizedBox(width: density.inset(AppSpacing.sm, min: 6)),
          Container(
            key: const ValueKey<String>('workspace-chat-search-status'),
            padding: EdgeInsets.symmetric(
              horizontal: density.inset(AppSpacing.xs, min: 4),
              vertical: density.inset(AppSpacing.xxs, min: 2),
            ),
            decoration: BoxDecoration(
              color: surfaces.panelMuted.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: surfaces.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
          IconButton(
            key: const ValueKey<String>(
              'workspace-chat-search-previous-button',
            ),
            onPressed: navigationEnabled ? onPreviousMatch : null,
            tooltip: 'Previous match',
            splashRadius: compact ? 16 : 18,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            key: const ValueKey<String>('workspace-chat-search-next-button'),
            onPressed: navigationEnabled ? onNextMatch : null,
            tooltip: 'Next match',
            splashRadius: compact ? 16 : 18,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            key: const ValueKey<String>('workspace-chat-search-close-button'),
            onPressed: onClose,
            tooltip: 'Close search',
            splashRadius: compact ? 16 : 18,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePanelToggleChip extends StatelessWidget {
  const _WorkspacePanelToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final accent = theme.colorScheme.primary;
    final backgroundColor = active
        ? accent.withValues(alpha: 0.12)
        : surfaces.panelRaised.withValues(alpha: 0.78);
    final borderColor = active
        ? accent.withValues(alpha: 0.26)
        : surfaces.lineSoft;
    final foregroundColor = active ? accent : surfaces.muted;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: density.inset(AppSpacing.sm),
              vertical: density.inset(AppSpacing.xs, min: 4),
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: foregroundColor),
                SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? theme.colorScheme.onSurface : null,
                    fontWeight: FontWeight.w700,
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

class _WorkspaceActionChip extends StatelessWidget {
  const _WorkspaceActionChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.52,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: density.inset(AppSpacing.sm),
                vertical: density.inset(AppSpacing.xs, min: 4),
              ),
              decoration: BoxDecoration(
                color: surfaces.panelRaised.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                border: Border.all(color: surfaces.lineSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 16, color: surfaces.muted),
                  SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
    required this.controller,
    required this.onManageServers,
    this.profile,
    this.report,
    this.project,
  });

  final WebParityAppController appController;
  final WorkspaceController controller;
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
  String? _savingPermissionToolId;

  Future<void> _openReleaseNotes() async {
    final releaseNotes = widget.appController.currentReleaseNotes;
    if (releaseNotes == null) {
      return;
    }
    await widget.appController.markReleaseNotesSeen(
      releaseNotes.currentVersion,
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AppReleaseNotesDialog(notes: releaseNotes),
    );
  }

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
      showAppSnackBar(
        context,
        message: 'Failed to refresh server status: $error',
        tone: AppSnackBarTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingProbe = false;
        });
      }
    }
  }

  Future<void> _setPermissionAction(
    String toolId,
    ConfigPermissionAction action,
  ) async {
    if (_savingPermissionToolId == toolId) {
      return;
    }
    setState(() {
      _savingPermissionToolId = toolId;
    });
    try {
      await widget.controller.updateToolPermissionAction(toolId, action);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: 'Failed to update tool permissions: $error',
        tone: AppSnackBarTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingPermissionToolId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final sectionGap = density.inset(AppSpacing.lg, min: AppSpacing.md);
    final sheetOuterPadding = density.inset(AppSpacing.md, min: AppSpacing.sm);
    final sheetTopPadding = density.inset(AppSpacing.lg, min: AppSpacing.md);
    final sheetHeaderLead = density.inset(AppSpacing.lg, min: AppSpacing.md);
    final headerBottom = density.inset(AppSpacing.md, min: AppSpacing.sm);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.appController,
        widget.controller,
      ]),
      builder: (context, _) {
        final profile = widget.appController.selectedProfile ?? widget.profile;
        final report = widget.appController.selectedReport ?? widget.report;
        final statusMeta = _workspaceSettingsStatusMeta(
          theme,
          surfaces,
          report,
        );
        final currentProject = widget.project;
        final permissionPolicies = resolveConfigPermissionToolPolicies(
          widget.controller.configSnapshot?.config,
        );
        final hasCustomPermissionRules = permissionPolicies.any(
          (policy) => policy.hasCustomPatterns,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            sheetOuterPadding,
            sheetTopPadding,
            sheetOuterPadding,
            sheetOuterPadding,
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
                              padding: EdgeInsets.fromLTRB(
                                sheetHeaderLead,
                                sheetHeaderLead,
                                sheetOuterPadding,
                                headerBottom,
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
                              padding: EdgeInsets.fromLTRB(
                                sheetHeaderLead,
                                headerBottom,
                                sheetHeaderLead,
                                sheetHeaderLead,
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
                                SizedBox(height: sectionGap),
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
                                              'Show to-do details in timeline',
                                          subtitle:
                                              'Display to-do updates directly in the chat stream.',
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
                                SizedBox(height: sectionGap),
                                _WorkspaceSettingsSection(
                                  title: 'Composer',
                                  child: _WorkspaceSettingsCard(
                                    child: Column(
                                      children: <Widget>[
                                        _WorkspaceSettingsFollowupModeRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-followup-mode-row',
                                          ),
                                          value: widget
                                              .appController
                                              .busyFollowupMode,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setBusyFollowupMode(value),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        _WorkspaceSettingsMultiPaneComposerModeRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-multi-pane-composer-mode-row',
                                          ),
                                          value: widget
                                              .appController
                                              .multiPaneComposerMode,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setMultiPaneComposerMode(
                                                    value,
                                                  ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                _WorkspaceSettingsSection(
                                  title: 'Permissions',
                                  child: _WorkspaceSettingsCard(
                                    key: const ValueKey<String>(
                                      'workspace-settings-permissions-card',
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Control what tools the server can use by default.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: surfaces.muted),
                                        ),
                                        if (hasCustomPermissionRules) ...<
                                          Widget
                                        >[
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'Path-specific permission rules already in config are preserved when you change a default here.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: surfaces.muted,
                                                ),
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.md),
                                        for (
                                          var index = 0;
                                          index < permissionPolicies.length;
                                          index += 1
                                        ) ...<Widget>[
                                          _WorkspaceSettingsPermissionRow(
                                            key: ValueKey<String>(
                                              'workspace-settings-permission-row-${permissionPolicies[index].tool.id}',
                                            ),
                                            policy: permissionPolicies[index],
                                            saving:
                                                _savingPermissionToolId ==
                                                permissionPolicies[index]
                                                    .tool
                                                    .id,
                                            onChanged: (value) {
                                              unawaited(
                                                _setPermissionAction(
                                                  permissionPolicies[index]
                                                      .tool
                                                      .id,
                                                  value,
                                                ),
                                              );
                                            },
                                          ),
                                          if (index !=
                                              permissionPolicies.length - 1)
                                            const SizedBox(
                                              height: AppSpacing.md,
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                _WorkspaceSettingsSection(
                                  title: 'Appearance',
                                  child: _WorkspaceSettingsCard(
                                    child: Column(
                                      children: <Widget>[
                                        _WorkspaceSettingsThemeRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-theme-row',
                                          ),
                                          value:
                                              widget.appController.themePreset,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setThemePreset(value),
                                            );
                                          },
                                          onCycle: () {
                                            unawaited(
                                              widget.appController
                                                  .cycleThemePreset(),
                                            );
                                          },
                                        ),
                                        SizedBox(height: sectionGap),
                                        _WorkspaceSettingsColorSchemeRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-color-mode-row',
                                          ),
                                          value: widget
                                              .appController
                                              .colorSchemeMode,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setColorSchemeMode(value),
                                            );
                                          },
                                          onCycle: () {
                                            unawaited(
                                              widget.appController
                                                  .cycleColorSchemeMode(),
                                            );
                                          },
                                        ),
                                        SizedBox(height: sectionGap),
                                        _WorkspaceSettingsLayoutDensityRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-layout-density-row',
                                          ),
                                          value: widget
                                              .appController
                                              .layoutDensity,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setLayoutDensity(value),
                                            );
                                          },
                                        ),
                                        SizedBox(height: sectionGap),
                                        _WorkspaceSettingsTextScaleRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-text-scale-row',
                                          ),
                                          value: widget
                                              .appController
                                              .textScaleFactor,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setTextScaleFactor(value),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                _WorkspaceSettingsSection(
                                  title: "What's New",
                                  child: _WorkspaceSettingsCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _WorkspaceSettingsToggleRow(
                                          key: const ValueKey<String>(
                                            'workspace-settings-release-notes-toggle',
                                          ),
                                          title:
                                              "Show What's New after updates",
                                          subtitle:
                                              'Automatically open release highlights when the bundled app version changes.',
                                          value: widget
                                              .appController
                                              .releaseNotesEnabled,
                                          onChanged: (value) {
                                            unawaited(
                                              widget.appController
                                                  .setReleaseNotesEnabled(
                                                    value,
                                                  ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(
                                            AppSpacing.md,
                                          ),
                                          decoration: BoxDecoration(
                                            color: surfaces.panelMuted
                                                .withValues(alpha: 0.52),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.075,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Text(
                                                      widget
                                                                  .appController
                                                                  .currentReleaseNotes ==
                                                              null
                                                          ? 'No release notes are bundled yet.'
                                                          : 'Latest bundled highlights: ${widget.appController.currentReleaseNotes!.versionLabel}',
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      height: AppSpacing.xxs,
                                                    ),
                                                    Text(
                                                      'Open the current release notes again at any time from here.',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                surfaces.muted,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.md,
                                              ),
                                              OutlinedButton.icon(
                                                key: const ValueKey<String>(
                                                  'workspace-settings-open-whats-new-button',
                                                ),
                                                onPressed:
                                                    widget
                                                            .appController
                                                            .currentReleaseNotes ==
                                                        null
                                                    ? null
                                                    : () {
                                                        unawaited(
                                                          _openReleaseNotes(),
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.auto_awesome_rounded,
                                                ),
                                                label: const Text(
                                                  "Open What's New",
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                _WorkspaceSettingsSection(
                                  title: 'Keyboard',
                                  child:
                                      const _WorkspaceKeyboardShortcutsCard(),
                                ),
                                SizedBox(height: sectionGap),
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
    final density = _workspaceDensity(context);
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
        SizedBox(height: density.inset(AppSpacing.sm)),
        child,
      ],
    );
  }
}

class _WorkspaceSettingsCard extends StatelessWidget {
  const _WorkspaceSettingsCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(density.inset(AppSpacing.md)),
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
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.md),
        vertical: density.inset(AppSpacing.sm),
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
          SizedBox(width: density.inset(AppSpacing.md)),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsPermissionRow extends StatelessWidget {
  const _WorkspaceSettingsPermissionRow({
    required this.policy,
    required this.saving,
    required this.onChanged,
    super.key,
  });

  final ConfigPermissionToolPolicy policy;
  final bool saving;
  final ValueChanged<ConfigPermissionAction> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final notes = <String>[
      if (policy.inheritedFromWildcard) 'Inherited from global default',
      if (policy.hasCustomPatterns) 'Custom patterns preserved',
    ];
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
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
                    Text(
                      policy.tool.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      policy.tool.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (saving)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              notes.join(' • '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: surfaces.muted,
              ),
            ),
          ],
          SizedBox(height: density.inset(AppSpacing.sm)),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: ConfigPermissionAction.values
                .map((action) {
                  final selected = policy.action == action;
                  return ChoiceChip(
                    key: ValueKey<String>(
                      'workspace-settings-permission-${policy.tool.id}-${action.storageValue}',
                    ),
                    label: Text(action.label),
                    selected: selected,
                    onSelected: saving || selected
                        ? null
                        : (_) {
                            onChanged(action);
                          },
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsFollowupModeRow extends StatelessWidget {
  const _WorkspaceSettingsFollowupModeRow({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final WorkspaceFollowupMode value;
  final ValueChanged<WorkspaceFollowupMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Default busy follow-up mode',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Choose what a normal send does while the current agent is still working.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkspaceFollowupMode>(
              key: const ValueKey<String>(
                'workspace-settings-followup-mode-segments',
              ),
              showSelectedIcon: false,
              segments: const <ButtonSegment<WorkspaceFollowupMode>>[
                ButtonSegment<WorkspaceFollowupMode>(
                  value: WorkspaceFollowupMode.queue,
                  label: Text('Queue'),
                  icon: Icon(Icons.schedule_send_rounded),
                ),
                ButtonSegment<WorkspaceFollowupMode>(
                  value: WorkspaceFollowupMode.steer,
                  label: Text('Steer'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
              ],
              selected: <WorkspaceFollowupMode>{value},
              onSelectionChanged: (selection) {
                final next = selection.isEmpty ? value : selection.first;
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsThemeRow extends StatelessWidget {
  const _WorkspaceSettingsThemeRow({
    required this.value,
    required this.onChanged,
    required this.onCycle,
    super.key,
  });

  final AppThemePreset value;
  final ValueChanged<AppThemePreset> onChanged;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final activeDefinition = AppTheme.definition(value);
    final previewBrightness = theme.brightness;
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
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
                    Text(
                      'Theme',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Choose the global app theme. ${activeDefinition.label} is active now.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: density.inset(AppSpacing.md)),
              OutlinedButton.icon(
                key: const ValueKey<String>(
                  'workspace-settings-theme-cycle-button',
                ),
                onPressed: onCycle,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Next theme'),
              ),
            ],
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AppThemePreset.values.indexed
                  .map((entry) {
                    final index = entry.$1;
                    final preset = entry.$2;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == AppThemePreset.values.length - 1
                            ? 0
                            : density.inset(AppSpacing.sm),
                      ),
                      child: _WorkspaceThemePreviewCard(
                        preset: preset,
                        brightness: previewBrightness,
                        selected: preset == value,
                        onPressed: () => onChanged(preset),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsColorSchemeRow extends StatelessWidget {
  const _WorkspaceSettingsColorSchemeRow({
    required this.value,
    required this.onChanged,
    required this.onCycle,
    super.key,
  });

  final AppColorSchemeMode value;
  final ValueChanged<AppColorSchemeMode> onChanged;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final effectiveMode = switch (theme.brightness) {
      Brightness.light => 'Light',
      Brightness.dark => 'Dark',
    };
    final subtitle = switch (value) {
      AppColorSchemeMode.system =>
        'Follow the device setting. Currently $effectiveMode.',
      AppColorSchemeMode.light => 'Always use the light palette.',
      AppColorSchemeMode.dark => 'Always use the dark palette.',
    };
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
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
                    Text(
                      'Color mode',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
              SizedBox(width: density.inset(AppSpacing.md)),
              OutlinedButton.icon(
                key: const ValueKey<String>(
                  'workspace-settings-color-mode-cycle-button',
                ),
                onPressed: onCycle,
                icon: const Icon(Icons.brightness_6_rounded),
                label: const Text('Next mode'),
              ),
            ],
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppColorSchemeMode>(
              key: const ValueKey<String>(
                'workspace-settings-color-mode-segments',
              ),
              showSelectedIcon: false,
              segments: const <ButtonSegment<AppColorSchemeMode>>[
                ButtonSegment<AppColorSchemeMode>(
                  value: AppColorSchemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_suggest_rounded),
                ),
                ButtonSegment<AppColorSchemeMode>(
                  value: AppColorSchemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment<AppColorSchemeMode>(
                  value: AppColorSchemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: <AppColorSchemeMode>{value},
              onSelectionChanged: (selection) {
                final next = selection.isEmpty ? value : selection.first;
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceThemePreviewCard extends StatelessWidget {
  const _WorkspaceThemePreviewCard({
    required this.preset,
    required this.brightness,
    required this.selected,
    required this.onPressed,
  });

  final AppThemePreset preset;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final definition = AppTheme.definition(preset);
    final tone = AppTheme.colorsFor(preset, brightness);
    final previewPanel = Color.lerp(tone.background, tone.text, 0.09)!;
    final previewBorder = Color.lerp(tone.background, tone.text, 0.16)!;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Switch theme to ${definition.label}',
      child: InkWell(
        key: ValueKey<String>(
          'workspace-settings-theme-option-${preset.storageValue}',
        ),
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 168,
          height: 194,
          padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
          decoration: BoxDecoration(
            color: selected
                ? surfaces.panelEmphasis.withValues(alpha: 0.92)
                : surfaces.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : surfaces.lineSoft,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: previewBorder),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 10,
                      width: 58,
                      decoration: BoxDecoration(
                        color: tone.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: previewPanel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: previewBorder),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        child: Row(
                          children: <Widget>[
                            _WorkspaceThemePreviewDot(color: tone.accent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: tone.text.withValues(alpha: 0.86),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _WorkspaceThemePreviewDot(color: tone.success),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: density.inset(AppSpacing.xs)),
              Text(
                definition.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                definition.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceThemePreviewDot extends StatelessWidget {
  const _WorkspaceThemePreviewDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _WorkspaceSettingsLayoutDensityRow extends StatelessWidget {
  const _WorkspaceSettingsLayoutDensityRow({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final WorkspaceLayoutDensity value;
  final ValueChanged<WorkspaceLayoutDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Layout density',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Reduce workspace padding and margins to fit more information on screen.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkspaceLayoutDensity>(
              key: const ValueKey<String>(
                'workspace-settings-layout-density-segments',
              ),
              showSelectedIcon: false,
              segments: const <ButtonSegment<WorkspaceLayoutDensity>>[
                ButtonSegment<WorkspaceLayoutDensity>(
                  value: WorkspaceLayoutDensity.normal,
                  label: Text('Normal'),
                  icon: Icon(Icons.crop_din_rounded),
                ),
                ButtonSegment<WorkspaceLayoutDensity>(
                  value: WorkspaceLayoutDensity.compact,
                  label: Text('Compact'),
                  icon: Icon(Icons.view_compact_alt_rounded),
                ),
              ],
              selected: <WorkspaceLayoutDensity>{value},
              onSelectionChanged: (selection) {
                final next = selection.isEmpty ? value : selection.first;
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsMultiPaneComposerModeRow extends StatelessWidget {
  const _WorkspaceSettingsMultiPaneComposerModeRow({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final WorkspaceMultiPaneComposerMode value;
  final ValueChanged<WorkspaceMultiPaneComposerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Split pane composer layout',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Keep one shared composer at the bottom, or place a separate composer under each pane when working with wide split layouts.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkspaceMultiPaneComposerMode>(
              key: const ValueKey<String>(
                'workspace-settings-multi-pane-composer-mode-segments',
              ),
              showSelectedIcon: false,
              segments: const <ButtonSegment<WorkspaceMultiPaneComposerMode>>[
                ButtonSegment<WorkspaceMultiPaneComposerMode>(
                  value: WorkspaceMultiPaneComposerMode.shared,
                  label: Text('Shared'),
                  icon: Icon(Icons.vertical_align_bottom_rounded),
                ),
                ButtonSegment<WorkspaceMultiPaneComposerMode>(
                  value: WorkspaceMultiPaneComposerMode.perPane,
                  label: Text('Per Pane'),
                  icon: Icon(Icons.splitscreen_rounded),
                ),
              ],
              selected: <WorkspaceMultiPaneComposerMode>{value},
              onSelectionChanged: (selection) {
                final next = selection.isEmpty ? value : selection.first;
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSettingsTextScaleRow extends StatelessWidget {
  const _WorkspaceSettingsTextScaleRow({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final percentLabel = '${(value * 100).round()}%';
    return Container(
      padding: EdgeInsets.all(density.inset(AppSpacing.md)),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Text size',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Scale text across the app without changing layout density.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: density.inset(AppSpacing.md)),
              Container(
                key: const ValueKey<String>(
                  'workspace-settings-text-scale-badge',
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: surfaces.panel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: surfaces.lineSoft),
                ),
                child: Text(
                  percentLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          Row(
            children: <Widget>[
              Text(
                'A',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider.adaptive(
                    key: const ValueKey<String>(
                      'workspace-settings-text-scale-slider',
                    ),
                    value: value,
                    min: WebParityAppController.minTextScaleFactor,
                    max: WebParityAppController.maxTextScaleFactor,
                    divisions: WebParityAppController.textScaleFactorDivisions,
                    label: percentLabel,
                    onChanged: onChanged,
                  ),
                ),
              ),
              Text(
                'A',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: density.inset(AppSpacing.sm)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: density.inset(AppSpacing.md),
              vertical: density.inset(AppSpacing.sm),
            ),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'Preview',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
                SizedBox(width: density.inset(AppSpacing.sm)),
                Expanded(
                  child: Text(
                    'Readable session summaries and messages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceShortcutSpec {
  const _WorkspaceShortcutSpec({
    required this.title,
    required this.description,
    required this.shortcut,
  });

  final String title;
  final String description;
  final String shortcut;
}

const List<_WorkspaceShortcutSpec> _workspaceKeyboardShortcuts =
    <_WorkspaceShortcutSpec>[
      _WorkspaceShortcutSpec(
        title: 'Open command palette',
        description:
            'Search and run workspace, theme, model, and custom commands.',
        shortcut: 'mod+k',
      ),
      _WorkspaceShortcutSpec(
        title: 'Open project',
        description: 'Bring up the server project picker.',
        shortcut: 'mod+o',
      ),
      _WorkspaceShortcutSpec(
        title: 'Open settings',
        description: 'Show workspace settings and the shortcut reference.',
        shortcut: 'mod+comma',
      ),
      _WorkspaceShortcutSpec(
        title: 'Toggle MCPs',
        description: 'Open the session MCP picker and connect integrations.',
        shortcut: 'mod+;',
      ),
      _WorkspaceShortcutSpec(
        title: 'Toggle sessions panel',
        description: 'Collapse or reveal the left sessions sidebar.',
        shortcut: 'mod+b',
      ),
      _WorkspaceShortcutSpec(
        title: 'Toggle review panel',
        description: 'Show or hide the review tab in the side panel.',
        shortcut: 'mod+shift+r',
      ),
      _WorkspaceShortcutSpec(
        title: 'Toggle files panel',
        description: 'Show or hide the files tab in the side panel.',
        shortcut: 'mod+backslash',
      ),
      _WorkspaceShortcutSpec(
        title: 'Focus composer',
        description: 'Jump straight to the chat input.',
        shortcut: 'ctrl+l',
      ),
      _WorkspaceShortcutSpec(
        title: 'New session',
        description: 'Create a fresh session in the current project.',
        shortcut: 'mod+shift+s',
      ),
      _WorkspaceShortcutSpec(
        title: 'Attach files',
        description: 'Open the file picker for prompt attachments.',
        shortcut: 'mod+u',
      ),
      _WorkspaceShortcutSpec(
        title: 'Previous / next session',
        description: 'Move across root sessions in the sidebar order.',
        shortcut: 'alt+arrowup / alt+arrowdown',
      ),
      _WorkspaceShortcutSpec(
        title: 'Previous / next project',
        description: 'Move across projects in the left rail order.',
        shortcut: 'mod+alt+arrowup / mod+alt+arrowdown',
      ),
      _WorkspaceShortcutSpec(
        title: 'Choose model',
        description: 'Open the model picker from anywhere in the workspace.',
        shortcut: 'mod+quote',
      ),
      _WorkspaceShortcutSpec(
        title: 'Cycle agent',
        description: 'Rotate the active agent selection.',
        shortcut: 'mod+period / mod+shift+period',
      ),
      _WorkspaceShortcutSpec(
        title: 'Cycle reasoning',
        description: 'Rotate the available reasoning depth options.',
        shortcut: 'mod+shift+d',
      ),
      _WorkspaceShortcutSpec(
        title: 'Toggle terminal / new terminal',
        description: 'Open the terminal panel or create a new terminal tab.',
        shortcut: 'ctrl+backquote / ctrl+alt+t',
      ),
      _WorkspaceShortcutSpec(
        title: 'Stop running session',
        description: 'Interrupt the active response when the composer is idle.',
        shortcut: 'escape',
      ),
    ];

String _formatWorkspaceShortcutLabel(String config) {
  final isApplePlatform =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final combos = config
      .split('/')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty);

  String formatCombo(String combo) {
    final parts = combo.split('+').map((part) => part.trim()).toList();
    final rendered = <String>[];
    for (final part in parts) {
      switch (part) {
        case 'mod':
          rendered.add(isApplePlatform ? '⌘' : 'Ctrl');
          break;
        case 'ctrl':
          rendered.add(isApplePlatform ? '⌃' : 'Ctrl');
          break;
        case 'alt':
          rendered.add(isApplePlatform ? '⌥' : 'Alt');
          break;
        case 'shift':
          rendered.add(isApplePlatform ? '⇧' : 'Shift');
          break;
        case 'comma':
          rendered.add(',');
          break;
        case 'quote':
          rendered.add("'");
          break;
        case 'period':
          rendered.add('.');
          break;
        case 'backslash':
          rendered.add(r'\');
          break;
        case 'backquote':
          rendered.add('`');
          break;
        case 'arrowup':
          rendered.add('↑');
          break;
        case 'arrowdown':
          rendered.add('↓');
          break;
        case 'escape':
          rendered.add('Esc');
          break;
        default:
          rendered.add(
            part.length == 1
                ? part.toUpperCase()
                : '${part[0].toUpperCase()}${part.substring(1)}',
          );
          break;
      }
    }
    if (isApplePlatform) {
      return rendered.join('');
    }
    return rendered.join('+');
  }

  return combos.map(formatCombo).join('  /  ');
}

class _WorkspaceKeyboardShortcutsCard extends StatelessWidget {
  const _WorkspaceKeyboardShortcutsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final rows = <Widget>[];
    for (
      var index = 0;
      index < _workspaceKeyboardShortcuts.length;
      index += 1
    ) {
      rows.add(_WorkspaceShortcutRow(spec: _workspaceKeyboardShortcuts[index]));
      if (index != _workspaceKeyboardShortcuts.length - 1) {
        rows.add(SizedBox(height: density.inset(AppSpacing.sm)));
      }
    }
    return _WorkspaceSettingsCard(
      child: Column(
        key: const ValueKey<String>('workspace-settings-shortcuts-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'OpenCode-style desktop shortcuts',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Web defaults are used where OpenCode web and CLI differ.',
            style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
          SizedBox(height: density.inset(AppSpacing.md)),
          ...rows,
        ],
      ),
    );
  }
}

class _WorkspaceShortcutRow extends StatelessWidget {
  const _WorkspaceShortcutRow({required this.spec});

  final _WorkspaceShortcutSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(AppSpacing.md),
        vertical: density.inset(AppSpacing.sm),
      ),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  spec.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  spec.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: density.inset(AppSpacing.md)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: surfaces.panel,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: surfaces.lineSoft),
              ),
              child: Text(
                _formatWorkspaceShortcutLabel(spec.shortcut),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCommandPaletteCommand {
  _WorkspaceCommandPaletteCommand({
    required this.id,
    required this.title,
    required this.category,
    required this.onSelected,
    this.description,
    this.shortcut,
    this.searchTerms = const <String>[],
  });

  final String id;
  final String title;
  final String category;
  final String? description;
  final String? shortcut;
  final List<String> searchTerms;
  final Future<void> Function() onSelected;
}

class _WorkspaceCommandPaletteSheet extends StatefulWidget {
  const _WorkspaceCommandPaletteSheet({required this.commands});

  final List<_WorkspaceCommandPaletteCommand> commands;

  @override
  State<_WorkspaceCommandPaletteSheet> createState() =>
      _WorkspaceCommandPaletteSheetState();
}

class _WorkspaceCommandPaletteSheetState
    extends State<_WorkspaceCommandPaletteSheet> {
  late final TextEditingController _queryController = TextEditingController()
    ..addListener(_handleQueryChanged);
  late final FocusNode _queryFocusNode = FocusNode();
  int _highlightedIndex = 0;

  @override
  void dispose() {
    _queryController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _highlightedIndex = 0;
    });
  }

  List<_WorkspaceCommandPaletteCommand> get _filteredCommands {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.commands;
    }
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    final matches = widget.commands.indexed
        .where((entry) {
          final searchable = _workspaceCommandSearchableText(
            entry.$2,
          ).toLowerCase();
          return tokens.every(searchable.contains);
        })
        .toList(growable: false);
    matches.sort((left, right) {
      final leftScore = _workspaceCommandMatchScore(left.$2, query, tokens);
      final rightScore = _workspaceCommandMatchScore(right.$2, query, tokens);
      if (leftScore != rightScore) {
        return leftScore.compareTo(rightScore);
      }
      return left.$1.compareTo(right.$1);
    });
    return matches.map((entry) => entry.$2).toList(growable: false);
  }

  int _resolvedHighlightedIndex(int length) {
    if (length <= 0) {
      return 0;
    }
    return _highlightedIndex.clamp(0, length - 1);
  }

  void _moveHighlight(int delta) {
    final filtered = _filteredCommands;
    if (filtered.isEmpty) {
      return;
    }
    setState(() {
      _highlightedIndex =
          (_resolvedHighlightedIndex(filtered.length) +
              delta +
              filtered.length) %
          filtered.length;
    });
  }

  void _selectCommand(_WorkspaceCommandPaletteCommand command) {
    Navigator.of(context).pop(command);
  }

  void _submitHighlighted() {
    final filtered = _filteredCommands;
    if (filtered.isEmpty) {
      return;
    }
    _selectCommand(filtered[_resolvedHighlightedIndex(filtered.length)]);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submitHighlighted();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        (event.logicalKey == LogicalKeyboardKey.tab &&
            !HardwareKeyboard.instance.isShiftPressed)) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        (event.logicalKey == LogicalKeyboardKey.tab &&
            HardwareKeyboard.instance.isShiftPressed)) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final filtered = _filteredCommands;
    final highlightedIndex = _resolvedHighlightedIndex(filtered.length);
    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg + mediaQuery.viewInsets.bottom,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: math.min(mediaQuery.size.height * 0.76, 640),
            ),
            child: Material(
              key: const ValueKey<String>('workspace-command-palette-sheet'),
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: surfaces.lineSoft),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Command Palette',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Search workspace actions, themes, models, agents, and custom commands.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const ValueKey<String>(
                        'workspace-command-palette-field',
                      ),
                      controller: _queryController,
                      focusNode: _queryFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submitHighlighted(),
                      decoration: const InputDecoration(
                        hintText: 'Type a command or search',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enter runs the highlighted command. Tab or arrow keys move the selection.',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                key: const ValueKey<String>(
                                  'workspace-command-palette-empty-state',
                                ),
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.search_off_rounded,
                                    color: surfaces.muted,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'No matching commands',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'Try a project name, session title, theme, model, or slash command.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: surfaces.muted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (context, index) {
                                final command = filtered[index];
                                final highlighted = index == highlightedIndex;
                                return _WorkspaceCommandPaletteTile(
                                  key: ValueKey<String>(
                                    'workspace-command-palette-option-${command.id}',
                                  ),
                                  command: command,
                                  highlighted: highlighted,
                                  onTap: () => _selectCommand(command),
                                  onHover: (hovering) {
                                    if (!hovering) {
                                      return;
                                    }
                                    setState(() {
                                      _highlightedIndex = index;
                                    });
                                  },
                                );
                              },
                            ),
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

class _WorkspaceCommandPaletteTile extends StatelessWidget {
  const _WorkspaceCommandPaletteTile({
    required this.command,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
    super.key,
  });

  final _WorkspaceCommandPaletteCommand command;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final shortcut = command.shortcut?.trim();
    return MouseRegion(
      onEnter: (_) => onHover(true),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : surfaces.panelRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted
                  ? theme.colorScheme.primary.withValues(alpha: 0.36)
                  : surfaces.lineSoft,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: surfaces.panel,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: surfaces.lineSoft),
                      ),
                      child: Text(
                        command.category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      command.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (command.description?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        command.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (shortcut != null && shortcut.isNotEmpty) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surfaces.panel,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: surfaces.lineSoft),
                  ),
                  child: Text(
                    _formatWorkspaceShortcutLabel(shortcut),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _workspaceCommandSearchableText(
  _WorkspaceCommandPaletteCommand command,
) {
  return <String>[
    command.title,
    command.category,
    command.description ?? '',
    command.shortcut ?? '',
    ...command.searchTerms,
  ].join(' ');
}

int _workspaceCommandMatchScore(
  _WorkspaceCommandPaletteCommand command,
  String query,
  List<String> tokens,
) {
  final title = command.title.toLowerCase();
  final category = command.category.toLowerCase();
  final description = command.description?.toLowerCase() ?? '';
  final shortcut = command.shortcut?.toLowerCase() ?? '';
  var score = 0;
  if (title == query) {
    score -= 320;
  }
  if (title.startsWith(query)) {
    score -= 200;
  }
  if (category.startsWith(query)) {
    score -= 90;
  }
  if (shortcut.contains(query)) {
    score -= 80;
  }
  if (description.contains(query)) {
    score -= 40;
  }
  for (final token in tokens) {
    if (title.startsWith(token)) {
      score -= 32;
    } else if (title.contains(token)) {
      score -= 18;
    } else if (category.contains(token)) {
      score -= 12;
    }
  }
  return score;
}

class _WorkspaceMcpPickerSheet extends StatefulWidget {
  const _WorkspaceMcpPickerSheet({
    required this.profile,
    required this.project,
    required this.service,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final IntegrationStatusService service;

  @override
  State<_WorkspaceMcpPickerSheet> createState() =>
      _WorkspaceMcpPickerSheetState();
}

class _WorkspaceMcpPickerSheetState extends State<_WorkspaceMcpPickerSheet> {
  late final TextEditingController _queryController = TextEditingController()
    ..addListener(_handleQueryChanged);
  late final FocusNode _queryFocusNode = FocusNode();
  Map<String, McpIntegrationStatus> _mcpDetails =
      const <String, McpIntegrationStatus>{};
  bool _loading = true;
  String? _errorMessage;
  String? _pendingToggleName;
  String? _pendingAuthName;
  String? _lastAuthUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMcpDetails());
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  List<MapEntry<String, McpIntegrationStatus>> get _filteredEntries {
    final entries = _mcpDetails.entries.toList(growable: false)
      ..sort(
        (left, right) =>
            left.key.toLowerCase().compareTo(right.key.toLowerCase()),
      );
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return entries;
    }
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    return entries
        .where((entry) {
          final searchable = _workspaceMcpSearchableText(
            entry.key,
            entry.value,
          ).toLowerCase();
          return tokens.every(searchable.contains);
        })
        .toList(growable: false);
  }

  Future<void> _loadMcpDetails({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final details = await widget.service.fetchMcpDetails(
        profile: widget.profile,
        project: widget.project,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _mcpDetails = details;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = _formatWorkspaceMcpError(error);
      });
    }
  }

  Future<void> _toggleMcp(String name) async {
    final detail = _mcpDetails[name];
    if (detail == null) {
      return;
    }
    setState(() {
      _pendingToggleName = name;
      _errorMessage = null;
    });
    try {
      if (detail.connected) {
        await widget.service.disconnectMcp(
          profile: widget.profile,
          project: widget.project,
          name: name,
        );
      } else {
        await widget.service.connectMcp(
          profile: widget.profile,
          project: widget.project,
          name: name,
        );
      }
      await _loadMcpDetails(showLoading: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatWorkspaceMcpError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _pendingToggleName = null;
        });
      }
    }
  }

  Future<void> _startAuth(String name) async {
    setState(() {
      _pendingAuthName = name;
      _errorMessage = null;
    });
    try {
      final url = await widget.service.startMcpAuth(
        profile: widget.profile,
        project: widget.project,
        name: name,
      );
      final normalizedUrl = url?.trim();
      if (!mounted) {
        return;
      }
      if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
        var copiedToClipboard = false;
        try {
          await Clipboard.setData(ClipboardData(text: normalizedUrl));
          copiedToClipboard = true;
        } catch (_) {
          copiedToClipboard = false;
        }
        if (!mounted) {
          return;
        }
        showAppSnackBar(
          context,
          message: copiedToClipboard
              ? 'MCP auth URL copied for $name.'
              : 'MCP auth URL is ready for $name.',
          tone: copiedToClipboard
              ? AppSnackBarTone.success
              : AppSnackBarTone.info,
        );
      } else {
        showAppSnackBar(
          context,
          message: 'No MCP auth URL was returned for $name.',
          tone: AppSnackBarTone.info,
        );
      }
      setState(() {
        _lastAuthUrl = normalizedUrl;
      });
      await _loadMcpDetails(showLoading: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatWorkspaceMcpError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _pendingAuthName = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final mediaQuery = MediaQuery.of(context);
    final filtered = _filteredEntries;
    final enabledCount = _mcpDetails.values
        .where((item) => item.connected)
        .length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + mediaQuery.viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 760,
            maxHeight: math.min(mediaQuery.size.height * 0.86, 760),
          ),
          child: Material(
            key: const ValueKey<String>('workspace-mcp-picker-sheet'),
            color: surfaces.panel,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: surfaces.lineSoft),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MCPs',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '$enabledCount of ${_mcpDetails.length} enabled in this workspace.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: surfaces.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>(
                          'workspace-mcp-picker-refresh-button',
                        ),
                        tooltip: 'Refresh MCP status',
                        onPressed: _loading ? null : () => _loadMcpDetails(),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey<String>('workspace-mcp-picker-field'),
                    controller: _queryController,
                    focusNode: _queryFocusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search MCP servers',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                  if ((_errorMessage ?? '').trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _WorkspaceMcpFeedbackCard(
                      icon: Icons.error_outline_rounded,
                      message: _errorMessage!,
                      toneColor: theme.colorScheme.error,
                    ),
                  ],
                  if ((_lastAuthUrl ?? '').trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _WorkspaceMcpFeedbackCard(
                      icon: Icons.link_rounded,
                      message: _lastAuthUrl!,
                      toneColor: theme.colorScheme.primary,
                      actionLabel: 'Copy URL',
                      onAction: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _lastAuthUrl!.trim()),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        showAppSnackBar(
                          context,
                          message: 'Authorization URL copied.',
                          tone: AppSnackBarTone.success,
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: _loading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const CircularProgressIndicator(),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Loading MCP status...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: surfaces.muted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _mcpDetails.isEmpty
                        ? _WorkspaceMcpEmptyState(
                            icon: Icons.extension_off_rounded,
                            title: 'No MCPs configured',
                            body:
                                'This workspace does not expose any MCP servers yet.',
                          )
                        : filtered.isEmpty
                        ? _WorkspaceMcpEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No MCPs match this search',
                            body:
                                'Try a server name or status like connected or needs auth.',
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final name = entry.key;
                              final detail = entry.value;
                              final togglePending = _pendingToggleName == name;
                              final authPending = _pendingAuthName == name;
                              return _WorkspaceMcpPickerTile(
                                key: ValueKey<String>(
                                  'workspace-mcp-picker-option-$name',
                                ),
                                name: name,
                                detail: detail,
                                togglePending: togglePending,
                                authPending: authPending,
                                onTap: () => _toggleMcp(name),
                                onStartAuth: detail.needsAuth
                                    ? () => _startAuth(name)
                                    : null,
                              );
                            },
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

class _WorkspaceMcpPickerTile extends StatelessWidget {
  const _WorkspaceMcpPickerTile({
    required this.name,
    required this.detail,
    required this.togglePending,
    required this.authPending,
    required this.onTap,
    this.onStartAuth,
    super.key,
  });

  final String name;
  final McpIntegrationStatus detail;
  final bool togglePending;
  final bool authPending;
  final VoidCallback onTap;
  final VoidCallback? onStartAuth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final statusMeta = _workspaceMcpStatusMeta(theme, detail.status);
    final busy = togglePending || authPending;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: surfaces.panelRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: surfaces.lineSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusMeta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusMeta.color.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          statusMeta.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusMeta.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (togglePending || authPending)
                        Text(
                          togglePending ? 'Updating...' : 'Starting auth...',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: surfaces.muted,
                          ),
                        ),
                    ],
                  ),
                  if ((detail.error ?? '').trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detail.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (onStartAuth != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      key: ValueKey<String>('workspace-mcp-picker-auth-$name'),
                      onPressed: busy ? null : onStartAuth,
                      icon: Icon(
                        authPending
                            ? Icons.hourglass_top_rounded
                            : Icons.open_in_new_rounded,
                        size: 16,
                      ),
                      label: Text(
                        authPending ? 'Starting auth...' : 'Start auth',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch.adaptive(
              key: ValueKey<String>('workspace-mcp-picker-switch-$name'),
              value: detail.connected,
              onChanged: busy ? null : (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMcpFeedbackCard extends StatelessWidget {
  const _WorkspaceMcpFeedbackCard({
    required this.icon,
    required this.message,
    required this.toneColor,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final Color toneColor;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: toneColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: toneColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          if (onAction != null && (actionLabel ?? '').trim().isNotEmpty)
            TextButton(
              onPressed: () {
                unawaited(onAction!.call());
              },
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceMcpEmptyState extends StatelessWidget {
  const _WorkspaceMcpEmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: surfaces.muted),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMcpStatusMeta {
  const _WorkspaceMcpStatusMeta({required this.label, required this.color});

  final String label;
  final Color color;
}

String _workspaceMcpSearchableText(String name, McpIntegrationStatus detail) {
  return <String>[
    name,
    detail.status,
    _workspaceMcpStatusLabel(detail.status),
    detail.error ?? '',
  ].join(' ');
}

String _workspaceMcpStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'connected' => 'connected',
    'failed' => 'failed',
    'needs_auth' => 'needs auth',
    'disabled' => 'disabled',
    'unknown' => 'unknown',
    final other => other.replaceAll('_', ' '),
  };
}

_WorkspaceMcpStatusMeta _workspaceMcpStatusMeta(
  ThemeData theme,
  String status,
) {
  return switch (status.trim().toLowerCase()) {
    'connected' => _WorkspaceMcpStatusMeta(
      label: 'connected',
      color: Colors.teal.shade400,
    ),
    'failed' => _WorkspaceMcpStatusMeta(
      label: 'failed',
      color: theme.colorScheme.error,
    ),
    'needs_auth' => _WorkspaceMcpStatusMeta(
      label: 'needs auth',
      color: Colors.amber.shade700,
    ),
    'disabled' => _WorkspaceMcpStatusMeta(
      label: 'disabled',
      color: Colors.blueGrey.shade400,
    ),
    _ => _WorkspaceMcpStatusMeta(
      label: _workspaceMcpStatusLabel(status),
      color: theme.colorScheme.secondary,
    ),
  };
}

String _formatWorkspaceMcpError(Object error) {
  final message = error.toString().trim();
  if (message.startsWith('StateError: ')) {
    return message.substring('StateError: '.length);
  }
  if (message.startsWith('Exception: ')) {
    return message.substring('Exception: '.length);
  }
  return message;
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

class _WorkspaceSidebar extends StatefulWidget {
  const _WorkspaceSidebar({
    required this.width,
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
    required this.onReorderProjects,
    required this.onSelectSession,
    required this.projectNotificationStateForDirectory,
    required this.sessionNotificationStateForSession,
    required this.hoverPreviewStateForSession,
    required this.onPrefetchSessionHoverPreview,
    required this.onFocusSessionMessage,
    required this.onAddProject,
    required this.onNewSession,
    required this.onOpenSettings,
  });

  final double width;
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
  final Future<void> Function(List<ProjectTarget> projects) onReorderProjects;
  final ValueChanged<String> onSelectSession;
  final WorkspaceSidebarNotificationState Function(String directory)
  projectNotificationStateForDirectory;
  final WorkspaceSidebarNotificationState Function(String sessionId)
  sessionNotificationStateForSession;
  final WorkspaceSessionHoverPreviewState Function(String sessionId)
  hoverPreviewStateForSession;
  final Future<void> Function(String sessionId) onPrefetchSessionHoverPreview;
  final void Function(String sessionId, String messageId) onFocusSessionMessage;
  final VoidCallback onAddProject;
  final VoidCallback onNewSession;
  final VoidCallback onOpenSettings;

  @override
  State<_WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<_WorkspaceSidebar> {
  List<ProjectTarget> _orderedProjects = const <ProjectTarget>[];

  @override
  void initState() {
    super.initState();
    _orderedProjects = List<ProjectTarget>.unmodifiable(widget.projects);
  }

  @override
  void didUpdateWidget(covariant _WorkspaceSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameProjectOrder(oldWidget.projects, widget.projects)) {
      _orderedProjects = List<ProjectTarget>.unmodifiable(widget.projects);
      return;
    }
    _orderedProjects = _mergedProjectsByExistingOrder(
      existingOrder: _orderedProjects,
      latestProjects: widget.projects,
    );
  }

  bool _sameProjectOrder(List<ProjectTarget> left, List<ProjectTarget> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index].directory != right[index].directory) {
        return false;
      }
    }
    return true;
  }

  List<ProjectTarget> _mergedProjectsByExistingOrder({
    required List<ProjectTarget> existingOrder,
    required List<ProjectTarget> latestProjects,
  }) {
    final latestByDirectory = <String, ProjectTarget>{
      for (final project in latestProjects) project.directory: project,
    };
    final next = existingOrder
        .where((project) => latestByDirectory.containsKey(project.directory))
        .map((project) => latestByDirectory[project.directory] ?? project)
        .toList(growable: true);
    final seenDirectories = next.map((project) => project.directory).toSet();
    for (final project in latestProjects) {
      if (seenDirectories.add(project.directory)) {
        next.add(project);
      }
    }
    return List<ProjectTarget>.unmodifiable(next);
  }

  Future<void> _handleProjectReorder(int oldIndex, int newIndex) async {
    if (_orderedProjects.length < 2) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _orderedProjects.length ||
        newIndex < 0 ||
        newIndex >= _orderedProjects.length) {
      return;
    }
    final next = List<ProjectTarget>.of(_orderedProjects);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() {
      _orderedProjects = List<ProjectTarget>.unmodifiable(next);
    });
    await widget.onReorderProjects(_orderedProjects);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final hoverPreviewEnabled = switch (theme.platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    final density = _workspaceDensity(context);
    final railWidth = density.sidebarRailWidth(72);
    final panelPadding = density.inset(AppSpacing.md, min: AppSpacing.xs);
    final sectionGap = density.inset(AppSpacing.lg, min: AppSpacing.md);
    final microGap = density.inset(AppSpacing.sm, min: AppSpacing.xs);
    final projects = _orderedProjects;
    final currentProject =
        widget.project ??
        _projectForDirectory(projects, widget.currentDirectory);
    final rootSelectedSessionId = _rootSessionFor(
      widget.allSessions,
      _sessionById(widget.allSessions, widget.currentSessionId),
    )?.id;
    final sessionEntries = _buildSidebarSessionEntries(
      roots: widget.sessions,
      allSessions: widget.allSessions,
      statuses: widget.statuses,
      selectedSessionId: widget.currentSessionId,
      includeNested: widget.showSubsessions,
    );

    return SizedBox(
      width: density.sidebarWidth(widget.width),
      child: Row(
        children: <Widget>[
          Container(
            width: railWidth,
            color: surfaces.panel,
            child: Column(
              children: <Widget>[
                SizedBox(height: panelPadding),
                Expanded(
                  child: ReorderableListView.builder(
                    key: const ValueKey<String>(
                      'workspace-project-sidebar-reorder-list',
                    ),
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    itemCount: projects.length,
                    onReorder: (oldIndex, newIndex) =>
                        unawaited(_handleProjectReorder(oldIndex, newIndex)),
                    proxyDecorator: (child, index, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: Tween<double>(
                          begin: 0.94,
                          end: 1,
                        ).animate(curved),
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 1,
                            end: 1.04,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final selected =
                          project.directory == widget.currentDirectory;
                      final tile = _ProjectSidebarTile(
                        key: ValueKey<String>(
                          'workspace-project-${project.directory}',
                        ),
                        project: project,
                        notificationState: widget
                            .projectNotificationStateForDirectory(
                              project.directory,
                            ),
                        selected: selected,
                        onSelect: () => widget.onSelectProject(project),
                        onEdit: () => widget.onEditProject(project),
                        onRemove: () => widget.onRemoveProject(project),
                      );
                      final reorderableTile = projects.length > 1
                          ? ReorderableDragStartListener(
                              index: index,
                              child: tile,
                            )
                          : tile;
                      return Padding(
                        key: ValueKey<String>(
                          'workspace-project-item-${project.directory}',
                        ),
                        padding: EdgeInsets.fromLTRB(
                          density.inset(AppSpacing.sm),
                          0,
                          density.inset(AppSpacing.sm),
                          index == projects.length - 1 ? 0 : microGap,
                        ),
                        child: reorderableTile,
                      );
                    },
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>(
                    'workspace-sidebar-add-project-button',
                  ),
                  onPressed: widget.onAddProject,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add project',
                ),
                IconButton(
                  key: const ValueKey<String>(
                    'workspace-sidebar-settings-button',
                  ),
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                  tooltip:
                      'Workspace settings (${_formatWorkspaceShortcutLabel('mod+comma')})',
                ),
                SizedBox(height: panelPadding),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: surfaces.panelRaised,
              padding: EdgeInsets.all(panelPadding),
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
                        SizedBox(width: microGap),
                        _SidebarProjectMenuButton(
                          project: currentProject,
                          onEdit: () => widget.onEditProject(currentProject),
                          onRemove: () =>
                              widget.onRemoveProject(currentProject),
                        ),
                      ],
                    ),
                    SizedBox(height: sectionGap),
                  ] else ...<Widget>[
                    Text(
                      projectDisplayLabel(widget.currentDirectory),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: sectionGap),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: panelPadding,
                          vertical: density.inset(AppSpacing.md),
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
                      onPressed: widget.loadingProjectContents
                          ? null
                          : widget.onNewSession,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('New session'),
                    ),
                  ),
                  SizedBox(height: panelPadding),
                  Expanded(
                    child: widget.loadingProjectContents
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
                                SizedBox(height: density.inset(AppSpacing.xs)),
                            itemBuilder: (context, index) {
                              final entry = sessionEntries[index];
                              return _SidebarSessionTreeRow(
                                key: ValueKey<String>(
                                  'workspace-session-entry-${entry.session.id}-${entry.depth}',
                                ),
                                entry: entry,
                                project: currentProject,
                                notificationState: widget
                                    .sessionNotificationStateForSession(
                                      entry.session.id,
                                    ),
                                hoverPreviewState: widget
                                    .hoverPreviewStateForSession(
                                      entry.session.id,
                                    ),
                                selected: widget.showSubsessions
                                    ? entry.session.id ==
                                          widget.currentSessionId
                                    : entry.rootId == rootSelectedSessionId,
                                hoverPreviewEnabled: hoverPreviewEnabled,
                                onHoverPreviewRequested: () {
                                  unawaited(
                                    widget.onPrefetchSessionHoverPreview(
                                      entry.session.id,
                                    ),
                                  );
                                },
                                onFocusPreviewMessage: (messageId) =>
                                    widget.onFocusSessionMessage(
                                      entry.session.id,
                                      messageId,
                                    ),
                                onTap: () =>
                                    widget.onSelectSession(entry.session.id),
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
    required this.notificationState,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  final ProjectTarget project;
  final WorkspaceSidebarNotificationState notificationState;
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
    return Tooltip(
      message: widget.project.title,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onSecondaryTapDown: (details) => _showMenu(details.globalPosition),
          onLongPressStart: (details) => _showMenu(details.globalPosition),
          child: InkWell(
            onTap: widget.onSelect,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.16)
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
                if (widget.notificationState.visible)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _WorkspaceSidebarNotificationBadge(
                      key: ValueKey<String>(
                        'workspace-project-notification-badge-${widget.project.directory}',
                      ),
                      state: widget.notificationState,
                      compact: true,
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

class _WorkspaceSidebarNotificationBadge extends StatelessWidget {
  const _WorkspaceSidebarNotificationBadge({
    required this.state,
    this.compact = false,
    super.key,
  });

  final WorkspaceSidebarNotificationState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final color = state.hasError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    final tooltip = switch (state.unseenCount) {
      0 => null,
      1 when state.hasError => '1 unseen update, including an error',
      1 => '1 unseen update',
      final count when state.hasError =>
        '$count unseen updates, including an error',
      final count => '$count unseen updates',
    };
    final size = compact ? 10.0 : 8.0;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 150),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: surfaces.panelRaised, width: 1.2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
    required this.active,
  });

  final SessionSummary session;
  final int depth;
  final String rootId;
  final bool active;
}

class _SidebarSessionTreeRow extends StatefulWidget {
  const _SidebarSessionTreeRow({
    required this.entry,
    required this.project,
    required this.notificationState,
    required this.hoverPreviewState,
    required this.selected,
    required this.hoverPreviewEnabled,
    required this.onHoverPreviewRequested,
    required this.onFocusPreviewMessage,
    required this.onTap,
    super.key,
  });

  final _SidebarSessionEntry entry;
  final ProjectTarget? project;
  final WorkspaceSidebarNotificationState notificationState;
  final WorkspaceSessionHoverPreviewState hoverPreviewState;
  final bool selected;
  final bool hoverPreviewEnabled;
  final VoidCallback onHoverPreviewRequested;
  final ValueChanged<String> onFocusPreviewMessage;
  final VoidCallback onTap;

  @override
  State<_SidebarSessionTreeRow> createState() => _SidebarSessionTreeRowState();
}

class _SidebarSessionTreeRowState extends State<_SidebarSessionTreeRow> {
  Timer? _hoverPrefetchTimer;
  bool _hovering = false;

  @override
  void dispose() {
    _hoverPrefetchTimer?.cancel();
    super.dispose();
  }

  void _handleHoverChanged(bool hovering) {
    if (!widget.hoverPreviewEnabled) {
      return;
    }
    if (!hovering) {
      _hoverPrefetchTimer?.cancel();
      if (_hovering) {
        setState(() {
          _hovering = false;
        });
      }
      return;
    }
    _hoverPrefetchTimer?.cancel();
    if (!_hovering) {
      setState(() {
        _hovering = true;
      });
    }
    _hoverPrefetchTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || !_hovering) {
        return;
      }
      widget.onHoverPreviewRequested();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final title = widget.entry.session.title.trim().isEmpty
        ? 'Untitled session'
        : widget.entry.session.title.trim();
    final active = widget.entry.active;
    final isRoot = widget.entry.depth == 0;
    final indent = widget.entry.depth * 18.0;
    final previewVisible =
        widget.hoverPreviewEnabled &&
        _hovering &&
        (widget.hoverPreviewState.loading ||
            widget.hoverPreviewState.hasContent);

    return MouseRegion(
      onEnter: (_) => _handleHoverChanged(true),
      onExit: (_) => _handleHoverChanged(false),
      child: Padding(
        padding: EdgeInsets.only(left: indent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onTap,
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: widget.selected
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
                              ? (widget.project != null
                                    ? _ProjectAvatar(
                                        project: widget.project!,
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
                            'sidebar-session-shimmer-${widget.entry.session.id}',
                          ),
                          active: active,
                          text: TextSpan(
                            text: title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isRoot
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: widget.selected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: isRoot ? 0.96 : 0.9,
                                    ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      if (widget.notificationState.visible) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        _WorkspaceSidebarNotificationBadge(
                          key: ValueKey<String>(
                            'workspace-session-notification-badge-${widget.entry.session.id}',
                          ),
                          state: widget.notificationState,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: !previewVisible
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey<String>(
                        'sidebar-session-hover-preview-wrap-${widget.entry.session.id}',
                      ),
                      padding: const EdgeInsets.only(
                        left: 30,
                        top: AppSpacing.xxs,
                      ),
                      child: _SidebarSessionHoverPreviewPanel(
                        session: widget.entry.session,
                        state: widget.hoverPreviewState,
                        onFocusMessage: widget.onFocusPreviewMessage,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarSessionHoverPreviewPanel extends StatelessWidget {
  const _SidebarSessionHoverPreviewPanel({
    required this.session,
    required this.state,
    required this.onFocusMessage,
  });

  final SessionSummary session;
  final WorkspaceSessionHoverPreviewState state;
  final ValueChanged<String> onFocusMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final summary = state.summary?.trim();

    return Container(
      key: ValueKey<String>('sidebar-session-hover-preview-${session.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaces.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.lineSoft),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.forum_rounded, size: 16, color: surfaces.muted),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  'Recent prompts',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state.loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (summary != null && summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              summary,
              key: ValueKey<String>(
                'sidebar-session-hover-summary-${session.id}',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: surfaces.muted,
                height: 1.3,
              ),
            ),
          ],
          if (state.messages.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ...state.messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _SidebarSessionHoverPreviewMessageButton(
                  sessionId: session.id,
                  message: message,
                  onTap: () => onFocusMessage(message.messageId),
                ),
              ),
            ),
          ] else if (!state.loading) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hover to load the latest prompts for this session.',
              style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarSessionHoverPreviewMessageButton extends StatelessWidget {
  const _SidebarSessionHoverPreviewMessageButton({
    required this.sessionId,
    required this.message,
    required this.onTap,
  });

  final String sessionId;
  final WorkspaceSessionHoverPreviewMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>(
          'sidebar-session-hover-message-$sessionId-${message.messageId}',
        ),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: surfaces.panelRaised.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 16,
                color: surfaces.muted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

class _ProjectAvatarImage extends StatefulWidget {
  const _ProjectAvatarImage({required this.image});

  final String image;

  @override
  State<_ProjectAvatarImage> createState() => _ProjectAvatarImageState();
}

class _ProjectAvatarImageState extends State<_ProjectAvatarImage> {
  ImageProvider<Object>? _provider;

  @override
  void initState() {
    super.initState();
    _provider = _resolveProvider(widget.image);
  }

  @override
  void didUpdateWidget(covariant _ProjectAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _provider = _resolveProvider(widget.image);
    }
  }

  ImageProvider<Object>? _resolveProvider(String image) {
    UriData? uriData;
    if (image.startsWith('data:')) {
      try {
        uriData = UriData.parse(image);
      } catch (_) {
        uriData = null;
      }
    }
    if (uriData != null) {
      return MemoryImage(uriData.contentAsBytes());
    }
    if (image.trim().isEmpty) {
      return null;
    }
    return NetworkImage(image);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return const SizedBox.shrink();
    }
    return Image(
      image: provider,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
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
  final childrenByParent = _sessionChildrenByParent(allSessions);

  int compareSessions(SessionSummary left, SessionSummary right) {
    final leftSelected = left.id == selectedSessionId;
    final rightSelected = right.id == selectedSessionId;
    if (leftSelected != rightSelected) {
      return leftSelected ? -1 : 1;
    }
    final leftActive = _sessionTreeIsActive(
      left.id,
      childrenByParent: childrenByParent,
      statuses: statuses,
    );
    final rightActive = _sessionTreeIsActive(
      right.id,
      childrenByParent: childrenByParent,
      statuses: statuses,
    );
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
      _SidebarSessionEntry(
        session: session,
        depth: depth,
        rootId: rootId,
        active: _sessionTreeIsActive(
          session.id,
          childrenByParent: childrenByParent,
          statuses: statuses,
        ),
      ),
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

Map<String, List<SessionSummary>> _sessionChildrenByParent(
  List<SessionSummary> sessions,
) {
  final childrenByParent = <String, List<SessionSummary>>{};
  for (final session in sessions) {
    final parentId = session.parentId;
    if (parentId == null || parentId.isEmpty || session.archivedAt != null) {
      continue;
    }
    childrenByParent
        .putIfAbsent(parentId, () => <SessionSummary>[])
        .add(session);
  }
  return childrenByParent;
}

bool _sessionTreeIsActive(
  String sessionId, {
  required Map<String, List<SessionSummary>> childrenByParent,
  required Map<String, SessionStatusSummary> statuses,
}) {
  final pending = Queue<String>()..add(sessionId);
  final seen = <String>{};
  while (pending.isNotEmpty) {
    final currentId = pending.removeFirst();
    if (!seen.add(currentId)) {
      continue;
    }
    if (_isActiveSessionStatus(statuses[currentId])) {
      return true;
    }
    for (final child
        in childrenByParent[currentId] ?? const <SessionSummary>[]) {
      pending.add(child.id);
    }
  }
  return false;
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
    required this.paneViewModels,
    required this.activePaneId,
    required this.activeWorkspaceLoading,
    required this.activeWorkspaceError,
    required this.sidePanelVisible,
    required this.sidePanelWidth,
    required this.submittingPrompt,
    required this.interruptiblePrompt,
    required this.interruptingPrompt,
    required this.pickingAttachments,
    required this.attachments,
    required this.historyEntries,
    required this.promptController,
    required this.promptFocusRequestToken,
    required this.submittedDraftEpoch,
    required this.recentSubmittedDraft,
    required this.compactPane,
    required this.busyFollowupMode,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.chatSearchQuery,
    required this.chatSearchMatchMessageIds,
    required this.chatSearchActiveMessageId,
    required this.chatSearchRevision,
    required this.timelineJumpEpoch,
    required this.focusedTimelineMessageIdForScope,
    required this.focusedTimelineMessageRevisionForScope,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onCompactPaneChanged,
    required this.onSubmitPrompt,
    required this.onEditQueuedPrompt,
    required this.onDeleteQueuedPrompt,
    required this.onSendQueuedPromptNow,
    required this.onInterruptPrompt,
    required this.onCreateSession,
    required this.onOpenSession,
    required this.onSelectSessionPane,
    required this.onCloseSessionPane,
    required this.onPickAttachments,
    required this.onDropFiles,
    required this.onPasteClipboardImage,
    required this.onContentInserted,
    required this.onRemoveAttachment,
    required this.onAddReviewCommentToComposerContext,
    required this.onTogglePermissionAutoAccept,
    required this.onOpenMcpPicker,
    required this.dropRegionBuilder,
    this.onShowSidePanel,
    this.onResizeSidePanel,
    this.onFinishResizeSidePanel,
    this.inlineComposerBuilder,
    required this.onToggleTerminal,
    required this.terminalPanelOpen,
    required this.terminalPanel,
    this.onShareSession,
    this.onUnshareSession,
    this.onSummarizeSession,
  });

  final bool compact;
  final WorkspaceController controller;
  final List<_WorkspacePaneViewModel> paneViewModels;
  final String? activePaneId;
  final bool activeWorkspaceLoading;
  final String? activeWorkspaceError;
  final bool sidePanelVisible;
  final double sidePanelWidth;
  final bool submittingPrompt;
  final bool interruptiblePrompt;
  final bool interruptingPrompt;
  final bool pickingAttachments;
  final List<PromptAttachment> attachments;
  final List<String> historyEntries;
  final TextEditingController promptController;
  final int promptFocusRequestToken;
  final int submittedDraftEpoch;
  final String? recentSubmittedDraft;
  final _CompactWorkspacePane compactPane;
  final WorkspaceFollowupMode busyFollowupMode;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final String chatSearchQuery;
  final List<String> chatSearchMatchMessageIds;
  final String? chatSearchActiveMessageId;
  final int chatSearchRevision;
  final int timelineJumpEpoch;
  final String? Function(String scopeKey) focusedTimelineMessageIdForScope;
  final int Function(String scopeKey) focusedTimelineMessageRevisionForScope;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<_CompactWorkspacePane> onCompactPaneChanged;
  final Future<void> Function(WorkspacePromptDispatchMode? mode) onSubmitPrompt;
  final Future<void> Function(String queuedPromptId) onEditQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onDeleteQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onSendQueuedPromptNow;
  final Future<void> Function() onInterruptPrompt;
  final Future<void> Function() onCreateSession;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function(String paneId) onSelectSessionPane;
  final ValueChanged<String> onCloseSessionPane;
  final Future<void> Function() onPickAttachments;
  final WorkspaceComposerDropFilesHandler onDropFiles;
  final Future<bool> Function() onPasteClipboardImage;
  final Future<void> Function(KeyboardInsertedContent content)
  onContentInserted;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<_ReviewLineCommentSubmission>
  onAddReviewCommentToComposerContext;
  final Future<void> Function() onTogglePermissionAutoAccept;
  final Future<void> Function() onOpenMcpPicker;
  final WorkspaceComposerDropRegionBuilder dropRegionBuilder;
  final VoidCallback? onShowSidePanel;
  final ValueChanged<double>? onResizeSidePanel;
  final VoidCallback? onFinishResizeSidePanel;
  final Widget Function(
    _WorkspacePaneViewModel paneViewModel,
    bool selected,
    bool compact,
  )?
  inlineComposerBuilder;
  final Future<void> Function() onToggleTerminal;
  final bool terminalPanelOpen;
  final Widget? terminalPanel;
  final Future<void> Function()? onShareSession;
  final Future<void> Function()? onUnshareSession;
  final Future<void> Function()? onSummarizeSession;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final questionRequest = controller.currentQuestionRequest;
    final permissionRequest = controller.currentPermissionRequest;
    final usesInlinePaneComposer = inlineComposerBuilder != null;
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
            child: _WorkspaceSessionPaneDeck(
              compact: compact,
              paneViewModels: paneViewModels,
              activePaneId: activePaneId,
              shellToolDefaultExpanded: shellToolDefaultExpanded,
              timelineProgressDetailsVisible: timelineProgressDetailsVisible,
              chatSearchQuery: chatSearchQuery,
              chatSearchMatchMessageIds: chatSearchMatchMessageIds,
              chatSearchActiveMessageId: chatSearchActiveMessageId,
              chatSearchRevision: chatSearchRevision,
              timelineJumpEpoch: timelineJumpEpoch,
              focusedTimelineMessageIdForScope:
                  focusedTimelineMessageIdForScope,
              focusedTimelineMessageRevisionForScope:
                  focusedTimelineMessageRevisionForScope,
              onSelectPane: onSelectSessionPane,
              onClosePane: onCloseSessionPane,
              onForkMessage: onForkMessage,
              onRevertMessage: onRevertMessage,
              onOpenSession: onOpenSession,
              onRetrySelectedSession: controller.retrySelectedSessionMessages,
              inlineComposerBuilder: inlineComposerBuilder,
            ),
          ),
        ),
        if (!usesInlinePaneComposer && activeWorkspaceLoading)
          Container(
            padding: EdgeInsets.fromLTRB(
              density.inset(compact ? AppSpacing.sm : AppSpacing.lg),
              density.inset(compact ? AppSpacing.xs : AppSpacing.md),
              density.inset(compact ? AppSpacing.sm : AppSpacing.lg),
              density.inset(compact ? AppSpacing.sm : AppSpacing.lg),
            ),
            decoration: BoxDecoration(
              color: surfaces.panel,
              border: Border(top: BorderSide(color: surfaces.lineSoft)),
            ),
            child: _PromptComposerLoadingPlaceholder(compact: compact),
          )
        else if (!usesInlinePaneComposer &&
            activeWorkspaceError == null &&
            questionRequest != null)
          _PendingQuestionComposerNotice(
            request: questionRequest,
            compact: compact,
          )
        else if (!usesInlinePaneComposer &&
            activeWorkspaceError == null &&
            permissionRequest != null)
          _PendingPermissionComposerNotice(
            request: permissionRequest,
            compact: compact,
          )
        else if (!usesInlinePaneComposer && activeWorkspaceError == null)
          _PromptComposer(
            controller: promptController,
            compact: compact,
            scopeKey:
                '${controller.directory}::${controller.selectedSessionId ?? 'new'}',
            focusRequestToken: promptFocusRequestToken,
            submitting: submittingPrompt,
            busyFollowupMode: busyFollowupMode,
            interruptible: interruptiblePrompt,
            interrupting: interruptingPrompt,
            pickingAttachments: pickingAttachments,
            attachments: attachments,
            queuedPrompts: controller.selectedSessionQueuedPrompts,
            failedQueuedPromptId:
                controller.selectedSessionFailedQueuedPromptId,
            sendingQueuedPromptId:
                controller.selectedSessionSendingQueuedPromptId,
            agents: controller.composerAgents,
            models: controller.composerModels,
            selectedAgentName: controller.selectedAgentName,
            selectedModel: controller.selectedModel,
            selectedReasoning: controller.selectedReasoning,
            reasoningValues: controller.availableReasoningValues,
            customCommands: controller.composerCommands,
            historyEntries: historyEntries,
            permissionAutoAccepting: controller.autoAcceptsPermissionForSession(
              controller.selectedSessionId,
            ),
            onSelectAgent: controller.selectAgent,
            onSelectModel: controller.selectModel,
            onSelectReasoning: controller.selectReasoning,
            onTogglePermissionAutoAccept: onTogglePermissionAutoAccept,
            onCreateSession: onCreateSession,
            onInterrupt: onInterruptPrompt,
            onPickAttachments: onPickAttachments,
            onDropFiles: onDropFiles,
            onPasteClipboardImage: onPasteClipboardImage,
            onContentInserted: onContentInserted,
            dropRegionBuilder: dropRegionBuilder,
            onRemoveAttachment: onRemoveAttachment,
            onEditQueuedPrompt: onEditQueuedPrompt,
            onDeleteQueuedPrompt: onDeleteQueuedPrompt,
            onSendQueuedPromptNow: onSendQueuedPromptNow,
            onShareSession: onShareSession,
            onUnshareSession: onUnshareSession,
            onSummarizeSession: onSummarizeSession,
            submittedDraftEpoch: submittedDraftEpoch,
            recentSubmittedDraft: recentSubmittedDraft,
            onOpenMcpPicker: onOpenMcpPicker,
            onToggleTerminal: onToggleTerminal,
            onSelectSideTab: (tab) {
              if (!compact && !sidePanelVisible) {
                onShowSidePanel?.call();
              }
              controller.setSideTab(tab);
            },
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

    final sidePanel = _SidePanel(
      controller: controller,
      onLineComment: onAddReviewCommentToComposerContext,
    );
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
        _HorizontalReveal(
          key: const ValueKey<String>('workspace-desktop-side-panel-reveal'),
          visible: sidePanelVisible,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DesktopResizeHandle(
                key: const ValueKey<String>(
                  'workspace-desktop-side-panel-resize-handle',
                ),
                onDragUpdate: onResizeSidePanel,
                onDragEnd: onFinishResizeSidePanel,
              ),
              Container(width: 1, color: Theme.of(context).dividerColor),
              SizedBox(
                key: const ValueKey<String>('workspace-desktop-side-panel'),
                width: density.sidePanelWidth(sidePanelWidth),
                child: sidePanel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopResizeHandle extends StatelessWidget {
  const _DesktopResizeHandle({
    required this.onDragUpdate,
    this.onDragEnd,
    super.key,
  });

  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: onDragUpdate == null
            ? null
            : (details) => onDragUpdate!(details.delta.dx),
        onHorizontalDragEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
        child: SizedBox(
          width: _WebParityWorkspaceScreenState._desktopResizeHandleWidth,
          child: Center(
            child: Container(
              width: 2,
              height: 52,
              decoration: BoxDecoration(
                color: surfaces.lineSoft.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _compactSideLabel(WorkspaceController controller) {
  final reviewCount = controller.reviewStatuses.length;
  return switch (controller.sideTab) {
    WorkspaceSideTab.review when reviewCount > 0 =>
      '$reviewCount Files Changed',
    WorkspaceSideTab.review => 'Review',
    WorkspaceSideTab.files => 'Files',
    WorkspaceSideTab.context => 'Context',
  };
}

String _desktopSidePanelLabel(WorkspaceController controller) {
  return switch (controller.sideTab) {
    WorkspaceSideTab.review => 'Review',
    WorkspaceSideTab.files => 'Files',
    WorkspaceSideTab.context => 'Context',
  };
}

class _HorizontalReveal extends StatelessWidget {
  const _HorizontalReveal({
    required this.visible,
    required this.alignment,
    required this.child,
    super.key,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: visible ? 1 : 0, end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(ignoring: !visible, child: child),
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: alignment,
            widthFactor: value,
            child: Opacity(opacity: value.clamp(0, 1).toDouble(), child: child),
          ),
        );
      },
    );
  }
}

class _WorkspaceSessionPaneDeck extends StatelessWidget {
  const _WorkspaceSessionPaneDeck({
    required this.compact,
    required this.paneViewModels,
    required this.activePaneId,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.chatSearchQuery,
    required this.chatSearchMatchMessageIds,
    required this.chatSearchActiveMessageId,
    required this.chatSearchRevision,
    required this.timelineJumpEpoch,
    required this.focusedTimelineMessageIdForScope,
    required this.focusedTimelineMessageRevisionForScope,
    required this.onSelectPane,
    required this.onClosePane,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onOpenSession,
    required this.onRetrySelectedSession,
    this.inlineComposerBuilder,
  });

  final bool compact;
  final List<_WorkspacePaneViewModel> paneViewModels;
  final String? activePaneId;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final String chatSearchQuery;
  final List<String> chatSearchMatchMessageIds;
  final String? chatSearchActiveMessageId;
  final int chatSearchRevision;
  final int timelineJumpEpoch;
  final String? Function(String scopeKey) focusedTimelineMessageIdForScope;
  final int Function(String scopeKey) focusedTimelineMessageRevisionForScope;
  final Future<void> Function(String paneId) onSelectPane;
  final ValueChanged<String> onClosePane;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onRetrySelectedSession;
  final Widget Function(
    _WorkspacePaneViewModel paneViewModel,
    bool selected,
    bool compact,
  )?
  inlineComposerBuilder;

  @override
  Widget build(BuildContext context) {
    final density = _workspaceDensity(context);
    final spacing = compact
        ? density.inset(AppSpacing.xs, min: 4)
        : density.inset(AppSpacing.sm, min: 6);
    final outerPadding = compact
        ? EdgeInsets.zero
        : EdgeInsets.all(density.inset(AppSpacing.sm, min: AppSpacing.xs));
    if (paneViewModels.isEmpty) {
      return const SizedBox.shrink();
    }
    final resolvedActivePaneId = activePaneId ?? paneViewModels.first.pane.id;
    final showSelectionChrome = paneViewModels.length > 1;

    return Padding(
      key: const ValueKey<String>('workspace-session-pane-deck'),
      padding: outerPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < paneViewModels.length; index += 1) ...[
            Expanded(
              child: _WorkspaceSessionPaneCard(
                paneViewModel: paneViewModels[index],
                compact: compact,
                selected: paneViewModels[index].pane.id == resolvedActivePaneId,
                showSelectionChrome: showSelectionChrome,
                canClose: !compact && paneViewModels.length > 1,
                shellToolDefaultExpanded: shellToolDefaultExpanded,
                timelineProgressDetailsVisible: timelineProgressDetailsVisible,
                chatSearchQuery: chatSearchQuery,
                chatSearchMatchMessageIds: chatSearchMatchMessageIds,
                chatSearchActiveMessageId: chatSearchActiveMessageId,
                chatSearchRevision: chatSearchRevision,
                timelineJumpEpoch: timelineJumpEpoch,
                focusedTimelineMessageIdForScope:
                    focusedTimelineMessageIdForScope,
                focusedTimelineMessageRevisionForScope:
                    focusedTimelineMessageRevisionForScope,
                onSelectPane: onSelectPane,
                onClosePane: onClosePane,
                onForkMessage: onForkMessage,
                onRevertMessage: onRevertMessage,
                onOpenSession: onOpenSession,
                onRetrySelectedSession: onRetrySelectedSession,
                inlineComposerBuilder: inlineComposerBuilder,
              ),
            ),
            if (index < paneViewModels.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceSessionPaneCard extends StatelessWidget {
  const _WorkspaceSessionPaneCard({
    required this.paneViewModel,
    required this.compact,
    required this.selected,
    required this.showSelectionChrome,
    required this.canClose,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.chatSearchQuery,
    required this.chatSearchMatchMessageIds,
    required this.chatSearchActiveMessageId,
    required this.chatSearchRevision,
    required this.timelineJumpEpoch,
    required this.focusedTimelineMessageIdForScope,
    required this.focusedTimelineMessageRevisionForScope,
    required this.onSelectPane,
    required this.onClosePane,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onOpenSession,
    required this.onRetrySelectedSession,
    this.inlineComposerBuilder,
  });

  final _WorkspacePaneViewModel paneViewModel;
  final bool compact;
  final bool selected;
  final bool showSelectionChrome;
  final bool canClose;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final String chatSearchQuery;
  final List<String> chatSearchMatchMessageIds;
  final String? chatSearchActiveMessageId;
  final int chatSearchRevision;
  final int timelineJumpEpoch;
  final String? Function(String scopeKey) focusedTimelineMessageIdForScope;
  final int Function(String scopeKey) focusedTimelineMessageRevisionForScope;
  final Future<void> Function(String paneId) onSelectPane;
  final ValueChanged<String> onClosePane;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onRetrySelectedSession;
  final Widget Function(
    _WorkspacePaneViewModel paneViewModel,
    bool selected,
    bool compact,
  )?
  inlineComposerBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final pane = paneViewModel.pane;
    final controller = paneViewModel.controller;
    final project = paneViewModel.project;
    final sessionId = pane.sessionId?.trim();
    final session = _sessionById(controller.sessions, sessionId);
    final timelineState = controller.timelineStateForSession(sessionId);
    final busy = controller.sessionBusyForSession(sessionId);
    final title = _sessionHeaderTitle(session, project);
    final projectLabel = (() {
      final label = project?.label.trim();
      if (label != null && label.isNotEmpty) {
        return label;
      }
      return projectDisplayLabel(pane.directory);
    })();
    final searchScoped =
        selected &&
        sessionId != null &&
        sessionId.isNotEmpty &&
        sessionId == controller.selectedSessionId &&
        chatSearchQuery.trim().isNotEmpty;
    final subtitle = controller.loading && sessionId == null
        ? '$projectLabel · Connecting to this project'
        : sessionId == null
        ? '$projectLabel · New session draft'
        : selected
        ? '$projectLabel · Sidebar, side panel, and composer follow this pane'
        : '$projectLabel · Click to focus this session';
    final normalizedSessionId = sessionId == null || sessionId.isEmpty
        ? 'new'
        : sessionId;
    final sessionFocusScopeKey = _workspaceScopedSessionKey(
      directory: pane.directory,
      sessionId: sessionId,
    );
    final timelineScopeKey =
        '${pane.id}::${pane.directory}::$normalizedSessionId';
    final timelinePageStorageKey = searchScoped
        ? 'web-parity-message-timeline::$timelineScopeKey::search-$chatSearchRevision-${chatSearchActiveMessageId ?? 'none'}'
        : 'web-parity-message-timeline::$timelineScopeKey';
    final rootSession = controller.rootSessionForSession(sessionId);
    final activeChildSessions = controller.activeChildSessionsForSession(
      sessionId,
    );
    final activeChildSessionPreviewById = controller
        .activeChildSessionPreviewByIdForSession(sessionId);
    final paneQuestionRequest = controller.currentQuestionRequestForSession(
      sessionId,
    );
    final panePermissionRequest = controller.currentPermissionRequestForSession(
      sessionId,
    );
    final paneTodos = controller.todosForSession(sessionId);
    final paneTodoLive =
        paneTodos.isNotEmpty ||
        paneQuestionRequest != null ||
        panePermissionRequest != null;
    final visuallySelected = selected && showSelectionChrome;

    Future<void> handleFocus() async {
      await onSelectPane(pane.id);
    }

    Future<void> handleRetry() async {
      if (selected) {
        await onRetrySelectedSession();
        return;
      }
      await controller.refreshTimelineSession(sessionId);
    }

    Future<void> handleLoadMoreHistory() async {
      await controller.loadMoreTimelineSessionHistory(sessionId);
    }

    Future<void> handleForkMessage(ChatMessage message) async {
      if (!selected) {
        await handleFocus();
      }
      await onForkMessage(message);
    }

    Future<void> handleRevertMessage(ChatMessage message) async {
      if (!selected) {
        await handleFocus();
      }
      await onRevertMessage(message);
    }

    Future<void> handleRetryWorkspace() async {
      await controller.load();
    }

    void handleOpenSession(String sessionId) {
      if (selected) {
        onOpenSession(sessionId);
        return;
      }
      unawaited(() async {
        await handleFocus();
        onOpenSession(sessionId);
      }());
    }

    return Semantics(
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('workspace-session-pane-${pane.id}'),
          onTap: selected ? null : () => unawaited(handleFocus()),
          borderRadius: BorderRadius.circular(compact ? 18 : 22),
          child: AnimatedContainer(
            key: ValueKey<String>(
              'workspace-session-pane-container-${pane.id}',
            ),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: visuallySelected
                  ? surfaces.panel.withValues(alpha: 0.98)
                  : surfaces.panelRaised.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(compact ? 18 : 22),
              border: Border.all(
                color: visuallySelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.78)
                    : surfaces.lineSoft,
                width: visuallySelected ? 1.8 : 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color:
                      (visuallySelected
                              ? theme.colorScheme.primary
                              : Colors.black)
                          .withValues(alpha: visuallySelected ? 0.14 : 0.08),
                  blurRadius: visuallySelected ? 24 : 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    density.inset(compact ? AppSpacing.sm : AppSpacing.md),
                    density.inset(compact ? AppSpacing.sm : AppSpacing.md),
                    density.inset(compact ? AppSpacing.sm : AppSpacing.md),
                    density.inset(compact ? AppSpacing.xs : AppSpacing.sm),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final headerWidth = constraints.maxWidth;
                      final hideTitle = headerWidth < 72;
                      final showSubtitle = headerWidth >= 180;
                      final showSelectedBadge =
                          visuallySelected && headerWidth >= 140;
                      final useCompactCloseButton = headerWidth < 120;

                      Widget closeButton() {
                        return IconButton(
                          key: ValueKey<String>(
                            'workspace-session-pane-close-${pane.id}',
                          ),
                          onPressed: () => onClosePane(pane.id),
                          tooltip: 'Close pane',
                          icon: Icon(
                            Icons.close_rounded,
                            size: useCompactCloseButton ? 14 : 18,
                          ),
                          splashRadius: useCompactCloseButton ? 14 : 18,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: useCompactCloseButton ? 20 : 28,
                            height: useCompactCloseButton ? 20 : 28,
                          ),
                        );
                      }

                      return Row(
                        children: <Widget>[
                          Expanded(
                            child: hideTitle
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Tooltip(
                                        message: title,
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              (compact || !showSubtitle
                                                      ? theme
                                                            .textTheme
                                                            .titleSmall
                                                      : theme
                                                            .textTheme
                                                            .titleMedium)
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                        ),
                                      ),
                                      if (showSubtitle) ...<Widget>[
                                        SizedBox(
                                          height: density.inset(
                                            AppSpacing.xxs,
                                            min: 2,
                                          ),
                                        ),
                                        Row(
                                          children: <Widget>[
                                            if (busy) ...<Widget>[
                                              Container(
                                                key: ValueKey<String>(
                                                  'workspace-session-pane-busy-indicator-${pane.id}',
                                                ),
                                                width: compact ? 7 : 8,
                                                height: compact ? 7 : 8,
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(
                                                width: density.inset(
                                                  AppSpacing.xxs,
                                                  min: 4,
                                                ),
                                              ),
                                            ],
                                            Expanded(
                                              child: Text(
                                                subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: visuallySelected
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.92,
                                                                )
                                                          : surfaces.muted,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                          if (showSelectedBadge)
                            Container(
                              key: ValueKey<String>(
                                'workspace-session-pane-selected-badge-${pane.id}',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.24,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Active',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (canClose) ...<Widget>[
                            SizedBox(
                              width: hideTitle
                                  ? 2
                                  : density.inset(AppSpacing.xs, min: 4),
                            ),
                            closeButton(),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: surfaces.lineSoft),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      if (activeChildSessions.isNotEmpty)
                        _ActiveSubSessionPanel(
                          key: ValueKey<String>(
                            'pane-subsessions-${pane.id}::$normalizedSessionId',
                          ),
                          rootSessionId: rootSession?.id,
                          sessions: activeChildSessions,
                          previewBySessionId: activeChildSessionPreviewById,
                          currentSessionId: sessionId,
                          compact: compact,
                          onOpenSession: handleOpenSession,
                        ),
                      Expanded(
                        child: sessionId == null && controller.loading
                            ? KeyedSubtree(
                                key: ValueKey<String>(
                                  'workspace-session-pane-loading-${pane.id}',
                                ),
                                child: _TimelineStatusCard(
                                  icon: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  title:
                                      'Loading ${projectLabel.isEmpty ? 'project' : projectLabel}...',
                                  message:
                                      'Keeping the rest of the workspace visible while this project connects.',
                                ),
                              )
                            : sessionId == null && controller.error != null
                            ? KeyedSubtree(
                                key: ValueKey<String>(
                                  'workspace-session-pane-error-${pane.id}',
                                ),
                                child: _TimelineStatusCard(
                                  icon: Icon(
                                    Icons.wifi_tethering_error_rounded,
                                    color: theme.colorScheme.error,
                                    size: 22,
                                  ),
                                  title:
                                      'Couldn\'t load ${projectLabel.isEmpty ? 'this project' : projectLabel}',
                                  message: controller.error!,
                                  action: OutlinedButton(
                                    onPressed: () =>
                                        unawaited(handleRetryWorkspace()),
                                    child: const Text('Retry'),
                                  ),
                                ),
                              )
                            : sessionId == null
                            ? _NewSessionView(
                                project: project,
                                messages: timelineState.messages,
                              )
                            : _MessageTimeline(
                                key: ValueKey<String>(
                                  'timeline-$timelinePageStorageKey',
                                ),
                                storageScopeKey: timelineScopeKey,
                                pageStorageKeyValue: timelinePageStorageKey,
                                currentSessionId: sessionId,
                                working: busy,
                                loading: timelineState.loading,
                                showingCachedMessages:
                                    timelineState.showingCachedMessages,
                                historyMore: timelineState.historyMore,
                                historyLoading: timelineState.historyLoading,
                                error: timelineState.error,
                                messages: timelineState.orderedMessages,
                                timelineContentSignature:
                                    controller.timelineContentSignature,
                                compact: compact,
                                sessions: controller.sessions,
                                selectedSession: selected
                                    ? controller.selectedSession
                                    : session,
                                configSnapshot: controller.configSnapshot,
                                shellToolDefaultExpanded:
                                    shellToolDefaultExpanded,
                                timelineProgressDetailsVisible:
                                    timelineProgressDetailsVisible,
                                searchQuery: searchScoped
                                    ? chatSearchQuery
                                    : '',
                                matchingMessageIds: searchScoped
                                    ? chatSearchMatchMessageIds.toSet()
                                    : const <String>{},
                                activeMatchMessageId: searchScoped
                                    ? chatSearchActiveMessageId
                                    : null,
                                searchRevision: searchScoped
                                    ? chatSearchRevision
                                    : 0,
                                focusedMessageId:
                                    focusedTimelineMessageIdForScope(
                                      sessionFocusScopeKey,
                                    ),
                                focusedMessageRevision:
                                    focusedTimelineMessageRevisionForScope(
                                      sessionFocusScopeKey,
                                    ),
                                onForkMessage: handleForkMessage,
                                onRevertMessage: handleRevertMessage,
                                onOpenSession: handleOpenSession,
                                onRetry: handleRetry,
                                onLoadMore: handleLoadMoreHistory,
                                jumpToBottomEpoch: searchScoped
                                    ? timelineJumpEpoch
                                    : 0,
                              ),
                      ),
                      if (sessionId != null && paneQuestionRequest != null)
                        _QuestionPromptDock(
                          key: ValueKey<String>(
                            'session-question-dock-${pane.id}::$normalizedSessionId-${paneQuestionRequest.id}',
                          ),
                          request: paneQuestionRequest,
                          compact: compact,
                          onReply: controller.replyToQuestion,
                          onReject: controller.rejectQuestion,
                        ),
                      if (sessionId != null && panePermissionRequest != null)
                        _PermissionPromptDock(
                          key: ValueKey<String>(
                            'session-permission-dock-${pane.id}::$normalizedSessionId-${panePermissionRequest.id}',
                          ),
                          request: panePermissionRequest,
                          compact: compact,
                          responding: controller.permissionRequestResponding(
                            panePermissionRequest.id,
                          ),
                          onDecide: controller.replyToPermission,
                        ),
                      if (sessionId != null)
                        _SessionTodoDock(
                          key: ValueKey<String>(
                            'session-todo-dock-${pane.id}::$normalizedSessionId',
                          ),
                          sessionId: sessionId,
                          todos: paneTodos,
                          live: paneTodoLive,
                          blocked:
                              paneQuestionRequest != null ||
                              panePermissionRequest != null,
                          compact: compact,
                          onClearStale: () =>
                              controller.clearTodosForSession(sessionId),
                        ),
                      if (inlineComposerBuilder != null)
                        inlineComposerBuilder!(
                          paneViewModel,
                          selected,
                          compact,
                        ),
                    ],
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

class _ActiveSubSessionPanel extends StatefulWidget {
  const _ActiveSubSessionPanel({
    required this.rootSessionId,
    required this.sessions,
    required this.previewBySessionId,
    required this.currentSessionId,
    required this.compact,
    required this.onOpenSession,
    super.key,
  });

  final String? rootSessionId;
  final List<SessionSummary> sessions;
  final Map<String, String> previewBySessionId;
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
              previewBySessionId: widget.previewBySessionId,
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
    required this.previewBySessionId,
    required this.currentSessionId,
    required this.compact,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onOpenSession,
    super.key,
  });

  final List<SessionSummary> sessions;
  final Map<String, String> previewBySessionId;
  final String? currentSessionId;
  final bool compact;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final preview = _activeSubSessionCollapsedPreview(
      sessions,
      previewBySessionId,
    );
    final showPreview = collapsed && !compact && preview.isNotEmpty;
    final idsSignature = sessions.map((session) => session.id).join('|');
    final panelRadius = compact ? 18.0 : 20.0;

    return Padding(
      padding: compact
          ? EdgeInsets.fromLTRB(
              density.inset(AppSpacing.xs),
              density.inset(AppSpacing.xs),
              density.inset(AppSpacing.xs),
              0,
            )
          : EdgeInsets.fromLTRB(
              density.inset(AppSpacing.md, min: AppSpacing.sm),
              density.inset(AppSpacing.md, min: AppSpacing.sm),
              density.inset(AppSpacing.md, min: AppSpacing.sm),
              0,
            ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: density.maxContentWidth(920)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  surfaces.panelRaised.withValues(alpha: 0.98),
                  surfaces.panel,
                ],
              ),
              borderRadius: BorderRadius.circular(panelRadius),
              border: Border.all(color: surfaces.lineSoft),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleCollapsed,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(panelRadius),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: surfaces.panelEmphasis.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(panelRadius),
                        ),
                        border: Border(
                          bottom: BorderSide(color: surfaces.lineSoft),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          density.inset(
                            compact ? AppSpacing.sm : AppSpacing.md,
                          ),
                          density.inset(
                            compact ? AppSpacing.sm : AppSpacing.md,
                          ),
                          density.inset(
                            compact ? AppSpacing.sm : AppSpacing.md,
                          ),
                          density.inset(
                            compact ? AppSpacing.sm : AppSpacing.md,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: compact ? 34 : 38,
                              height: compact ? 34 : 38,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.26,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.hub_rounded,
                                size: compact ? 18 : 20,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.94,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: density.inset(AppSpacing.sm, min: 6),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _ShimmeringRichText(
                                    key: const ValueKey<String>(
                                      'active-subsessions-title',
                                    ),
                                    text: TextSpan(
                                      text: 'Sub-agents Running',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.15,
                                          ),
                                    ),
                                    active: true,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                              top: AppSpacing.xxs,
                                              right: AppSpacing.sm,
                                            ),
                                            child: Text(
                                              preview,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: surfaces.muted,
                                                    height: 1.2,
                                                  ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: density.inset(AppSpacing.sm, min: 6),
                            ),
                            _ActiveSubSessionCountBadge(
                              count: sessions.length,
                              compact: compact,
                            ),
                            SizedBox(
                              width: compact ? AppSpacing.xs : AppSpacing.sm,
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
                              constraints: BoxConstraints.tightFor(
                                width: compact ? 34 : 38,
                                height: compact ? 34 : 38,
                              ),
                              splashRadius: compact ? 17 : 19,
                              tooltip: collapsed ? 'Expand' : 'Collapse',
                            ),
                          ],
                        ),
                      ),
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
                            padding: EdgeInsets.fromLTRB(
                              density.inset(
                                compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                              density.inset(
                                compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                              density.inset(
                                compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                              density.inset(
                                compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final spacing = compact
                                    ? density.inset(AppSpacing.xs, min: 4)
                                    : density.inset(AppSpacing.sm, min: 6);
                                final columns = _activeSubSessionColumnCount(
                                  constraints.maxWidth,
                                  spacing: spacing,
                                  compact: compact,
                                );
                                final itemWidth = columns <= 1
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth -
                                              (columns - 1) * spacing) /
                                          columns;
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
                                  child: Wrap(
                                    key: ValueKey<String>(
                                      'active-subsessions-list-$idsSignature',
                                    ),
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children: sessions
                                        .map(
                                          (session) => SizedBox(
                                            width: itemWidth,
                                            child: _ActiveSubSessionChip(
                                              session: session,
                                              preview:
                                                  previewBySessionId[session
                                                      .id] ??
                                                  'Working on the latest step',
                                              selected:
                                                  session.id ==
                                                  currentSessionId,
                                              compact: compact,
                                              onTap: () =>
                                                  onOpenSession(session.id),
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                );
                              },
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
    required this.preview,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final SessionSummary session;
  final String preview;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final selectedColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('active-subsession-chip-${session.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minHeight: density.inset(compact ? 76 : 84, min: 68),
          ),
          padding: EdgeInsets.fromLTRB(
            density.inset(compact ? AppSpacing.sm : AppSpacing.md),
            density.inset(compact ? AppSpacing.sm : AppSpacing.md),
            density.inset(compact ? AppSpacing.sm : AppSpacing.md),
            density.inset(compact ? AppSpacing.sm : AppSpacing.md),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                selected
                    ? selectedColor.withValues(alpha: 0.18)
                    : surfaces.panelRaised.withValues(alpha: 0.98),
                selected
                    ? selectedColor.withValues(alpha: 0.08)
                    : surfaces.panelEmphasis.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: 0.52)
                  : surfaces.lineSoft,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.12 : 0.08),
                blurRadius: selected ? 18 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: compact ? 9 : 10,
                    height: compact ? 9 : 10,
                    decoration: BoxDecoration(
                      color: selected ? selectedColor : const Color(0xFF64D7C4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(
                    width: density.inset(
                      compact ? AppSpacing.xs : AppSpacing.sm,
                      min: 4,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _sessionDisplayTitle(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? theme.textTheme.bodySmall
                                  : theme.textTheme.bodyMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected ? selectedColor : null,
                              ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: density.inset(
                  compact ? AppSpacing.xxs : AppSpacing.xs,
                  min: 2,
                ),
              ),
              _ShimmeringRichText(
                key: ValueKey<String>(
                  'active-subsession-preview-${session.id}',
                ),
                text: TextSpan(
                  text: preview,
                  style:
                      (compact
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(
                            color: selected
                                ? Color.lerp(
                                    surfaces.muted,
                                    selectedColor,
                                    0.38,
                                  )
                                : surfaces.muted,
                            height: 1.25,
                          ),
                ),
                active: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSubSessionCountBadge extends StatelessWidget {
  const _ActiveSubSessionCountBadge({
    required this.count,
    required this.compact,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = '$count running';
    return Container(
      key: const ValueKey<String>('active-subsessions-count-badge'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

int _activeSubSessionColumnCount(
  double maxWidth, {
  required double spacing,
  required bool compact,
}) {
  if (maxWidth <= 0) {
    return 1;
  }
  final minCardWidth = compact ? 250.0 : 270.0;
  final estimated = ((maxWidth + spacing) / (minCardWidth + spacing)).floor();
  final maxColumns = compact ? 2 : 3;
  if (estimated < 1) {
    return 1;
  }
  if (estimated > maxColumns) {
    return maxColumns;
  }
  return estimated;
}

String _activeSubSessionCollapsedPreview(
  List<SessionSummary> sessions,
  Map<String, String> previewBySessionId,
) {
  return sessions
      .take(2)
      .map((session) {
        final title = _sessionDisplayTitle(session);
        final preview = previewBySessionId[session.id]?.trim() ?? '';
        if (preview.isEmpty) {
          return title;
        }
        return '$title: $preview';
      })
      .join('  •  ');
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
    final density = _workspaceDensity(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          density.inset(AppSpacing.xl, min: AppSpacing.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              project?.label ?? 'New Session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: density.inset(AppSpacing.sm, min: AppSpacing.xs)),
            Text(
              'Send a prompt to create a session for this worktree.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              textAlign: TextAlign.center,
            ),
            if (messages.isNotEmpty)
              SizedBox(
                height: density.inset(AppSpacing.lg, min: AppSpacing.md),
              ),
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
    final density = _workspaceDensity(context);
    final title =
        project?.title ?? projectDisplayLabel(project?.directory ?? '');
    final outerPadding = density.inset(compact ? AppSpacing.md : AppSpacing.xl);
    final panelPadding = density.inset(compact ? AppSpacing.md : AppSpacing.xl);
    final composerHorizontal = density.inset(
      compact ? AppSpacing.sm : AppSpacing.lg,
    );
    final composerTop = density.inset(compact ? AppSpacing.xs : AppSpacing.md);
    final composerBottom = density.inset(
      compact ? AppSpacing.sm : AppSpacing.lg,
    );
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
                constraints: BoxConstraints(
                  maxWidth: density.maxContentWidth(860),
                ),
                child: Padding(
                  padding: EdgeInsets.all(outerPadding),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(panelPadding),
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
            padding: EdgeInsets.fromLTRB(
              composerHorizontal,
              composerTop,
              composerHorizontal,
              composerBottom,
            ),
            decoration: BoxDecoration(
              color: surfaces.panel,
              border: Border(top: BorderSide(color: surfaces.lineSoft)),
            ),
            child: _PromptComposerLoadingPlaceholder(compact: compact),
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
        _ShimmerBox(
          height: 96,
          widthFactor: 1,
          borderRadius: 18,
          style: _ShimmerBoxStyle.surface,
        ),
      ],
    );
  }
}

class _PromptComposerLoadingPlaceholder extends StatelessWidget {
  const _PromptComposerLoadingPlaceholder({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final padding = compact ? AppSpacing.xs : AppSpacing.md;
    final radius = compact ? 14.0 : 18.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: surfaces.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ShimmerBox(height: 16, widthFactor: 0.18, borderRadius: 8),
          SizedBox(height: AppSpacing.md),
          _ShimmerBox(
            height: 44,
            widthFactor: 1,
            borderRadius: 14,
            style: _ShimmerBoxStyle.surface,
          ),
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

int _timelineStringSignature(String? value) {
  if (value == null || value.isEmpty) {
    return 0;
  }
  return Object.hash(value.length, value.hashCode);
}

class _MessageTimeline extends StatefulWidget {
  const _MessageTimeline({
    required this.storageScopeKey,
    required this.pageStorageKeyValue,
    required this.currentSessionId,
    required this.working,
    required this.loading,
    required this.showingCachedMessages,
    required this.historyMore,
    required this.historyLoading,
    required this.error,
    required this.messages,
    required this.timelineContentSignature,
    required this.compact,
    required this.sessions,
    required this.selectedSession,
    required this.configSnapshot,
    required this.shellToolDefaultExpanded,
    required this.timelineProgressDetailsVisible,
    required this.searchQuery,
    required this.matchingMessageIds,
    required this.activeMatchMessageId,
    required this.searchRevision,
    required this.focusedMessageId,
    required this.focusedMessageRevision,
    required this.onForkMessage,
    required this.onRevertMessage,
    required this.onOpenSession,
    required this.onRetry,
    required this.onLoadMore,
    required this.jumpToBottomEpoch,
    super.key,
  });

  final String storageScopeKey;
  final String pageStorageKeyValue;
  final String? currentSessionId;
  final bool working;
  final bool loading;
  final bool showingCachedMessages;
  final bool historyMore;
  final bool historyLoading;
  final String? error;
  final List<ChatMessage> messages;
  final int timelineContentSignature;
  final bool compact;
  final List<SessionSummary> sessions;
  final SessionSummary? selectedSession;
  final ConfigSnapshot? configSnapshot;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final String searchQuery;
  final Set<String> matchingMessageIds;
  final String? activeMatchMessageId;
  final int searchRevision;
  final String? focusedMessageId;
  final int focusedMessageRevision;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<String> onOpenSession;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoadMore;
  final int jumpToBottomEpoch;

  @override
  State<_MessageTimeline> createState() => _MessageTimelineState();
}

class _MessageTimelineState extends State<_MessageTimeline> {
  static const int _initialWindowSize = 60;
  static const int _windowGrowthSize = 40;
  static const double _loadOlderThreshold = 96;
  static const ValueKey<String> _loadOlderItemKey = ValueKey<String>(
    'timeline-load-older-indicator-item',
  );

  int _visibleStartIndex = 0;
  bool _loadingOlder = false;
  bool _loadOlderCheckScheduled = false;
  late final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  String? _lastScopeKey;
  int _lastMessageCount = 0;
  int _lastContentSignature = 0;
  bool _lastLoading = false;
  bool _wasNearBottom = true;
  int _lastJumpToBottomEpoch = 0;
  double? _bottomLockLastExtent;
  int _bottomLockStableFrames = 0;
  int _bottomLockAttempts = 0;
  bool _bottomLockScheduled = false;
  String? _bottomLockScopeKey;
  double? _olderHistoryPreservedPixels;
  double? _olderHistoryPreservedExtent;
  bool _awaitingOlderHistoryInsert = false;
  final Map<String, GlobalKey> _messageItemKeys = <String, GlobalKey>{};

  List<ChatMessage> get _visibleMessages => widget.messages.sublist(
    _visibleStartIndex.clamp(0, widget.messages.length),
  );

  int get _hiddenMessageCount =>
      _visibleStartIndex.clamp(0, widget.messages.length);

  bool get _hasMoreHistory => _hiddenMessageCount > 0 || widget.historyMore;

  bool get _searchActive => widget.searchQuery.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _visibleStartIndex = _initialVisibleStart(widget.messages.length);
    final initialSearchMessageId = widget.activeMatchMessageId;
    if (initialSearchMessageId != null && initialSearchMessageId.isNotEmpty) {
      final targetIndex = widget.messages.indexWhere(
        (message) => message.info.id == initialSearchMessageId,
      );
      if (targetIndex >= 0) {
        _visibleStartIndex = math.max(0, targetIndex - 2);
      }
    }
    _lastJumpToBottomEpoch = widget.jumpToBottomEpoch;
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _MessageTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sessionChanged =
        oldWidget.currentSessionId != widget.currentSessionId;
    final becameNonEmpty =
        oldWidget.messages.isEmpty && widget.messages.isNotEmpty;
    final messagesShrank = widget.messages.length < oldWidget.messages.length;
    final searchChanged =
        oldWidget.activeMatchMessageId != widget.activeMatchMessageId ||
        oldWidget.searchRevision != widget.searchRevision;
    final focusedMessageChanged =
        oldWidget.focusedMessageId != widget.focusedMessageId ||
        oldWidget.focusedMessageRevision != widget.focusedMessageRevision;
    final messageIds = widget.messages
        .map((message) => message.info.id)
        .toSet();
    _messageItemKeys.removeWhere(
      (messageId, _) => !messageIds.contains(messageId),
    );
    if (sessionChanged || becameNonEmpty || messagesShrank) {
      _visibleStartIndex = _initialVisibleStart(widget.messages.length);
      _loadingOlder = false;
      _clearOlderHistoryPreservation();
    }

    if (_visibleStartIndex > widget.messages.length) {
      _visibleStartIndex = _initialVisibleStart(widget.messages.length);
    }

    final olderHistoryInserted =
        _awaitingOlderHistoryInsert &&
        widget.messages.length > oldWidget.messages.length;
    final olderHistoryFinishedWithoutGrowth =
        _awaitingOlderHistoryInsert &&
        oldWidget.historyLoading &&
        !widget.historyLoading &&
        widget.messages.length == oldWidget.messages.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (olderHistoryInserted) {
        _restoreOlderHistoryScroll();
        unawaited(_handleScroll());
      } else if (olderHistoryFinishedWithoutGrowth) {
        _clearOlderHistoryPreservation();
      }
      if (widget.activeMatchMessageId != null &&
          widget.activeMatchMessageId!.isNotEmpty &&
          (searchChanged ||
              sessionChanged ||
              becameNonEmpty ||
              messagesShrank)) {
        _revealSearchMatch(widget.activeMatchMessageId!);
      } else if (widget.focusedMessageId != null &&
          widget.focusedMessageId!.isNotEmpty &&
          (focusedMessageChanged ||
              sessionChanged ||
              becameNonEmpty ||
              messagesShrank)) {
        _revealSearchMatch(widget.focusedMessageId!);
      } else {
        _syncTimelinePosition(
          forceBottom: _lastJumpToBottomEpoch != widget.jumpToBottomEpoch,
        );
      }
    });
    _lastJumpToBottomEpoch = widget.jumpToBottomEpoch;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  int _initialVisibleStart(int messageCount) {
    return math.max(0, messageCount - _initialWindowSize);
  }

  GlobalKey _messageItemKey(String messageId) {
    return _messageItemKeys.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'timeline-message-$messageId'),
    );
  }

  void _beginOlderHistoryPreservation() {
    if (!_scrollController.hasClients) {
      _clearOlderHistoryPreservation();
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions || !position.hasPixels) {
      _clearOlderHistoryPreservation();
      return;
    }
    _olderHistoryPreservedPixels = position.pixels;
    _olderHistoryPreservedExtent = position.maxScrollExtent;
    _awaitingOlderHistoryInsert = true;
  }

  void _clearOlderHistoryPreservation() {
    _olderHistoryPreservedPixels = null;
    _olderHistoryPreservedExtent = null;
    _awaitingOlderHistoryInsert = false;
  }

  void _restoreOlderHistoryScroll() {
    if (!_awaitingOlderHistoryInsert || !_scrollController.hasClients) {
      _clearOlderHistoryPreservation();
      return;
    }
    final beforePixels = _olderHistoryPreservedPixels;
    final beforeExtent = _olderHistoryPreservedExtent;
    _clearOlderHistoryPreservation();
    if (beforePixels == null || beforeExtent == null) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final delta = position.maxScrollExtent - beforeExtent;
    final target = (beforePixels + delta).clamp(0.0, position.maxScrollExtent);
    if ((target - position.pixels).abs() > 1) {
      _scrollController.jumpTo(target);
    }
    _wasNearBottom = false;
  }

  void _revealSearchMatch(String messageId) {
    final targetIndex = widget.messages.indexWhere(
      (message) => message.info.id == messageId,
    );
    if (targetIndex < 0) {
      return;
    }
    final preferredStart = math.max(0, targetIndex - 2);
    if (preferredStart != _visibleStartIndex) {
      setState(() {
        _visibleStartIndex = preferredStart;
        _loadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _revealSearchMatch(messageId);
      });
      return;
    }
    if (_scrollController.hasClients &&
        _scrollController.position.hasPixels &&
        _scrollController.offset > 1) {
      _scrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _messageItemKeys[messageId]?.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.18,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _handleScroll() async {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (position.hasContentDimensions) {
        _wasNearBottom =
            !position.hasPixels ||
            (position.maxScrollExtent - position.pixels) <= 120;
      }
    }
    if (_loadingOlder || widget.historyLoading || !_hasMoreHistory) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions ||
        position.pixels > _loadOlderThreshold) {
      return;
    }
    await _loadOlderMessages();
  }

  void _scheduleLoadOlderCheck() {
    if (_loadOlderCheckScheduled ||
        _loadingOlder ||
        widget.historyLoading ||
        !_hasMoreHistory) {
      return;
    }
    _loadOlderCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOlderCheckScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_handleScroll());
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder ||
        widget.historyLoading ||
        !_hasMoreHistory ||
        !mounted) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    if (_hiddenMessageCount == 0) {
      _beginOlderHistoryPreservation();
      try {
        await widget.onLoadMore();
      } catch (_) {
        _clearOlderHistoryPreservation();
        rethrow;
      }
      return;
    }
    final nextStart = math.max(0, _visibleStartIndex - _windowGrowthSize);
    if (nextStart == _visibleStartIndex) {
      return;
    }

    _beginOlderHistoryPreservation();
    setState(() {
      _loadingOlder = true;
      _visibleStartIndex = nextStart;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _restoreOlderHistoryScroll();
      if (!_scrollController.hasClients) {
        setState(() {
          _loadingOlder = false;
        });
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOlder = false;
      });
      unawaited(_handleScroll());
    });
  }

  int _contentSignature() {
    return Object.hash(
      widget.timelineContentSignature,
      _showThinkingPlaceholder,
    );
  }

  bool get _showThinkingPlaceholder =>
      widget.working &&
      !_hasRenderableActiveAssistantMessage(
        widget.messages,
        showProgressDetails: widget.timelineProgressDetailsVisible,
      );

  void _beginBottomLock(String scopeKey) {
    _bottomLockScopeKey = scopeKey;
    _bottomLockLastExtent = null;
    _bottomLockStableFrames = 0;
    _bottomLockAttempts = 0;
    _scheduleBottomLock();
  }

  void _clearBottomLock() {
    _bottomLockScopeKey = null;
    _bottomLockLastExtent = null;
    _bottomLockStableFrames = 0;
    _bottomLockAttempts = 0;
  }

  void _scheduleBottomLock() {
    if (_bottomLockScheduled || _bottomLockScopeKey == null) {
      return;
    }
    _bottomLockScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomLockScheduled = false;
      if (!mounted) {
        return;
      }
      final expectedScopeKey = _bottomLockScopeKey;
      if (expectedScopeKey == null) {
        return;
      }
      if (!_scrollController.hasClients) {
        _scheduleBottomLock();
        return;
      }
      if (widget.storageScopeKey != expectedScopeKey) {
        _clearBottomLock();
        return;
      }
      final position = _scrollController.position;
      if (!position.hasContentDimensions) {
        _scheduleBottomLock();
        return;
      }
      final target = position.maxScrollExtent;
      if (!position.hasPixels || (target - position.pixels).abs() > 1) {
        _scrollController.jumpTo(target);
      }
      _wasNearBottom = true;

      final lastExtent = _bottomLockLastExtent;
      if (lastExtent != null && (target - lastExtent).abs() <= 1) {
        _bottomLockStableFrames += 1;
      } else {
        _bottomLockStableFrames = 0;
        _bottomLockLastExtent = target;
      }

      _bottomLockAttempts += 1;
      if (_bottomLockStableFrames >= 1 || _bottomLockAttempts >= 8) {
        _clearBottomLock();
        return;
      }
      _scheduleBottomLock();
    });
  }

  void _syncTimelinePosition({bool forceBottom = false}) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final scopeKey = widget.storageScopeKey;
    final messageCount = widget.messages.length;
    final contentSignature = _contentSignature();
    final sessionChanged = _lastScopeKey != scopeKey;
    final sessionLoadFinished =
        _lastLoading &&
        !widget.loading &&
        messageCount > 0 &&
        _lastScopeKey == scopeKey;
    final messageCountChanged = _lastMessageCount != messageCount;
    final contentChanged =
        _lastContentSignature != contentSignature || messageCountChanged;

    if (messageCount > 0 &&
        (sessionChanged || sessionLoadFinished || forceBottom)) {
      _beginBottomLock(scopeKey);
    }

    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    if (_searchActive && !forceBottom) {
      _lastScopeKey = scopeKey;
      _lastMessageCount = messageCount;
      _lastContentSignature = contentSignature;
      _lastLoading = widget.loading;
      return;
    }
    final nearBottomNow =
        !position.hasPixels ||
        (position.maxScrollExtent - position.pixels) <= 120;
    final shouldFollowTimeline =
        forceBottom ||
        sessionChanged ||
        (contentChanged && (_wasNearBottom || nearBottomNow));

    if (shouldFollowTimeline) {
      final target = position.maxScrollExtent;
      if ((target - position.pixels).abs() <= 1) {
        _wasNearBottom = true;
      } else if (sessionChanged || !position.hasPixels) {
        _scrollController.jumpTo(target);
        _wasNearBottom = true;
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        _wasNearBottom = true;
      }
    }

    _lastScopeKey = scopeKey;
    _lastMessageCount = messageCount;
    _lastContentSignature = contentSignature;
    _lastLoading = widget.loading;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final theme = Theme.of(context);
    final density = _workspaceDensity(context);
    final showThinkingPlaceholder = _showThinkingPlaceholder;
    _scheduleLoadOlderCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final activeMatchMessageId = widget.activeMatchMessageId;
      if (_searchActive &&
          activeMatchMessageId != null &&
          activeMatchMessageId.isNotEmpty) {
        _revealSearchMatch(activeMatchMessageId);
        return;
      }
      _syncTimelinePosition();
    });
    if (widget.loading && widget.messages.isEmpty) {
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
    if (widget.error != null && widget.messages.isEmpty) {
      return _TimelineStatusCard(
        icon: Icon(
          Icons.wifi_tethering_error_rounded,
          color: theme.colorScheme.error,
          size: 22,
        ),
        title: 'Couldn\'t load this session',
        message: widget.error!,
        action: OutlinedButton(
          onPressed: () => unawaited(widget.onRetry()),
          child: const Text('Retry'),
        ),
      );
    }
    if (widget.messages.isEmpty && !showThinkingPlaceholder) {
      return Center(
        child: Text(
          'No messages yet.',
          style: theme.textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (widget.showingCachedMessages && widget.loading)
          _TimelineCachedRefreshBanner(
            key: const ValueKey<String>('timeline-cached-refresh-banner'),
            compact: widget.compact,
            shimmering: true,
            title: 'Refreshing cached messages...',
            message:
                'Showing the last saved snapshot while the server loads newer messages.',
          )
        else if (widget.showingCachedMessages && widget.error != null)
          _TimelineCachedRefreshBanner(
            key: const ValueKey<String>('timeline-cached-refresh-banner'),
            compact: widget.compact,
            shimmering: false,
            title: 'Showing cached messages',
            message: widget.error!,
            action: OutlinedButton(
              onPressed: () => unawaited(widget.onRetry()),
              child: const Text('Retry'),
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            child: Builder(
              builder: (context) {
                final visibleMessages = _visibleMessages;
                final showLoadOlderIndicator =
                    _hiddenMessageCount > 0 ||
                    widget.historyMore ||
                    widget.historyLoading;
                final placeholderIndex =
                    visibleMessages.length + (showLoadOlderIndicator ? 1 : 0);
                final itemCount =
                    placeholderIndex + (showThinkingPlaceholder ? 1 : 0);
                final normalizedSearchTerms = _searchActive
                    ? _normalizedSearchTerms(widget.searchQuery)
                    : const <String>[];

                return ListView.builder(
                  controller: _scrollController,
                  key: PageStorageKey<String>(widget.pageStorageKeyValue),
                  padding: EdgeInsets.fromLTRB(
                    density.inset(
                      widget.compact ? AppSpacing.sm : AppSpacing.xl,
                    ),
                    density.inset(
                      widget.compact ? AppSpacing.sm : AppSpacing.xl,
                    ),
                    density.inset(
                      widget.compact ? AppSpacing.sm : AppSpacing.xl,
                    ),
                    density.inset(
                      widget.compact ? AppSpacing.xs : AppSpacing.lg,
                    ),
                  ),
                  itemCount: itemCount,
                  cacheExtent: _searchActive ? 200000 : 1600,
                  itemBuilder: (context, index) {
                    if (showThinkingPlaceholder && index == placeholderIndex) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: density.maxContentWidth(860),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: visibleMessages.isEmpty
                                  ? 0
                                  : (widget.compact
                                        ? density.inset(AppSpacing.sm)
                                        : density.inset(AppSpacing.md)),
                            ),
                            child: _TimelineThinkingPlaceholder(
                              compact: widget.compact,
                            ),
                          ),
                        ),
                      );
                    }
                    if (showLoadOlderIndicator && index == 0) {
                      return KeyedSubtree(
                        key: _loadOlderItemKey,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: density.maxContentWidth(860),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: widget.compact
                                    ? density.inset(AppSpacing.sm)
                                    : density.inset(AppSpacing.md),
                              ),
                              child: _TimelineLoadOlderIndicator(
                                hiddenCount: _hiddenMessageCount,
                                loading: _loadingOlder || widget.historyLoading,
                                serverMore: widget.historyMore,
                                compact: widget.compact,
                                onPressed: () =>
                                    unawaited(_loadOlderMessages()),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final messageIndex =
                        index - (showLoadOlderIndicator ? 1 : 0);
                    final message = visibleMessages[messageIndex];
                    final isLast = messageIndex == visibleMessages.length - 1;
                    final matched = widget.matchingMessageIds.contains(
                      message.info.id,
                    );
                    final activeMatch =
                        widget.activeMatchMessageId == message.info.id;
                    return KeyedSubtree(
                      key: _messageItemKey(message.info.id),
                      child: RepaintBoundary(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: density.maxContentWidth(860),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: isLast
                                    ? 0
                                    : (widget.compact
                                          ? density.inset(AppSpacing.md)
                                          : density.inset(AppSpacing.xl)),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: _TimelineMessage(
                                  currentSessionId: widget.currentSessionId,
                                  message: message,
                                  compact: widget.compact,
                                  searchTerms: matched
                                      ? normalizedSearchTerms
                                      : const <String>[],
                                  searchMatched: matched,
                                  searchActive: activeMatch,
                                  sessions: widget.sessions,
                                  selectedSession: widget.selectedSession,
                                  configSnapshot: widget.configSnapshot,
                                  shellToolDefaultExpanded:
                                      widget.shellToolDefaultExpanded,
                                  timelineProgressDetailsVisible:
                                      widget.timelineProgressDetailsVisible,
                                  onForkMessage: widget.onForkMessage,
                                  onRevertMessage: widget.onRevertMessage,
                                  onOpenSession: widget.onOpenSession,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineLoadOlderIndicator extends StatelessWidget {
  const _TimelineLoadOlderIndicator({
    required this.hiddenCount,
    required this.loading,
    required this.serverMore,
    required this.compact,
    this.onPressed,
  });

  final int hiddenCount;
  final bool loading;
  final bool serverMore;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final label = loading
        ? 'Loading earlier messages...'
        : hiddenCount > 0
        ? '$hiddenCount earlier messages'
        : serverMore
        ? 'Earlier messages available'
        : 'Load earlier messages';
    final hint = loading ? null : 'Scroll up or tap to load more';
    final content = Container(
      key: const ValueKey<String>('timeline-load-older-indicator'),
      padding: EdgeInsets.symmetric(
        horizontal: density.inset(compact ? AppSpacing.sm : AppSpacing.md),
        vertical: density.inset(compact ? AppSpacing.xs : AppSpacing.sm),
      ),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (loading) ...<Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.xs),
          ] else
            Icon(Icons.expand_less_rounded, size: 16, color: surfaces.muted),
          Text(
            label,
            style:
                (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
            ),
          ],
        ],
      ),
    );
    return Align(
      alignment: Alignment.center,
      child: onPressed == null || loading
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(compact ? 12 : 14),
                onTap: onPressed,
                child: content,
              ),
            ),
    );
  }
}

class _TimelineCachedRefreshBanner extends StatelessWidget {
  const _TimelineCachedRefreshBanner({
    required this.title,
    required this.message,
    required this.shimmering,
    this.compact = false,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final bool shimmering;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        density.inset(compact ? AppSpacing.sm : AppSpacing.xl),
        density.inset(compact ? AppSpacing.xs : AppSpacing.lg),
        density.inset(compact ? AppSpacing.sm : AppSpacing.xl),
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: density.maxContentWidth(860)),
          child: Container(
            padding: EdgeInsets.all(
              density.inset(compact ? AppSpacing.xs : AppSpacing.md),
            ),
            decoration: BoxDecoration(
              color: surfaces.panelRaised.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
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
                SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
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
                      SizedBox(
                        height: compact ? AppSpacing.xxs : AppSpacing.xs,
                      ),
                      Text(
                        message,
                        style:
                            (compact
                                    ? theme.textTheme.labelMedium
                                    : theme.textTheme.bodySmall)
                                ?.copyWith(color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...<Widget>[
                  SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
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
    final density = _workspaceDensity(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: density.maxContentWidth(520)),
        child: Padding(
          padding: EdgeInsets.all(
            density.inset(AppSpacing.xl, min: AppSpacing.md),
          ),
          child: Container(
            padding: EdgeInsets.all(
              density.inset(AppSpacing.lg, min: AppSpacing.md),
            ),
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

class _TimelineThinkingPlaceholder extends StatelessWidget {
  const _TimelineThinkingPlaceholder({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final summaryStyle =
        (compact ? theme.textTheme.labelMedium : theme.textTheme.bodySmall)
            ?.copyWith(color: surfaces.muted, height: 1.45);
    return Container(
      key: const ValueKey<String>('timeline-thinking-placeholder'),
      padding: EdgeInsets.all(
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
      ),
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.more_horiz_rounded,
              size: compact ? 18 : 20,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ShimmeringRichText(
                  key: const ValueKey<String>(
                    'timeline-thinking-placeholder-title',
                  ),
                  active: true,
                  text: TextSpan(text: 'Thinking', style: titleStyle),
                ),
                SizedBox(height: compact ? AppSpacing.xxs : AppSpacing.xs),
                _ShimmeringRichText(
                  key: const ValueKey<String>(
                    'timeline-thinking-placeholder-summary',
                  ),
                  active: true,
                  text: TextSpan(
                    text: 'The agent is preparing a response.',
                    style: summaryStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptComposer extends StatefulWidget {
  const _PromptComposer({
    super.key,
    required this.controller,
    required this.compact,
    required this.scopeKey,
    required this.focusRequestToken,
    required this.submitting,
    required this.busyFollowupMode,
    required this.interruptible,
    required this.interrupting,
    required this.pickingAttachments,
    required this.attachments,
    required this.queuedPrompts,
    required this.failedQueuedPromptId,
    required this.sendingQueuedPromptId,
    required this.agents,
    required this.models,
    required this.selectedAgentName,
    required this.selectedModel,
    required this.selectedReasoning,
    required this.reasoningValues,
    required this.customCommands,
    required this.historyEntries,
    required this.permissionAutoAccepting,
    required this.onSelectAgent,
    required this.onSelectModel,
    required this.onSelectReasoning,
    required this.onTogglePermissionAutoAccept,
    required this.onCreateSession,
    required this.onInterrupt,
    required this.onPickAttachments,
    required this.onDropFiles,
    required this.onPasteClipboardImage,
    required this.onContentInserted,
    required this.dropRegionBuilder,
    required this.onRemoveAttachment,
    required this.onEditQueuedPrompt,
    required this.onDeleteQueuedPrompt,
    required this.onSendQueuedPromptNow,
    required this.onOpenMcpPicker,
    required this.onToggleTerminal,
    required this.onSelectSideTab,
    required this.onSubmit,
    required this.submittedDraftEpoch,
    this.textFieldKey = const ValueKey<String>('composer-text-field'),
    this.onActivateComposer,
    this.onShareSession,
    this.onUnshareSession,
    this.onSummarizeSession,
    this.recentSubmittedDraft,
  });

  static const String _defaultReasoningSentinel = '__default_reasoning__';

  final TextEditingController controller;
  final bool compact;
  final String scopeKey;
  final int focusRequestToken;
  final bool submitting;
  final WorkspaceFollowupMode busyFollowupMode;
  final bool interruptible;
  final bool interrupting;
  final bool pickingAttachments;
  final List<PromptAttachment> attachments;
  final List<WorkspaceQueuedPrompt> queuedPrompts;
  final String? failedQueuedPromptId;
  final String? sendingQueuedPromptId;
  final List<AgentDefinition> agents;
  final List<WorkspaceComposerModelOption> models;
  final String? selectedAgentName;
  final WorkspaceComposerModelOption? selectedModel;
  final String? selectedReasoning;
  final List<String> reasoningValues;
  final List<CommandDefinition> customCommands;
  final List<String> historyEntries;
  final bool permissionAutoAccepting;
  final ValueChanged<String?> onSelectAgent;
  final ValueChanged<String?> onSelectModel;
  final ValueChanged<String?> onSelectReasoning;
  final Future<void> Function() onTogglePermissionAutoAccept;
  final Future<void> Function() onCreateSession;
  final Future<void> Function() onInterrupt;
  final Future<void> Function() onPickAttachments;
  final WorkspaceComposerDropFilesHandler onDropFiles;
  final Future<bool> Function() onPasteClipboardImage;
  final Future<void> Function(KeyboardInsertedContent content)
  onContentInserted;
  final WorkspaceComposerDropRegionBuilder dropRegionBuilder;
  final ValueChanged<String> onRemoveAttachment;
  final Future<void> Function(String queuedPromptId) onEditQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onDeleteQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onSendQueuedPromptNow;
  final Future<void> Function() onOpenMcpPicker;
  final Future<void> Function() onToggleTerminal;
  final ValueChanged<WorkspaceSideTab> onSelectSideTab;
  final Future<void> Function(WorkspacePromptDispatchMode? mode) onSubmit;
  final int submittedDraftEpoch;
  final Key textFieldKey;
  final VoidCallback? onActivateComposer;
  final Future<void> Function()? onShareSession;
  final Future<void> Function()? onUnshareSession;
  final Future<void> Function()? onSummarizeSession;
  final String? recentSubmittedDraft;

  @override
  State<_PromptComposer> createState() => _PromptComposerState();
}

class _PromptComposerState extends State<_PromptComposer> {
  static const Duration _restoredDraftGuardDuration = Duration(seconds: 1);

  final FocusNode _focusNode = FocusNode();
  Timer? _restoredDraftGuardTimer;
  String? _guardedRestoredDraft;
  bool _clearingRestoredDraft = false;
  int _historyIndex = -1;
  String? _savedHistoryDraft;
  bool _applyingPromptHistory = false;
  bool _draggingFiles = false;

  bool get _canSubmit =>
      widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty;

  bool _usesDesktopEnterToSubmit(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  bool get _hasActiveTextComposition {
    final composing = widget.controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  bool _isPlainSubmitKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    return !keyboard.isShiftPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed;
  }

  bool _isShiftNewlineKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed;
  }

  bool _isPlainArrowHistoryKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowUp &&
        event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    return !keyboard.isShiftPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed;
  }

  bool _canNavigatePromptHistory({required bool up}) {
    if (widget.historyEntries.isEmpty) {
      return false;
    }
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }
    final text = widget.controller.text;
    final cursor = selection.baseOffset.clamp(0, text.length);
    if (_historyIndex >= 0) {
      return cursor == 0 || cursor == text.length;
    }
    if (!up) {
      return false;
    }
    return cursor == 0 && text.isEmpty;
  }

  void _applyPromptHistoryEntry(String text, {required bool moveToStart}) {
    _applyingPromptHistory = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: moveToStart ? 0 : text.length),
      composing: TextRange.empty,
    );
    _applyingPromptHistory = false;
  }

  bool _navigatePromptHistory(bool up) {
    final entries = widget.historyEntries;
    if (entries.isEmpty) {
      return false;
    }
    if (up) {
      if (_historyIndex == -1) {
        _savedHistoryDraft = widget.controller.text;
        _historyIndex = 0;
        _applyPromptHistoryEntry(entries.first, moveToStart: true);
        return true;
      }
      if (_historyIndex < entries.length - 1) {
        _historyIndex += 1;
        _applyPromptHistoryEntry(entries[_historyIndex], moveToStart: true);
        return true;
      }
      return false;
    }

    if (_historyIndex > 0) {
      _historyIndex -= 1;
      _applyPromptHistoryEntry(entries[_historyIndex], moveToStart: false);
      return true;
    }
    if (_historyIndex == 0) {
      final restored = _savedHistoryDraft ?? '';
      _historyIndex = -1;
      _savedHistoryDraft = null;
      _applyPromptHistoryEntry(restored, moveToStart: false);
      return true;
    }
    return false;
  }

  void _resetPromptHistoryNavigation() {
    _historyIndex = -1;
    _savedHistoryDraft = null;
  }

  void _insertComposerNewLine() {
    final value = widget.controller.value;
    final fallbackSelection = TextSelection.collapsed(
      offset: value.text.length,
    );
    final selection = value.selection.isValid
        ? value.selection
        : fallbackSelection;
    final start = math.min(selection.start, selection.end);
    final end = math.max(selection.start, selection.end);
    final nextText = value.text.replaceRange(start, end, '\n');
    final nextOffset = start + 1;
    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }

  KeyEventResult _handleComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (!_usesDesktopEnterToSubmit(Theme.of(context).platform) ||
        event is! KeyDownEvent ||
        _hasActiveTextComposition) {
      return KeyEventResult.ignored;
    }
    if (_isPlainArrowHistoryKey(event)) {
      final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
      if (_canNavigatePromptHistory(up: up) && _navigatePromptHistory(up)) {
        return KeyEventResult.handled;
      }
    }
    if (_isShiftNewlineKey(event)) {
      _insertComposerNewLine();
      return KeyEventResult.handled;
    }
    if (_isPlainSubmitKey(event)) {
      unawaited(_handleSubmit());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

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
    if (oldWidget.submittedDraftEpoch != widget.submittedDraftEpoch) {
      _armRestoredDraftGuard(widget.recentSubmittedDraft);
    }
    if (_historyIndex >= widget.historyEntries.length) {
      _resetPromptHistoryNavigation();
    }
    if (oldWidget.scopeKey != widget.scopeKey) {
      _clearRestoredDraftGuard();
      _resetPromptHistoryNavigation();
      _draggingFiles = false;
      _dismissFocus();
    }
    if ((widget.submitting || widget.pickingAttachments) && _draggingFiles) {
      _draggingFiles = false;
    }
    if (oldWidget.focusRequestToken != widget.focusRequestToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _restoredDraftGuardTimer?.cancel();
    widget.controller.removeListener(_handleComposerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (_clearingRestoredDraft) {
      return;
    }
    if (_applyingPromptHistory) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final guardedDraft = _guardedRestoredDraft;
    final currentText = widget.controller.text;
    if (guardedDraft != null && currentText == guardedDraft) {
      _clearingRestoredDraft = true;
      widget.controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
      _clearingRestoredDraft = false;
      return;
    }
    if (guardedDraft != null && currentText.isNotEmpty) {
      _clearRestoredDraftGuard();
    }
    if (_historyIndex >= 0 && currentText != _savedHistoryDraft) {
      // Keep the currently recalled prompt visible, but stop treating future
      // navigation as part of the previous history traversal once the user edits.
      _historyIndex = -1;
      _savedHistoryDraft = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _armRestoredDraftGuard(String? draft) {
    _restoredDraftGuardTimer?.cancel();
    final normalizedDraft = draft == null || draft.isEmpty ? null : draft;
    _guardedRestoredDraft = normalizedDraft;
    if (normalizedDraft == null) {
      return;
    }
    _restoredDraftGuardTimer = Timer(_restoredDraftGuardDuration, () {
      if (!mounted) {
        return;
      }
      _clearRestoredDraftGuard();
    });
  }

  void _clearRestoredDraftGuard() {
    _restoredDraftGuardTimer?.cancel();
    _restoredDraftGuardTimer = null;
    _guardedRestoredDraft = null;
  }

  void _dismissFocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _setDraggingFiles(bool value) {
    if (_draggingFiles == value || !mounted) {
      return;
    }
    setState(() {
      _draggingFiles = value;
    });
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
        id: 'builtin.permissions',
        trigger: 'permissions',
        title: 'Toggle permission auto-accept',
        description: 'Enable or disable auto-accept for this session',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.permissionAutoAccept,
      ),
      const _ComposerSlashCommand(
        id: 'builtin.mcp',
        trigger: 'mcp',
        title: 'Toggle MCPs',
        description: 'Connect or disconnect MCP servers for this session',
        type: _ComposerSlashCommandType.builtin,
        action: _ComposerBuiltinSlashAction.mcpPicker,
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

  bool get _showsInterruptAction => widget.interruptible && !_canSubmit;

  Future<void> _handleSubmit([WorkspacePromptDispatchMode? mode]) async {
    if (_showsInterruptAction) {
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
    await widget.onSubmit(mode);
  }

  Future<void> _handleSubmitLongPress() async {
    if (_showsInterruptAction || widget.submitting || !_canSubmit) {
      return;
    }
    final selection = await _showSubmitModePicker(context);
    if (selection == null) {
      return;
    }
    await _handleSubmit(selection);
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

  Future<WorkspacePromptDispatchMode?> _showSubmitModePicker(
    BuildContext context,
  ) {
    return showModalBottomSheet<WorkspacePromptDispatchMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ComposerSubmitModeSheet(
        defaultMode: widget.busyFollowupMode,
        busy: widget.interruptible,
      ),
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
      case _ComposerBuiltinSlashAction.permissionAutoAccept:
        await widget.onTogglePermissionAutoAccept();
        break;
      case _ComposerBuiltinSlashAction.mcpPicker:
        await widget.onOpenMcpPicker();
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

  List<ContextMenuButtonItem> _contextMenuButtonItems(
    EditableTextState editableTextState,
  ) {
    return editableTextState.contextMenuButtonItems
        .map((item) {
          if (item.type != ContextMenuButtonType.paste) {
            return item;
          }
          return item.copyWith(
            onPressed: () {
              unawaited(_handleContextMenuPaste(editableTextState));
            },
          );
        })
        .toList(growable: false);
  }

  Future<void> _handleContextMenuPaste(
    EditableTextState editableTextState,
  ) async {
    final handledImagePaste = await widget.onPasteClipboardImage();
    if (handledImagePaste) {
      editableTextState.hideToolbar();
      return;
    }
    await _pasteClipboardText();
    editableTextState.hideToolbar();
  }

  Future<void> _pasteClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    final value = widget.controller.value;
    final fallbackSelection = TextSelection.collapsed(
      offset: value.text.length,
    );
    final selection = value.selection.isValid
        ? value.selection
        : fallbackSelection;
    final start = math.min(selection.start, selection.end);
    final end = math.max(selection.start, selection.end);
    final nextText = value.text.replaceRange(start, end, text);
    final nextOffset = start + text.length;
    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final reasoningLabel = _reasoningLabel(widget.selectedReasoning);
    final slashCommands = _filteredSlashCommands;
    final isCompact = widget.compact || density.compact;
    final submitIcon = _showsInterruptAction
        ? Icons.stop_rounded
        : widget.interruptible &&
              widget.busyFollowupMode == WorkspaceFollowupMode.queue
        ? Icons.schedule_send_rounded
        : Icons.arrow_upward_rounded;
    final submitEnabled = _showsInterruptAction
        ? !widget.interrupting
        : !(widget.submitting || !_canSubmit);
    final submitBusy = !_showsInterruptAction && widget.submitting;
    final dropEnabled = !(widget.submitting || widget.pickingAttachments);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        density.inset(isCompact ? AppSpacing.sm : AppSpacing.md),
        density.inset(isCompact ? AppSpacing.xs : AppSpacing.sm),
        density.inset(isCompact ? AppSpacing.sm : AppSpacing.md),
        density.inset(isCompact ? AppSpacing.sm : AppSpacing.md),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: density.maxContentWidth(920)),
          child: Stack(
            children: <Widget>[
              widget.dropRegionBuilder(
                enabled: dropEnabled,
                onHoverChanged: _setDraggingFiles,
                onFilesDropped: (files) async {
                  _setDraggingFiles(false);
                  await widget.onDropFiles(files);
                },
                child: Container(
                  padding: EdgeInsets.all(
                    density.inset(isCompact ? AppSpacing.sm : AppSpacing.md),
                  ),
                  decoration: BoxDecoration(
                    color: surfaces.panel,
                    borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
                    border: Border.all(
                      color: _draggingFiles
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.55)
                          : surfaces.lineSoft,
                      width: _draggingFiles ? 1.5 : 1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: isCompact ? 16 : 24,
                        offset: Offset(0, isCompact ? 6 : 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      if (widget.queuedPrompts.isNotEmpty) ...<Widget>[
                        _ComposerQueuedPromptDock(
                          compact: isCompact,
                          queuedPrompts: widget.queuedPrompts,
                          failedQueuedPromptId: widget.failedQueuedPromptId,
                          sendingQueuedPromptId: widget.sendingQueuedPromptId,
                          busy: widget.interruptible,
                          onEditQueuedPrompt: widget.onEditQueuedPrompt,
                          onDeleteQueuedPrompt: widget.onDeleteQueuedPrompt,
                          onSendQueuedPromptNow: widget.onSendQueuedPromptNow,
                        ),
                        SizedBox(
                          height: density.inset(
                            isCompact ? AppSpacing.sm : AppSpacing.md,
                          ),
                        ),
                      ],
                      if (slashCommands.isNotEmpty) ...<Widget>[
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: density.inset(
                              isCompact ? 240 : 320,
                              min: 220,
                            ),
                          ),
                          child: DecoratedBox(
                            key: const ValueKey<String>(
                              'composer-slash-popover',
                            ),
                            decoration: BoxDecoration(
                              color: surfaces.panelMuted,
                              borderRadius: BorderRadius.circular(
                                isCompact ? 14 : 18,
                              ),
                              border: Border.all(color: surfaces.lineSoft),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.all(
                                density.inset(
                                  isCompact ? AppSpacing.xs : AppSpacing.sm,
                                ),
                              ),
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
                                        borderRadius: BorderRadius.circular(
                                          isCompact ? 10 : 12,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact
                                            ? density.inset(AppSpacing.sm)
                                            : density.inset(AppSpacing.md),
                                        vertical: isCompact
                                            ? density.inset(AppSpacing.xs)
                                            : density.inset(AppSpacing.sm),
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
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color:
                                                                surfaces.muted,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (command.type ==
                                                  _ComposerSlashCommandType
                                                      .custom &&
                                              command.source != null &&
                                              command.source !=
                                                  'command') ...<Widget>[
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.sm,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: surfaces.panel,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                command.source!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: surfaces.muted,
                                                    ),
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
                        SizedBox(
                          height: density.inset(
                            isCompact ? AppSpacing.sm : AppSpacing.md,
                          ),
                        ),
                      ],
                      if (widget.attachments.isNotEmpty) ...<Widget>[
                        _ComposerAttachmentStrip(
                          attachments: widget.attachments,
                          onRemove: widget.onRemoveAttachment,
                        ),
                        SizedBox(
                          height: density.inset(
                            isCompact ? AppSpacing.sm : AppSpacing.md,
                          ),
                        ),
                      ],
                      Actions(
                        actions: <Type, Action<Intent>>{
                          PasteTextIntent: _ComposerPasteTextAction(
                            onPasteImage: widget.onPasteClipboardImage,
                            onPasteText: _pasteClipboardText,
                          ),
                        },
                        child: Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: _handleComposerKeyEvent,
                          child: TextField(
                            key: widget.textFieldKey,
                            controller: widget.controller,
                            focusNode: _focusNode,
                            minLines: isCompact ? 2 : 3,
                            maxLines: isCompact ? 6 : 8,
                            contextMenuBuilder: kIsWeb
                                ? null
                                : (
                                    BuildContext context,
                                    EditableTextState editableTextState,
                                  ) {
                                    return AdaptiveTextSelectionToolbar.buttonItems(
                                      anchors:
                                          editableTextState.contextMenuAnchors,
                                      buttonItems: _contextMenuButtonItems(
                                        editableTextState,
                                      ),
                                    );
                                  },
                            contentInsertionConfiguration:
                                ContentInsertionConfiguration(
                                  allowedMimeTypes: PromptAttachmentService
                                      .supportedContentInsertionMimeTypes,
                                  onContentInserted: (content) {
                                    unawaited(
                                      widget.onContentInserted(content),
                                    );
                                  },
                                ),
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
                            onTap: widget.onActivateComposer,
                            onSubmitted: (_) => _handleSubmit(),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: density.inset(
                          isCompact ? AppSpacing.xs : AppSpacing.sm,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          _ComposerIconButton(
                            key: const ValueKey<String>(
                              'composer-attach-button',
                            ),
                            compact: isCompact,
                            icon: Icons.add_rounded,
                            onTap:
                                widget.submitting || widget.pickingAttachments
                                ? null
                                : () {
                                    unawaited(widget.onPickAttachments());
                                  },
                            busy: widget.pickingAttachments,
                          ),
                          SizedBox(
                            width: density.inset(
                              isCompact ? AppSpacing.xs : AppSpacing.sm,
                            ),
                          ),
                          _ComposerIconButton(
                            key: const ValueKey<String>(
                              'composer-permissions-button',
                            ),
                            compact: isCompact,
                            icon: widget.permissionAutoAccepting
                                ? Icons.verified_user_rounded
                                : Icons.policy_outlined,
                            onTap: () {
                              unawaited(widget.onTogglePermissionAutoAccept());
                            },
                            filled: widget.permissionAutoAccepting,
                          ),
                          SizedBox(
                            width: density.inset(
                              isCompact ? AppSpacing.xs : AppSpacing.sm,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: <Widget>[
                                  _ComposerSelectionPill(
                                    compact: isCompact,
                                    label: widget.selectedAgentName ?? 'Agent',
                                    onTap: widget.agents.isEmpty
                                        ? null
                                        : () async {
                                            final selection =
                                                await _showAgentPicker(context);
                                            if (selection != null) {
                                              widget.onSelectAgent(selection);
                                            }
                                          },
                                  ),
                                  SizedBox(
                                    width: density.inset(
                                      isCompact
                                          ? AppSpacing.xxs
                                          : AppSpacing.xs,
                                      min: 3,
                                    ),
                                  ),
                                  _ComposerSelectionPill(
                                    compact: isCompact,
                                    label:
                                        widget.selectedModel?.name ?? 'Model',
                                    onTap: widget.models.isEmpty
                                        ? null
                                        : () async {
                                            final selection =
                                                await _showModelPicker(context);
                                            if (selection != null) {
                                              widget.onSelectModel(selection);
                                            }
                                          },
                                  ),
                                  SizedBox(
                                    width: density.inset(
                                      isCompact
                                          ? AppSpacing.xxs
                                          : AppSpacing.xs,
                                      min: 3,
                                    ),
                                  ),
                                  _ComposerSelectionPill(
                                    compact: isCompact,
                                    label: reasoningLabel,
                                    onTap: widget.selectedModel == null
                                        ? null
                                        : () async {
                                            final selection =
                                                await _showReasoningPicker(
                                                  context,
                                                );
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
                          SizedBox(
                            width: density.inset(
                              isCompact ? AppSpacing.xs : AppSpacing.sm,
                            ),
                          ),
                          _ComposerIconButton(
                            key: const ValueKey<String>(
                              'composer-submit-button',
                            ),
                            compact: isCompact,
                            icon: submitIcon,
                            onTap: submitEnabled
                                ? () => unawaited(_handleSubmit())
                                : null,
                            onLongPress: submitEnabled
                                ? () => unawaited(_handleSubmitLongPress())
                                : null,
                            filled: true,
                            busy: _showsInterruptAction
                                ? widget.interrupting
                                : submitBusy,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_draggingFiles)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const ValueKey<String>('composer-drop-overlay'),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          isCompact ? 16 : 20,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: density.inset(
                              isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            vertical: density.inset(
                              isCompact ? AppSpacing.sm : AppSpacing.md,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: surfaces.panelRaised.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(
                              isCompact ? 14 : 18,
                            ),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'Drop files or images to attach',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
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
    final density = _workspaceDensity(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: density.inset(AppSpacing.sm),
        runSpacing: density.inset(AppSpacing.sm),
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
    final density = _workspaceDensity(context);
    final previewBytes = _attachmentDataBytes(attachment.url);
    return Container(
      width: attachment.isImage ? 112 : 200,
      padding: EdgeInsets.all(density.inset(AppSpacing.sm)),
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
          SizedBox(width: density.inset(AppSpacing.sm)),
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
          SizedBox(width: density.inset(AppSpacing.xs)),
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

class _ComposerPasteTextAction extends Action<PasteTextIntent> {
  _ComposerPasteTextAction({
    required this.onPasteImage,
    required this.onPasteText,
  });

  final Future<bool> Function() onPasteImage;
  final Future<void> Function() onPasteText;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    return _invokeAsync(intent, context);
  }

  Future<void> _invokeAsync(
    PasteTextIntent intent,
    BuildContext? context,
  ) async {
    final handledImagePaste = await onPasteImage();
    if (handledImagePaste) {
      return;
    }
    await onPasteText();
  }

  @override
  bool consumesKey(PasteTextIntent intent) => true;

  @override
  bool isEnabled(PasteTextIntent intent) => true;
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
  permissionAutoAccept,
  mcpPicker,
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

class _PendingQuestionComposerNotice extends StatelessWidget {
  const _PendingQuestionComposerNotice({
    required this.request,
    required this.compact,
  });

  final QuestionRequestSummary request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
        density.inset(compact ? AppSpacing.xs : AppSpacing.sm),
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: density.maxContentWidth(920)),
          child: Container(
            padding: EdgeInsets.all(
              density.inset(compact ? AppSpacing.sm : AppSpacing.md),
            ),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(compact ? 12 : 14),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: compact ? 18 : 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(
                  width: density.inset(compact ? AppSpacing.sm : AppSpacing.md),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Question pending in the active session',
                        style:
                            (compact
                                    ? theme.textTheme.titleSmall
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(
                        height: density.inset(
                          compact ? AppSpacing.xxs : AppSpacing.xs,
                          min: 2,
                        ),
                      ),
                      Text(
                        'Answer it in the session panel to continue.',
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: surfaces.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
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

class _PendingPermissionComposerNotice extends StatelessWidget {
  const _PendingPermissionComposerNotice({
    required this.request,
    required this.compact,
  });

  final PermissionRequestSummary request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
        density.inset(compact ? AppSpacing.xs : AppSpacing.sm),
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
        density.inset(compact ? AppSpacing.sm : AppSpacing.md),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: density.maxContentWidth(920)),
          child: Container(
            padding: EdgeInsets.all(
              density.inset(compact ? AppSpacing.sm : AppSpacing.md),
            ),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    color: surfaces.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(compact ? 12 : 14),
                  ),
                  child: Icon(
                    Icons.policy_outlined,
                    size: compact ? 18 : 20,
                    color: surfaces.warning,
                  ),
                ),
                SizedBox(
                  width: density.inset(compact ? AppSpacing.sm : AppSpacing.md),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Permission required in the active session',
                        style:
                            (compact
                                    ? theme.textTheme.titleSmall
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(
                        height: density.inset(
                          compact ? AppSpacing.xxs : AppSpacing.xs,
                          min: 2,
                        ),
                      ),
                      Text(
                        request.permission.trim().isEmpty
                            ? 'Approve or reject it in the session panel to continue.'
                            : 'Approve or reject ${request.permission} in the session panel to continue.',
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: surfaces.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
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

class _QuestionPromptDock extends StatefulWidget {
  const _QuestionPromptDock({
    required this.request,
    required this.compact,
    required this.onReply,
    required this.onReject,
    super.key,
  });

  final QuestionRequestSummary request;
  final bool compact;
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
  List<FocusNode> _customFocusNodes = const <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _resetState();
  }

  @override
  void didUpdateWidget(covariant _QuestionPromptDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) {
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
    for (final focusNode in _customFocusNodes) {
      focusNode.dispose();
    }
    _customControllers = const <TextEditingController>[];
    _customFocusNodes = const <FocusNode>[];
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
    _customFocusNodes = List<FocusNode>.generate(
      count,
      (_) => FocusNode(),
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

  bool _questionAllowsCustom(QuestionPromptSummary? question) {
    return question?.custom ?? true;
  }

  void _focusCustomInput() {
    if (_tab >= _customFocusNodes.length) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tab >= _customFocusNodes.length) {
        return;
      }
      _customFocusNodes[_tab].requestFocus();
    });
  }

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
    _customFocusNodes[_tab].unfocus();
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
    if (question == null || _submitting || !_questionAllowsCustom(question)) {
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
      _focusCustomInput();
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
    if (nextSelected) {
      _focusCustomInput();
    } else {
      _customFocusNodes[_tab].unfocus();
    }
  }

  void _updateCustomValue(String value) {
    final question = _question;
    if (question == null || !_questionAllowsCustom(question)) {
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
    final customAllowed = _questionAllowsCustom(question);
    final customValue = _customControllers[_tab].text.trim();
    final customSelected = _customEnabled[_tab];
    final isCompact = widget.compact;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompact ? AppSpacing.sm : AppSpacing.md,
        isCompact ? AppSpacing.xs : AppSpacing.sm,
        isCompact ? AppSpacing.sm : AppSpacing.md,
        isCompact ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            padding: EdgeInsets.all(isCompact ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
              border: Border.all(color: surfaces.lineSoft),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: isCompact ? 16 : 24,
                  offset: Offset(0, isCompact ? 6 : 10),
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
                            width: isCompact ? 18 : 22,
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
                SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: isCompact ? 300 : 360),
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
                          SizedBox(
                            height: isCompact ? AppSpacing.xxs : AppSpacing.xs,
                          ),
                        ],
                        Text(
                          question.question,
                          style:
                              (isCompact
                                      ? theme.textTheme.titleMedium
                                      : theme.textTheme.titleLarge)
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                        ),
                        SizedBox(
                          height: isCompact ? AppSpacing.xxs : AppSpacing.xs,
                        ),
                        Text(
                          question.multiple
                              ? 'Select one or more answers.'
                              : 'Select one answer.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: surfaces.muted,
                          ),
                        ),
                        SizedBox(
                          height: isCompact ? AppSpacing.sm : AppSpacing.md,
                        ),
                        for (final option in question.options) ...<Widget>[
                          _QuestionChoiceTile(
                            title: option.label,
                            subtitle: option.description,
                            selected: _answers[_tab].contains(option.label),
                            multiple: question.multiple,
                            compact: isCompact,
                            onTap: () => _selectOption(option.label),
                          ),
                          SizedBox(
                            height: isCompact ? AppSpacing.xs : AppSpacing.sm,
                          ),
                        ],
                        if (customAllowed)
                          _QuestionChoiceTile(
                            key: ValueKey<String>(
                              'question-dock-custom-option-$_tab',
                            ),
                            title: 'Other',
                            subtitle: customValue.isEmpty
                                ? 'Type your own answer'
                                : customValue,
                            selected: customSelected,
                            multiple: question.multiple,
                            compact: isCompact,
                            onTap: _toggleCustom,
                          ),
                        if (customAllowed &&
                            (customSelected ||
                                customValue.isNotEmpty)) ...<Widget>[
                          SizedBox(
                            height: isCompact ? AppSpacing.xs : AppSpacing.sm,
                          ),
                          TextField(
                            key: ValueKey<String>(
                              'question-dock-custom-input-$_tab',
                            ),
                            controller: _customControllers[_tab],
                            focusNode: _customFocusNodes[_tab],
                            onChanged: _updateCustomValue,
                            enabled: !_submitting,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Type your answer...',
                              filled: true,
                              fillColor: surfaces.panelMuted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 14 : 16,
                                ),
                                borderSide: BorderSide(
                                  color: surfaces.lineSoft,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 14 : 16,
                                ),
                                borderSide: BorderSide(
                                  color: surfaces.lineSoft,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 14 : 16,
                                ),
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
                SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
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

class _PermissionPromptDock extends StatelessWidget {
  const _PermissionPromptDock({
    required this.request,
    required this.compact,
    required this.responding,
    required this.onDecide,
    super.key,
  });

  final PermissionRequestSummary request;
  final bool compact;
  final bool responding;
  final Future<void> Function(String requestId, String reply) onDecide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final patterns = request.patterns
        .map((pattern) => pattern.trim())
        .where((pattern) => pattern.isNotEmpty)
        .toList(growable: false);

    Future<void> decide(String reply) async {
      if (responding) {
        return;
      }
      await onDecide(request.id, reply);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.sm : AppSpacing.md,
        compact ? AppSpacing.xs : AppSpacing.sm,
        compact ? AppSpacing.sm : AppSpacing.md,
        compact ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
              border: Border.all(color: surfaces.lineSoft),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: compact ? 16 : 24,
                  offset: Offset(0, compact ? 6 : 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: compact ? 34 : 40,
                      height: compact ? 34 : 40,
                      decoration: BoxDecoration(
                        color: surfaces.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(compact ? 12 : 14),
                      ),
                      child: Icon(
                        Icons.policy_outlined,
                        size: compact ? 18 : 20,
                        color: surfaces.warning,
                      ),
                    ),
                    SizedBox(
                      width: density.inset(
                        compact ? AppSpacing.sm : AppSpacing.md,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Permission Request',
                            style:
                                (compact
                                        ? theme.textTheme.titleMedium
                                        : theme.textTheme.titleLarge)
                                    ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(
                            height: density.inset(
                              compact ? AppSpacing.xxs : AppSpacing.xs,
                              min: 2,
                            ),
                          ),
                          Text(
                            request.permission.trim().isEmpty
                                ? 'A tool is asking for permission.'
                                : request.permission,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: surfaces.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (patterns.isNotEmpty) ...<Widget>[
                  SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: patterns
                        .map(
                          (pattern) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: surfaces.panelMuted,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: surfaces.lineSoft),
                            ),
                            child: Text(
                              pattern,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 440;
                    final denyButton = TextButton(
                      key: const ValueKey<String>('permission-dock-deny'),
                      onPressed: responding
                          ? null
                          : () => unawaited(decide('reject')),
                      child: const Text('Deny'),
                    );
                    final alwaysButton = OutlinedButton(
                      key: const ValueKey<String>(
                        'permission-dock-allow-always',
                      ),
                      onPressed: responding
                          ? null
                          : () => unawaited(decide('always')),
                      child: const Text('Allow Always'),
                    );
                    final onceButton = FilledButton(
                      key: const ValueKey<String>('permission-dock-allow-once'),
                      onPressed: responding
                          ? null
                          : () => unawaited(decide('once')),
                      child: responding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Allow Once'),
                    );
                    if (!narrow) {
                      return Row(
                        children: <Widget>[
                          denyButton,
                          const Spacer(),
                          alwaysButton,
                          const SizedBox(width: AppSpacing.sm),
                          onceButton,
                        ],
                      );
                    }
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        alignment: WrapAlignment.end,
                        children: <Widget>[
                          denyButton,
                          alwaysButton,
                          onceButton,
                        ],
                      ),
                    );
                  },
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
    required this.compact,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool multiple;
  final bool compact;
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
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? surfaces.panelRaised : surfaces.panelMuted,
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: compact ? 18 : 20, color: borderColor),
              SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style:
                          (compact
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null &&
                        subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style:
                            (compact
                                    ? theme.textTheme.bodySmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(color: surfaces.muted, height: 1.45),
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
    required this.compact,
    required this.onClearStale,
    super.key,
  });

  final String sessionId;
  final List<TodoItem> todos;
  final bool live;
  final bool blocked;
  final bool compact;
  final VoidCallback onClearStale;

  @override
  State<_SessionTodoDock> createState() => _SessionTodoDockState();
}

class _SessionTodoDockState extends State<_SessionTodoDock> {
  static const Duration _closeDelay = Duration(milliseconds: 400);
  static const String _todoItemSeparator = '\u001f';
  static const String _todoListSeparator = '\u001e';

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  Timer? _closeTimer;
  bool _visible = false;
  bool _closing = false;
  bool _collapsed = false;
  bool _stuck = false;
  bool _clearQueued = false;
  String? _dismissedCompletedSignature;
  String? _scheduledCloseSignature;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _syncState(initial: true);
  }

  @override
  void didUpdateWidget(covariant _SessionTodoDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousSignature = _todoSignatureFor(oldWidget.todos);
    final nextSignature = _todoSignature;
    if (oldWidget.sessionId != widget.sessionId) {
      _collapsed = false;
      _stuck = false;
      _clearQueued = false;
      _dismissedCompletedSignature = null;
      _cancelCloseTimer();
    } else if (previousSignature != nextSignature || !_done || !widget.live) {
      _dismissedCompletedSignature = null;
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

  String get _todoSignature => _todoSignatureFor(widget.todos);

  String _todoSignatureFor(List<TodoItem> todos) {
    if (todos.isEmpty) {
      return '';
    }
    return todos
        .map(
          (todo) => <String>[
            todo.id,
            todo.status,
            todo.priority,
            todo.content,
          ].join(_todoItemSeparator),
        )
        .join(_todoListSeparator);
  }

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
    final todoSignature = _todoSignature;
    final next = _todoDockState(
      count: widget.todos.length,
      done: _done,
      live: widget.live,
    );

    if (next == _TodoDockState.hide) {
      _dismissedCompletedSignature = null;
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
      _dismissedCompletedSignature = null;
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
      _dismissedCompletedSignature = null;
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

    if (_dismissedCompletedSignature == todoSignature &&
        !_visible &&
        !_closing) {
      return;
    }
    if (!_visible || !_closing) {
      setState(() {
        _visible = true;
        _closing = true;
      });
    }
    _scheduleClose(todoSignature);
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
    _scheduledCloseSignature = null;
  }

  void _scheduleClose(String todoSignature) {
    if (_closeTimer != null && _scheduledCloseSignature == todoSignature) {
      return;
    }
    _cancelCloseTimer();
    _scheduledCloseSignature = todoSignature;
    _closeTimer = Timer(_closeDelay, () {
      if (!mounted) {
        return;
      }
      final shouldDismiss =
          widget.live && _done && _todoSignature == todoSignature;
      setState(() {
        _visible = false;
        _closing = false;
      });
      if (shouldDismiss) {
        _dismissedCompletedSignature = todoSignature;
      }
      _closeTimer = null;
      _scheduledCloseSignature = null;
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
    final isCompact = widget.compact;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: !shouldRender
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? AppSpacing.sm : AppSpacing.md,
                isCompact ? AppSpacing.xs : AppSpacing.sm,
                isCompact ? AppSpacing.sm : AppSpacing.md,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaces.panel,
                      borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: Column(
                      children: <Widget>[
                        InkWell(
                          onTap: _toggleCollapsed,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(isCompact ? 16 : 20),
                            bottom: Radius.circular(isCompact ? 16 : 20),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isCompact ? AppSpacing.sm : AppSpacing.md,
                              isCompact ? AppSpacing.sm : AppSpacing.md,
                              isCompact ? AppSpacing.xs : AppSpacing.sm,
                              isCompact ? AppSpacing.sm : AppSpacing.md,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _collapsed && preview.isNotEmpty
                                      ? Row(
                                          children: <Widget>[
                                            Flexible(
                                              flex: 3,
                                              child: Text(
                                                progressLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    (isCompact
                                                            ? theme
                                                                  .textTheme
                                                                  .titleSmall
                                                            : theme
                                                                  .textTheme
                                                                  .titleMedium)
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: isCompact
                                                  ? AppSpacing.xs
                                                  : AppSpacing.sm,
                                            ),
                                            Flexible(
                                              flex: 4,
                                              child: Text(
                                                preview,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: surfaces.muted,
                                                      height: 1.45,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          progressLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              (isCompact
                                                      ? theme
                                                            .textTheme
                                                            .titleSmall
                                                      : theme
                                                            .textTheme
                                                            .titleMedium)
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                        ),
                                ),
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
                                  splashRadius: isCompact ? 16 : 18,
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
                                        constraints: BoxConstraints(
                                          maxHeight: isCompact ? 220 : 260,
                                        ),
                                        child: SingleChildScrollView(
                                          controller: _scrollController,
                                          padding: EdgeInsets.fromLTRB(
                                            isCompact
                                                ? AppSpacing.sm
                                                : AppSpacing.md,
                                            0,
                                            isCompact
                                                ? AppSpacing.sm
                                                : AppSpacing.md,
                                            isCompact
                                                ? AppSpacing.lg
                                                : AppSpacing.xl,
                                          ),
                                          child: Column(
                                            key: const ValueKey<String>(
                                              'session-todo-list',
                                            ),
                                            children: widget.todos
                                                .map(
                                                  (todo) => Padding(
                                                    key: _keyForTodo(todo),
                                                    padding: EdgeInsets.only(
                                                      bottom: isCompact
                                                          ? AppSpacing.xs
                                                          : AppSpacing.sm,
                                                    ),
                                                    child: _TodoDockRow(
                                                      todo: todo,
                                                      compact: isCompact,
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
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(
                                                      isCompact ? 16 : 20,
                                                    ),
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
  const _TodoDockRow({required this.todo, required this.compact});

  final TodoItem todo;
  final bool compact;

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
          child: _TodoStatusIcon(status: todo.status, compact: compact),
        ),
        SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
        Expanded(
          child: Text(
            todo.content,
            style:
                (compact
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(
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
  const _TodoStatusIcon({required this.status, required this.compact});

  final String status;
  final bool compact;

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

    return Icon(icon, size: compact ? 16 : 18, color: color);
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
      height: 46,
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

class _TimelineMessage extends StatefulWidget {
  const _TimelineMessage({
    required this.currentSessionId,
    required this.message,
    required this.compact,
    required this.searchTerms,
    required this.searchMatched,
    required this.searchActive,
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
  final bool compact;
  final List<String> searchTerms;
  final bool searchMatched;
  final bool searchActive;
  final List<SessionSummary> sessions;
  final SessionSummary? selectedSession;
  final ConfigSnapshot? configSnapshot;
  final bool shellToolDefaultExpanded;
  final bool timelineProgressDetailsVisible;
  final Future<void> Function(ChatMessage message) onForkMessage;
  final Future<void> Function(ChatMessage message) onRevertMessage;
  final ValueChanged<String> onOpenSession;

  @override
  State<_TimelineMessage> createState() => _TimelineMessageState();
}

class _TimelineMessageState extends State<_TimelineMessage> {
  ChatMessage? _derivedMessageRef;
  bool _derivedShowProgressDetails = false;
  List<ChatPart> _cachedAttachments = const <ChatPart>[];
  String _cachedUserText = '';
  List<ChatPart> _cachedOrderedParts = const <ChatPart>[];

  @override
  void initState() {
    super.initState();
    _syncDerivedState(force: true);
  }

  @override
  void didUpdateWidget(covariant _TimelineMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.message, widget.message) ||
        oldWidget.timelineProgressDetailsVisible !=
            widget.timelineProgressDetailsVisible) {
      _syncDerivedState(force: true);
    }
  }

  void _syncDerivedState({bool force = false}) {
    if (!force &&
        identical(_derivedMessageRef, widget.message) &&
        _derivedShowProgressDetails == widget.timelineProgressDetailsVisible) {
      return;
    }
    _derivedMessageRef = widget.message;
    _derivedShowProgressDetails = widget.timelineProgressDetailsVisible;

    if (widget.message.info.role == 'user') {
      _cachedAttachments = widget.message.parts
          .where(_isAttachmentFilePart)
          .toList(growable: false);
      _cachedUserText = _messageBody(widget.message);
      _cachedOrderedParts = const <ChatPart>[];
      return;
    }

    _cachedAttachments = const <ChatPart>[];
    _cachedUserText = '';
    _cachedOrderedParts = _orderedTimelineParts(
      widget.message,
      showProgressDetails: widget.timelineProgressDetailsVisible,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.info.role == 'user';
    if (isUser) {
      Widget child = _UserTimelineMessage(
        message: widget.message,
        text: _cachedUserText,
        compact: widget.compact,
        attachments: _cachedAttachments,
        searchTerms: widget.searchTerms,
        searchMatched: widget.searchMatched,
        searchActive: widget.searchActive,
        configSnapshot: widget.configSnapshot,
        selectedSession: widget.selectedSession,
        onForkMessage: widget.onForkMessage,
        onRevertMessage: widget.onRevertMessage,
      );
      if (!widget.searchMatched) {
        return child;
      }
      if (widget.searchActive) {
        child = KeyedSubtree(
          key: ValueKey<String>(
            'timeline-search-active-${widget.message.info.id}',
          ),
          child: child,
        );
      }
      return KeyedSubtree(
        key: ValueKey<String>(
          'timeline-search-match-${widget.message.info.id}',
        ),
        child: child,
      );
    }

    final timelineItems = <Widget>[];
    final messageIsActive = _messageIsActive(widget.message);
    for (var index = 0; index < _cachedOrderedParts.length; index += 1) {
      final part = _cachedOrderedParts[index];
      if (_isContextGroupToolPart(part)) {
        final contextParts = <ChatPart>[part];
        while (index + 1 < _cachedOrderedParts.length &&
            _isContextGroupToolPart(_cachedOrderedParts[index + 1])) {
          index += 1;
          contextParts.add(_cachedOrderedParts[index]);
        }
        timelineItems.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: widget.compact ? AppSpacing.sm : AppSpacing.md,
            ),
            child: _TimelineExploredContextPart(
              parts: contextParts,
              searchTerms: widget.searchTerms,
              searchActive: widget.searchActive,
            ),
          ),
        );
        continue;
      }
      timelineItems.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: widget.compact ? AppSpacing.sm : AppSpacing.md,
          ),
          child: _TimelinePart(
            currentSessionId: widget.currentSessionId,
            part: part,
            sessions: widget.sessions,
            shellToolDefaultExpanded: widget.shellToolDefaultExpanded,
            textStreamingActive: messageIsActive,
            searchTerms: widget.searchTerms,
            searchActive: widget.searchActive,
            shimmerActive: _activityPartShimmerActive(
              part,
              messageIsActive: messageIsActive,
            ),
            onOpenSession: widget.onOpenSession,
          ),
        ),
      );
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: timelineItems,
    );
    if (!widget.searchMatched) {
      return content;
    }
    Widget child = _TimelineSearchFrame(
      key: ValueKey<String>('timeline-search-match-${widget.message.info.id}'),
      compact: widget.compact,
      active: widget.searchActive,
      child: content,
    );
    if (widget.searchActive) {
      child = KeyedSubtree(
        key: ValueKey<String>(
          'timeline-search-active-${widget.message.info.id}',
        ),
        child: child,
      );
    }
    return child;
  }
}

class _TimelineSearchFrame extends StatelessWidget {
  const _TimelineSearchFrame({
    required this.compact,
    required this.active,
    required this.child,
    super.key,
  });

  final bool compact;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: active ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        border: Border.all(
          color: accent.withValues(alpha: active ? 0.46 : 0.2),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: active ? 0.16 : 0.08),
            blurRadius: active ? 18 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _UserTimelineMessage extends StatefulWidget {
  const _UserTimelineMessage({
    required this.message,
    required this.text,
    required this.compact,
    required this.attachments,
    required this.searchTerms,
    required this.searchMatched,
    required this.searchActive,
    required this.configSnapshot,
    required this.selectedSession,
    required this.onForkMessage,
    required this.onRevertMessage,
  });

  final ChatMessage message;
  final String text;
  final bool compact;
  final List<ChatPart> attachments;
  final List<String> searchTerms;
  final bool searchMatched;
  final bool searchActive;
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
    showAppSnackBar(
      context,
      message: 'Message copied.',
      tone: AppSnackBarTone.success,
    );
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
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final searchAccent = theme.colorScheme.primary;
    final hasText = widget.text.trim().isNotEmpty;
    final hasActions = _canCopy || _canFork || _canRevert;
    final matched = widget.searchMatched;
    final active = widget.searchActive;
    final bubbleColor = matched
        ? Color.alphaBlend(
            searchAccent.withValues(alpha: active ? 0.12 : 0.07),
            surfaces.panelRaised,
          )
        : surfaces.panelRaised;
    final borderColor = matched
        ? searchAccent.withValues(alpha: active ? 0.5 : 0.26)
        : surfaces.lineSoft;
    final boxShadow = matched
        ? <BoxShadow>[
            BoxShadow(
              color: searchAccent.withValues(alpha: active ? 0.18 : 0.1),
              blurRadius: active ? 20 : 14,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

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
                  padding: EdgeInsets.all(
                    widget.compact ? AppSpacing.sm : AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(
                      widget.compact ? 16 : 18,
                    ),
                    border: Border.all(color: borderColor),
                    boxShadow: boxShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.attachments.isNotEmpty)
                        _UserMessageAttachmentGrid(
                          compact: widget.compact,
                          attachments: widget.attachments,
                          searchTerms: widget.searchTerms,
                          searchActive: widget.searchActive,
                        ),
                      if (widget.attachments.isNotEmpty && hasText)
                        SizedBox(
                          height: widget.compact
                              ? AppSpacing.sm
                              : AppSpacing.md,
                        ),
                      if (hasText)
                        _InlineCodeText(
                          text: widget.text,
                          searchTerms: widget.searchTerms,
                          searchActive: widget.searchActive,
                        ),
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
    required this.searchTerms,
    required this.searchActive,
    required this.shimmerActive,
    required this.onOpenSession,
  });

  final String? currentSessionId;
  final ChatPart part;
  final List<SessionSummary> sessions;
  final bool shellToolDefaultExpanded;
  final bool textStreamingActive;
  final List<String> searchTerms;
  final bool searchActive;
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
        searchTerms: searchTerms,
        searchActive: searchActive,
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
        searchTerms: searchTerms,
        searchActive: searchActive,
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
        searchTerms: searchTerms,
        searchActive: searchActive,
        summaryTapKey: linkedSession == null
            ? null
            : ValueKey<String>('timeline-activity-link-${part.id}'),
        onSummaryTap: linkedSession == null
            ? null
            : () => onOpenSession(linkedSession.sessionId),
      );
    }
    return _StructuredTextBlock(
      cacheKey: part.id,
      text: body,
      searchTerms: searchTerms,
      searchActive: searchActive,
    );
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
  const _UserMessageAttachmentGrid({
    required this.attachments,
    required this.compact,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final List<ChatPart> attachments;
  final bool compact;
  final List<String> searchTerms;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? AppSpacing.xs : AppSpacing.sm,
      runSpacing: compact ? AppSpacing.xs : AppSpacing.sm,
      children: attachments
          .map(
            (part) => _UserMessageAttachmentTile(
              part: part,
              compact: compact,
              searchTerms: searchTerms,
              searchActive: searchActive,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _UserMessageAttachmentTile extends StatelessWidget {
  const _UserMessageAttachmentTile({
    required this.part,
    this.compact = false,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final ChatPart part;
  final bool compact;
  final List<String> searchTerms;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final url = _attachmentPartUrl(part);
    final mime = _attachmentPartMime(part) ?? 'application/octet-stream';
    final filename = _attachmentPartFilename(part);
    final previewBytes = url == null ? null : _attachmentDataBytes(url);
    return Container(
      width: compact
          ? (mime.startsWith('image/') ? 148 : 204)
          : (mime.startsWith('image/') ? 164 : 220),
      padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
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
                height: compact ? 88 : 100,
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
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          Text.rich(
            TextSpan(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              children: _buildSearchHighlightedTextSpans(
                text: filename,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                terms: searchTerms,
                highlightColor: _searchTextHighlightColor(
                  context,
                  active: searchActive,
                ),
              ),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
    this.searchTerms = const <String>[],
    this.searchActive = false,
    super.key,
  });

  final String partId;
  final String title;
  final String? subtitle;
  final String body;
  final bool shimmerActive;
  final bool defaultExpanded;
  final List<String> searchTerms;
  final bool searchActive;

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
              padding: _timelineExpandableHeaderPadding,
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
                          text: TextSpan(
                            style: titleStyle,
                            children: _buildSearchHighlightedTextSpans(
                              text: widget.title,
                              style: titleStyle,
                              terms: widget.searchTerms,
                              highlightColor: _searchTextHighlightColor(
                                context,
                                active: widget.searchActive,
                              ),
                            ),
                          ),
                        ),
                        if (hasSubtitle)
                          Text.rich(
                            TextSpan(
                              style: subtitleStyle,
                              children: _buildSearchHighlightedTextSpans(
                                text: subtitle,
                                style: subtitleStyle,
                                terms: widget.searchTerms,
                                highlightColor: _searchTextHighlightColor(
                                  context,
                                  active: widget.searchActive,
                                ),
                              ),
                            ),
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
                    margin: _timelineExpandableBodyMargin,
                    decoration: BoxDecoration(
                      color: surfaces.panelMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: Stack(
                      children: <Widget>[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: _timelineShellBodyPadding,
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 14,
                                height: 1.5,
                                color: theme.colorScheme.onSurface,
                              ),
                              children: _buildSearchHighlightedTextSpans(
                                text: widget.body,
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: theme.colorScheme.onSurface,
                                ),
                                terms: widget.searchTerms,
                                highlightColor: _searchTextHighlightColor(
                                  context,
                                  active: widget.searchActive,
                                  code: true,
                                ),
                              ),
                            ),
                            key: ValueKey<String>(
                              'timeline-shell-body-${widget.partId}',
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
    this.searchTerms = const <String>[],
    this.searchActive = false,
    this.summaryTapKey,
    this.onSummaryTap,
    this.shimmerKey,
    super.key,
  });

  final String title;
  final String summary;
  final String body;
  final bool shimmerActive;
  final List<String> searchTerms;
  final bool searchActive;
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
            style: titleStyle,
            children: <InlineSpan>[
              ..._buildSearchHighlightedTextSpans(
                text: widget.title,
                style: titleStyle,
                terms: widget.searchTerms,
                highlightColor: _searchTextHighlightColor(
                  context,
                  active: widget.searchActive,
                ),
              ),
              if (widget.summary.isNotEmpty)
                ..._buildSearchHighlightedTextSpans(
                  text: ' ${widget.summary}',
                  style: summaryStyle,
                  terms: widget.searchTerms,
                  highlightColor: _searchTextHighlightColor(
                    context,
                    active: widget.searchActive,
                  ),
                ),
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
              child: Text.rich(
                TextSpan(
                  style: summaryLinkStyle,
                  children: _buildSearchHighlightedTextSpans(
                    text: widget.summary,
                    style: summaryLinkStyle,
                    terms: widget.searchTerms,
                    highlightColor: _searchTextHighlightColor(
                      context,
                      active: widget.searchActive,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final headerContent = Padding(
      padding: _timelineExpandableHeaderPadding,
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
                    margin: _timelineExpandableBodyMargin,
                    padding: _timelineExpandableBodyPadding,
                    decoration: BoxDecoration(
                      color: surfaces.panelMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: surfaces.lineSoft),
                    ),
                    child: _StructuredTextBlock(
                      text: widget.body,
                      searchTerms: widget.searchTerms,
                      searchActive: widget.searchActive,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TimelineExploredContextPart extends StatefulWidget {
  const _TimelineExploredContextPart({
    required this.parts,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final List<ChatPart> parts;
  final List<String> searchTerms;
  final bool searchActive;

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
              padding: _timelineExpandableHeaderPadding,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ShimmeringRichText(
                      key: ValueKey<String>(
                        'timeline-explored-context-shimmer-${widget.parts.first.id}',
                      ),
                      active: pending,
                      text: TextSpan(
                        style: titleStyle,
                        children: _buildSearchHighlightedTextSpans(
                          text: summaryText.isEmpty
                              ? label
                              : '$label $summaryText',
                          style: titleStyle,
                          terms: widget.searchTerms,
                          highlightColor: _searchTextHighlightColor(
                            context,
                            active: widget.searchActive,
                          ),
                        ),
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
                    padding: _timelineExploredContextDetailPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.parts
                          .map(
                            (part) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: detailStyle,
                                  children: _buildSearchHighlightedTextSpans(
                                    text: _contextToolDetailLine(part),
                                    style: detailStyle,
                                    terms: widget.searchTerms,
                                    highlightColor: _searchTextHighlightColor(
                                      context,
                                      active: widget.searchActive,
                                    ),
                                  ),
                                ),
                                key: ValueKey<String>(
                                  'timeline-explored-context-detail-${part.id}',
                                ),
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

const EdgeInsets _timelineExpandableHeaderPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.xs,
  vertical: AppSpacing.xxs,
);

const EdgeInsets _timelineExpandableBodyMargin = EdgeInsets.only(
  top: AppSpacing.xs,
);

const EdgeInsets _timelineExpandableBodyPadding = EdgeInsets.fromLTRB(
  AppSpacing.sm,
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
);

const EdgeInsets _timelineShellBodyPadding = EdgeInsets.fromLTRB(
  AppSpacing.sm,
  AppSpacing.md,
  56,
  AppSpacing.md,
);

const EdgeInsets _timelineExploredContextDetailPadding = EdgeInsets.only(
  top: AppSpacing.xs,
);

class _ShimmeringRichText extends StatefulWidget {
  const _ShimmeringRichText({
    required this.text,
    required this.active,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final InlineSpan text;
  final bool active;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<_ShimmeringRichText> createState() => _ShimmeringRichTextState();
}

class _ShimmeringRichTextState extends State<_ShimmeringRichText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
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
    final child = Text.rich(
      widget.text,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
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
            final shimmerBounds = Rect.fromLTWH(
              0,
              0,
              bounds.width <= 0 ? 1 : bounds.width,
              bounds.height <= 0 ? 1 : bounds.height,
            );
            return _shimmerHighlightGradient(
              shimmerBounds,
              _controller.value,
            ).createShader(shimmerBounds);
          },
          child: child,
        );
      },
    );
  }
}

LinearGradient _shimmerHighlightGradient(
  Rect bounds,
  double progress, {
  Color highlightColor = Colors.white,
}) {
  final width = bounds.width <= 0 ? 1.0 : bounds.width;
  final bandWidth = _shimmerHighlightWidth(width);
  final start = ui.lerpDouble(-bandWidth, width, progress) ?? -bandWidth;
  final end = start + bandWidth;
  final safeWidth = width <= 0 ? 1.0 : width;
  final left = (start / safeWidth).clamp(0.0, 1.0);
  final right = (end / safeWidth).clamp(0.0, 1.0);
  final center = ((start + end) / 2 / safeWidth).clamp(0.0, 1.0);
  final innerLeft = (ui.lerpDouble(left, center, 0.34) ?? center).clamp(
    0.0,
    1.0,
  );
  final innerRight = (ui.lerpDouble(center, right, 0.34) ?? center).clamp(
    0.0,
    1.0,
  );

  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      Colors.transparent,
      Colors.transparent,
      highlightColor.withValues(alpha: 0.06),
      highlightColor.withValues(alpha: 0.94),
      highlightColor.withValues(alpha: 0.06),
      Colors.transparent,
      Colors.transparent,
    ],
    stops: <double>[0, left, innerLeft, center, innerRight, right, 1],
  );
}

double _shimmerHighlightWidth(double width) {
  return (width * 0.14).clamp(28.0, 64.0);
}

enum _ShimmerBoxStyle { line, surface }

LinearGradient _shimmerSurfaceGradient(
  Rect bounds,
  double progress, {
  Color highlightColor = Colors.white,
}) {
  final width = bounds.width <= 0 ? 1.0 : bounds.width;
  final bandWidth = (width * 0.58).clamp(96.0, 240.0);
  final start = ui.lerpDouble(-bandWidth, width, progress) ?? -bandWidth;
  final end = start + bandWidth;
  final safeWidth = width <= 0 ? 1.0 : width;
  final left = (start / safeWidth).clamp(0.0, 1.0);
  final right = (end / safeWidth).clamp(0.0, 1.0);
  final center = ((start + end) / 2 / safeWidth).clamp(0.0, 1.0);
  final innerLeft = (ui.lerpDouble(left, center, 0.42) ?? center).clamp(
    0.0,
    1.0,
  );
  final innerRight = (ui.lerpDouble(center, right, 0.42) ?? center).clamp(
    0.0,
    1.0,
  );

  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      Colors.transparent,
      highlightColor.withValues(alpha: 0.04),
      highlightColor.withValues(alpha: 0.1),
      highlightColor.withValues(alpha: 0.28),
      highlightColor.withValues(alpha: 0.1),
      highlightColor.withValues(alpha: 0.04),
      Colors.transparent,
    ],
    stops: <double>[0, left, innerLeft, center, innerRight, right, 1],
  );
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.height,
    required this.widthFactor,
    required this.borderRadius,
    this.style = _ShimmerBoxStyle.line,
  });

  final double height;
  final double widthFactor;
  final double borderRadius;
  final _ShimmerBoxStyle style;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: switch (widget.style) {
        _ShimmerBoxStyle.line => 3000,
        _ShimmerBoxStyle.surface => 1800,
      },
    ),
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
        return SizedBox(
          width: width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaces.panelRaised,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                ),
                builder: (context, shimmerChild) {
                  return ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      final shimmerBounds = Rect.fromLTWH(
                        0,
                        0,
                        bounds.width <= 0 ? 1 : bounds.width,
                        bounds.height <= 0 ? 1 : bounds.height,
                      );
                      final gradient = switch (widget.style) {
                        _ShimmerBoxStyle.line => _shimmerHighlightGradient(
                          shimmerBounds,
                          _controller.value,
                        ),
                        _ShimmerBoxStyle.surface => _shimmerSurfaceGradient(
                          shimmerBounds,
                          _controller.value,
                        ),
                      };
                      return gradient.createShader(shimmerBounds);
                    },
                    child: shimmerChild,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

final _structuredTextParseCache =
    _LruCache<String, List<_StructuredContentBlockData>>(maximumSize: 256);
final _paragraphSplitCache = _LruCache<String, List<String>>(maximumSize: 512);
final _inlineCodeSegmentCache = _LruCache<String, List<_InlineCodeSegment>>(
  maximumSize: 1024,
);
final _attachmentPreviewBytesCache = _LruCache<String, Uint8List?>(
  maximumSize: 128,
);

sealed class _StructuredContentBlockData {
  const _StructuredContentBlockData();
}

class _StructuredParagraphData extends _StructuredContentBlockData {
  const _StructuredParagraphData({required this.text});

  final String text;
}

class _StructuredCodeFenceData extends _StructuredContentBlockData {
  const _StructuredCodeFenceData({required this.code, this.language});

  final String code;
  final String? language;
}

class _InlineCodeSegment {
  const _InlineCodeSegment({required this.text, required this.code});

  final String text;
  final bool code;
}

List<_StructuredContentBlockData> _parseStructuredTextBlocks(String text) {
  final cached = _structuredTextParseCache.get(text);
  if (cached != null) {
    return cached;
  }

  final blocks = <_StructuredContentBlockData>[];
  final fencePattern = RegExp(r'```([a-zA-Z0-9_-]*)\n([\s\S]*?)```');
  var cursor = 0;
  for (final match in fencePattern.allMatches(text)) {
    final before = text.substring(cursor, match.start).trim();
    if (before.isNotEmpty) {
      blocks.add(_StructuredParagraphData(text: before));
    }
    blocks.add(
      _StructuredCodeFenceData(
        language: match.group(1)?.trim(),
        code: (match.group(2) ?? '').trimRight(),
      ),
    );
    cursor = match.end;
  }

  final tail = text.substring(cursor).trim();
  if (tail.isNotEmpty) {
    blocks.add(_StructuredParagraphData(text: tail));
  }

  final resolved = List<_StructuredContentBlockData>.unmodifiable(
    blocks.isEmpty
        ? <_StructuredContentBlockData>[_StructuredParagraphData(text: text)]
        : blocks,
  );
  _structuredTextParseCache.set(text, resolved);
  return resolved;
}

List<String> _splitStructuredParagraphs(String text) {
  final cached = _paragraphSplitCache.get(text);
  if (cached != null) {
    return cached;
  }

  final paragraphs = List<String>.unmodifiable(
    text
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false),
  );
  _paragraphSplitCache.set(text, paragraphs);
  return paragraphs;
}

List<_InlineCodeSegment> _parseInlineCodeSegments(String text) {
  final cached = _inlineCodeSegmentCache.get(text);
  if (cached != null) {
    return cached;
  }

  final codePattern = RegExp(r'`([^`]+)`');
  final segments = <_InlineCodeSegment>[];
  var cursor = 0;
  for (final match in codePattern.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(
        _InlineCodeSegment(
          text: text.substring(cursor, match.start),
          code: false,
        ),
      );
    }
    segments.add(_InlineCodeSegment(text: match.group(1) ?? '', code: true));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(_InlineCodeSegment(text: text.substring(cursor), code: false));
  }

  final resolved = List<_InlineCodeSegment>.unmodifiable(segments);
  _inlineCodeSegmentCache.set(text, resolved);
  return resolved;
}

class _SearchHighlightRange {
  const _SearchHighlightRange({required this.start, required this.end});

  final int start;
  final int end;
}

int _searchTermsSignature(List<String> terms) {
  if (terms.isEmpty) {
    return 0;
  }
  return Object.hash(terms.length, Object.hashAll(terms));
}

Color _searchTextHighlightColor(
  BuildContext context, {
  required bool active,
  bool code = false,
}) {
  final accent = Theme.of(context).colorScheme.primary;
  return accent.withValues(
    alpha: active ? (code ? 0.34 : 0.28) : (code ? 0.24 : 0.18),
  );
}

List<_SearchHighlightRange> _searchHighlightRanges(
  String text,
  List<String> terms,
) {
  if (text.isEmpty || terms.isEmpty) {
    return const <_SearchHighlightRange>[];
  }
  final normalizedText = text.toLowerCase();
  final ranges = <_SearchHighlightRange>[];
  for (final term in terms) {
    final normalizedTerm = term.trim().toLowerCase();
    if (normalizedTerm.isEmpty) {
      continue;
    }
    var searchIndex = 0;
    while (searchIndex < normalizedText.length) {
      final matchIndex = normalizedText.indexOf(normalizedTerm, searchIndex);
      if (matchIndex < 0) {
        break;
      }
      ranges.add(
        _SearchHighlightRange(
          start: matchIndex,
          end: matchIndex + normalizedTerm.length,
        ),
      );
      searchIndex = matchIndex + normalizedTerm.length;
    }
  }
  if (ranges.isEmpty) {
    return const <_SearchHighlightRange>[];
  }
  ranges.sort((left, right) => left.start.compareTo(right.start));
  final merged = <_SearchHighlightRange>[ranges.first];
  for (var index = 1; index < ranges.length; index += 1) {
    final current = ranges[index];
    final last = merged.last;
    if (current.start <= last.end) {
      merged[merged.length - 1] = _SearchHighlightRange(
        start: last.start,
        end: math.max(last.end, current.end),
      );
      continue;
    }
    merged.add(current);
  }
  return List<_SearchHighlightRange>.unmodifiable(merged);
}

List<InlineSpan> _buildSearchHighlightedTextSpans({
  required String text,
  required TextStyle? style,
  required List<String> terms,
  required Color highlightColor,
}) {
  if (text.isEmpty) {
    return const <InlineSpan>[TextSpan(text: '')];
  }
  final ranges = _searchHighlightRanges(text, terms);
  if (ranges.isEmpty) {
    return <InlineSpan>[TextSpan(text: text, style: style)];
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final range in ranges) {
    if (range.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, range.start), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(range.start, range.end),
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: highlightColor,
        ),
      ),
    );
    cursor = range.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: style));
  }
  return spans;
}

List<InlineSpan> _highlightInlineSpansForSearch({
  required List<InlineSpan> spans,
  required List<String> terms,
  required Color highlightColor,
  TextStyle? inheritedStyle,
}) {
  if (terms.isEmpty) {
    return spans;
  }
  final highlighted = <InlineSpan>[];
  for (final span in spans) {
    if (span is! TextSpan) {
      highlighted.add(span);
      continue;
    }
    highlighted.addAll(
      _highlightTextSpanForSearch(
        span,
        terms: terms,
        highlightColor: highlightColor,
        inheritedStyle: inheritedStyle,
      ),
    );
  }
  return highlighted;
}

List<InlineSpan> _highlightTextSpanForSearch(
  TextSpan span, {
  required List<String> terms,
  required Color highlightColor,
  TextStyle? inheritedStyle,
}) {
  final effectiveStyle = inheritedStyle?.merge(span.style) ?? span.style;
  final highlighted = <InlineSpan>[];
  final text = span.text;
  if (text != null && text.isNotEmpty) {
    highlighted.addAll(
      _buildSearchHighlightedTextSpans(
        text: text,
        style: effectiveStyle,
        terms: terms,
        highlightColor: highlightColor,
      ),
    );
  }
  final children = span.children;
  if (children != null && children.isNotEmpty) {
    highlighted.addAll(
      _highlightInlineSpansForSearch(
        spans: children,
        terms: terms,
        highlightColor: highlightColor,
        inheritedStyle: effectiveStyle,
      ),
    );
  }
  return highlighted;
}

const int _structuredTextBlockCacheLimit = 128;
final Map<String, List<_StructuredContentBlockData>>
_structuredTextBlockCache = <String, List<_StructuredContentBlockData>>{};

List<_StructuredContentBlockData> _structuredTextBlocksFor({
  String? cacheKey,
  required String text,
}) {
  final resolvedCacheKey =
      '${cacheKey ?? '_structured-text'}:${text.length}:${text.hashCode}';
  final cached = _structuredTextBlockCache.remove(resolvedCacheKey);
  if (cached != null) {
    _structuredTextBlockCache[resolvedCacheKey] = cached;
    return cached;
  }

  final blocks = _parseStructuredTextBlocks(text);
  if (_structuredTextBlockCache.length >= _structuredTextBlockCacheLimit) {
    _structuredTextBlockCache.remove(_structuredTextBlockCache.keys.first);
  }
  _structuredTextBlockCache[resolvedCacheKey] = blocks;
  return blocks;
}

class _StructuredTextBlock extends StatelessWidget {
  const _StructuredTextBlock({
    this.cacheKey,
    required this.text,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final String? cacheKey;
  final String text;
  final List<String> searchTerms;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    final blocks = _structuredTextBlocksFor(cacheKey: cacheKey, text: text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: switch (block) {
                _StructuredParagraphData(:final text) => _ParagraphBlock(
                  text: text,
                  searchTerms: searchTerms,
                  searchActive: searchActive,
                ),
                _StructuredCodeFenceData(:final code, :final language) =>
                  _StructuredCodeFenceBlock(
                    language: language,
                    code: code,
                    searchTerms: searchTerms,
                    searchActive: searchActive,
                  ),
              },
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StructuredCodeFenceBlock extends StatefulWidget {
  const _StructuredCodeFenceBlock({
    required this.code,
    this.language,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final String code;
  final String? language;
  final List<String> searchTerms;
  final bool searchActive;

  @override
  State<_StructuredCodeFenceBlock> createState() =>
      _StructuredCodeFenceBlockState();
}

class _StructuredCodeFenceBlockState extends State<_StructuredCodeFenceBlock> {
  Timer? _copiedTimer;
  bool _copied = false;
  String? _cachedHighlightCode;
  String? _cachedHighlightLanguage;
  bool? _cachedHighlightEnabled;
  int? _cachedHighlightThemeSignature;
  int? _cachedSearchTermsSignature;
  bool? _cachedSearchActive;
  List<InlineSpan>? _cachedHighlightedSpans;

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
    showAppSnackBar(
      context,
      message: 'Code block copied.',
      tone: AppSnackBarTone.success,
    );
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
    final themeSignature = _syntaxThemeSignature(theme, surfaces);
    final searchTermsSignature = _searchTermsSignature(widget.searchTerms);
    final searchHighlightColor = _searchTextHighlightColor(
      context,
      active: widget.searchActive,
      code: true,
    );
    List<InlineSpan>? highlightedSpans;
    if (canHighlight) {
      if (_cachedHighlightedSpans == null ||
          _cachedHighlightCode != widget.code ||
          _cachedHighlightLanguage != language ||
          _cachedHighlightEnabled != highlightEnabled ||
          _cachedHighlightThemeSignature != themeSignature ||
          _cachedSearchTermsSignature != searchTermsSignature ||
          _cachedSearchActive != widget.searchActive) {
        final syntaxSpans = _buildHighlightedCodeBlockSpans(
          code: widget.code,
          language: language,
          syntaxTheme: syntaxTheme,
        );
        _cachedHighlightedSpans = _highlightInlineSpansForSearch(
          spans: syntaxSpans,
          terms: widget.searchTerms,
          highlightColor: searchHighlightColor,
        );
        _cachedHighlightCode = widget.code;
        _cachedHighlightLanguage = language;
        _cachedHighlightEnabled = highlightEnabled;
        _cachedHighlightThemeSignature = themeSignature;
        _cachedSearchTermsSignature = searchTermsSignature;
        _cachedSearchActive = widget.searchActive;
      }
      highlightedSpans = _cachedHighlightedSpans;
    }

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
                    TextSpan(
                      style: syntaxTheme.base,
                      children: highlightedSpans,
                    ),
                    key: ValueKey<String>(
                      'timeline-code-content-highlighted-$languageKey',
                    ),
                  )
                : SelectableText.rich(
                    TextSpan(
                      style: syntaxTheme.base,
                      children: _buildSearchHighlightedTextSpans(
                        text: widget.code,
                        style: syntaxTheme.base,
                        terms: widget.searchTerms,
                        highlightColor: searchHighlightColor,
                      ),
                    ),
                    key: ValueKey<String>(
                      'timeline-code-content-plain-$languageKey',
                    ),
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
    this.searchTerms = const <String>[],
    this.searchActive = false,
    super.key,
  });

  final String partId;
  final String text;
  final bool animate;
  final List<String> searchTerms;
  final bool searchActive;

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
      return _StructuredTextBlock(
        cacheKey: widget.partId,
        text: widget.text,
        searchTerms: widget.searchTerms,
        searchActive: widget.searchActive,
      );
    }

    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.8);
    final searchHighlightColor = _searchTextHighlightColor(
      context,
      active: widget.searchActive,
    );
    final transparentStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: Colors.transparent,
    );
    final spans = <InlineSpan>[];
    if (_sequence.leadingWhitespace.isNotEmpty) {
      spans.addAll(
        _buildSearchHighlightedTextSpans(
          text: _sequence.leadingWhitespace,
          style: baseStyle,
          terms: widget.searchTerms,
          highlightColor: searchHighlightColor,
        ),
      );
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
              child: Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: _buildSearchHighlightedTextSpans(
                    text: chunk.text,
                    style: baseStyle,
                    terms: widget.searchTerms,
                    highlightColor: searchHighlightColor,
                  ),
                ),
                key: ValueKey<String>(
                  'streaming-text-chunk-${widget.partId}-$index',
                ),
              ),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
            ),
          ),
        );
      } else {
        spans.addAll(
          _buildSearchHighlightedTextSpans(
            text: chunk.text,
            style: baseStyle,
            terms: widget.searchTerms,
            highlightColor: searchHighlightColor,
          ),
        );
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
  const _ParagraphBlock({
    required this.text,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final String text;
  final List<String> searchTerms;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    final paragraphs = _splitStructuredParagraphs(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs
          .map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _InlineCodeText(
                text: paragraph,
                searchTerms: searchTerms,
                searchActive: searchActive,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _InlineCodeText extends StatelessWidget {
  const _InlineCodeText({
    required this.text,
    this.searchTerms = const <String>[],
    this.searchActive = false,
  });

  final String text;
  final List<String> searchTerms;
  final bool searchActive;

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
    final searchHighlightColor = _searchTextHighlightColor(
      context,
      active: searchActive,
    );
    final spans = <InlineSpan>[];
    for (final segment in _parseInlineCodeSegments(text)) {
      if (!segment.code) {
        spans.addAll(
          _buildSearchHighlightedTextSpans(
            text: segment.text,
            style: baseStyle,
            terms: searchTerms,
            highlightColor: searchHighlightColor,
          ),
        );
        continue;
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
            child: Text.rich(
              TextSpan(
                style: codeStyle,
                children: _buildSearchHighlightedTextSpans(
                  text: segment.text,
                  style: codeStyle,
                  terms: searchTerms,
                  highlightColor: _searchTextHighlightColor(
                    context,
                    active: searchActive,
                    code: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.onLongPress,
    this.compact = false,
    this.filled = false,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;
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
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      child: Container(
        width: compact ? 36 : 40,
        height: compact ? 36 : 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(color: filled ? color : surfaces.lineSoft),
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: compact ? 14 : 16,
                  height: compact ? 14 : 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              : Icon(icon, size: compact ? 16 : 18, color: foreground),
        ),
      ),
    );
  }
}

class _ComposerQueuedPromptDock extends StatelessWidget {
  const _ComposerQueuedPromptDock({
    required this.compact,
    required this.queuedPrompts,
    required this.failedQueuedPromptId,
    required this.sendingQueuedPromptId,
    required this.busy,
    required this.onEditQueuedPrompt,
    required this.onDeleteQueuedPrompt,
    required this.onSendQueuedPromptNow,
  });

  final bool compact;
  final List<WorkspaceQueuedPrompt> queuedPrompts;
  final String? failedQueuedPromptId;
  final String? sendingQueuedPromptId;
  final bool busy;
  final Future<void> Function(String queuedPromptId) onEditQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onDeleteQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onSendQueuedPromptNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final sessionSending = sendingQueuedPromptId != null;
    return Container(
      key: const ValueKey<String>('composer-queued-dock'),
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaces.panelMuted,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  queuedPrompts.length == 1
                      ? '1 queued follow-up'
                      : '${queuedPrompts.length} queued follow-ups',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (sessionSending)
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: compact ? 14 : 16,
                      height: compact ? 14 : 16,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Sending',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (
            var index = 0;
            index < queuedPrompts.length;
            index += 1
          ) ...<Widget>[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _ComposerQueuedPromptRow(
              compact: compact,
              queuedPrompt: queuedPrompts[index],
              failed: failedQueuedPromptId == queuedPrompts[index].id,
              sending: sendingQueuedPromptId == queuedPrompts[index].id,
              actionsDisabled: sessionSending,
              busy: busy,
              onEditQueuedPrompt: onEditQueuedPrompt,
              onDeleteQueuedPrompt: onDeleteQueuedPrompt,
              onSendQueuedPromptNow: onSendQueuedPromptNow,
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerQueuedPromptRow extends StatelessWidget {
  const _ComposerQueuedPromptRow({
    required this.compact,
    required this.queuedPrompt,
    required this.failed,
    required this.sending,
    required this.actionsDisabled,
    required this.busy,
    required this.onEditQueuedPrompt,
    required this.onDeleteQueuedPrompt,
    required this.onSendQueuedPromptNow,
  });

  final bool compact;
  final WorkspaceQueuedPrompt queuedPrompt;
  final bool failed;
  final bool sending;
  final bool actionsDisabled;
  final bool busy;
  final Future<void> Function(String queuedPromptId) onEditQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onDeleteQueuedPrompt;
  final Future<void> Function(String queuedPromptId) onSendQueuedPromptNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final colorScheme = theme.colorScheme;
    final muted = failed
        ? colorScheme.error.withValues(alpha: 0.9)
        : surfaces.muted;
    return Container(
      key: ValueKey<String>('composer-queued-item-${queuedPrompt.id}'),
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: failed
            ? colorScheme.error.withValues(alpha: 0.08)
            : surfaces.panel,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(
          color: failed
              ? colorScheme.error.withValues(alpha: 0.4)
              : surfaces.lineSoft,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  queuedPrompt.previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  failed
                      ? 'Could not send automatically. Edit, delete, or send again.'
                      : busy
                      ? 'Waiting behind the current run.'
                      : 'Will send as soon as the session is ready.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (sending)
            SizedBox(
              width: compact ? 18 : 20,
              height: compact ? 18 : 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  key: ValueKey<String>(
                    'composer-queued-send-button-${queuedPrompt.id}',
                  ),
                  onPressed: actionsDisabled
                      ? null
                      : () {
                          unawaited(onSendQueuedPromptNow(queuedPrompt.id));
                        },
                  child: Text(busy ? 'Steer' : 'Send'),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'composer-queued-edit-button-${queuedPrompt.id}',
                  ),
                  onPressed: actionsDisabled
                      ? null
                      : () {
                          unawaited(onEditQueuedPrompt(queuedPrompt.id));
                        },
                  tooltip: 'Edit queued message',
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'composer-queued-delete-button-${queuedPrompt.id}',
                  ),
                  onPressed: actionsDisabled
                      ? null
                      : () {
                          unawaited(onDeleteQueuedPrompt(queuedPrompt.id));
                        },
                  tooltip: 'Delete queued message',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ComposerSubmitModeSheet extends StatelessWidget {
  const _ComposerSubmitModeSheet({
    required this.defaultMode,
    required this.busy,
  });

  final WorkspaceFollowupMode defaultMode;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final defaultLabel = switch (defaultMode) {
      WorkspaceFollowupMode.queue => 'Queue',
      WorkspaceFollowupMode.steer => 'Steer',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Send this message',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Default while busy: $defaultLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: surfaces.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ComposerSubmitModeTile(
                  key: const ValueKey<String>('composer-submit-mode-queue'),
                  title: 'Queue',
                  subtitle: busy
                      ? 'Keep this follow-up waiting and send it automatically when the current run finishes.'
                      : 'Send normally now, and keep this mode queued by default when the session is already busy.',
                  icon: Icons.schedule_send_rounded,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(WorkspacePromptDispatchMode.queue),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ComposerSubmitModeTile(
                  key: const ValueKey<String>('composer-submit-mode-steer'),
                  title: 'Steer',
                  subtitle: busy
                      ? 'Send immediately to the running agent instead of waiting in the queue.'
                      : 'Send immediately without queueing.',
                  icon: Icons.arrow_upward_rounded,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(WorkspacePromptDispatchMode.steer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerSubmitModeTile extends StatelessWidget {
  const _ComposerSubmitModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surfaces.panelMuted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                        height: 1.45,
                      ),
                    ),
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

class _ComposerSelectionPill extends StatelessWidget {
  const _ComposerSelectionPill({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 180 : 220),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
          vertical: compact ? 6 : AppSpacing.xs,
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
                style:
                    (compact
                            ? Theme.of(context).textTheme.labelMedium
                            : Theme.of(context).textTheme.bodySmall)
                        ?.copyWith(
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

bool _hasRenderableActiveAssistantMessage(
  List<ChatMessage> messages, {
  required bool showProgressDetails,
}) {
  for (final message in messages) {
    if (!_messageIsActive(message)) {
      continue;
    }
    if (_orderedTimelineParts(
      message,
      showProgressDetails: showProgressDetails,
    ).isNotEmpty) {
      return true;
    }
  }
  return false;
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

class _MessageSearchTextCacheEntry {
  const _MessageSearchTextCacheEntry({
    required this.signature,
    required this.value,
  });

  final int signature;
  final String value;
}

final LinkedHashMap<String, _MessageSearchTextCacheEntry>
_messageSearchTextCache = LinkedHashMap<String, _MessageSearchTextCacheEntry>();

List<String> _normalizedSearchTerms(String query) {
  return query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
}

bool _messageMatchesSearch(ChatMessage message, List<String> terms) {
  if (terms.isEmpty) {
    return false;
  }
  final haystack = _searchableMessageText(message);
  for (final term in terms) {
    if (!haystack.contains(term)) {
      return false;
    }
  }
  return true;
}

int _messageSearchSignature(ChatMessage message) {
  var signature = Object.hash(
    message.info.id,
    message.info.role,
    message.parts.length,
  );
  for (final part in message.parts) {
    signature = Object.hash(
      signature,
      part.id,
      part.type,
      part.tool,
      part.filename,
      _timelineStringSignature(part.text),
      _timelineStringSignature(part.metadata['summary']?.toString()),
      _timelineStringSignature(part.metadata['content']?.toString()),
      _timelineStringSignature(part.metadata['command']?.toString()),
      _timelineStringSignature(part.metadata['output']?.toString()),
      _timelineStringSignature(part.metadata['description']?.toString()),
    );
  }
  return signature;
}

String _searchableMessageText(ChatMessage message) {
  final cacheKey = message.info.id.isEmpty
      ? '${message.info.role}:${message.parts.length}'
      : message.info.id;
  final signature = _messageSearchSignature(message);
  final cached = _messageSearchTextCache[cacheKey];
  if (cached != null && cached.signature == signature) {
    return cached.value;
  }

  final fragments = <String>[];
  if (message.info.role == 'user') {
    final body = _messageBody(message).trim();
    if (body.isNotEmpty) {
      fragments.add(body);
    }
  }
  for (final part in message.parts) {
    final title = _partTitle(part).trim();
    final body = _partText(part).trim();
    final filename = _attachmentPartFilename(part).trim();
    if (part.type != 'text' && part.type != 'file' && title.isNotEmpty) {
      fragments.add(title);
    }
    if (body.isNotEmpty) {
      fragments.add(body);
    }
    if (part.type == 'file' && filename.isNotEmpty) {
      fragments.add(filename);
    }
  }
  final searchable = fragments.join('\n').toLowerCase();
  _messageSearchTextCache.remove(cacheKey);
  _messageSearchTextCache[cacheKey] = _MessageSearchTextCacheEntry(
    signature: signature,
    value: searchable,
  );
  while (_messageSearchTextCache.length > 512) {
    _messageSearchTextCache.remove(_messageSearchTextCache.keys.first);
  }
  return searchable;
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
  if (_isAlwaysHiddenTimelinePart(part)) {
    return false;
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

bool _isAlwaysHiddenTimelinePart(ChatPart part) {
  return part.type == 'step-start' || part.type == 'step-finish';
}

bool _isProgressDetailPart(ChatPart part) {
  return _isTodoWriteToolPart(part);
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
  final cached = _attachmentPreviewBytesCache.get(url);
  if (cached != null || _attachmentPreviewBytesCache.containsKey(url)) {
    return cached;
  }
  if (!url.startsWith('data:')) {
    _attachmentPreviewBytesCache.set(url, null);
    return null;
  }
  final commaIndex = url.indexOf(',');
  if (commaIndex == -1 || commaIndex == url.length - 1) {
    _attachmentPreviewBytesCache.set(url, null);
    return null;
  }
  try {
    final bytes = base64Decode(url.substring(commaIndex + 1));
    _attachmentPreviewBytesCache.set(url, bytes);
    return bytes;
  } catch (_) {
    _attachmentPreviewBytesCache.set(url, null);
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
  const _SidePanel({required this.controller, required this.onLineComment});

  final WorkspaceController controller;
  final ValueChanged<_ReviewLineCommentSubmission> onLineComment;

  @override
  Widget build(BuildContext context) {
    final tab = controller.sideTab;
    final bundle = controller.fileBundle;
    final density = _workspaceDensity(context);
    final panelPadding = density.inset(AppSpacing.md, min: AppSpacing.sm);
    final reviewCount = controller.reviewStatuses.length;
    final fileCount = bundle?.nodes.length ?? 0;
    final contextUsage = controller.sessionContextMetrics.context?.usagePercent;
    final messageCount = controller.messages.length;
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(panelPadding),
          child: _WorkspaceSideTabSwitcher(
            selectedTab: tab,
            items: <_WorkspaceSideTabItem>[
              _WorkspaceSideTabItem(
                tab: WorkspaceSideTab.review,
                icon: Icons.rate_review_rounded,
                title: 'Review',
                subtitle: reviewCount > 0 ? 'Diffs' : 'No changes',
                badge: reviewCount > 0 ? '$reviewCount' : null,
              ),
              _WorkspaceSideTabItem(
                tab: WorkspaceSideTab.files,
                icon: Icons.folder_copy_rounded,
                title: 'Files',
                subtitle: 'Browse',
                badge: fileCount > 0 ? '$fileCount' : null,
              ),
              _WorkspaceSideTabItem(
                tab: WorkspaceSideTab.context,
                icon: Icons.tune_rounded,
                title: 'Context',
                subtitle: contextUsage != null ? 'Tokens' : 'Session',
                badge: contextUsage != null
                    ? '${contextUsage.clamp(0, 999)}%'
                    : (messageCount > 0 ? '$messageCount' : null),
              ),
            ],
            onChanged: controller.setSideTab,
          ),
        ),
        Expanded(
          child: switch (tab) {
            WorkspaceSideTab.review => _ReviewPanel(
              project: controller.project,
              configSnapshot: controller.configSnapshot,
              statuses: controller.reviewStatuses,
              selectedPath: controller.selectedReviewPath,
              diff: controller.reviewDiff,
              loadingDiff: controller.loadingReviewDiff,
              diffError: controller.reviewDiffError,
              initializingGitRepository: controller.initializingGitRepository,
              onInitializeGitRepository: () {
                unawaited(controller.initializeGitRepository());
              },
              onLineComment: onLineComment,
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

class _WorkspaceSideTabItem {
  const _WorkspaceSideTabItem({
    required this.tab,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final WorkspaceSideTab tab;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
}

class _WorkspaceSideTabSwitcher extends StatelessWidget {
  const _WorkspaceSideTabSwitcher({
    required this.selectedTab,
    required this.items,
    required this.onChanged,
  });

  final WorkspaceSideTab selectedTab;
  final List<_WorkspaceSideTabItem> items;
  final ValueChanged<WorkspaceSideTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final switcherPadding = density.inset(6, min: 4);
    return Container(
      key: const ValueKey<String>('workspace-side-tab-switcher'),
      padding: EdgeInsets.all(switcherPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            surfaces.panelMuted.withValues(alpha: 0.88),
            surfaces.panelRaised.withValues(alpha: 0.97),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: surfaces.lineSoft),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < items.length; index += 1) ...<Widget>[
            if (index > 0)
              SizedBox(width: density.inset(AppSpacing.xs, min: 4)),
            Expanded(
              child: _WorkspaceSideTabButton(
                item: items[index],
                selected: items[index].tab == selectedTab,
                onTap: () => onChanged(items[index].tab),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceSideTabButton extends StatelessWidget {
  const _WorkspaceSideTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _WorkspaceSideTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final accent = _workspaceSideTabAccent(item.tab, theme, surfaces);
    final titleColor = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.92);
    final subtitleColor = selected
        ? Color.lerp(surfaces.muted, accent, 0.32) ?? surfaces.muted
        : surfaces.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('workspace-side-tab-${item.tab.name}-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minHeight: density.inset(78, min: 66)),
          padding: EdgeInsets.fromLTRB(
            density.inset(AppSpacing.sm),
            density.inset(AppSpacing.sm),
            density.inset(AppSpacing.sm),
            density.inset(AppSpacing.sm),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? <Color>[
                      accent.withValues(alpha: 0.18),
                      accent.withValues(alpha: 0.07),
                    ]
                  : <Color>[
                      surfaces.panelRaised.withValues(alpha: 0.94),
                      surfaces.panel.withValues(alpha: 0.72),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.04),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: density.inset(28, min: 24),
                    height: density.inset(28, min: 24),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: selected ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accent.withValues(alpha: selected ? 0.3 : 0.18),
                      ),
                    ),
                    child: Icon(item.icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: item.badge == null
                          ? const SizedBox.shrink()
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? accent.withValues(alpha: 0.16)
                                      : surfaces.panelEmphasis.withValues(
                                          alpha: 0.58,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.pillRadius,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? accent.withValues(alpha: 0.28)
                                        : surfaces.lineSoft,
                                  ),
                                ),
                                child: Text(
                                  item.badge!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: selected ? accent : surfaces.muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subtitleColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _workspaceSideTabAccent(
  WorkspaceSideTab tab,
  ThemeData theme,
  AppSurfaces surfaces,
) {
  return switch (tab) {
    WorkspaceSideTab.review => surfaces.warning,
    WorkspaceSideTab.files => theme.colorScheme.primary,
    WorkspaceSideTab.context => surfaces.success,
  };
}

class _ReviewPanel extends StatefulWidget {
  const _ReviewPanel({
    required this.project,
    required this.configSnapshot,
    required this.statuses,
    required this.selectedPath,
    required this.diff,
    required this.loadingDiff,
    required this.diffError,
    required this.initializingGitRepository,
    required this.onInitializeGitRepository,
    required this.onLineComment,
    required this.onSelectFile,
  });

  final ProjectTarget? project;
  final ConfigSnapshot? configSnapshot;
  final List<FileStatusSummary> statuses;
  final String? selectedPath;
  final FileDiffSummary? diff;
  final bool loadingDiff;
  final String? diffError;
  final bool initializingGitRepository;
  final VoidCallback onInitializeGitRepository;
  final ValueChanged<_ReviewLineCommentSubmission> onLineComment;
  final ValueChanged<String> onSelectFile;

  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  static const double _defaultPreviewHeight = 280;
  static const double _minPreviewHeight = 160;
  static const double _minListHeight = 220;

  double _previewHeight = _defaultPreviewHeight;
  _ReviewDiffMode _diffMode = _ReviewDiffMode.unified;
  final TextEditingController _lineCommentController = TextEditingController();

  @override
  void dispose() {
    _lineCommentController.dispose();
    super.dispose();
  }

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

  Future<void> _startLineComment(_ReviewCommentTarget target) async {
    _lineCommentController.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _ReviewLineCommentEditor(
              target: target,
              controller: _lineCommentController,
              onCancel: () => Navigator.of(dialogContext).pop(),
              onSubmit: () => Navigator.of(
                dialogContext,
              ).pop(_lineCommentController.text.trim()),
            ),
          ),
        );
      },
    );
    if (!mounted || comment == null || comment.trim().isEmpty) {
      return;
    }
    widget.onLineComment(
      _ReviewLineCommentSubmission(target: target, comment: comment),
    );
    _lineCommentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final hasGitRepository =
        (widget.project?.vcs ?? '').trim().toLowerCase() == 'git';
    final snapshotTrackingDisabled =
        widget.configSnapshot?.snapshotTrackingEnabled == false;
    if (widget.statuses.isEmpty) {
      if (!hasGitRepository) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.all(density.inset(AppSpacing.lg)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.source_rounded,
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: density.inset(AppSpacing.sm)),
                  Text(
                    'Create a Git repository',
                    key: const ValueKey<String>('review-no-vcs-title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: density.inset(AppSpacing.xs)),
                  Text(
                    'Initialize Git for this project to unlock review diffs and tracked file changes.',
                    key: const ValueKey<String>('review-no-vcs-message'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: surfaces.muted,
                    ),
                  ),
                  SizedBox(height: density.inset(AppSpacing.md)),
                  FilledButton.icon(
                    key: const ValueKey<String>('review-init-git-button'),
                    onPressed: widget.initializingGitRepository
                        ? null
                        : widget.onInitializeGitRepository,
                    icon: widget.initializingGitRepository
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_link_rounded),
                    label: Text(
                      widget.initializingGitRepository
                          ? 'Creating repository...'
                          : 'Create Git repository',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (snapshotTrackingDisabled) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.all(density.inset(AppSpacing.lg)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 30,
                    color: surfaces.warning,
                  ),
                  SizedBox(height: density.inset(AppSpacing.sm)),
                  Text(
                    'Snapshot tracking is disabled',
                    key: const ValueKey<String>('review-no-snapshot-title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: density.inset(AppSpacing.xs)),
                  Text(
                    'Snapshot tracking is disabled in config, so session changes are unavailable.',
                    key: const ValueKey<String>('review-no-snapshot-message'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: surfaces.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (widget.loadingDiff) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.diffError != null) {
        return Center(
          child: Text(
            widget.diffError!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
          ),
        );
      }
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
                padding: EdgeInsets.all(density.inset(AppSpacing.md)),
                itemCount: widget.statuses.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: density.inset(AppSpacing.xs, min: 4)),
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
                        padding: EdgeInsets.fromLTRB(
                          density.inset(AppSpacing.md),
                          0,
                          density.inset(AppSpacing.md),
                          density.inset(AppSpacing.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: density.inset(AppSpacing.sm),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      widget.selectedPath!,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: surfaces.muted),
                                    ),
                                  ),
                                  SizedBox(
                                    width: density.inset(AppSpacing.sm, min: 6),
                                  ),
                                  SegmentedButton<_ReviewDiffMode>(
                                    key: const ValueKey<String>(
                                      'review-diff-mode-toggle',
                                    ),
                                    showSelectedIcon: false,
                                    segments:
                                        const <ButtonSegment<_ReviewDiffMode>>[
                                          ButtonSegment<_ReviewDiffMode>(
                                            value: _ReviewDiffMode.unified,
                                            label: Text('Unified'),
                                            icon: Icon(
                                              Icons.view_stream_rounded,
                                            ),
                                          ),
                                          ButtonSegment<_ReviewDiffMode>(
                                            value: _ReviewDiffMode.split,
                                            label: Text('Split'),
                                            icon: Icon(Icons.view_week_rounded),
                                          ),
                                        ],
                                    selected: <_ReviewDiffMode>{_diffMode},
                                    onSelectionChanged: (selection) {
                                      final next = selection.isEmpty
                                          ? _diffMode
                                          : selection.first;
                                      if (next == _diffMode) {
                                        return;
                                      }
                                      setState(() {
                                        _diffMode = next;
                                      });
                                    },
                                  ),
                                ],
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
                                  : _ReviewDiffView(
                                      diff: widget.diff!,
                                      mode: _diffMode,
                                      onLineComment: (target) {
                                        unawaited(_startLineComment(target));
                                      },
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

enum _ReviewDiffMode { unified, split }

class _ReviewDiffView extends StatelessWidget {
  const _ReviewDiffView({
    required this.diff,
    required this.mode,
    required this.onLineComment,
  });

  final FileDiffSummary diff;
  final _ReviewDiffMode mode;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final density = _workspaceDensity(context);
    final parsedDiff = _cachedParsedReviewDiff(diff.content);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: BackdropFilter(
        key: const ValueKey<String>('review-diff-blur'),
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const ValueKey<String>('review-diff-surface'),
          width: double.infinity,
          padding: EdgeInsets.all(density.inset(AppSpacing.md)),
          decoration: BoxDecoration(
            color: surfaces.background.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 22,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = mode == _ReviewDiffMode.split
                  ? math.max(constraints.maxWidth, density.maxContentWidth(940))
                  : constraints.maxWidth;
              if (mode == _ReviewDiffMode.unified) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minWidth),
                    child: SingleChildScrollView(
                      child: _ReviewUnifiedDiffBody(
                        key: const ValueKey<String>('review-diff-unified-view'),
                        diff: parsedDiff,
                        filePath: diff.path,
                        contentWidth: minWidth,
                        theme: theme,
                        surfaces: surfaces,
                        onLineComment: onLineComment,
                      ),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  child: SingleChildScrollView(
                    child: _ReviewSplitDiffBody(
                      key: const ValueKey<String>('review-diff-split-view'),
                      diff: parsedDiff,
                      filePath: diff.path,
                      theme: theme,
                      surfaces: surfaces,
                      onLineComment: onLineComment,
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

class _ReviewSplitDiffBody extends StatelessWidget {
  const _ReviewSplitDiffBody({
    required this.diff,
    required this.filePath,
    required this.theme,
    required this.surfaces,
    required this.onLineComment,
    super.key,
  });

  final _ParsedReviewDiff diff;
  final String filePath;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (
            var index = 0;
            index < diff.headers.length;
            index += 1
          ) ...<Widget>[
            _ReviewDiffMetaRow(
              text: diff.headers[index],
              theme: theme,
              surfaces: surfaces,
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          for (
            var hunkIndex = 0;
            hunkIndex < diff.hunks.length;
            hunkIndex += 1
          ) ...<Widget>[
            if (diff.headers.isNotEmpty || hunkIndex > 0)
              const SizedBox(height: AppSpacing.sm),
            _ReviewDiffHunkHeaderRow(
              text: diff.hunks[hunkIndex].header,
              theme: theme,
              surfaces: surfaces,
            ),
            const SizedBox(height: AppSpacing.xxs),
            _ReviewSplitSideHeader(theme: theme, surfaces: surfaces),
            ..._buildReviewSplitRows(
              filePath,
              diff.hunks[hunkIndex],
              theme: theme,
              surfaces: surfaces,
              onLineComment: onLineComment,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewDiffMetaRow extends StatelessWidget {
  const _ReviewDiffMetaRow({
    required this.text,
    required this.theme,
    required this.surfaces,
  });

  final String text;
  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        softWrap: false,
        style: _reviewDiffMetaTextStyle(theme: theme, surfaces: surfaces),
      ),
    );
  }
}

class _ReviewDiffHunkHeaderRow extends StatelessWidget {
  const _ReviewDiffHunkHeaderRow({
    required this.text,
    required this.theme,
    required this.surfaces,
  });

  final String text;
  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        text,
        softWrap: false,
        style: _reviewDiffHunkTextStyle(theme: theme, surfaces: surfaces),
      ),
    );
  }
}

class _ReviewSplitSideHeader extends StatelessWidget {
  const _ReviewSplitSideHeader({required this.theme, required this.surfaces});

  final ThemeData theme;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: surfaces.muted,
      fontFamily: 'monospace',
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: surfaces.panelMuted.withValues(alpha: 0.62),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
              ),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text('Before', style: labelStyle),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: surfaces.panelMuted.withValues(alpha: 0.62),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
              ),
              border: Border.all(color: surfaces.lineSoft),
            ),
            child: Text('After', style: labelStyle),
          ),
        ),
      ],
    );
  }
}

class _ReviewUnifiedDiffBody extends StatelessWidget {
  const _ReviewUnifiedDiffBody({
    required this.diff,
    required this.filePath,
    required this.contentWidth,
    required this.theme,
    required this.surfaces,
    required this.onLineComment,
    super.key,
  });

  final _ParsedReviewDiff diff;
  final String filePath;
  final double contentWidth;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: contentWidth,
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (
              var index = 0;
              index < diff.headers.length;
              index += 1
            ) ...<Widget>[
              _ReviewDiffMetaRow(
                text: diff.headers[index],
                theme: theme,
                surfaces: surfaces,
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
            for (
              var hunkIndex = 0;
              hunkIndex < diff.hunks.length;
              hunkIndex += 1
            ) ...<Widget>[
              if (diff.headers.isNotEmpty || hunkIndex > 0)
                const SizedBox(height: AppSpacing.sm),
              _ReviewDiffHunkHeaderRow(
                text: diff.hunks[hunkIndex].header,
                theme: theme,
                surfaces: surfaces,
              ),
              const SizedBox(height: AppSpacing.xxs),
              for (
                var lineIndex = 0;
                lineIndex < diff.hunks[hunkIndex].lines.length;
                lineIndex += 1
              ) ...<Widget>[
                _ReviewUnifiedLineRow(
                  filePath: filePath,
                  hunkHeader: diff.hunks[hunkIndex].header,
                  line: diff.hunks[hunkIndex].lines[lineIndex],
                  theme: theme,
                  surfaces: surfaces,
                  onLineComment: onLineComment,
                ),
                if (lineIndex != diff.hunks[hunkIndex].lines.length - 1)
                  const SizedBox(height: 1),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewUnifiedLineRow extends StatelessWidget {
  const _ReviewUnifiedLineRow({
    required this.filePath,
    required this.hunkHeader,
    required this.line,
    required this.theme,
    required this.surfaces,
    required this.onLineComment,
  });

  final String filePath;
  final String hunkHeader;
  final _ParsedReviewLine line;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (line.kind) {
      _ParsedReviewLineKind.insert => surfaces.success.withValues(alpha: 0.08),
      _ParsedReviewLineKind.delete => surfaces.danger.withValues(alpha: 0.08),
      _ParsedReviewLineKind.context => Colors.transparent,
    };
    final textColor = switch (line.kind) {
      _ParsedReviewLineKind.insert => surfaces.success,
      _ParsedReviewLineKind.delete => surfaces.danger,
      _ParsedReviewLineKind.context => theme.colorScheme.onSurface,
    };
    final prefix = switch (line.kind) {
      _ParsedReviewLineKind.insert => '+',
      _ParsedReviewLineKind.delete => '-',
      _ParsedReviewLineKind.context => ' ',
    };
    final target = _reviewCommentTargetForLine(
      path: filePath,
      hunkHeader: hunkHeader,
      line: line,
    );
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(
              line.oldNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: surfaces.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 40,
            child: Text(
              line.newNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: surfaces.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ReviewLineCommentButton(
            target: target,
            onPressed: () => onLineComment(target),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$prefix${line.text}',
              softWrap: false,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildReviewSplitRows(
  String filePath,
  _ParsedReviewHunk hunk, {
  required ThemeData theme,
  required AppSurfaces surfaces,
  required ValueChanged<_ReviewCommentTarget> onLineComment,
}) {
  final rows = <Widget>[];
  final pairs = _pairReviewSplitLines(hunk.lines);
  for (final pair in pairs) {
    rows.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _ReviewSplitLineCell(
              line: pair.left,
              filePath: filePath,
              hunkHeader: hunk.header,
              theme: theme,
              surfaces: surfaces,
              side: _ReviewSplitSide.before,
              onLineComment: onLineComment,
            ),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: _ReviewSplitLineCell(
              line: pair.right,
              filePath: filePath,
              hunkHeader: hunk.header,
              theme: theme,
              surfaces: surfaces,
              side: _ReviewSplitSide.after,
              onLineComment: onLineComment,
            ),
          ),
        ],
      ),
    );
    rows.add(const SizedBox(height: 1));
  }
  return rows;
}

enum _ReviewSplitSide { before, after }

class _ReviewSplitLineCell extends StatelessWidget {
  const _ReviewSplitLineCell({
    required this.line,
    required this.filePath,
    required this.hunkHeader,
    required this.theme,
    required this.surfaces,
    required this.side,
    required this.onLineComment,
  });

  final _ParsedReviewLine? line;
  final String filePath;
  final String hunkHeader;
  final ThemeData theme;
  final AppSurfaces surfaces;
  final _ReviewSplitSide side;
  final ValueChanged<_ReviewCommentTarget> onLineComment;

  @override
  Widget build(BuildContext context) {
    final lineKind = line?.kind;
    final backgroundColor = switch (lineKind) {
      _ParsedReviewLineKind.insert => surfaces.success.withValues(alpha: 0.08),
      _ParsedReviewLineKind.delete => surfaces.danger.withValues(alpha: 0.08),
      _ParsedReviewLineKind.context => Colors.transparent,
      null => surfaces.panelEmphasis.withValues(alpha: 0.32),
    };
    final textColor = switch (lineKind) {
      _ParsedReviewLineKind.insert => surfaces.success,
      _ParsedReviewLineKind.delete => surfaces.danger,
      _ParsedReviewLineKind.context || null => theme.colorScheme.onSurface,
    };
    final lineNumber = switch (side) {
      _ReviewSplitSide.before => line?.oldNumber,
      _ReviewSplitSide.after => line?.newNumber,
    };
    final prefix = switch (lineKind) {
      _ParsedReviewLineKind.insert => '+',
      _ParsedReviewLineKind.delete => '-',
      _ParsedReviewLineKind.context || null => ' ',
    };
    final commentTarget = line == null
        ? null
        : _reviewCommentTargetForLine(
            path: filePath,
            hunkHeader: hunkHeader,
            line: line!,
          );
    final showCommentButton =
        commentTarget != null && _canCommentOnSplitLine(line: line, side: side);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      color: backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              lineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: surfaces.muted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 12,
            child: Text(
              line == null ? '' : prefix,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 26,
            child: !showCommentButton
                ? const SizedBox.shrink()
                : _ReviewLineCommentButton(
                    target: commentTarget,
                    onPressed: () => onLineComment(commentTarget),
                  ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              line?.text ?? '',
              softWrap: false,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLineCommentButton extends StatelessWidget {
  const _ReviewLineCommentButton({
    required this.target,
    required this.onPressed,
  });

  final _ReviewCommentTarget target;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add review comment for ${target.locationLabel}',
      child: IconButton(
        key: ValueKey<String>(_reviewCommentTargetButtonKey(target)),
        onPressed: onPressed,
        icon: const Icon(Icons.add_comment_rounded, size: 16),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
      ),
    );
  }
}

class _ReviewLineCommentEditor extends StatelessWidget {
  const _ReviewLineCommentEditor({
    required this.target,
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final _ReviewCommentTarget target;
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      key: const ValueKey<String>('review-line-comment-editor'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaces.panelMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Add to composer context',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${target.path} · ${target.locationLabel}',
            style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            target.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: surfaces.muted,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey<String>('review-line-comment-field'),
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Explain what you want the model to focus on.',
            ),
            onSubmitted: (_) {
              if (controller.text.trim().isEmpty) {
                return;
              }
              onSubmit();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final canSubmit = value.text.trim().isNotEmpty;
              return OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: AppSpacing.xs,
                children: <Widget>[
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                  FilledButton(
                    key: const ValueKey<String>('review-line-comment-submit'),
                    onPressed: canSubmit ? onSubmit : null,
                    child: const Text('Add to composer'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewCommentTarget {
  const _ReviewCommentTarget({
    required this.path,
    required this.preview,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final String path;
  final String preview;
  final int? oldLineNumber;
  final int? newLineNumber;

  String get locationLabel {
    if (oldLineNumber != null && newLineNumber != null) {
      if (oldLineNumber == newLineNumber) {
        return 'line $newLineNumber';
      }
      return 'old $oldLineNumber / new $newLineNumber';
    }
    if (newLineNumber != null) {
      return 'new line $newLineNumber';
    }
    if (oldLineNumber != null) {
      return 'old line $oldLineNumber';
    }
    return 'selected lines';
  }
}

class _ReviewLineCommentSubmission {
  const _ReviewLineCommentSubmission({
    required this.target,
    required this.comment,
  });

  final _ReviewCommentTarget target;
  final String comment;
}

_ReviewCommentTarget _reviewCommentTargetForLine({
  required String path,
  required String hunkHeader,
  required _ParsedReviewLine line,
}) {
  final prefix = switch (line.kind) {
    _ParsedReviewLineKind.insert => '+',
    _ParsedReviewLineKind.delete => '-',
    _ParsedReviewLineKind.context => ' ',
  };
  return _ReviewCommentTarget(
    path: path,
    oldLineNumber: line.oldNumber,
    newLineNumber: line.newNumber,
    preview: '$hunkHeader\n$prefix${line.text}',
  );
}

bool _canCommentOnSplitLine({
  required _ParsedReviewLine? line,
  required _ReviewSplitSide side,
}) {
  if (line == null) {
    return false;
  }
  return switch (line.kind) {
    _ParsedReviewLineKind.insert => side == _ReviewSplitSide.after,
    _ParsedReviewLineKind.delete => side == _ReviewSplitSide.before,
    _ParsedReviewLineKind.context => side == _ReviewSplitSide.after,
  };
}

String _reviewCommentTargetButtonKey(_ReviewCommentTarget target) {
  return 'review-line-comment-button-${target.path}-old-${target.oldLineNumber ?? 'none'}-new-${target.newLineNumber ?? 'none'}';
}

class _ParsedReviewDiff {
  const _ParsedReviewDiff({required this.headers, required this.hunks});

  final List<String> headers;
  final List<_ParsedReviewHunk> hunks;
}

class _ParsedReviewHunk {
  const _ParsedReviewHunk({required this.header, required this.lines});

  final String header;
  final List<_ParsedReviewLine> lines;
}

enum _ParsedReviewLineKind { context, delete, insert }

class _ParsedReviewLine {
  const _ParsedReviewLine({
    required this.kind,
    required this.text,
    this.oldNumber,
    this.newNumber,
  });

  final _ParsedReviewLineKind kind;
  final String text;
  final int? oldNumber;
  final int? newNumber;
}

class _ReviewSplitLinePair {
  const _ReviewSplitLinePair({this.left, this.right});

  final _ParsedReviewLine? left;
  final _ParsedReviewLine? right;
}

class _ParsedReviewDiffCacheEntry {
  const _ParsedReviewDiffCacheEntry({
    required this.content,
    required this.parsedDiff,
  });

  final String content;
  final _ParsedReviewDiff parsedDiff;
}

final _reviewDiffParseCache = _LruCache<int, _ParsedReviewDiffCacheEntry>(
  maximumSize: 24,
);

_ParsedReviewDiff _cachedParsedReviewDiff(String content) {
  if (content.trim().isEmpty) {
    return const _ParsedReviewDiff(
      headers: <String>[],
      hunks: <_ParsedReviewHunk>[],
    );
  }
  final signature = Object.hash(content.length, content.hashCode);
  final cached = _reviewDiffParseCache.get(signature);
  if (cached != null && cached.content == content) {
    return cached.parsedDiff;
  }
  final parsedDiff = _parseReviewDiff(content);
  _reviewDiffParseCache.set(
    signature,
    _ParsedReviewDiffCacheEntry(content: content, parsedDiff: parsedDiff),
  );
  return parsedDiff;
}

_ParsedReviewDiff _parseReviewDiff(String content) {
  if (content.trim().isEmpty) {
    return const _ParsedReviewDiff(
      headers: <String>[],
      hunks: <_ParsedReviewHunk>[],
    );
  }

  final lines = content.split('\n');
  final headers = <String>[];
  final hunks = <_ParsedReviewHunk>[];
  final hunkHeaderPattern = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

  String? currentHunkHeader;
  var currentHunkLines = <_ParsedReviewLine>[];
  var oldNumber = 0;
  var newNumber = 0;

  void flushCurrentHunk() {
    final header = currentHunkHeader;
    if (header == null) {
      return;
    }
    hunks.add(
      _ParsedReviewHunk(
        header: header,
        lines: List<_ParsedReviewLine>.unmodifiable(currentHunkLines),
      ),
    );
    currentHunkHeader = null;
    currentHunkLines = <_ParsedReviewLine>[];
  }

  for (final rawLine in lines) {
    if (rawLine.startsWith('@@')) {
      flushCurrentHunk();
      currentHunkHeader = rawLine;
      final match = hunkHeaderPattern.firstMatch(rawLine);
      oldNumber = int.tryParse(match?.group(1) ?? '') ?? 0;
      newNumber = int.tryParse(match?.group(2) ?? '') ?? 0;
      continue;
    }

    if (currentHunkHeader == null) {
      headers.add(rawLine);
      continue;
    }

    if (rawLine.startsWith('+') && !rawLine.startsWith('+++')) {
      currentHunkLines.add(
        _ParsedReviewLine(
          kind: _ParsedReviewLineKind.insert,
          text: rawLine.substring(1),
          newNumber: newNumber,
        ),
      );
      newNumber += 1;
      continue;
    }
    if (rawLine.startsWith('-') && !rawLine.startsWith('---')) {
      currentHunkLines.add(
        _ParsedReviewLine(
          kind: _ParsedReviewLineKind.delete,
          text: rawLine.substring(1),
          oldNumber: oldNumber,
        ),
      );
      oldNumber += 1;
      continue;
    }
    if (rawLine.startsWith(' ')) {
      currentHunkLines.add(
        _ParsedReviewLine(
          kind: _ParsedReviewLineKind.context,
          text: rawLine.substring(1),
          oldNumber: oldNumber,
          newNumber: newNumber,
        ),
      );
      oldNumber += 1;
      newNumber += 1;
      continue;
    }
  }

  flushCurrentHunk();

  return _ParsedReviewDiff(
    headers: List<String>.unmodifiable(headers),
    hunks: List<_ParsedReviewHunk>.unmodifiable(hunks),
  );
}

List<_ReviewSplitLinePair> _pairReviewSplitLines(
  List<_ParsedReviewLine> lines,
) {
  final pairs = <_ReviewSplitLinePair>[];
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    if (line.kind == _ParsedReviewLineKind.context) {
      pairs.add(_ReviewSplitLinePair(left: line, right: line));
      index += 1;
      continue;
    }
    if (line.kind == _ParsedReviewLineKind.delete) {
      final deletes = <_ParsedReviewLine>[];
      while (index < lines.length &&
          lines[index].kind == _ParsedReviewLineKind.delete) {
        deletes.add(lines[index]);
        index += 1;
      }
      final inserts = <_ParsedReviewLine>[];
      while (index < lines.length &&
          lines[index].kind == _ParsedReviewLineKind.insert) {
        inserts.add(lines[index]);
        index += 1;
      }
      final count = math.max(deletes.length, inserts.length);
      for (var pairIndex = 0; pairIndex < count; pairIndex += 1) {
        pairs.add(
          _ReviewSplitLinePair(
            left: pairIndex < deletes.length ? deletes[pairIndex] : null,
            right: pairIndex < inserts.length ? inserts[pairIndex] : null,
          ),
        );
      }
      continue;
    }
    final inserts = <_ParsedReviewLine>[];
    while (index < lines.length &&
        lines[index].kind == _ParsedReviewLineKind.insert) {
      inserts.add(lines[index]);
      index += 1;
    }
    for (final insert in inserts) {
      pairs.add(_ReviewSplitLinePair(right: insert));
    }
  }
  return pairs;
}

TextStyle? _reviewDiffMetaTextStyle({
  required ThemeData theme,
  required AppSurfaces surfaces,
}) {
  return theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    height: 1.45,
    color: surfaces.warning,
  );
}

TextStyle? _reviewDiffHunkTextStyle({
  required ThemeData theme,
  required AppSurfaces surfaces,
}) {
  return theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    height: 1.45,
    color: theme.colorScheme.primary,
    fontWeight: FontWeight.w700,
  );
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
    final density = _workspaceDensity(context);
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
    final visibleNodes = _cachedVisibleFileNodes(
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
                padding: EdgeInsets.all(density.inset(AppSpacing.md)),
                itemCount: visibleNodes.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: density.inset(AppSpacing.xs)),
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
                      left:
                          density.inset(AppSpacing.md) +
                          (entry.depth * density.inset(18, min: 14)),
                      right: density.inset(AppSpacing.md),
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
                        SizedBox(width: density.inset(AppSpacing.xs)),
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
                        padding: EdgeInsets.fromLTRB(
                          density.inset(AppSpacing.md),
                          0,
                          density.inset(AppSpacing.md),
                          density.inset(AppSpacing.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (bundle.selectedPath != null)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: density.inset(AppSpacing.sm),
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
                                      padding: EdgeInsets.all(
                                        density.inset(AppSpacing.md),
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

class _VisibleFileTreeCacheKey {
  const _VisibleFileTreeCacheKey({
    required this.nodeSignature,
    required this.expandedSignature,
    required this.loadingDirectoryPath,
  });

  final int nodeSignature;
  final int expandedSignature;
  final String? loadingDirectoryPath;

  @override
  bool operator ==(Object other) {
    return other is _VisibleFileTreeCacheKey &&
        other.nodeSignature == nodeSignature &&
        other.expandedSignature == expandedSignature &&
        other.loadingDirectoryPath == loadingDirectoryPath;
  }

  @override
  int get hashCode =>
      Object.hash(nodeSignature, expandedSignature, loadingDirectoryPath);
}

final Expando<int> _fileNodeSignatureCache = Expando<int>(
  'workspaceFileNodeSignature',
);
final _visibleFileTreeCache =
    _LruCache<_VisibleFileTreeCacheKey, List<_VisibleFileTreeEntry>>(
      maximumSize: 48,
    );

int _fileNodeListSignature(List<FileNodeSummary> nodes) {
  final cachedSignature = _fileNodeSignatureCache[nodes];
  if (cachedSignature != null) {
    return cachedSignature;
  }
  var signature = nodes.length;
  for (final node in nodes) {
    signature = Object.hash(
      signature,
      node.path,
      node.name,
      node.type,
      node.ignored,
    );
  }
  _fileNodeSignatureCache[nodes] = signature;
  return signature;
}

int _expandedDirectoriesSignature(Set<String> expandedDirectories) {
  if (expandedDirectories.isEmpty) {
    return 0;
  }
  return Object.hashAllUnordered(expandedDirectories);
}

List<_VisibleFileTreeEntry> _cachedVisibleFileNodes({
  required FileBrowserBundle bundle,
  required Set<String> expandedDirectories,
  required String? loadingDirectoryPath,
}) {
  final cacheKey = _VisibleFileTreeCacheKey(
    nodeSignature: _fileNodeListSignature(bundle.nodes),
    expandedSignature: _expandedDirectoriesSignature(expandedDirectories),
    loadingDirectoryPath: loadingDirectoryPath,
  );
  final cached = _visibleFileTreeCache.get(cacheKey);
  if (cached != null) {
    return cached;
  }
  final visibleNodes = List<_VisibleFileTreeEntry>.unmodifiable(
    _buildVisibleFileNodes(
      bundle: bundle,
      expandedDirectories: expandedDirectories,
      loadingDirectoryPath: loadingDirectoryPath,
    ),
  );
  _visibleFileTreeCache.set(cacheKey, visibleNodes);
  return visibleNodes;
}

class _HighlightedFilePreview extends StatefulWidget {
  const _HighlightedFilePreview({required this.path, required this.content});

  final String? path;
  final String content;

  @override
  State<_HighlightedFilePreview> createState() =>
      _HighlightedFilePreviewState();
}

class _HighlightedFilePreviewState extends State<_HighlightedFilePreview> {
  String? _cachedPath;
  String? _cachedContent;
  int? _cachedThemeSignature;
  List<InlineSpan>? _cachedSpans;

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
    final themeSignature = _syntaxThemeSignature(theme, surfaces);
    if (_cachedSpans == null ||
        _cachedPath != widget.path ||
        _cachedContent != widget.content ||
        _cachedThemeSignature != themeSignature) {
      _cachedSpans = _buildHighlightedFilePreviewSpans(
        content: widget.content,
        path: widget.path,
        syntaxTheme: syntaxTheme,
      );
      _cachedPath = widget.path;
      _cachedContent = widget.content;
      _cachedThemeSignature = themeSignature;
    }

    return SelectableText.rich(
      key: const ValueKey<String>('files-preview-content'),
      TextSpan(style: syntaxTheme.base, children: _cachedSpans),
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

int _syntaxThemeSignature(ThemeData theme, AppSurfaces surfaces) {
  return Object.hashAll(<Object?>[
    theme.colorScheme.primary,
    theme.colorScheme.onSurface,
    surfaces.panel,
    surfaces.panelRaised,
    surfaces.muted,
    surfaces.warning,
    surfaces.success,
    surfaces.accentSoft,
  ]);
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
    final density = _workspaceDensity(context);
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
          padding: EdgeInsets.fromLTRB(
            density.inset(AppSpacing.lg, min: AppSpacing.md),
            density.inset(AppSpacing.md),
            density.inset(AppSpacing.lg, min: AppSpacing.md),
            density.inset(AppSpacing.xl, min: AppSpacing.md),
          ),
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = density.inset(AppSpacing.lg, min: AppSpacing.md);
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

class _LruCache<K, V> {
  _LruCache({required this.maximumSize});

  final int maximumSize;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  V? get(K key) {
    if (!_entries.containsKey(key)) {
      return null;
    }
    final value = _entries.remove(key);
    _entries[key] = value as V;
    return value;
  }

  bool containsKey(K key) => _entries.containsKey(key);

  void set(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maximumSize) {
      _entries.remove(_entries.keys.first);
    }
  }
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
