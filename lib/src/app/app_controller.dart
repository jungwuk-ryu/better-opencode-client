import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/connection/connection_models.dart';
import '../core/network/opencode_server_probe.dart';
import '../core/persistence/server_profile_store.dart';
import '../core/persistence/stale_cache_store.dart';
import '../features/projects/project_models.dart';
import '../features/projects/project_store.dart';
import '../features/web_parity/workspace_controller.dart';

typedef WorkspaceControllerFactory =
    WorkspaceController Function({
      required ServerProfile profile,
      required String directory,
      String? initialSessionId,
    });

WorkspaceController _defaultWorkspaceControllerFactory({
  required ServerProfile profile,
  required String directory,
  String? initialSessionId,
}) {
  return WorkspaceController(
    profile: profile,
    directory: directory,
    initialSessionId: initialSessionId,
  );
}

enum WorkspaceLayoutDensity {
  normal,
  compact;

  String get storageValue => name;

  static WorkspaceLayoutDensity fromStorage(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'compact' => WorkspaceLayoutDensity.compact,
      _ => WorkspaceLayoutDensity.normal,
    };
  }
}

class WebParityAppController extends ChangeNotifier {
  WebParityAppController({
    ServerProfileStore? profileStore,
    ProjectStore? projectStore,
    StaleCacheStore? cacheStore,
    OpenCodeServerProbe? probeService,
    WorkspaceControllerFactory? workspaceControllerFactory,
  }) : _profileStore = profileStore ?? ServerProfileStore(),
       _projectStore = projectStore ?? ProjectStore(),
       _cacheStore = cacheStore ?? StaleCacheStore(),
       _probeService = probeService ?? OpenCodeServerProbe(),
       _workspaceControllerFactory =
           workspaceControllerFactory ?? _defaultWorkspaceControllerFactory;

  static const _selectedProfileKey = 'web_parity.selected_profile';
  static const _shellToolPartsExpandedKey =
      'web_parity.shell_tool_parts_expanded';
  static const _timelineProgressDetailsVisibleKey =
      'web_parity.timeline_progress_details_visible';
  static const _sidebarChildSessionsVisibleKey =
      'web_parity.sidebar_child_sessions_visible';
  static const _chatCodeBlockHighlightingEnabledKey =
      'web_parity.chat_code_block_highlighting_enabled';
  static const _busyFollowupModeKey = 'web_parity.busy_followup_mode';
  static const _textScaleFactorKey = 'web_parity.text_scale_factor';
  static const _layoutDensityKey = 'web_parity.layout_density';
  static const double defaultTextScaleFactor = 1.0;
  static const double minTextScaleFactor = 0.9;
  static const double maxTextScaleFactor = 1.25;
  static const double textScaleFactorStep = 0.05;
  static const int textScaleFactorDivisions = 7;

  final ServerProfileStore _profileStore;
  final ProjectStore _projectStore;
  final StaleCacheStore _cacheStore;
  final OpenCodeServerProbe _probeService;
  final WorkspaceControllerFactory _workspaceControllerFactory;

