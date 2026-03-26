import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'project_models.dart';

class ProjectStore {
  static const _recentProjectsKey = 'recent_projects';
  static const _pinnedProjectsKey = 'pinned_projects';
  static const _hiddenProjectsKey = 'hidden_projects';
  static const _recentProjectLimit = 10;

  String _lastWorkspaceKey(String serverStorageKey) =>
      'last_workspace::$serverStorageKey';

  Future<List<ProjectTarget>> loadRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = await loadHiddenProjects();
    final raw = prefs.getStringList(_recentProjectsKey) ?? const <String>[];
    var needsRewrite = false;
    final projects = <ProjectTarget>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is! Map) {
          needsRewrite = true;
          continue;
        }
        final project = ProjectTarget.fromJson(decoded.cast<String, Object?>());
        if (!hidden.contains(project.directory)) {
          projects.add(project);
        }
      } catch (_) {
        needsRewrite = true;
      }
    }
    if (needsRewrite) {
      await _saveRecentProjects(projects);
    }
    return List<ProjectTarget>.unmodifiable(projects);
  }

  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    await restoreProject(target.directory);
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
    await _saveRecentProjects(next);
    return List<ProjectTarget>.unmodifiable(next);
  }

  Future<List<ProjectTarget>> updateRecentProject(ProjectTarget target) async {
    final current = await loadRecentProjects();
    final next = <ProjectTarget>[];
    var replaced = false;
    for (final item in current) {
      if (item.directory == target.directory) {
        next.add(target);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) {
      next.insert(0, target);
    }
    if (next.length > _recentProjectLimit) {
      next.removeRange(_recentProjectLimit, next.length);
    }
    await _saveRecentProjects(next);
    return List<ProjectTarget>.unmodifiable(next);
  }

  Future<List<ProjectTarget>> removeRecentProject(String directory) async {
    final current = await loadRecentProjects();
    final next = current
        .where((item) => item.directory != directory)
        .toList(growable: false);
    await _saveRecentProjects(next);
    return next;
  }

  Future<List<ProjectTarget>> reorderRecentProjects(
    List<ProjectTarget> orderedProjects,
  ) async {
    final current = await loadRecentProjects();
    final byDirectory = <String, ProjectTarget>{
      for (final project in current) project.directory: project,
    };
    for (final project in orderedProjects) {
      byDirectory[project.directory] = project;
    }

    final next = <ProjectTarget>[];
    final seen = <String>{};
    for (final project in orderedProjects) {
      if (!seen.add(project.directory)) {
        continue;
      }
      next.add(byDirectory[project.directory] ?? project);
      if (next.length >= _recentProjectLimit) {
        break;
      }
    }
    if (next.length < _recentProjectLimit) {
      for (final project in current) {
        if (!seen.add(project.directory)) {
          continue;
        }
        next.add(project);
        if (next.length >= _recentProjectLimit) {
          break;
        }
      }
    }

    await _saveRecentProjects(next);
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

  Future<Set<String>> loadHiddenProjects() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return <String>{};
    }
    return (prefs.getStringList(_hiddenProjectsKey) ?? const <String>[])
        .toSet();
  }

  Future<Set<String>> hideProject(String directory) async {
    final prefs = await SharedPreferences.getInstance();
    final next = await loadHiddenProjects()
      ..add(directory);
    await prefs.setStringList(_hiddenProjectsKey, next.toList(growable: false));
    await removeRecentProject(directory);
    return next;
  }

  Future<Set<String>> restoreProject(String directory) async {
    final prefs = await SharedPreferences.getInstance();
    final next = await loadHiddenProjects()
      ..remove(directory);
    await prefs.setStringList(_hiddenProjectsKey, next.toList(growable: false));
    return next;
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

  Future<void> _saveRecentProjects(List<ProjectTarget> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentProjectsKey,
      projects.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
  }
}
