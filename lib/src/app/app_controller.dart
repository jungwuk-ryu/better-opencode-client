import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeData, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/connection/connection_models.dart';
import '../core/network/opencode_server_probe.dart';
import '../core/persistence/server_profile_store.dart';
import '../core/persistence/stale_cache_store.dart';
import '../design_system/app_theme.dart';
import '../features/projects/project_models.dart';
import '../features/projects/project_store.dart';
import '../features/web_parity/workspace_controller.dart';
import '../features/web_parity/workspace_layout_store.dart';
import 'app_release_notes.dart';

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

enum WorkspaceMultiPaneComposerMode {
  shared,
  perPane;

  String get storageValue => name;

  static WorkspaceMultiPaneComposerMode fromStorage(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'perpane' ||
      'per_pane' ||
      'per-pane' => WorkspaceMultiPaneComposerMode.perPane,
      _ => WorkspaceMultiPaneComposerMode.shared,
    };
  }
}

enum AppColorSchemeMode {
  system,
  light,
  dark;

  String get storageValue => name;

  static AppColorSchemeMode fromStorage(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'light' => AppColorSchemeMode.light,
      'dark' => AppColorSchemeMode.dark,
      _ => AppColorSchemeMode.system,
    };
  }
}

class WebParityAppController extends ChangeNotifier {
  WebParityAppController({
    ServerProfileStore? profileStore,
    ProjectStore? projectStore,
    StaleCacheStore? cacheStore,
    OpenCodeServerProbe? probeService,
    WorkspacePaneLayoutStore? workspacePaneLayoutStore,
    WorkspaceControllerFactory? workspaceControllerFactory,
  }) : _profileStore = profileStore ?? ServerProfileStore(),
       _projectStore = projectStore ?? ProjectStore(),
       _cacheStore = cacheStore ?? StaleCacheStore(),
       _probeService = probeService ?? OpenCodeServerProbe(),
       _workspacePaneLayoutStore =
           workspacePaneLayoutStore ?? WorkspacePaneLayoutStore(),
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
  static const _multiPaneComposerModeKey =
      'web_parity.multi_pane_composer_mode';
  static const _themePresetKey = 'web_parity.theme_preset';
  static const _themeSchemeKey = 'web_parity.theme_scheme';
  static const _releaseNotesEnabledKey = 'web_parity.release_notes_enabled';
  static const _releaseNotesSeenVersionKey =
      'web_parity.release_notes_seen_version';
  static const double defaultTextScaleFactor = 1.0;
  static const double textScaleBaselineMultiplier = 0.9;
  static const double minTextScaleFactor = 0.9;
  static const double maxTextScaleFactor = 1.25;
  static const double textScaleFactorStep = 0.05;
  static const int textScaleFactorDivisions = 7;

  final ServerProfileStore _profileStore;
  final ProjectStore _projectStore;
  final StaleCacheStore _cacheStore;
  final OpenCodeServerProbe _probeService;
  final WorkspacePaneLayoutStore _workspacePaneLayoutStore;
  final WorkspaceControllerFactory _workspaceControllerFactory;

