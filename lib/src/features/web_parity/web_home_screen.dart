import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/app_routes.dart';
import '../../app/app_scope.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../design_system/app_modal.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_surface_decor.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';
import '../../i18n/web_parity_localizations.dart';
import '../connection/connection_profile_import.dart';
import '../connection/connection_profile_import_sheet.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import 'project_picker_sheet.dart';
import 'workspace_controller.dart';
import 'workspace_layout_store.dart';

part 'web_home_screen_server_management.dart';

class WebParityHomeScreen extends StatefulWidget {
  const WebParityHomeScreen({
    required this.flavor,
    required this.localeController,
    this.connectionImport,
    this.projectStore,
    this.projectCatalogService,
    super.key,
  });

  final AppFlavor flavor;
  final LocaleController localeController;
  final ConnectionImportRouteData? connectionImport;
  final ProjectStore? projectStore;
  final ProjectCatalogService? projectCatalogService;

  @override
  State<WebParityHomeScreen> createState() => _WebParityHomeScreenState();
}

class _WebParityHomeScreenState extends State<WebParityHomeScreen>
    with WidgetsBindingObserver {
  static const Duration _serverStatusRefreshInterval = Duration(seconds: 30);

  late final ProjectStore _projectStore = widget.projectStore ?? ProjectStore();
  final Map<String, ProjectTarget> _lastWorkspaceByServerStorageKey =
      <String, ProjectTarget>{};
  final Map<String, WorkspaceController> _observedWorkspaceControllersByKey =
      <String, WorkspaceController>{};
  final Map<WorkspaceController, VoidCallback>
  _observedWorkspaceControllerListeners = <WorkspaceController, VoidCallback>{};
  bool _workspaceStateSyncInFlight = false;
  bool _workspaceStateSyncQueued = false;
  String _lastWorkspaceStateSignature = '';
  String _inFlightWorkspaceStateSignature = '';
  int _workspaceStateSyncRevision = 0;
  final Set<String> _handledConnectionImportPayloads = <String>{};
  Timer? _serverStatusRefreshTimer;
  bool _serverStatusRefreshInFlight = false;
  String _serverStatusRefreshRosterSignature = '';
  int _homeTransientRouteDepth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    _scheduleServerStatusRefresh(AppScope.of(context));
  }

  void _ensureServerStatusPolling(WebParityAppController controller) {
    if (controller.loading) {
      return;
    }
    final rosterSignature = controller.profiles
        .map((profile) => profile.storageKey)
        .join('|');
    if (_serverStatusRefreshRosterSignature != rosterSignature) {
      _serverStatusRefreshRosterSignature = rosterSignature;
      _scheduleServerStatusRefresh(controller);
    }
    _serverStatusRefreshTimer ??= Timer.periodic(_serverStatusRefreshInterval, (
      _,
    ) {
      if (!mounted || !_allowsServerStatusRefresh) {
        return;
      }
      unawaited(_refreshSavedServerStatuses(AppScope.of(context)));
    });
  }

  void _scheduleServerStatusRefresh(WebParityAppController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          controller != AppScope.of(context) ||
          !_allowsServerStatusRefresh) {
        return;
      }
      unawaited(_refreshSavedServerStatuses(controller));
    });
  }

  bool get _allowsServerStatusRefresh {
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      return true;
    }
    return route.isActive && _homeTransientRouteDepth > 0;
  }

  Future<T?> _trackHomeTransientRoute<T>(
    Future<T?> Function() openRoute,
  ) async {
    _homeTransientRouteDepth += 1;
    try {
      return await openRoute();
    } finally {
      _homeTransientRouteDepth -= 1;
    }
  }

  Future<bool> _refreshSavedServerStatuses(
    WebParityAppController controller,
  ) async {
    if (controller.loading ||
        _serverStatusRefreshInFlight ||
        !_allowsServerStatusRefresh) {
      return false;
    }
    final profiles = controller.profiles.toList(growable: false);
    if (profiles.isEmpty) {
      return false;
    }
    _serverStatusRefreshInFlight = true;
    try {
      await Future.wait(profiles.map(controller.refreshProbe));
      return true;
    } finally {
      _serverStatusRefreshInFlight = false;
    }
  }

  Future<void> _manualRefreshSavedServerStatuses(
    WebParityAppController controller,
  ) async {
    final refreshed = await _refreshSavedServerStatuses(controller);
    if (!mounted || !refreshed) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp('Refreshed saved server status.'),
      tone: AppSnackBarTone.info,
    );
  }

  void _scheduleConnectionImportPromptIfNeeded(
    WebParityAppController controller,
  ) {
    final routeData = widget.connectionImport;
    if (controller.loading || routeData == null) {
      return;
    }
    final rawPayload = routeData.rawPayload.trim();
    if (rawPayload.isEmpty ||
        !_handledConnectionImportPayloads.add(rawPayload)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_presentConnectionImport(controller, routeData));
    });
  }

  ServerProfile? _existingProfileForImport(
    WebParityAppController controller,
    ConnectionImportRouteData routeData,
  ) {
    final imported = routeData.payload.toServerProfile();
    for (final profile in controller.profiles) {
      if (profile.storageKey == imported.storageKey) {
        return profile;
      }
    }
    return null;
  }

  Future<void> _presentConnectionImport(
    WebParityAppController controller,
    ConnectionImportRouteData routeData,
  ) async {
    final existingProfile = _existingProfileForImport(controller, routeData);
    final confirmed = await _trackHomeTransientRoute<bool>(
      () => showAppModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.74,
          child: ConnectionProfileImportSheet(
            routeData: routeData,
            existingProfile: existingProfile,
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    if (confirmed == true && routeData.hasValidPayload) {
      final savedProfile = await controller.saveProfile(
        routeData.payload.toServerProfile(id: existingProfile?.id),
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: existingProfile == null
            ? context.wp(
                'Imported "{label}" and refreshed its connection status.',
                args: <String, Object?>{'label': savedProfile.effectiveLabel},
              )
            : context.wp(
                'Updated "{label}" from the shared connection link.',
                args: <String, Object?>{'label': savedProfile.effectiveLabel},
              ),
        tone: AppSnackBarTone.success,
      );
    }
    if (!mounted || currentRoute == '/') {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  String _connectionImportLinkForProfile(ServerProfile profile) {
    final payload = ConnectionProfileImportPayload.fromProfile(
      profile,
      issuedAt: DateTime.now(),
      expiresIn: const Duration(days: 7),
    );
    return buildConnectionImportDeepLink(
      rawPayload: payload.toToken(),
    ).toString();
  }

  Future<void> _copyConnectionImportLink(ServerProfile profile) async {
    final link = _connectionImportLinkForProfile(profile);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp(
        'Copied a reusable connection link for "{label}".',
        args: <String, Object?>{'label': profile.effectiveLabel},
      ),
      tone: AppSnackBarTone.info,
    );
  }

  Future<ProjectTarget> _resolveNavigationTarget(
    WebParityAppController controller,
    ServerProfile profile,
    ProjectTarget target,
  ) async {
    ProjectSessionHint? remembered = target.lastSession;
    if (remembered?.id == null || remembered!.id!.trim().isEmpty) {
      final lastWorkspace = await _projectStore.loadLastWorkspace(
        profile.storageKey,
      );
      if (lastWorkspace?.directory == target.directory &&
          lastWorkspace?.lastSession != null) {
        remembered = lastWorkspace!.lastSession;
      }
    }

    if (remembered?.id == null || remembered!.id!.trim().isEmpty) {
      for (final item in controller.recentProjects) {
        if (item.directory == target.directory && item.lastSession != null) {
          remembered = item.lastSession;
          break;
        }
      }
    }

    if (remembered == null) {
      return target;
    }
    return target.copyWith(lastSession: remembered);
  }

  Future<void> _openResolvedProject(
    WebParityAppController controller,
    ServerProfile profile,
    ProjectTarget target,
  ) async {
    final resolvedTarget = await _resolveNavigationTarget(
      controller,
      profile,
      target,
    );
    await _projectStore.recordRecentProject(resolvedTarget);
    await _projectStore.saveLastWorkspace(
      serverStorageKey: profile.storageKey,
      target: resolvedTarget,
    );
    if (controller.selectedProfile?.id != profile.id) {
      await controller.selectProfile(profile);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamed(
      buildWorkspaceRoute(
        resolvedTarget.directory,
        sessionId: _preferredSessionId(resolvedTarget),
      ),
    );
  }

  Future<void> _openProjectPicker(
    WebParityAppController controller,
    ServerProfile? profile,
  ) async {
    if (profile == null) {
      await _openServers(controller);
      return;
    }

    final target = await _trackHomeTransientRoute<ProjectTarget>(
      () => showAppModalBottomSheet<ProjectTarget>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.82,
          child: ProjectPickerSheet(
            profile: profile,
            projectCatalogService: widget.projectCatalogService,
          ),
        ),
      ),
    );
    if (target == null || !mounted) {
      return;
    }
    await _openResolvedProject(controller, profile, target);
  }

  ProjectTarget? _lastWorkspaceForProfile(ServerProfile profile) {
    return _lastWorkspaceByServerStorageKey[profile.storageKey];
  }

  WorkspacePaneLayoutSnapshot? _layoutForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    return controller.workspacePaneLayoutFor(profile);
  }

  bool _isPaneStillValidForHome(
    ServerProfile profile,
    WorkspacePaneLayoutPane pane,
  ) {
    final sessionId = pane.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      return true;
    }
    final observedController = _observedWorkspaceController(
      profile,
      pane.directory,
    );
    if (observedController == null ||
        observedController.loading ||
        observedController.error != null ||
        observedController.sessions.isEmpty) {
      return true;
    }
    return observedController.sessions.any(
      (session) => session.id == sessionId,
    );
  }

  WorkspacePaneLayoutSnapshot? _normalizedLayoutForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final layout = _layoutForProfile(controller, profile);
    if (layout == null) {
      return null;
    }
    final panes = layout.panes
        .where((pane) => _isPaneStillValidForHome(profile, pane))
        .toList(growable: false);
    if (panes.isEmpty) {
      return null;
    }
    final activePaneId = panes.any((pane) => pane.id == layout.activePaneId)
        ? layout.activePaneId
        : panes.first.id;
    return WorkspacePaneLayoutSnapshot(
      panes: List<WorkspacePaneLayoutPane>.unmodifiable(panes),
      activePaneId: activePaneId,
    );
  }

  String _workspaceStateSignature(WebParityAppController controller) {
    final buffer = StringBuffer()..write('loading=${controller.loading};');
    for (final profile in controller.profiles) {
      buffer
        ..write(profile.storageKey)
        ..write('::');
      final layout = _normalizedLayoutForProfile(controller, profile);
      if (layout != null) {
        buffer
          ..write(layout.activePaneId)
          ..write('[');
        for (final pane in layout.panes) {
          buffer
            ..write(pane.id)
            ..write(':')
            ..write(pane.directory)
            ..write(':')
            ..write(pane.sessionId ?? '')
            ..write(';');
        }
        buffer.write(']');
      }
      buffer.write('|');
    }
    return buffer.toString();
  }

  void _scheduleWorkspaceStateSyncIfNeeded(WebParityAppController controller) {
    if (controller.loading) {
      return;
    }
    final signature = _workspaceStateSignature(controller);
    if (_workspaceStateSyncInFlight) {
      if (signature != _inFlightWorkspaceStateSignature) {
        _workspaceStateSyncQueued = true;
      }
      return;
    }
    if (signature == _lastWorkspaceStateSignature) {
      return;
    }
    _workspaceStateSyncInFlight = true;
    _inFlightWorkspaceStateSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_syncWorkspaceState(controller));
    });
  }

  Future<void> _syncWorkspaceState(WebParityAppController controller) async {
    final revision = ++_workspaceStateSyncRevision;
    final profiles = controller.profiles.toList(growable: false);
    await Future.wait(
      profiles.map((profile) => controller.ensureWorkspacePaneLayout(profile)),
    );
    final workspaceEntries = await Future.wait(
      profiles.map((profile) async {
        final target = await _projectStore.loadLastWorkspace(
          profile.storageKey,
        );
        return MapEntry<String, ProjectTarget?>(profile.storageKey, target);
      }),
    );
    if (!mounted ||
        _workspaceStateSyncRevision != revision ||
        controller != AppScope.of(context)) {
      _workspaceStateSyncInFlight = false;
      _inFlightWorkspaceStateSignature = '';
      return;
    }
    final nextLastWorkspaces = <String, ProjectTarget>{
      for (final entry in workspaceEntries)
        if (entry.value != null) entry.key: entry.value!,
    };
    setState(() {
      _lastWorkspaceByServerStorageKey
        ..clear()
        ..addAll(nextLastWorkspaces);
    });
    _syncObservedWorkspaceControllers(controller, profiles);
    _lastWorkspaceStateSignature = _workspaceStateSignature(controller);
    _workspaceStateSyncInFlight = false;
    _inFlightWorkspaceStateSignature = '';
    final shouldResync =
        _workspaceStateSyncQueued &&
        _lastWorkspaceStateSignature != _workspaceStateSignature(controller);
    _workspaceStateSyncQueued = false;
    if (shouldResync) {
      _scheduleWorkspaceStateSyncIfNeeded(controller);
    }
  }

  String _workspaceControllerKey(ServerProfile profile, String directory) {
    return '${profile.storageKey}::$directory';
  }

  List<String> _rememberedDirectoriesForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final layout = _normalizedLayoutForProfile(controller, profile);
    final directories = <String>[];
    final seen = <String>{};
    if (layout != null) {
      for (final pane in layout.panes) {
        if (seen.add(pane.directory)) {
          directories.add(pane.directory);
        }
      }
    }
    final lastWorkspace = _lastWorkspaceForProfile(profile);
    if (lastWorkspace != null && seen.add(lastWorkspace.directory)) {
      directories.add(lastWorkspace.directory);
    }
    return directories;
  }

  String? _preferredSessionIdForDirectory(
    WebParityAppController controller,
    ServerProfile profile,
    String directory,
  ) {
    final layout = _normalizedLayoutForProfile(controller, profile);
    if (layout != null) {
      final activePane = layout.activePane;
      if (activePane != null &&
          activePane.directory == directory &&
          activePane.sessionId != null) {
        return activePane.sessionId;
      }
      for (final pane in layout.panes) {
        if (pane.directory == directory && pane.sessionId != null) {
          return pane.sessionId;
        }
      }
    }
    final lastWorkspace = _lastWorkspaceForProfile(profile);
    if (lastWorkspace?.directory == directory) {
      return lastWorkspace?.lastSession?.id;
    }
    return null;
  }

  void _syncObservedWorkspaceControllers(
    WebParityAppController controller,
    List<ServerProfile> profiles,
  ) {
    final desiredKeys = <String>{};
    for (final profile in profiles) {
      for (final directory in _rememberedDirectoriesForProfile(
        controller,
        profile,
      )) {
        final key = _workspaceControllerKey(profile, directory);
        desiredKeys.add(key);
        if (_observedWorkspaceControllersByKey.containsKey(key)) {
          continue;
        }
        final observedController = controller.obtainWorkspaceController(
          profile: profile,
          directory: directory,
          initialSessionId: _preferredSessionIdForDirectory(
            controller,
            profile,
            directory,
          ),
        );
        void listener() {
          if (!mounted) {
            return;
          }
          setState(() {});
        }

        observedController.addListener(listener);
        _observedWorkspaceControllersByKey[key] = observedController;
        _observedWorkspaceControllerListeners[observedController] = listener;
      }
    }

    final staleKeys = _observedWorkspaceControllersByKey.keys
        .where((key) => !desiredKeys.contains(key))
        .toList(growable: false);
    for (final key in staleKeys) {
      final observedController = _observedWorkspaceControllersByKey.remove(key);
      final listener = observedController == null
          ? null
          : _observedWorkspaceControllerListeners.remove(observedController);
      if (observedController != null && listener != null) {
        observedController.removeListener(listener);
      }
    }
  }

  WorkspaceController? _observedWorkspaceController(
    ServerProfile profile,
    String directory,
  ) {
    return _observedWorkspaceControllersByKey[_workspaceControllerKey(
      profile,
      directory,
    )];
  }

  WorkspacePaneLayoutPane? _resumePaneForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    return _normalizedLayoutForProfile(controller, profile)?.activePane;
  }

  Future<void> _resumeWorkspace(
    WebParityAppController controller,
    ServerProfile profile,
  ) async {
    final activePane = _resumePaneForProfile(controller, profile);
    if (activePane != null) {
      if (controller.selectedProfile?.id != profile.id) {
        await controller.selectProfile(profile);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamed(
        buildWorkspaceRoute(
          activePane.directory,
          sessionId: activePane.sessionId,
        ),
      );
      return;
    }

    final lastWorkspace = _lastWorkspaceForProfile(profile);
    if (lastWorkspace != null) {
      await _openResolvedProject(controller, profile, lastWorkspace);
      return;
    }
    await _openProjectPicker(controller, profile);
  }

  Future<void> _openServerEditor(
    WebParityAppController controller, {
    ServerProfile? profile,
  }) async {
    final draft = await _trackHomeTransientRoute<ServerProfile>(
      () => showAppModalBottomSheet<ServerProfile>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.72,
          child: _ServerEditorSheet(initialProfile: profile),
        ),
      ),
    );
    if (draft == null) {
      return;
    }
    final savedProfile = await controller.saveProfile(draft);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp(
        'Saved "{label}" and refreshed status.',
        args: <String, Object?>{'label': savedProfile.effectiveLabel},
      ),
      tone: AppSnackBarTone.success,
    );
  }

  Future<void> _confirmDeleteServer(
    WebParityAppController controller,
    ServerProfile profile,
  ) async {
    final confirmed = await _trackHomeTransientRoute<bool>(
      () => showAppDialog<bool>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final surfaces = Theme.of(context).extension<AppSurfaces>()!;
          return AppDialogFrame(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: surfaces.panelRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
                side: BorderSide(color: surfaces.lineSoft),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.wp('Delete server?'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.wp(
                        'Remove "{label}" from saved servers? This keeps the rest of your home screen intact.',
                        args: <String, Object?>{
                          'label': profile.effectiveLabel,
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(context.wp('Cancel')),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(context.wp('Delete')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != true) {
      return;
    }
    await controller.deleteServerProfile(profile);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp(
        'Removed "{label}".',
        args: <String, Object?>{'label': profile.effectiveLabel},
      ),
      tone: AppSnackBarTone.warning,
    );
  }

  Future<void> _openServers(WebParityAppController controller) async {
    await _trackHomeTransientRoute<void>(
      () => showAppModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.84,
          child: _ServersSheet(controller: controller),
        ),
      ),
    );
  }

  Future<void> _openServerDetails(
    WebParityAppController controller,
    ServerProfile profile,
  ) async {
    await _trackHomeTransientRoute<void>(
      () => showAppModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: 0.84,
          child: _HomeServerDetailPanel(
            embeddedInPage: false,
            profile: profile,
            report: controller.reports[profile.storageKey],
            summary: _serverSummaryForProfile(controller, profile),
            activityLoading: _isServerActivityLoading(controller, profile),
            runningSessions: _runningSessionsForProfile(controller, profile),
            paneSnapshots: _paneSnapshotsForProfile(controller, profile),
            projectTargets: _projectTargetsForProfile(controller, profile),
            onResumeWorkspace: () {
              Navigator.of(sheetContext).pop();
              unawaited(_resumeWorkspace(controller, profile));
            },
            onEditServer: () {
              Navigator.of(sheetContext).pop();
              unawaited(_openServerEditor(controller, profile: profile));
            },
            onCopyConnectLink: () =>
                unawaited(_copyConnectionImportLink(profile)),
            onOpenProjectPicker: () {
              Navigator.of(sheetContext).pop();
              unawaited(_openProjectPicker(controller, profile));
            },
            onOpenProject: (target) {
              Navigator.of(sheetContext).pop();
              unawaited(_openRecentProject(controller, profile, target));
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openRecentProject(
    WebParityAppController controller,
    ServerProfile profile,
    ProjectTarget target,
  ) async {
    await _openResolvedProject(controller, profile, target);
  }

  bool _isServerActivityLoading(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final directories = _rememberedDirectoriesForProfile(controller, profile);
    if (directories.isEmpty) {
      return false;
    }
    for (final directory in directories) {
      final observedController = _observedWorkspaceController(
        profile,
        directory,
      );
      if (observedController == null || observedController.loading) {
        return true;
      }
    }
    return false;
  }

  bool _isSessionActive(String? status) {
    return (status?.trim().toLowerCase() ?? 'idle') != 'idle';
  }

  String _projectLabelForDirectory(
    WebParityAppController controller,
    ServerProfile profile,
    String directory,
  ) {
    final observedController = _observedWorkspaceController(profile, directory);
    final project = observedController?.project;
    if (project != null) {
      return project.title;
    }
    final lastWorkspace = _lastWorkspaceForProfile(profile);
    if (lastWorkspace?.directory == directory) {
      return lastWorkspace!.title;
    }
    for (final target in controller.recentProjects) {
      if (target.directory == directory) {
        return target.title;
      }
    }
    return projectDisplayLabel(directory);
  }

  String _sessionTitleForPane(
    WorkspaceController? controller,
    WorkspacePaneLayoutPane pane, {
    ProjectTarget? lastWorkspace,
  }) {
    final sessionId = pane.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty && controller != null) {
      for (final session in controller.sessions) {
        if (session.id == sessionId) {
          final title = session.title.trim();
          return title.isNotEmpty ? title : session.id;
        }
      }
    }
    if (lastWorkspace?.directory == pane.directory &&
        lastWorkspace?.lastSession?.title?.trim().isNotEmpty == true) {
      return lastWorkspace!.lastSession!.title!.trim();
    }
    return sessionId == null || sessionId.isEmpty
        ? context.wp('New session')
        : sessionId;
  }

  String? _sessionStatusForPane(
    WorkspaceController? controller,
    WorkspacePaneLayoutPane pane, {
    ProjectTarget? lastWorkspace,
  }) {
    final sessionId = pane.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty && controller != null) {
      return controller.statuses[sessionId]?.type;
    }
    if (lastWorkspace?.directory == pane.directory &&
        lastWorkspace?.lastSession?.id == sessionId) {
      return lastWorkspace?.lastSession?.status;
    }
    return null;
  }

  List<_HomeRunningSession> _runningSessionsForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final items = <_HomeRunningSession>[];
    final seenSessionKeys = <String>{};
    for (final directory in _rememberedDirectoriesForProfile(
      controller,
      profile,
    )) {
      final observedController = _observedWorkspaceController(
        profile,
        directory,
      );
      if (observedController == null) {
        continue;
      }
      for (final session in observedController.sessions) {
        if (session.archivedAt != null) {
          continue;
        }
        final status = observedController.statuses[session.id];
        if (!_isSessionActive(status?.type)) {
          continue;
        }
        final key = '$directory::${session.id}';
        if (!seenSessionKeys.add(key)) {
          continue;
        }
        final todos = observedController.todosForSession(session.id);
        final completedTodoCount = todos
            .where((todo) => todo.status.trim().toLowerCase() == 'completed')
            .length;
        items.add(
          _HomeRunningSession(
            directory: directory,
            projectLabel: _projectLabelForDirectory(
              controller,
              profile,
              directory,
            ),
            sessionId: session.id,
            sessionTitle: session.title.trim().isEmpty
                ? session.id
                : session.title.trim(),
            status: status?.type ?? 'running',
            completedTodoCount: completedTodoCount,
            totalTodoCount: todos.length,
            updatedAt: session.updatedAt,
          ),
        );
      }
    }
    items.sort((left, right) {
      final leftTime =
          left.updatedAt?.millisecondsSinceEpoch ?? left.sessionId.hashCode;
      final rightTime =
          right.updatedAt?.millisecondsSinceEpoch ?? right.sessionId.hashCode;
      return rightTime.compareTo(leftTime);
    });
    return items;
  }

  _HomeServerSummary _serverSummaryForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final runningSessions = _runningSessionsForProfile(controller, profile);
    final layout = _normalizedLayoutForProfile(controller, profile);
    final lastWorkspace = _lastWorkspaceForProfile(profile);
    final paneCount = layout?.panes.length ?? (lastWorkspace == null ? 0 : 1);
    var completedTodoCount = 0;
    var totalTodoCount = 0;
    for (final session in runningSessions) {
      completedTodoCount += session.completedTodoCount;
      totalTodoCount += session.totalTodoCount;
    }
    return _HomeServerSummary(
      paneCount: paneCount,
      runningSessionCount: runningSessions.length,
      completedTodoCount: completedTodoCount,
      totalTodoCount: totalTodoCount,
      activeDirectory:
          layout?.activePane?.directory ?? lastWorkspace?.directory,
    );
  }

  List<ProjectTarget> _projectTargetsForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final layout = _normalizedLayoutForProfile(controller, profile);
    final lastWorkspace = _lastWorkspaceForProfile(profile);
    final activeDirectory =
        layout?.activePane?.directory ?? lastWorkspace?.directory;
    final byDirectory = <String, ProjectTarget>{};

    void add(ProjectTarget target) {
      byDirectory[target.directory] = target;
    }

    if (activeDirectory != null) {
      final observedController = _observedWorkspaceController(
        profile,
        activeDirectory,
      );
      for (final target
          in observedController?.availableProjects ?? const <ProjectTarget>[]) {
        add(target);
      }
    }
    if (lastWorkspace != null) {
      add(lastWorkspace);
    }
    if (layout != null) {
      for (final pane in layout.panes) {
        byDirectory.putIfAbsent(
          pane.directory,
          () => ProjectTarget(
            directory: pane.directory,
            label: _projectLabelForDirectory(
              controller,
              profile,
              pane.directory,
            ),
          ),
        );
      }
    }
    if (byDirectory.isEmpty) {
      for (final target in controller.recentProjects) {
        add(target);
      }
    }

    final projects = byDirectory.values.toList(growable: false);
    projects.sort(
      (left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()),
    );
    return projects.take(8).toList(growable: false);
  }

  List<_HomePaneSnapshot> _paneSnapshotsForProfile(
    WebParityAppController controller,
    ServerProfile profile,
  ) {
    final layout = _normalizedLayoutForProfile(controller, profile);
    final lastWorkspace = _lastWorkspaceForProfile(profile);
    if (layout == null) {
      if (lastWorkspace == null) {
        return const <_HomePaneSnapshot>[];
      }
      return <_HomePaneSnapshot>[
        _HomePaneSnapshot(
          paneId: 'last_workspace',
          label: context.wp('Last workspace'),
          projectLabel: lastWorkspace.title,
          directory: lastWorkspace.directory,
          sessionTitle:
              lastWorkspace.lastSession?.title ?? context.wp('New session'),
          status: lastWorkspace.lastSession?.status,
          active: true,
        ),
      ];
    }
    return List<_HomePaneSnapshot>.generate(layout.panes.length, (index) {
      final pane = layout.panes[index];
      final observedController = _observedWorkspaceController(
        profile,
        pane.directory,
      );
      return _HomePaneSnapshot(
        paneId: pane.id,
        label: context.wp(
          'Pane {index}',
          args: <String, Object?>{'index': index + 1},
        ),
        projectLabel: _projectLabelForDirectory(
          controller,
          profile,
          pane.directory,
        ),
        directory: pane.directory,
        sessionTitle: _sessionTitleForPane(
          observedController,
          pane,
          lastWorkspace: lastWorkspace,
        ),
        status: _sessionStatusForPane(
          observedController,
          pane,
          lastWorkspace: lastWorkspace,
        ),
        active: pane.id == layout.activePaneId,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serverStatusRefreshTimer?.cancel();
    for (final entry in _observedWorkspaceControllerListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _observedWorkspaceControllerListeners.clear();
    _observedWorkspaceControllersByKey.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _scheduleConnectionImportPromptIfNeeded(controller);
        _scheduleWorkspaceStateSyncIfNeeded(controller);
        _ensureServerStatusPolling(controller);
        final selectedProfile = controller.selectedProfile;
        return Scaffold(
          backgroundColor: surfaces.background,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600
                    ? AppSpacing.sm
                    : AppSpacing.md,
              ),
              child: controller.loading
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _HomeHeroHeader(
                              profiles: controller.profiles,
                              reports: controller.reports,
                              anyRefreshing: controller.profiles.any(
                                (profile) =>
                                    controller.isRefreshingProfile(profile),
                              ),
                              onOpenServers: () => _openServers(controller),
                              onAddServer: () => _openServerEditor(controller),
                              onRefreshAll: () =>
                                  _manualRefreshSavedServerStatuses(controller),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Expanded(
                              child: _HomeServerListPanel(
                                profiles: controller.profiles,
                                selectedProfile: selectedProfile,
                                reports: controller.reports,
                                isRefreshingProfile:
                                    controller.isRefreshingProfile,
                                summaryForProfile: (profile) =>
                                    _serverSummaryForProfile(
                                      controller,
                                      profile,
                                    ),
                                onSelectProfile: controller.selectProfile,
                                onResumeProfile: (profile) =>
                                    _resumeWorkspace(controller, profile),
                                onShowProfileDetails: (profile) =>
                                    _openServerDetails(controller, profile),
                                onRefreshProfile: controller.refreshProbe,
                                onEditProfile: (profile) => _openServerEditor(
                                  controller,
                                  profile: profile,
                                ),
                                onDeleteProfile: (profile) =>
                                    _confirmDeleteServer(controller, profile),
                                onMoveProfile: controller.moveProfile,
                              ),
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

String? _preferredSessionId(ProjectTarget target) {
  final sessionId = target.lastSession?.id?.trim();
  if (sessionId == null || sessionId.isEmpty) {
    return null;
  }
  return sessionId;
}

class _HomeServerSummary {
  const _HomeServerSummary({
    required this.paneCount,
    required this.runningSessionCount,
    required this.completedTodoCount,
    required this.totalTodoCount,
    required this.activeDirectory,
  });

  final int paneCount;
  final int runningSessionCount;
  final int completedTodoCount;
  final int totalTodoCount;
  final String? activeDirectory;
}

class _HomeRunningSession {
  const _HomeRunningSession({
    required this.directory,
    required this.projectLabel,
    required this.sessionId,
    required this.sessionTitle,
    required this.status,
    required this.completedTodoCount,
    required this.totalTodoCount,
    required this.updatedAt,
  });

  final String directory;
  final String projectLabel;
  final String sessionId;
  final String sessionTitle;
  final String status;
  final int completedTodoCount;
  final int totalTodoCount;
  final DateTime? updatedAt;
}

class _HomePaneSnapshot {
  const _HomePaneSnapshot({
    required this.paneId,
    required this.label,
    required this.projectLabel,
    required this.directory,
    required this.sessionTitle,
    required this.status,
    required this.active,
  });

  final String paneId;
  final String label;
  final String projectLabel;
  final String directory;
  final String sessionTitle;
  final String? status;
  final bool active;
}

class _HomeHeroHeader extends StatelessWidget {
  const _HomeHeroHeader({
    required this.profiles,
    required this.reports,
    required this.anyRefreshing,
    required this.onOpenServers,
    required this.onAddServer,
    required this.onRefreshAll,
  });

  final List<ServerProfile> profiles;
  final Map<String, ServerProbeReport> reports;
  final bool anyRefreshing;
  final VoidCallback onOpenServers;
  final Future<void> Function() onAddServer;
  final Future<void> Function() onRefreshAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final onlineCount = profiles
        .where(
          (profile) =>
              reports[profile.storageKey]?.classification ==
              ConnectionProbeClassification.ready,
        )
        .length;
    final checkedAt = _latestCheckedAt(profiles, reports);
    final summary = profiles.isEmpty
        ? context.wp('No saved servers')
        : checkedAt == null
        ? context.wp(
            '{serverCount} servers · {onlineCount} online',
            args: <String, Object?>{
              'serverCount': profiles.length,
              'onlineCount': onlineCount,
            },
          )
        : context.wp(
            '{serverCount} servers · {onlineCount} online · last checked {time}',
            args: <String, Object?>{
              'serverCount': profiles.length,
              'onlineCount': onlineCount,
              'time': MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(checkedAt)),
            },
          );
    final brand = Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Image.asset(
            'web/icons/Icon-192.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(Icons.terminal_rounded, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.wp('BOC Remote'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: surfaces.muted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
    Widget actions({required bool compact}) {
      if (compact) {
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            IconButton(
              tooltip: context.wp('Refresh'),
              onPressed: profiles.isEmpty || anyRefreshing
                  ? null
                  : () => unawaited(onRefreshAll()),
              icon: anyRefreshing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: context.wp('Manage'),
              onPressed: onOpenServers,
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: AppSpacing.xs),
            Semantics(
              identifier: 'home-add-server-button',
              label: 'Add Server',
              button: true,
              onTap: () => unawaited(onAddServer()),
              child: FilledButton.icon(
                key: const ValueKey<String>('home-add-server-button'),
                onPressed: () => unawaited(onAddServer()),
                icon: const Icon(Icons.add_rounded),
                label: Text(context.wp('Add Server')),
              ),
            ),
          ],
        );
      }
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.end,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: profiles.isEmpty || anyRefreshing
                ? null
                : () => unawaited(onRefreshAll()),
            icon: anyRefreshing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(context.wp('Refresh')),
          ),
          OutlinedButton.icon(
            onPressed: onOpenServers,
            icon: const Icon(Icons.tune_rounded),
            label: Text(context.wp('Manage')),
          ),
          Semantics(
            identifier: 'home-add-server-button',
            label: 'Add Server',
            button: true,
            onTap: () => unawaited(onAddServer()),
            child: FilledButton.icon(
              key: const ValueKey<String>('home-add-server-button'),
              onPressed: () => unawaited(onAddServer()),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.wp('Add Server')),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                brand,
                const SizedBox(height: AppSpacing.sm),
                actions(compact: true),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: brand),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: actions(compact: false)),
            ],
          );
        },
      ),
    );
  }
}

