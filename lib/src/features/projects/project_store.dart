import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'project_models.dart';

class ProjectStore {
  static const _recentProjectsKey = 'recent_projects';
  static const _pinnedProjectsKey = 'pinned_projects';
  static const _recentProjectLimit = 10;

  String _lastWorkspaceKey(String serverStorageKey) =>
      'last_workspace::$serverStorageKey';

  Future<List<ProjectTarget>> loadRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentProjectsKey) ?? const <String>[];
    return raw
        .map(
          (item) => ProjectTarget.fromJson(
            (jsonDecode(item) as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    final current = await loadRecentProjects();
    final next = <ProjectTarget>[target];
    for (final item in current) {
      if (item.directory == target.directory) {
        continue;
      }
      next.add(item);
      if (next.length >= _recentProjectLimit) {
        break;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentProjectsKey,
      next.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
    return List<ProjectTarget>.unmodifiable(next);
  }

  Future<ProjectTarget?> loadLastWorkspace(String serverStorageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastWorkspaceKey(serverStorageKey));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return ProjectTarget.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      await prefs.remove(_lastWorkspaceKey(serverStorageKey));
      return null;
    }
  }

  Future<void> saveLastWorkspace({
    required String serverStorageKey,
    required ProjectTarget target,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastWorkspaceKey(serverStorageKey),
      jsonEncode(target.toJson()),
    );
  }

  Future<void> clearLastWorkspace(String serverStorageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastWorkspaceKey(serverStorageKey));
  }

  Future<Set<String>> loadPinnedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pinnedProjectsKey) ?? const <String>[])
        .toSet();
  }

  Future<Set<String>> togglePinnedProject(String directory) async {
    final prefs = await SharedPreferences.getInstance();
    final next = await loadPinnedProjects();
    if (!next.add(directory)) {
      next.remove(directory);
    }
    await prefs.setStringList(_pinnedProjectsKey, next.toList(growable: false));
    return next;
  }
}
