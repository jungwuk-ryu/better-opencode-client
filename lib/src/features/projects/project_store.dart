import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'project_models.dart';

class ProjectStore {
  static const _recentProjectsKey = 'recent_projects';
  static const _recentProjectLimit = 10;

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
}