DateTime? _latestCheckedAt(
  List<ServerProfile> profiles,
  Map<String, ServerProbeReport> reports,
) {
  DateTime? latest;
  for (final profile in profiles) {
    final checkedAt = reports[profile.storageKey]?.checkedAt;
    if (checkedAt == null) {
      continue;
    }
    if (latest == null || checkedAt.isAfter(latest)) {
      latest = checkedAt;
    }
  }
  return latest;
}

class _HomeServerListPanel extends StatelessWidget {
  const _HomeServerListPanel({
    required this.profiles,
    required this.selectedProfile,
    required this.reports,
    required this.isRefreshingProfile,
    required this.summaryForProfile,
    required this.onSelectProfile,
    required this.onResumeProfile,
    required this.onShowProfileDetails,
    required this.onRefreshProfile,
    required this.onEditProfile,
    required this.onDeleteProfile,
    required this.onMoveProfile,
  });

  final List<ServerProfile> profiles;
  final ServerProfile? selectedProfile;
  final Map<String, ServerProbeReport> reports;
  final bool Function(ServerProfile profile) isRefreshingProfile;
  final _HomeServerSummary Function(ServerProfile profile) summaryForProfile;
  final Future<void> Function(ServerProfile profile) onSelectProfile;
  final Future<void> Function(ServerProfile profile) onResumeProfile;
  final Future<void> Function(ServerProfile profile) onShowProfileDetails;
  final Future<void> Function(ServerProfile profile) onRefreshProfile;
  final Future<void> Function(ServerProfile profile) onEditProfile;
  final Future<void> Function(ServerProfile profile) onDeleteProfile;
  final Future<void> Function(String profileId, int offset) onMoveProfile;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return LayoutBuilder(
      builder: (context, panelConstraints) {
        final compact = panelConstraints.maxWidth < 620;
        final selected = selectedProfile == null
            ? null
            : profiles.cast<ServerProfile?>().firstWhere(
                (profile) => profile?.id == selectedProfile!.id,
                orElse: () => selectedProfile,
              );
        return _HomeSectionCard(
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.wp('Servers'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                context.wp(
                  'Pick a server first, then use the fixed actions below.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              if (profiles.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: surfaces.panelMuted.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.storage_rounded,
                            color: surfaces.muted,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.wp('No saved servers yet.'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          context.wp(
                            'Add your first server and it will start checking status automatically.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: surfaces.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      final profileSelected = selectedProfile?.id == profile.id;
                      return _ServerManagementCard(
                        key: ValueKey<String>('home-server-card-${profile.id}'),
                        keyNamespace: 'home-server',
                        profile: profile,
                        report: reports[profile.storageKey],
                        selected: profileSelected,
                        isRefreshing: isRefreshingProfile(profile),
                        canMoveUp: index > 0,
                        canMoveDown: index < profiles.length - 1,
                        showInlineActions: false,
                        footer: profileSelected
                            ? _HomeServerCardFooter(
                                summary: summaryForProfile(profile),
                              )
                            : null,
                        onSelect: () => unawaited(onSelectProfile(profile)),
                        onOpen: () => unawaited(onResumeProfile(profile)),
                        onRefresh: () => unawaited(onRefreshProfile(profile)),
                        onEdit: () => unawaited(onEditProfile(profile)),
                        onDelete: () => unawaited(onDeleteProfile(profile)),
                        onMoveUp: index > 0
                            ? () => unawaited(onMoveProfile(profile.id, -1))
                            : null,
                        onMoveDown: index < profiles.length - 1
                            ? () => unawaited(onMoveProfile(profile.id, 1))
                            : null,
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              _HomeServerActionBar(
                profile: selected,
                report: selected == null ? null : reports[selected.storageKey],
                isRefreshing: selected == null
                    ? false
                    : isRefreshingProfile(selected),
                onConnect: selected == null
                    ? null
                    : () => unawaited(onResumeProfile(selected)),
                onRefresh: selected == null
                    ? null
                    : () => unawaited(onRefreshProfile(selected)),
                onDetails: selected == null
                    ? null
                    : () => unawaited(onShowProfileDetails(selected)),
                onEdit: selected == null
                    ? null
                    : () => unawaited(onEditProfile(selected)),
                onDelete: selected == null
                    ? null
                    : () => unawaited(onDeleteProfile(selected)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeServerActionBar extends StatelessWidget {
  const _HomeServerActionBar({
    required this.profile,
    required this.report,
    required this.isRefreshing,
    required this.onConnect,
    required this.onRefresh,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  static const double _compactActionButtonHeight = 48;
  static const double _twoRowActionBreakpoint = 320;

  final ServerProfile? profile;
  final ServerProbeReport? report;
  final bool isRefreshing;
  final VoidCallback? onConnect;
  final VoidCallback? onRefresh;
  final VoidCallback? onDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final profile = this.profile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final title = profile == null
              ? Text(
                  context.wp('Select a server to connect or manage it.'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _StatusDot(report: report, busy: isRefreshing),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        profile.effectiveLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
          final actionButtons = <Widget>[
            FilledButton.icon(
              key: profile == null
                  ? null
                  : ValueKey<String>('home-server-resume-button-${profile.id}'),
              onPressed: onConnect,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(context.wp('Connect')),
            ),
            OutlinedButton.icon(
              onPressed: isRefreshing ? null : onRefresh,
              icon: isRefreshing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(context.wp('Refresh')),
            ),
            OutlinedButton.icon(
              key: profile == null
                  ? null
                  : ValueKey<String>(
                      'home-server-details-button-${profile.id}',
                    ),
              onPressed: onDetails,
              icon: const Icon(Icons.info_outline_rounded),
              label: Text(context.wp('Details')),
            ),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.wp('Edit')),
            ),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(context.wp('Delete')),
              style: OutlinedButton.styleFrom(foregroundColor: surfaces.danger),
            ),
          ];
          final actions = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            children: actionButtons,
          );
          final moreAction = PopupMenuButton<String>(
            enabled: profile != null,
            tooltip: context.wp('More'),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  if (!isRefreshing) {
                    onRefresh?.call();
                  }
                  break;
                case 'edit':
                  onEdit?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'refresh',
                enabled: onRefresh != null && !isRefreshing,
                child: Text(context.wp('Refresh')),
              ),
              PopupMenuItem<String>(
                value: 'edit',
                enabled: onEdit != null,
                child: Text(context.wp('Edit')),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                enabled: onDelete != null,
                child: Text(context.wp('Delete')),
              ),
            ],
            child: _HomeMoreActionButton(
              key: profile == null
                  ? null
                  : ValueKey<String>('home-server-more-button-${profile.id}'),
              enabled: profile != null,
            ),
          );
          final compactActions = constraints.maxWidth < _twoRowActionBreakpoint
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: _compactActionButtonHeight,
                      child: actionButtons[0],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: _compactActionButtonHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: actionButtons[2]),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: moreAction),
                        ],
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  height: _compactActionButtonHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 13, child: actionButtons[0]),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(flex: 12, child: actionButtons[2]),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(flex: 13, child: moreAction),
                    ],
                  ),
                );
          if (compact) {
            return compactActions;
          }
          return Row(
            children: <Widget>[
              Expanded(child: title),
              const SizedBox(width: AppSpacing.md),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HomeMoreActionButton extends StatelessWidget {
  const _HomeMoreActionButton({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final foreground = enabled ? colorScheme.primary : surfaces.muted;
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: surfaces.lineSoft),
        color: surfaces.panelMuted.withValues(alpha: enabled ? 0.44 : 0.24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.more_horiz_rounded, color: foreground, size: 20),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            context.wp('More'),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _HomeServerCardFooter extends StatelessWidget {
  const _HomeServerCardFooter({required this.summary});

  final _HomeServerSummary summary;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final badges = <Widget>[
      if (summary.paneCount > 0)
        _ServerMetaBadge(
          icon: Icons.splitscreen_rounded,
          label: context.wp(
            summary.paneCount == 1 ? '{count} pane' : '{count} panes',
            args: <String, Object?>{'count': summary.paneCount},
          ),
          tint: Theme.of(context).colorScheme.primary,
        ),
      if (summary.runningSessionCount > 0)
        _ServerMetaBadge(
          icon: Icons.bolt_rounded,
          label: context.wp(
            summary.runningSessionCount == 1
                ? '{count} running session'
                : '{count} running sessions',
            args: <String, Object?>{'count': summary.runningSessionCount},
          ),
          tint: surfaces.success,
        ),
      if (summary.totalTodoCount > 0)
        _ServerMetaBadge(
          icon: Icons.checklist_rtl_rounded,
          label: context.wp(
            '{done}/{total} todos',
            args: <String, Object?>{
              'done': summary.completedTodoCount,
              'total': summary.totalTodoCount,
            },
          ),
          tint: surfaces.warning,
        ),
      if ((summary.activeDirectory ?? '').isNotEmpty)
        _ServerMetaBadge(
          icon: Icons.folder_open_rounded,
          label: projectDisplayLabel(summary.activeDirectory!),
          tint: surfaces.muted,
        ),
    ];
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: badges,
    );
  }
}

class _HomeServerDetailPanel extends StatelessWidget {
  const _HomeServerDetailPanel({
    required this.embeddedInPage,
    required this.profile,
    required this.report,
    required this.summary,
    required this.activityLoading,
    required this.runningSessions,
    required this.paneSnapshots,
    required this.projectTargets,
    required this.onResumeWorkspace,
    required this.onEditServer,
    required this.onCopyConnectLink,
    required this.onOpenProjectPicker,
    required this.onOpenProject,
  });

  final bool embeddedInPage;
  final ServerProfile? profile;
  final ServerProbeReport? report;
  final _HomeServerSummary? summary;
  final bool activityLoading;
  final List<_HomeRunningSession> runningSessions;
  final List<_HomePaneSnapshot> paneSnapshots;
  final List<ProjectTarget> projectTargets;
  final VoidCallback? onResumeWorkspace;
  final VoidCallback? onEditServer;
  final VoidCallback? onCopyConnectLink;
  final VoidCallback? onOpenProjectPicker;
  final ValueChanged<ProjectTarget>? onOpenProject;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    if (profile == null) {
      return _HomeSectionCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: surfaces.panelMuted.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  size: 32,
                  color: surfaces.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.wp('Select a server'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.wp(
                  'Inspect its status and restore the workspace you were last using.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final meta = _serverMetaItems(context, profile!, report);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = constraints.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (compactHeader)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HomeServerDetailIdentity(
                    profile: profile!,
                    report: report,
                    meta: meta,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HomeServerDetailActions(
                    profileId: profile!.id,
                    paneCount: summary?.paneCount ?? 0,
                    onResumeWorkspace: onResumeWorkspace,
                    onEditServer: onEditServer,
                    onCopyConnectLink: onCopyConnectLink,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _HomeServerDetailIdentity(
                      profile: profile!,
                      report: report,
                      meta: meta,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _HomeServerDetailActions(
                    profileId: profile!.id,
                    paneCount: summary?.paneCount ?? 0,
                    onResumeWorkspace: onResumeWorkspace,
                    onEditServer: onEditServer,
                    onCopyConnectLink: onCopyConnectLink,
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            _HomeDetailSection(
              title: context.wp('Workspace'),
              subtitle: context.wp(
                'This is the last remembered pane layout for the selected server.',
              ),
              child: paneSnapshots.isEmpty
                  ? _HomeEmptyStateText(
                      message: context.wp(
                        'No remembered workspace yet. Open a project and the layout will appear here.',
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: paneSnapshots
                          .map((pane) => _HomePaneCard(pane: pane))
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _HomeDetailSection(
              title: context.wp('Running Now'),
              subtitle: context.wp(
                'Best-effort activity from the projects in your remembered workspace.',
              ),
              child: activityLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : runningSessions.isEmpty
                  ? _HomeEmptyStateText(
                      message: context.wp(
                        'No active agent sessions were found in the remembered projects.',
                      ),
                    )
                  : Column(
                      children: runningSessions
                          .map(
                            (session) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: _HomeRunningSessionCard(session: session),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _HomeDetailSection(
              title: context.wp('Projects'),
              subtitle: context.wp(
                'Jump into a project directly, or add another one from the server like a quick action tile.',
              ),
              child: projectTargets.isEmpty
                  ? _HomeAddProjectTile(
                      onTap: onOpenProjectPicker,
                      expanded: true,
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        _HomeAddProjectTile(onTap: onOpenProjectPicker),
                        ...projectTargets.map(
                          (target) => ActionChip(
                            avatar: const Icon(Icons.folder_outlined, size: 18),
                            label: Text(target.title),
                            onPressed: onOpenProject == null
                                ? null
                                : () => onOpenProject!(target),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
    return _HomeSectionCard(
      child: embeddedInPage ? content : SingleChildScrollView(child: content),
    );
  }
}

class _HomeServerDetailIdentity extends StatelessWidget {
  const _HomeServerDetailIdentity({
    required this.profile,
    required this.report,
    required this.meta,
  });

  final ServerProfile profile;
  final ServerProbeReport? report;
  final List<_ServerMetaItem> meta;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: surfaces.panelMuted.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          ),
          child: Text(
            context.wp('Selected server'),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: surfaces.muted),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                profile.effectiveLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ServerStatusBadge(report: report),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          profile.normalizedBaseUrl,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: meta
              .map(
                (item) => _ServerMetaBadge(
                  icon: item.icon,
                  label: item.label,
                  tint: item.tint,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _HomeServerDetailActions extends StatelessWidget {
  const _HomeServerDetailActions({
    required this.profileId,
    required this.paneCount,
    required this.onResumeWorkspace,
    required this.onEditServer,
    required this.onCopyConnectLink,
  });

  final String profileId;
  final int paneCount;
  final VoidCallback? onResumeWorkspace;
  final VoidCallback? onEditServer;
  final VoidCallback? onCopyConnectLink;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        final resumeLabel = paneCount > 1
            ? context.wp(
                'Resume {count} Panes',
                args: <String, Object?>{'count': paneCount},
              )
            : context.wp('Resume Workspace');
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton.icon(
                key: ValueKey<String>('home-server-resume-button-$profileId'),
                onPressed: onResumeWorkspace,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(resumeLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onEditServer,
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.wp('Edit Server')),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onCopyConnectLink,
                icon: const Icon(Icons.link_rounded),
                label: Text(context.wp('Copy Link')),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            FilledButton.icon(
              key: ValueKey<String>('home-server-resume-button-$profileId'),
              onPressed: onResumeWorkspace,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(resumeLabel),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onEditServer,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.wp('Edit Server')),
                ),
                OutlinedButton.icon(
                  onPressed: onCopyConnectLink,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(context.wp('Copy Link')),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      radius: AppSpacing.cardRadius,
      blur: 10,
      backgroundOpacity: 0.88,
      borderOpacity: 0.06,
      showShadow: false,
      padding: padding,
      child: child,
    );
  }
}

class _HomeDetailSection extends StatelessWidget {
  const _HomeDetailSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: appSoftCardDecoration(
        context,
        radius: AppSpacing.panelRadius,
        muted: true,
        emphasized: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _HomePaneCard extends StatelessWidget {
  const _HomePaneCard({required this.pane});

  final _HomePaneSnapshot pane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      key: ValueKey<String>('home-pane-card-${pane.paneId}'),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      decoration: appSoftCardDecoration(
        context,
        radius: AppSpacing.panelRadius,
        tone: AppSurfaceTone.accent,
        muted: !pane.active,
        selected: pane.active,
        emphasized: pane.active,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: surfaces.panelMuted.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: surfaces.lineSoft),
                  ),
                  child: Icon(
                    Icons.dashboard_customize_outlined,
                    size: 18,
                    color: pane.active
                        ? theme.colorScheme.primary
                        : surfaces.muted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pane.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: surfaces.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (pane.active)
                  _ServerMetaBadge(
                    icon: Icons.radio_button_checked_rounded,
                    label: context.wp('Active'),
                    tint: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              pane.projectLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              pane.directory,
              style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              pane.sessionTitle,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((pane.status ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _ServerMetaBadge(
                icon: Icons.timelapse_rounded,
                label: _statusTextForSession(context, pane.status),
                tint: _sessionStatusTint(context, pane.status),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeRunningSessionCard extends StatelessWidget {
  const _HomeRunningSessionCard({required this.session});

  final _HomeRunningSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      key: ValueKey<String>('home-running-session-${session.sessionId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: appSoftCardDecoration(
        context,
        radius: AppSpacing.lg,
        muted: true,
        emphasized: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: surfaces.panelMuted.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: surfaces.lineSoft),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: _sessionStatusTint(context, session.status),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.sessionTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${session.projectLabel}  •  ${session.directory}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _ServerMetaBadge(
                icon: Icons.bolt_rounded,
                label: _statusTextForSession(context, session.status),
                tint: _sessionStatusTint(context, session.status),
              ),
            ],
          ),
          if (session.totalTodoCount > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: session.completedTodoCount / session.totalTodoCount,
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.wp(
                '{done}/{total} todos complete',
                args: <String, Object?>{
                  'done': session.completedTodoCount,
                  'total': session.totalTodoCount,
                },
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeAddProjectTile extends StatelessWidget {
  const _HomeAddProjectTile({required this.onTap, this.expanded = false});

  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('home-server-project-add-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Ink(
          width: expanded ? double.infinity : 156,
          height: 56,
          decoration: appSoftCardDecoration(
            context,
            radius: AppSpacing.lg,
            tone: AppSurfaceTone.accent,
            muted: !enabled,
            selected: enabled,
            emphasized: true,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.add_rounded,
                      color: enabled
                          ? Theme.of(context).colorScheme.primary
                          : surfaces.muted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      context.wp('Add Project'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: enabled
                            ? Theme.of(context).colorScheme.primary
                            : surfaces.muted,
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

class _HomeEmptyStateText extends StatelessWidget {
  const _HomeEmptyStateText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: surfaces.muted, height: 1.45),
    );
  }
}
