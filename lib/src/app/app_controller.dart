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

class WebParityAppController extends ChangeNotifier {
  WebParityAppController({
    ServerProfileStore? profileStore,
    ProjectStore? projectStore,
    StaleCacheStore? cacheStore,
    OpenCodeServerProbe? probeService,
  }) : _profileStore = profileStore ?? ServerProfileStore(),
       _projectStore = projectStore ?? ProjectStore(),
       _cacheStore = cacheStore ?? StaleCacheStore(),
       _probeService = probeService ?? OpenCodeServerProbe();

  static const _selectedProfileKey = 'web_parity.selected_profile';

  final ServerProfileStore _profileStore;
  final ProjectStore _projectStore;
  final StaleCacheStore _cacheStore;
  final OpenCodeServerProbe _probeService;

  bool _loading = true;
  List<ServerProfile> _profiles = const <ServerProfile>[];
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];
  Map<String, ServerProbeReport> _reports = const <String, ServerProbeReport>{};
  ServerProfile? _selectedProfile;

  bool get loading => _loading;
  List<ServerProfile> get profiles => _profiles;
  List<ProjectTarget> get recentProjects => _recentProjects;
  Map<String, ServerProbeReport> get reports => _reports;
  ServerProfile? get selectedProfile => _selectedProfile;
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

  Future<void> refreshProbe(ServerProfile profile) async {
    final report = await _probeService.probe(profile);
    await _cacheStore.save('probe::${profile.storageKey}', report.toJson());
    _reports = <String, ServerProbeReport>{
      ..._reports,
      profile.storageKey: report,
    };
    notifyListeners();
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
    _probeService.dispose();
    super.dispose();
  }
}