  bool _loading = true;
  List<ServerProfile> _profiles = const <ServerProfile>[];
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];
  Map<String, ServerProbeReport> _reports = const <String, ServerProbeReport>{};
  ServerProfile? _selectedProfile;
  bool _shellToolPartsExpanded = true;
  bool _timelineProgressDetailsVisible = false;
  bool _sidebarChildSessionsVisible = false;
  bool _chatCodeBlockHighlightingEnabled = true;
  WorkspaceFollowupMode _busyFollowupMode = WorkspaceFollowupMode.queue;
  double _textScaleFactor = defaultTextScaleFactor;
  WorkspaceLayoutDensity _layoutDensity = WorkspaceLayoutDensity.normal;
  final Map<String, WorkspaceController> _workspaceControllers =
      <String, WorkspaceController>{};

  bool get loading => _loading;
  List<ServerProfile> get profiles => _profiles;
  List<ProjectTarget> get recentProjects => _recentProjects;
  Map<String, ServerProbeReport> get reports => _reports;
  ServerProfile? get selectedProfile => _selectedProfile;
  bool get shellToolPartsExpanded => _shellToolPartsExpanded;
  bool get timelineProgressDetailsVisible => _timelineProgressDetailsVisible;
  bool get sidebarChildSessionsVisible => _sidebarChildSessionsVisible;
  bool get chatCodeBlockHighlightingEnabled =>
      _chatCodeBlockHighlightingEnabled;
  WorkspaceFollowupMode get busyFollowupMode => _busyFollowupMode;
  double get textScaleFactor => _textScaleFactor;
  WorkspaceLayoutDensity get layoutDensity => _layoutDensity;
  ServerProbeReport? get selectedReport {
    final selectedProfile = _selectedProfile;
    if (selectedProfile == null) {
      return null;
    }
    return _reports[selectedProfile.storageKey];
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final profiles = await _profileStore.load();
    final recentProjects = await _projectStore.loadRecentProjects();
    final reports = await _loadCachedReports(profiles);
    final prefs = await SharedPreferences.getInstance();
    final selectedProfileId = prefs.getString(_selectedProfileKey);
    final shellToolPartsExpanded =
        prefs.getBool(_shellToolPartsExpandedKey) ?? true;
    final timelineProgressDetailsVisible =
        prefs.getBool(_timelineProgressDetailsVisibleKey) ?? false;
    final sidebarChildSessionsVisible =
        prefs.getBool(_sidebarChildSessionsVisibleKey) ?? false;
    final chatCodeBlockHighlightingEnabled =
        prefs.getBool(_chatCodeBlockHighlightingEnabledKey) ?? true;
    final busyFollowupMode = WorkspaceFollowupMode.fromStorage(
      prefs.getString(_busyFollowupModeKey),
    );
    final textScaleFactor = _normalizeTextScaleFactor(
      prefs.getDouble(_textScaleFactorKey),
    );
    final layoutDensity = WorkspaceLayoutDensity.fromStorage(
      prefs.getString(_layoutDensityKey),
    );

    ServerProfile? selectedProfile;
    if (selectedProfileId != null) {
      for (final profile in profiles) {
        if (profile.id == selectedProfileId) {
          selectedProfile = profile;
          break;
        }
      }
    }
    selectedProfile ??= profiles.isEmpty ? null : profiles.first;

    _profiles = profiles;
    _recentProjects = recentProjects;
    _reports = reports;
    _selectedProfile = selectedProfile;
    _shellToolPartsExpanded = shellToolPartsExpanded;
    _timelineProgressDetailsVisible = timelineProgressDetailsVisible;
    _sidebarChildSessionsVisible = sidebarChildSessionsVisible;
    _chatCodeBlockHighlightingEnabled = chatCodeBlockHighlightingEnabled;
    _busyFollowupMode = busyFollowupMode;
    _textScaleFactor = textScaleFactor;
    _layoutDensity = layoutDensity;
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() => load();

  Future<void> selectProfile(ServerProfile profile) async {
    if (_selectedProfile?.id == profile.id) {
      return;
    }
    _selectedProfile = profile;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProfileKey, profile.id);
  }

  Future<void> setShellToolPartsExpanded(bool value) async {
    if (_shellToolPartsExpanded == value) {
      return;
    }
    _shellToolPartsExpanded = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shellToolPartsExpandedKey, value);
  }

  Future<void> setTimelineProgressDetailsVisible(bool value) async {
    if (_timelineProgressDetailsVisible == value) {
      return;
    }
    _timelineProgressDetailsVisible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timelineProgressDetailsVisibleKey, value);
  }

  Future<void> setSidebarChildSessionsVisible(bool value) async {
    if (_sidebarChildSessionsVisible == value) {
      return;
    }
    _sidebarChildSessionsVisible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarChildSessionsVisibleKey, value);
  }

  Future<void> setChatCodeBlockHighlightingEnabled(bool value) async {
    if (_chatCodeBlockHighlightingEnabled == value) {
      return;
    }
    _chatCodeBlockHighlightingEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatCodeBlockHighlightingEnabledKey, value);
  }

  Future<void> setBusyFollowupMode(WorkspaceFollowupMode value) async {
    if (_busyFollowupMode == value) {
      return;
    }
    _busyFollowupMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_busyFollowupModeKey, value.storageValue);
  }

  Future<void> setTextScaleFactor(double value) async {
    final normalized = _normalizeTextScaleFactor(value);
    if ((_textScaleFactor - normalized).abs() < 0.0001) {
      return;
    }
    _textScaleFactor = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleFactorKey, normalized);
  }

  Future<void> setLayoutDensity(WorkspaceLayoutDensity value) async {
    if (_layoutDensity == value) {
      return;
    }
    _layoutDensity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutDensityKey, value.storageValue);
  }

  Future<void> refreshProbe(ServerProfile profile) async {
    final report = await _probeService.probe(profile);
    await _cacheStore.save('probe::${profile.storageKey}', report.toJson());
    _reports = <String, ServerProbeReport>{
      ..._reports,
      profile.storageKey: report,
    };
    notifyListeners();
  }

  Future<void> persistProjectUpdate({
    required ServerProfile profile,
    required ProjectTarget target,
  }) async {
    await _projectStore.restoreProject(target.directory);
    _recentProjects = await _projectStore.updateRecentProject(target);
    final lastWorkspace = await _projectStore.loadLastWorkspace(
      profile.storageKey,
    );
    if (lastWorkspace?.directory == target.directory) {
      await _projectStore.saveLastWorkspace(
        serverStorageKey: profile.storageKey,
        target: target,
      );
    }
    _applyProjectTargetUpdate(profile: profile, target: target);
    notifyListeners();
  }

  Future<void> hideProject({
    required ServerProfile profile,
    required String directory,
  }) async {
    await _projectStore.hideProject(directory);
    _recentProjects = await _projectStore.loadRecentProjects();
    final lastWorkspace = await _projectStore.loadLastWorkspace(
      profile.storageKey,
    );
    if (lastWorkspace?.directory == directory) {
      await _projectStore.clearLastWorkspace(profile.storageKey);
    }
    _applyProjectRemoval(profile: profile, directory: directory);
    notifyListeners();
  }

  bool hasWorkspaceController({
    required ServerProfile profile,
    required String directory,
  }) {
    return _workspaceControllers.containsKey(
      _workspaceControllerKey(profile: profile, directory: directory),
    );
  }

  WorkspaceController obtainWorkspaceController({
    required ServerProfile profile,
    required String directory,
    String? initialSessionId,
  }) {
    final key = _workspaceControllerKey(profile: profile, directory: directory);
    final existing = _workspaceControllers[key];
    if (existing != null) {
      return existing;
    }

    final controller = _workspaceControllerFactory(
      profile: profile,
      directory: directory,
      initialSessionId: initialSessionId,
    )..load();
    _workspaceControllers[key] = controller;
    return controller;
  }

  String _workspaceControllerKey({
    required ServerProfile profile,
    required String directory,
  }) {
    return '${profile.storageKey}::$directory';
  }

  void _applyProjectTargetUpdate({
    required ServerProfile profile,
    required ProjectTarget target,
  }) {
    for (final entry in _workspaceControllers.entries) {
      if (!entry.key.startsWith('${profile.storageKey}::')) {
        continue;
      }
      entry.value.applyProjectTargetUpdate(target);
    }
  }

  void _applyProjectRemoval({
    required ServerProfile profile,
    required String directory,
  }) {
    for (final entry in _workspaceControllers.entries) {
      if (!entry.key.startsWith('${profile.storageKey}::')) {
        continue;
      }
      entry.value.applyProjectRemoval(directory);
    }
  }

  Future<Map<String, ServerProbeReport>> _loadCachedReports(
    List<ServerProfile> profiles,
  ) async {
    final entries = await Future.wait(
      profiles.map((profile) async {
        final entry = await _cacheStore.load('probe::${profile.storageKey}');
        if (entry == null) {
          return MapEntry<String, ServerProbeReport?>(profile.storageKey, null);
        }
        try {
          final report = ServerProbeReport.fromJson(
            (jsonDecode(entry.payloadJson) as Map).cast<String, Object?>(),
          );
          return MapEntry<String, ServerProbeReport?>(
            profile.storageKey,
            report,
          );
        } catch (_) {
          return MapEntry<String, ServerProbeReport?>(profile.storageKey, null);
        }
      }),
    );

    return <String, ServerProbeReport>{
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  @override
  void dispose() {
    for (final controller in _workspaceControllers.values) {
      controller.dispose();
    }
    _workspaceControllers.clear();
    _probeService.dispose();
    super.dispose();
  }

  double _normalizeTextScaleFactor(double? value) {
    final candidate = value;
    if (candidate == null || !candidate.isFinite) {
      return defaultTextScaleFactor;
    }
    final clamped = candidate
        .clamp(minTextScaleFactor, maxTextScaleFactor)
        .toDouble();
    final snapped =
        ((clamped - minTextScaleFactor) / textScaleFactorStep).round() *
            textScaleFactorStep +
        minTextScaleFactor;
    return double.parse(
      snapped.clamp(minTextScaleFactor, maxTextScaleFactor).toStringAsFixed(2),
    );
  }
}
