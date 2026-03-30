import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_routes.dart';
import '../../app/app_scope.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';
import '../../i18n/web_parity_localizations.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import 'project_picker_sheet.dart';
import 'workspace_controller.dart';
import 'workspace_layout_store.dart';

class WebParityHomeScreen extends StatefulWidget {
  const WebParityHomeScreen({
    required this.flavor,
    required this.localeController,
    this.projectStore,
    this.projectCatalogService,
    super.key,
  });

  final AppFlavor flavor;
  final LocaleController localeController;
  final ProjectStore? projectStore;
  final ProjectCatalogService? projectCatalogService;

  @override
  State<WebParityHomeScreen> createState() => _WebParityHomeScreenState();
}

class _WebParityHomeScreenState extends State<WebParityHomeScreen> {
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

    final target = await showModalBottomSheet<ProjectTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ProjectPickerSheet(
          profile: profile,
          projectCatalogService: widget.projectCatalogService,
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

  String _workspaceStateSignature(WebParityAppController controller) {
    final buffer = StringBuffer()..write('loading=${controller.loading};');
    for (final profile in controller.profiles) {
      buffer
        ..write(profile.storageKey)
        ..write('::');
      final layout = controller.workspacePaneLayoutFor(profile);
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
    final layout = _layoutForProfile(controller, profile);
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
    final layout = _layoutForProfile(controller, profile);
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
    return _layoutForProfile(controller, profile)?.activePane;
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
    final draft = await showModalBottomSheet<ServerProfile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _ServerEditorSheet(initialProfile: profile),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.wp('Delete server?')),
        content: Text(
          context.wp(
            'Remove "{label}" from saved servers? This keeps the rest of your home screen intact.',
            args: <String, Object?>{'label': profile.effectiveLabel},
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.wp('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.wp('Delete')),
          ),
        ],
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
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.84,
        child: _ServersSheet(controller: controller),
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
    final layout = _layoutForProfile(controller, profile);
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
    final layout = _layoutForProfile(controller, profile);
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
    final layout = _layoutForProfile(controller, profile);
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
        _scheduleWorkspaceStateSyncIfNeeded(controller);
        final selectedProfile = controller.selectedProfile;
        final selectedReport = controller.selectedReport;
        final selectedSummary = selectedProfile == null
            ? null
            : _serverSummaryForProfile(controller, selectedProfile);
        final selectedRunningSessions = selectedProfile == null
            ? const <_HomeRunningSession>[]
            : _runningSessionsForProfile(controller, selectedProfile);
        final selectedPaneSnapshots = selectedProfile == null
            ? const <_HomePaneSnapshot>[]
            : _paneSnapshotsForProfile(controller, selectedProfile);
        final selectedProjectTargets = selectedProfile == null
            ? const <ProjectTarget>[]
            : _projectTargetsForProfile(controller, selectedProfile);
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  surfaces.background,
                  Color.alphaBlend(
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                    surfaces.panel,
                  ),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600
                      ? AppSpacing.md
                      : AppSpacing.lg,
                ),
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1180;
                              final compactHome =
                                  constraints.maxWidth < 600 ||
                                  constraints.maxHeight < 700;
                              final compactHeader = constraints.maxWidth < 720;
                              final serverListPanel = _HomeServerListPanel(
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
                                onOpenServers: () => _openServers(controller),
                                onAddServer: () =>
                                    _openServerEditor(controller),
                                onRefreshProfile: controller.refreshProbe,
                                onEditProfile: (profile) => _openServerEditor(
                                  controller,
                                  profile: profile,
                                ),
                                onDeleteProfile: (profile) =>
                                    _confirmDeleteServer(controller, profile),
                                onMoveProfile: controller.moveProfile,
                              );
                              final detailPanel = _HomeServerDetailPanel(
                                profile: selectedProfile,
                                report: selectedReport,
                                summary: selectedSummary,
                                activityLoading: selectedProfile == null
                                    ? false
                                    : _isServerActivityLoading(
                                        controller,
                                        selectedProfile,
                                      ),
                                runningSessions: selectedRunningSessions,
                                paneSnapshots: selectedPaneSnapshots,
                                projectTargets: selectedProjectTargets,
                                onResumeWorkspace: selectedProfile == null
                                    ? null
                                    : () => _resumeWorkspace(
                                        controller,
                                        selectedProfile,
                                      ),
                                onEditServer: selectedProfile == null
                                    ? null
                                    : () => _openServerEditor(
                                        controller,
                                        profile: selectedProfile,
                                      ),
                                onOpenProjectPicker: selectedProfile == null
                                    ? null
                                    : () => _openProjectPicker(
                                        controller,
                                        selectedProfile,
                                      ),
                                onOpenProject: selectedProfile == null
                                    ? null
                                    : (target) => _openRecentProject(
                                        controller,
                                        selectedProfile,
                                        target,
                                      ),
                              );
                              final headerSection = compactHeader
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          context.wp('Servers'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.xxs,
                                        ),
                                        Text(
                                          context.wp(
                                            'Choose a server, inspect its current status, and jump back into the exact workspace layout you were using last.',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: surfaces.muted,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.md,
                                        ),
                                        Wrap(
                                          spacing: AppSpacing.sm,
                                          runSpacing: AppSpacing.sm,
                                          children: <Widget>[
                                            _ServerPill(
                                              profile: selectedProfile,
                                              report: selectedReport,
                                              onTap: () =>
                                                  _openServers(controller),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openServers(controller),
                                              icon: const Icon(
                                                Icons.storage_rounded,
                                              ),
                                              label: Text(
                                                context.wp('See Servers'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                context.wp('Servers'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xxs,
                                              ),
                                              Text(
                                                context.wp(
                                                  'Choose a server, inspect its current status, and jump back into the exact workspace layout you were using last.',
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color: surfaces.muted,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.lg),
                                        Wrap(
                                          spacing: AppSpacing.sm,
                                          runSpacing: AppSpacing.sm,
                                          children: <Widget>[
                                            _ServerPill(
                                              profile: selectedProfile,
                                              report: selectedReport,
                                              onTap: () =>
                                                  _openServers(controller),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openServers(controller),
                                              icon: const Icon(
                                                Icons.storage_rounded,
                                              ),
                                              label: Text(
                                                context.wp('See Servers'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                              final contentSection = wide
                                  ? Row(
                                      children: <Widget>[
                                        Flexible(
                                          flex: 4,
                                          child: serverListPanel,
                                        ),
                                        const SizedBox(width: AppSpacing.lg),
                                        Flexible(
                                          flex: 6,
                                          child: detailPanel,
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: <Widget>[
                                        Expanded(
                                          flex: 4,
                                          child: serverListPanel,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.lg,
                                        ),
                                        Expanded(
                                          flex: 6,
                                          child: detailPanel,
                                        ),
                                      ],
                                    );
                              if (compactHome) {
                                final listPanelHeight = (constraints.maxHeight *
                                        0.7)
                                    .clamp(320.0, 440.0)
                                    .toDouble();
                                final detailPanelHeight =
                                    (constraints.maxHeight * 1.05)
                                        .clamp(460.0, 760.0)
                                        .toDouble();
                                return SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      headerSection,
                                      const SizedBox(height: AppSpacing.lg),
                                      SizedBox(
                                        height: listPanelHeight,
                                        child: serverListPanel,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      SizedBox(
                                        height: detailPanelHeight,
                                        child: detailPanel,
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  headerSection,
                                  const SizedBox(height: AppSpacing.lg),
                                  Expanded(child: contentSection),
                                ],
                              );
                            },
                          ),
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

class _HomeServerListPanel extends StatelessWidget {
  const _HomeServerListPanel({
    required this.profiles,
    required this.selectedProfile,
    required this.reports,
    required this.isRefreshingProfile,
    required this.summaryForProfile,
    required this.onSelectProfile,
    required this.onOpenServers,
    required this.onAddServer,
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
  final VoidCallback onOpenServers;
  final Future<void> Function() onAddServer;
  final Future<void> Function(ServerProfile profile) onRefreshProfile;
  final Future<void> Function(ServerProfile profile) onEditProfile;
  final Future<void> Function(ServerProfile profile) onDeleteProfile;
  final Future<void> Function(String profileId, int offset) onMoveProfile;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 420;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.wp('Servers'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.wp(
                      'Saved servers stay visible here, with status and workspace summaries attached.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: onOpenServers,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(context.wp('Manage')),
                  ),
                  FilledButton.icon(
                    key: const ValueKey<String>('home-add-server-button'),
                    onPressed: () => unawaited(onAddServer()),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.wp('Add Server')),
                  ),
                ],
              );
              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    titleBlock,
                    const SizedBox(height: AppSpacing.md),
                    actions,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: titleBlock),
                  const SizedBox(width: AppSpacing.md),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (profiles.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  context.wp(
                    'No saved servers yet. Add your first server to start tracking its workspace.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: profiles.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final selected = selectedProfile?.id == profile.id;
                  return _ServerManagementCard(
                    key: ValueKey<String>('home-server-card-${profile.id}'),
                    keyNamespace: 'home-server',
                    profile: profile,
                    report: reports[profile.storageKey],
                    selected: selected,
                    isRefreshing: isRefreshingProfile(profile),
                    canMoveUp: index > 0,
                    canMoveDown: index < profiles.length - 1,
                    footer: _HomeServerCardFooter(
                      summary: summaryForProfile(profile),
                    ),
                    onSelect: () => unawaited(onSelectProfile(profile)),
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
    required this.profile,
    required this.report,
    required this.summary,
    required this.activityLoading,
    required this.runningSessions,
    required this.paneSnapshots,
    required this.projectTargets,
    required this.onResumeWorkspace,
    required this.onEditServer,
    required this.onOpenProjectPicker,
    required this.onOpenProject,
  });

  final ServerProfile? profile;
  final ServerProbeReport? report;
  final _HomeServerSummary? summary;
  final bool activityLoading;
  final List<_HomeRunningSession> runningSessions;
  final List<_HomePaneSnapshot> paneSnapshots;
  final List<ProjectTarget> projectTargets;
  final VoidCallback? onResumeWorkspace;
  final VoidCallback? onEditServer;
  final VoidCallback? onOpenProjectPicker;
  final ValueChanged<ProjectTarget>? onOpenProject;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    if (profile == null) {
      return _HomeSectionCard(
        child: Center(
          child: Text(
            context.wp(
              'Select a server to inspect its status and restore its workspace.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final meta = _serverMetaItems(context, profile!, report);
    return _HomeSectionCard(
      child: SingleChildScrollView(
        child: LayoutBuilder(
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
                      const SizedBox(width: AppSpacing.lg),
                      _HomeServerDetailActions(
                        profileId: profile!.id,
                        paneCount: summary?.paneCount ?? 0,
                        onResumeWorkspace: onResumeWorkspace,
                        onEditServer: onEditServer,
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                _HomeDetailSection(
                  title: context.wp('Workspace'),
                  subtitle: context.wp(
                    'This is the last remembered pane layout for the selected server.',
                  ),
                  child: paneSnapshots.isEmpty
                      ? Text(
                          context.wp(
                            'No remembered workspace yet. Open a project and the layout will appear here.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: surfaces.muted),
                        )
                      : Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: paneSnapshots
                              .map((pane) => _HomePaneCard(pane: pane))
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _HomeDetailSection(
                  title: context.wp('Running Now'),
                  subtitle: context.wp(
                    'Best-effort activity from the projects in your remembered workspace.',
                  ),
                  child: activityLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : runningSessions.isEmpty
                      ? Text(
                          context.wp(
                            'No active agent sessions were found in the remembered projects.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: surfaces.muted),
                        )
                      : Column(
                          children: runningSessions
                              .map(
                                (session) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _HomeRunningSessionCard(
                                    session: session,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _HomeDetailSection(
                  title: context.wp('Projects'),
                  subtitle: context.wp(
                    'Jump into a project directly, or add another one from the server like a quick action tile.',
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
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
        ),
      ),
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
  });

  final String profileId;
  final int paneCount;
  final VoidCallback? onResumeWorkspace;
  final VoidCallback? onEditServer;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.end,
      children: <Widget>[
        FilledButton.icon(
          key: ValueKey<String>('home-server-resume-button-$profileId'),
          onPressed: onResumeWorkspace,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            paneCount > 1
                ? context.wp(
                    'Resume {count} Panes',
                    args: <String, Object?>{'count': paneCount},
                  )
                : context.wp('Resume Workspace'),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onEditServer,
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.wp('Edit Server')),
        ),
      ],
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _HomePaneCard extends StatelessWidget {
  const _HomePaneCard({required this.pane});

  final _HomePaneSnapshot pane;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      key: ValueKey<String>('home-pane-card-${pane.paneId}'),
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: pane.active
            ? Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                surfaces.panel,
              )
            : surfaces.panel,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(
          color: pane.active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.42)
              : surfaces.lineSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  pane.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: surfaces.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (pane.active)
                _ServerMetaBadge(
                  icon: Icons.radio_button_checked_rounded,
                  label: context.wp('Active'),
                  tint: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            pane.projectLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            pane.directory,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            pane.sessionTitle,
            style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}

class _HomeRunningSessionCard extends StatelessWidget {
  const _HomeRunningSessionCard({required this.session});

  final _HomeRunningSession session;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      key: ValueKey<String>('home-running-session-${session.sessionId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: surfaces.lineSoft),
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
                      session.sessionTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${session.projectLabel}  •  ${session.directory}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
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
  const _HomeAddProjectTile({required this.onTap});

  final VoidCallback? onTap;

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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: enabled
                ? surfaces.panel
                : surfaces.panel.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(
              color: enabled
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                  : surfaces.lineSoft,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : surfaces.muted,
          ),
        ),
      ),
    );
  }
}

class _ServerPill extends StatelessWidget {
  const _ServerPill({
    required this.profile,
    required this.report,
    required this.onTap,
  });

  final ServerProfile? profile;
  final ServerProbeReport? report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final color = switch (report?.classification) {
      ConnectionProbeClassification.ready => surfaces.success,
      ConnectionProbeClassification.authFailure => Theme.of(
        context,
      ).colorScheme.secondary,
      ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
      ConnectionProbeClassification.specFetchFailure => surfaces.warning,
      ConnectionProbeClassification.connectivityFailure => surfaces.danger,
      null => surfaces.muted,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: surfaces.panelRaised.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(color: surfaces.lineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(profile?.effectiveLabel ?? context.wp('Select Server')),
          ],
        ),
      ),
    );
  }
}

class _ServersSheet extends StatefulWidget {
  const _ServersSheet({required this.controller});

  final WebParityAppController controller;

  @override
  State<_ServersSheet> createState() => _ServersSheetState();
}

class _ServersSheetState extends State<_ServersSheet> {
  WebParityAppController get controller => widget.controller;

  Future<void> _openServerEditor({ServerProfile? profile}) async {
    final draft = await showModalBottomSheet<ServerProfile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _ServerEditorSheet(initialProfile: profile),
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

  Future<void> _confirmDelete(ServerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.wp('Delete server?')),
        content: Text(
          context.wp(
            'Remove "{label}" from saved servers? This keeps the rest of your home screen intact.',
            args: <String, Object?>{'label': profile.effectiveLabel},
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.wp('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.wp('Delete')),
          ),
        ],
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

  Future<void> _moveProfile(ServerProfile profile, int offset) async {
    await controller.moveProfile(profile.id, offset);
  }

  Future<void> _refreshAll() async {
    for (final profile in controller.profiles) {
      await controller.refreshProbe(profile);
    }
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp('Refreshed saved server status.'),
      tone: AppSnackBarTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final profiles = controller.profiles;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.wp('See Servers'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.wp('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  IconButton(
                    tooltip: context.wp('Refresh all statuses'),
                    onPressed: profiles.isEmpty ? null : _refreshAll,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    key: const ValueKey<String>('servers-sheet-add-button'),
                    onPressed: _openServerEditor,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.wp('Add Server')),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.wp(
                  'Choose the active server, edit saved entries, reorder them, and keep connection status visible here.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: profiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.storage_rounded,
                              size: 34,
                              color: surfaces.muted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              context.wp('No saved servers yet.'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              context.wp(
                                'Add your first OpenCode server here and it will immediately be ready for project browsing.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: surfaces.muted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final report = controller.reports[profile.storageKey];
                          final selected =
                              controller.selectedProfile?.id == profile.id;
                          return _ServerManagementCard(
                            key: ValueKey<String>(
                              'servers-sheet-card-${profile.id}',
                            ),
                            profile: profile,
                            report: report,
                            selected: selected,
                            isRefreshing: controller.isRefreshingProfile(
                              profile,
                            ),
                            canMoveUp: index > 0,
                            canMoveDown: index < profiles.length - 1,
                            onSelect: () => controller.selectProfile(profile),
                            onRefresh: () => controller.refreshProbe(profile),
                            onEdit: () => _openServerEditor(profile: profile),
                            onDelete: () => _confirmDelete(profile),
                            onMoveUp: index > 0
                                ? () => _moveProfile(profile, -1)
                                : null,
                            onMoveDown: index < profiles.length - 1
                                ? () => _moveProfile(profile, 1)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerManagementCard extends StatelessWidget {
  const _ServerManagementCard({
    required this.profile,
    required this.report,
    required this.selected,
    required this.isRefreshing,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onSelect,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    this.keyNamespace = 'servers-sheet',
    this.footer,
    super.key,
  });

  final ServerProfile profile;
  final ServerProbeReport? report;
  final bool selected;
  final bool isRefreshing;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String keyNamespace;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final meta = _serverMetaItems(context, profile, report);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.09),
                    surfaces.panelRaised,
                  )
                : surfaces.panelRaised.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : surfaces.lineSoft,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _StatusDot(report: report, busy: isRefreshing),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compactBadges = constraints.maxWidth < 220;
                              final title = Text(
                                profile.effectiveLabel,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                              final badges = Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: <Widget>[
                                  _ServerStatusBadge(report: report),
                                  if (selected)
                                    _ServerMetaBadge(
                                      icon: Icons.check_circle_rounded,
                                      label: context.wp('Active'),
                                      tint: Theme.of(context).colorScheme.primary,
                                    ),
                                ],
                              );
                              if (compactBadges) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    title,
                                    const SizedBox(height: AppSpacing.xxs),
                                    badges,
                                  ],
                                );
                              }
                              return Row(
                                children: <Widget>[
                                  Expanded(child: title),
                                  const SizedBox(width: AppSpacing.xs),
                                  badges,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            profile.normalizedBaseUrl,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: surfaces.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                if (footer != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  footer!,
                ],
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final actionButtons = <Widget>[
                      IconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-refresh-${profile.id}',
                        ),
                        tooltip: context.wp('Refresh status'),
                        onPressed: isRefreshing ? null : onRefresh,
                        icon: isRefreshing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-move-up-${profile.id}',
                        ),
                        tooltip: context.wp('Move up'),
                        onPressed: onMoveUp,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-move-down-${profile.id}',
                        ),
                        tooltip: context.wp('Move down'),
                        onPressed: onMoveDown,
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-edit-${profile.id}',
                        ),
                        tooltip: context.wp('Edit server'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-delete-${profile.id}',
                        ),
                        tooltip: context.wp('Delete server'),
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ];
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextButton.icon(
                            key: ValueKey<String>(
                              '$keyNamespace-select-${profile.id}',
                            ),
                            onPressed: onSelect,
                            icon: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                            ),
                            label: Text(
                              selected
                                  ? context.wp('Selected')
                                  : context.wp('Use This Server'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: AppSpacing.xs,
                              children: actionButtons,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: ValueKey<String>(
                                '$keyNamespace-select-${profile.id}',
                              ),
                              onPressed: onSelect,
                              icon: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                              ),
                              label: Text(
                                selected
                                    ? context.wp('Selected')
                                    : context.wp('Use This Server'),
                              ),
                            ),
                          ),
                        ),
                        ...actionButtons,
                      ],
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

class _ServerEditorSheet extends StatefulWidget {
  const _ServerEditorSheet({this.initialProfile});

  final ServerProfile? initialProfile;

  @override
  State<_ServerEditorSheet> createState() => _ServerEditorSheetState();
}

class _ServerEditorSheetState extends State<_ServerEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _labelController = TextEditingController(text: profile?.label ?? '');
    _baseUrlController = TextEditingController(
      text: profile?.normalizedBaseUrl ?? '',
    );
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController(text: profile?.password ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final existing = widget.initialProfile;
    final profile = ServerProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      username: _optionalValue(_usernameController.text),
      password: _optionalValue(_passwordController.text),
    );
    Navigator.of(context).pop(profile);
  }

  String? _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateAddress(String? value) {
    final draft = ServerProfile(id: 'draft', label: '', baseUrl: value ?? '');
    final uri = draft.uriOrNull;
    if (uri == null || uri.host.isEmpty) {
      return context.wp('Enter a valid server address.');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final editingExisting = widget.initialProfile != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Text(
              editingExisting
                  ? context.wp('Edit Server')
                  : context.wp('Add Server'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.wp(
                'Save the server here and its status will be checked immediately.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const ValueKey<String>('servers-editor-label-field'),
              controller: _labelController,
              decoration: InputDecoration(
                labelText: context.wp('Label'),
                hintText: context.wp('Studio'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('servers-editor-url-field'),
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.wp('Server URL'),
                hintText: context.wp('https://studio.example.com'),
              ),
              validator: _validateAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('servers-editor-username-field'),
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: context.wp('Username'),
                hintText: context.wp('Optional'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('servers-editor-password-field'),
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: context.wp('Password'),
                hintText: context.wp('Optional'),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.wp('Cancel')),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('servers-editor-save-button'),
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      editingExisting
                          ? context.wp('Save Changes')
                          : context.wp('Save Server'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerMetaItem {
  const _ServerMetaItem({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;
}

class _ServerMetaBadge extends StatelessWidget {
  const _ServerMetaBadge({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final accent = tint ?? surfaces.panelMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerStatusBadge extends StatelessWidget {
  const _ServerStatusBadge({required this.report});

  final ServerProbeReport? report;

  @override
  Widget build(BuildContext context) {
    return _ServerMetaBadge(
      icon: _statusIconData(report),
      label: _statusLabel(context, report),
      tint: _statusColor(context, report),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.report, this.busy = false});

  final ServerProbeReport? report;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, report);
    if (busy) {
      return SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

List<_ServerMetaItem> _serverMetaItems(
  BuildContext context,
  ServerProfile profile,
  ServerProbeReport? report,
) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  final items = <_ServerMetaItem>[];
  final snapshotName = report?.snapshot.name.trim() ?? '';
  if (snapshotName.isNotEmpty &&
      snapshotName.toLowerCase() != profile.effectiveLabel.toLowerCase()) {
    items.add(
      _ServerMetaItem(
        icon: Icons.memory_rounded,
        label: snapshotName,
        tint: surfaces.accentSoft,
      ),
    );
  }
  final version = report?.snapshot.version.trim() ?? '';
  if (version.isNotEmpty && version.toLowerCase() != 'unknown') {
    items.add(
      _ServerMetaItem(
        icon: Icons.tag_rounded,
        label: context.wp(
          'v{version}',
          args: <String, Object?>{'version': version},
        ),
        tint: Theme.of(context).colorScheme.primary,
      ),
    );
  }
  final username = profile.username?.trim();
  if (username != null && username.isNotEmpty) {
    items.add(
      _ServerMetaItem(
        icon: Icons.person_outline_rounded,
        label: username,
        tint: surfaces.muted,
      ),
    );
  } else if (report?.requiresBasicAuth == true) {
    items.add(
      _ServerMetaItem(
        icon: Icons.lock_outline_rounded,
        label: context.wp('Basic Auth'),
        tint: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
  if (report != null) {
    items.add(
      _ServerMetaItem(
        icon: Icons.schedule_rounded,
        label: _checkedAtLabel(context, report.checkedAt),
        tint: surfaces.muted,
      ),
    );
  } else {
    items.add(
      _ServerMetaItem(
        icon: Icons.schedule_rounded,
        label: context.wp('Not checked yet'),
        tint: surfaces.muted,
      ),
    );
  }
  return items;
}

String _statusLabel(BuildContext context, ServerProbeReport? report) {
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => context.wp('Ready'),
    ConnectionProbeClassification.authFailure => context.wp('Sign In'),
    ConnectionProbeClassification.unsupportedCapabilities =>
      context.wp('Needs Update'),
    ConnectionProbeClassification.specFetchFailure => context.wp('Unavailable'),
    ConnectionProbeClassification.connectivityFailure => context.wp('Offline'),
    null => context.wp('Unknown'),
  };
}

IconData _statusIconData(ServerProbeReport? report) {
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => Icons.check_circle_rounded,
    ConnectionProbeClassification.authFailure => Icons.lock_outline_rounded,
    ConnectionProbeClassification.unsupportedCapabilities =>
      Icons.warning_amber_rounded,
    ConnectionProbeClassification.specFetchFailure =>
      Icons.error_outline_rounded,
    ConnectionProbeClassification.connectivityFailure => Icons.wifi_off_rounded,
    null => Icons.help_outline_rounded,
  };
}

Color _statusColor(BuildContext context, ServerProbeReport? report) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => surfaces.success,
    ConnectionProbeClassification.authFailure => Theme.of(
      context,
    ).colorScheme.secondary,
    ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
    ConnectionProbeClassification.specFetchFailure => surfaces.warning,
    ConnectionProbeClassification.connectivityFailure => surfaces.danger,
    null => surfaces.muted,
  };
}

String _statusTextForSession(BuildContext context, String? status) {
  final normalized = status?.trim().toLowerCase() ?? 'idle';
  return switch (normalized) {
    'running' => context.wp('Running'),
    'completed' => context.wp('Completed'),
    'error' => context.wp('Error'),
    'pending' => context.wp('Pending'),
    'queued' => context.wp('Queued'),
    'starting' => context.wp('Starting'),
    'steering' => context.wp('Steering'),
    'waiting' => context.wp('Waiting'),
    'idle' => context.wp('Idle'),
    _ =>
      normalized.isEmpty
          ? context.wp('Idle')
          : '${normalized[0].toUpperCase()}${normalized.substring(1)}',
  };
}

Color _sessionStatusTint(BuildContext context, String? status) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  return switch (status?.trim().toLowerCase()) {
    'completed' => surfaces.success,
    'error' => surfaces.danger,
    'idle' => surfaces.muted,
    _ => Theme.of(context).colorScheme.primary,
  };
}

String _checkedAtLabel(BuildContext context, DateTime checkedAt) {
  final localizations = MaterialLocalizations.of(context);
  final time = TimeOfDay.fromDateTime(checkedAt);
  return context.wp(
    'Checked {time}',
    args: <String, Object?>{'time': localizations.formatTimeOfDay(time)},
  );
}