  bool _loading = true;
  List<ServerProfile> _profiles = const <ServerProfile>[];
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];
  Map<String, ServerProbeReport> _reports = const <String, ServerProbeReport>{};
  Map<String, WorkspacePaneLayoutSnapshot> _workspacePaneLayoutsByStorageKey =
      const <String, WorkspacePaneLayoutSnapshot>{};
  ServerProfile? _selectedProfile;
  bool _shellToolPartsExpanded = true;
  bool _timelineProgressDetailsVisible = false;
  bool _sidebarChildSessionsVisible = false;
  bool _chatCodeBlockHighlightingEnabled = true;
  WorkspaceFollowupMode _busyFollowupMode = WorkspaceFollowupMode.queue;
  double _textScaleFactor = defaultTextScaleFactor;
  WorkspaceLayoutDensity _layoutDensity = WorkspaceLayoutDensity.normal;
  WorkspaceMultiPaneComposerMode _multiPaneComposerMode =
      WorkspaceMultiPaneComposerMode.shared;
  AppThemePreset _themePreset = AppThemePreset.remote;
  AppColorSchemeMode _colorSchemeMode = AppColorSchemeMode.system;
  bool _releaseNotesEnabled = true;
  String? _seenReleaseNotesVersion;
  AppReleaseNotesPresentation? _pendingReleaseNotes;
  Set<String> _refreshingProfileKeys = const <String>{};
  final Map<String, WorkspaceController> _workspaceControllers =
      <String, WorkspaceController>{};

  bool get loading => _loading;
  List<ServerProfile> get profiles => _profiles;
  List<ProjectTarget> get recentProjects => _recentProjects;
  Map<String, ServerProbeReport> get reports => _reports;
  Map<String, WorkspacePaneLayoutSnapshot>
  get workspacePaneLayoutsByStorageKey => _workspacePaneLayoutsByStorageKey;
  ServerProfile? get selectedProfile => _selectedProfile;
  bool get shellToolPartsExpanded => _shellToolPartsExpanded;
  bool get timelineProgressDetailsVisible => _timelineProgressDetailsVisible;
  bool get sidebarChildSessionsVisible => _sidebarChildSessionsVisible;
  bool get chatCodeBlockHighlightingEnabled =>
      _chatCodeBlockHighlightingEnabled;
  WorkspaceFollowupMode get busyFollowupMode => _busyFollowupMode;
  double get textScaleFactor => _textScaleFactor;
  double get effectiveTextScaleFactor =>
      _textScaleFactor * textScaleBaselineMultiplier;
  WorkspaceLayoutDensity get layoutDensity => _layoutDensity;
  WorkspaceMultiPaneComposerMode get multiPaneComposerMode =>
      _multiPaneComposerMode;
  AppThemePreset get themePreset => _themePreset;
  AppColorSchemeMode get colorSchemeMode => _colorSchemeMode;
  bool get releaseNotesEnabled => _releaseNotesEnabled;
  String? get seenReleaseNotesVersion => _seenReleaseNotesVersion;
  AppReleaseNotesPresentation? get pendingReleaseNotes => _pendingReleaseNotes;
  AppReleaseNotesPresentation? get currentReleaseNotes =>
      latestAppReleaseNotesPresentation();
  bool get hasReleaseNotes => currentReleaseNotes != null;
  ThemeMode get themeMode => switch (_colorSchemeMode) {
    AppColorSchemeMode.light => ThemeMode.light,
    AppColorSchemeMode.dark => ThemeMode.dark,
    AppColorSchemeMode.system => ThemeMode.system,
  };
  ThemeData get lightThemeData => AppTheme.light(_themePreset);
  ThemeData get darkThemeData => AppTheme.dark(_themePreset);
  ThemeData get themeData => darkThemeData;
  bool isRefreshingProfile(ServerProfile? profile) {
    return profile != null &&
        _refreshingProfileKeys.contains(profile.storageKey);
  }

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
    final workspacePaneLayouts = await _loadWorkspacePaneLayouts(profiles);
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
    final multiPaneComposerMode = WorkspaceMultiPaneComposerMode.fromStorage(
      prefs.getString(_multiPaneComposerModeKey),
    );
    final themePreset = AppThemePreset.fromStorage(
      prefs.getString(_themePresetKey),
    );
    final colorSchemeMode = AppColorSchemeMode.fromStorage(
      prefs.getString(_themeSchemeKey),
    );
    final releaseNotesEnabled =
        prefs.getBool(_releaseNotesEnabledKey) ?? true;
    var seenReleaseNotesVersion = normalizeReleaseNotesVersion(
      prefs.getString(_releaseNotesSeenVersionKey),
    );
    AppReleaseNotesPresentation? pendingReleaseNotes;
    final currentReleaseNotes = this.currentReleaseNotes;
    if (currentReleaseNotes != null) {
      if (seenReleaseNotesVersion == null) {
        seenReleaseNotesVersion = currentReleaseNotes.currentVersion;
        await prefs.setString(
          _releaseNotesSeenVersionKey,
          currentReleaseNotes.currentVersion,
        );
      } else if (!releaseNotesEnabled) {
        if (seenReleaseNotesVersion != currentReleaseNotes.currentVersion) {
          seenReleaseNotesVersion = currentReleaseNotes.currentVersion;
          await prefs.setString(
            _releaseNotesSeenVersionKey,
            currentReleaseNotes.currentVersion,
          );
        }
      } else if (seenReleaseNotesVersion != currentReleaseNotes.currentVersion) {
        pendingReleaseNotes = releaseNotesSinceVersion(seenReleaseNotesVersion);
      }
    }

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
    _workspacePaneLayoutsByStorageKey = workspacePaneLayouts;
    _selectedProfile = selectedProfile;
    _shellToolPartsExpanded = shellToolPartsExpanded;
    _timelineProgressDetailsVisible = timelineProgressDetailsVisible;
    _sidebarChildSessionsVisible = sidebarChildSessionsVisible;
    _chatCodeBlockHighlightingEnabled = chatCodeBlockHighlightingEnabled;
    _busyFollowupMode = busyFollowupMode;
    _textScaleFactor = textScaleFactor;
    _layoutDensity = layoutDensity;
    _multiPaneComposerMode = multiPaneComposerMode;
    _themePreset = themePreset;
    _colorSchemeMode = colorSchemeMode;
    _releaseNotesEnabled = releaseNotesEnabled;
    _seenReleaseNotesVersion = seenReleaseNotesVersion;
    _pendingReleaseNotes = pendingReleaseNotes;
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
    await _persistSelectedProfile(profile);
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

  Future<void> setMultiPaneComposerMode(
    WorkspaceMultiPaneComposerMode value,
  ) async {
    if (_multiPaneComposerMode == value) {
      return;
    }
    _multiPaneComposerMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_multiPaneComposerModeKey, value.storageValue);
  }

  Future<void> setThemePreset(AppThemePreset value) async {
    if (_themePreset == value) {
      return;
    }
    _themePreset = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, value.storageValue);
  }

  Future<void> cycleThemePreset([int direction = 1]) async {
    final presets = AppThemePreset.values;
    if (presets.isEmpty) {
      return;
    }
    final currentIndex = presets.indexOf(_themePreset);
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + direction + presets.length) % presets.length;
    await setThemePreset(presets[nextIndex]);
  }

  Future<void> setColorSchemeMode(AppColorSchemeMode value) async {
    if (_colorSchemeMode == value) {
      return;
    }
    _colorSchemeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeSchemeKey, value.storageValue);
  }

  Future<void> cycleColorSchemeMode([int direction = 1]) async {
    final modes = AppColorSchemeMode.values;
    if (modes.isEmpty) {
      return;
    }
    final currentIndex = modes.indexOf(_colorSchemeMode);
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + direction + modes.length) % modes.length;
    await setColorSchemeMode(modes[nextIndex]);
  }

  Future<void> setReleaseNotesEnabled(bool value) async {
    if (_releaseNotesEnabled == value) {
      return;
    }
    _releaseNotesEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_releaseNotesEnabledKey, value);
    if (!value) {
      final currentReleaseNotes = this.currentReleaseNotes;
      if (currentReleaseNotes != null) {
        _seenReleaseNotesVersion = currentReleaseNotes.currentVersion;
        _pendingReleaseNotes = null;
        await prefs.setString(
          _releaseNotesSeenVersionKey,
          currentReleaseNotes.currentVersion,
        );
      }
    } else if (_pendingReleaseNotes == null) {
      final currentReleaseNotes = this.currentReleaseNotes;
      if (currentReleaseNotes != null &&
          _seenReleaseNotesVersion != currentReleaseNotes.currentVersion) {
        _pendingReleaseNotes = releaseNotesSinceVersion(_seenReleaseNotesVersion);
      }
    }
    notifyListeners();
  }

  Future<void> markReleaseNotesSeen([String? version]) async {
    final normalizedVersion = normalizeReleaseNotesVersion(
      version ?? currentReleaseNotes?.currentVersion,
    );
    if (normalizedVersion == null || normalizedVersion.isEmpty) {
      return;
    }
    if (_seenReleaseNotesVersion == normalizedVersion &&
        _pendingReleaseNotes?.currentVersion != normalizedVersion) {
      return;
    }
    _seenReleaseNotesVersion = normalizedVersion;
    if (_pendingReleaseNotes?.currentVersion == normalizedVersion) {
      _pendingReleaseNotes = null;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_releaseNotesSeenVersionKey, normalizedVersion);
  }

  Future<void> refreshProbe(ServerProfile profile) async {
    if (_refreshingProfileKeys.contains(profile.storageKey)) {
      return;
    }
    _refreshingProfileKeys = <String>{
      ..._refreshingProfileKeys,
      profile.storageKey,
    };
    notifyListeners();
    try {
      final report = await _probeService.probe(profile);
      await _cacheStore.save('probe::${profile.storageKey}', report.toJson());
      _reports = <String, ServerProbeReport>{
        ..._reports,
        profile.storageKey: report,
      };
    } finally {
      _refreshingProfileKeys = Set<String>.unmodifiable(
        _refreshingProfileKeys.where((key) => key != profile.storageKey),
      );
      notifyListeners();
    }
  }

  Future<ServerProfile> saveProfile(ServerProfile profile) async {
    final previousProfile = _profiles.cast<ServerProfile?>().firstWhere(
      (item) => item?.id == profile.id,
      orElse: () => null,
    );
    final profiles = await _profileStore.upsertProfile(profile);
    final savedProfile = profiles.firstWhere(
      (item) => item.id == profile.id || item.storageKey == profile.storageKey,
      orElse: () => profile,
    );
    if (previousProfile != null &&
        previousProfile.storageKey != savedProfile.storageKey) {
      await _workspacePaneLayoutStore.transfer(
        fromServerStorageKey: previousProfile.storageKey,
        toServerStorageKey: savedProfile.storageKey,
      );
      await _projectStore.transferLastWorkspace(
        fromServerStorageKey: previousProfile.storageKey,
        toServerStorageKey: savedProfile.storageKey,
      );
    }
    _profiles = profiles;
    _reports = _retainReportsForProfiles(profiles);
    _workspacePaneLayoutsByStorageKey = _retainWorkspacePaneLayoutsForProfiles(
      profiles,
    );
    if (previousProfile != null &&
        previousProfile.storageKey != savedProfile.storageKey) {
      final transferred = await _workspacePaneLayoutStore.load(
        savedProfile.storageKey,
      );
      if (transferred != null) {
        _workspacePaneLayoutsByStorageKey =
            Map<String, WorkspacePaneLayoutSnapshot>.unmodifiable(
              <String, WorkspacePaneLayoutSnapshot>{
                ..._workspacePaneLayoutsByStorageKey,
                savedProfile.storageKey: transferred,
              },
            );
      }
    }
    _selectedProfile = savedProfile;
    notifyListeners();
    await _persistSelectedProfile(savedProfile);
    await refreshProbe(savedProfile);
    return savedProfile;
  }

  Future<void> deleteServerProfile(ServerProfile profile) async {
    final profiles = await _profileStore.deleteProfile(profile.id);
    await _workspacePaneLayoutStore.clear(profile.storageKey);
    _profiles = profiles;
    _reports = _retainReportsForProfiles(profiles);
    _workspacePaneLayoutsByStorageKey = _retainWorkspacePaneLayoutsForProfiles(
      profiles,
    );
    final selectedId = _selectedProfile?.id;
    _selectedProfile = selectedId == null
        ? (profiles.isEmpty ? null : profiles.first)
        : profiles.cast<ServerProfile?>().firstWhere(
            (item) => item?.id == selectedId,
            orElse: () => profiles.isEmpty ? null : profiles.first,
          );
    notifyListeners();
    await _persistSelectedProfile(_selectedProfile);
  }

  Future<void> moveProfile(String profileId, int offset) async {
    final profiles = await _profileStore.moveProfile(profileId, offset);
    _profiles = profiles;
    final selectedId = _selectedProfile?.id;
    if (selectedId != null) {
      for (final profile in profiles) {
        if (profile.id == selectedId) {
          _selectedProfile = profile;
          break;
        }
      }
    }
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

  Future<void> reorderProjects({
    required ServerProfile profile,
    required List<ProjectTarget> orderedProjects,
  }) async {
    _recentProjects = await _projectStore.reorderRecentProjects(
      orderedProjects,
    );
    _applyProjectOrder(profile: profile, orderedProjects: _recentProjects);
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

  WorkspacePaneLayoutSnapshot? workspacePaneLayoutFor(ServerProfile? profile) {
    if (profile == null) {
      return null;
    }
    return _workspacePaneLayoutsByStorageKey[profile.storageKey];
  }

  Future<WorkspacePaneLayoutSnapshot?> ensureWorkspacePaneLayout(
    ServerProfile profile,
  ) async {
    final existing = workspacePaneLayoutFor(profile);
    if (existing != null) {
      return existing;
    }
    final snapshot = await _workspacePaneLayoutStore.load(profile.storageKey);
    if (snapshot == null) {
      return null;
    }
    _workspacePaneLayoutsByStorageKey =
        Map<String, WorkspacePaneLayoutSnapshot>.unmodifiable(
          <String, WorkspacePaneLayoutSnapshot>{
            ..._workspacePaneLayoutsByStorageKey,
            profile.storageKey: snapshot,
          },
        );
    notifyListeners();
    return snapshot;
  }

  Future<void> persistWorkspacePaneLayout({
    required ServerProfile profile,
    required WorkspacePaneLayoutSnapshot snapshot,
  }) async {
    await _workspacePaneLayoutStore.save(profile.storageKey, snapshot);
    _workspacePaneLayoutsByStorageKey =
        Map<String, WorkspacePaneLayoutSnapshot>.unmodifiable(
          <String, WorkspacePaneLayoutSnapshot>{
            ..._workspacePaneLayoutsByStorageKey,
            profile.storageKey: snapshot,
          },
        );
    notifyListeners();
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

  void _applyProjectOrder({
    required ServerProfile profile,
    required List<ProjectTarget> orderedProjects,
  }) {
    for (final entry in _workspaceControllers.entries) {
      if (!entry.key.startsWith('${profile.storageKey}::')) {
        continue;
      }
      entry.value.applyProjectOrder(orderedProjects);
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
          await _cacheStore.remove('probe::${profile.storageKey}');
          return MapEntry<String, ServerProbeReport?>(profile.storageKey, null);
        }
      }),
    );

    return <String, ServerProbeReport>{
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<Map<String, WorkspacePaneLayoutSnapshot>> _loadWorkspacePaneLayouts(
    List<ServerProfile> profiles,
  ) async {
    final entries = await Future.wait(
      profiles.map((profile) async {
        final snapshot = await _workspacePaneLayoutStore.load(
          profile.storageKey,
        );
        return MapEntry<String, WorkspacePaneLayoutSnapshot?>(
          profile.storageKey,
          snapshot,
        );
      }),
    );
    return <String, WorkspacePaneLayoutSnapshot>{
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

  Map<String, ServerProbeReport> _retainReportsForProfiles(
    List<ServerProfile> profiles,
  ) {
    final keys = profiles.map((profile) => profile.storageKey).toSet();
    return <String, ServerProbeReport>{
      for (final entry in _reports.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Map<String, WorkspacePaneLayoutSnapshot>
  _retainWorkspacePaneLayoutsForProfiles(List<ServerProfile> profiles) {
    final keys = profiles.map((profile) => profile.storageKey).toSet();
    return <String, WorkspacePaneLayoutSnapshot>{
      for (final entry in _workspacePaneLayoutsByStorageKey.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<void> _persistSelectedProfile(ServerProfile? profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile == null) {
      await prefs.remove(_selectedProfileKey);
      return;
    }
    await prefs.setString(_selectedProfileKey, profile.id);
  }
}
