import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePaneLayoutPane {
  const WorkspacePaneLayoutPane({
    required this.id,
    required this.directory,
    this.sessionId,
  });

  final String id;
  final String directory;
  final String? sessionId;

  WorkspacePaneLayoutPane copyWith({
    String? id,
    String? directory,
    String? sessionId,
    bool clearSessionId = false,
  }) {
    return WorkspacePaneLayoutPane(
      id: id ?? this.id,
      directory: directory ?? this.directory,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'directory': directory,
    'sessionId': sessionId,
  };

  static WorkspacePaneLayoutPane? tryFromJson(Map<String, Object?> json) {
    final id = json['id']?.toString().trim();
    final directory = json['directory']?.toString().trim();
    if (id == null || id.isEmpty || directory == null || directory.isEmpty) {
      return null;
    }
    return WorkspacePaneLayoutPane(
      id: id,
      directory: directory,
      sessionId: normalizeWorkspacePaneSessionId(json['sessionId']?.toString()),
    );
  }
}

class WorkspacePaneLayoutSnapshot {
  const WorkspacePaneLayoutSnapshot({
    required this.panes,
    required this.activePaneId,
  });

  final List<WorkspacePaneLayoutPane> panes;
  final String activePaneId;

  WorkspacePaneLayoutPane? get activePane {
    for (final pane in panes) {
      if (pane.id == activePaneId) {
        return pane;
      }
    }
    return panes.isEmpty ? null : panes.first;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'activePaneId': activePaneId,
    'panes': panes.map((pane) => pane.toJson()).toList(growable: false),
  };

  String encode() => jsonEncode(toJson());

  WorkspacePaneLayoutSnapshot retargetActivePane({
    required String directory,
    String? sessionId,
  }) {
    return WorkspacePaneLayoutSnapshot(
      panes: panes
          .map(
            (pane) => pane.id == activePaneId
                ? pane.copyWith(
                    directory: directory,
                    sessionId: normalizeWorkspacePaneSessionId(sessionId),
                    clearSessionId:
                        normalizeWorkspacePaneSessionId(sessionId) == null,
                  )
                : pane,
          )
          .toList(growable: false),
      activePaneId: activePaneId,
    );
  }

  static WorkspacePaneLayoutSnapshot? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final rawPanes = decoded['panes'];
      if (rawPanes is! List) {
        return null;
      }
      final panes = <WorkspacePaneLayoutPane>[];
      final seenPaneIds = <String>{};
      for (final item in rawPanes) {
        if (item is! Map) {
          continue;
        }
        final pane = WorkspacePaneLayoutPane.tryFromJson(
          item.cast<String, Object?>(),
        );
        if (pane == null || !seenPaneIds.add(pane.id)) {
          continue;
        }
        panes.add(pane);
      }
      if (panes.isEmpty) {
        return null;
      }
      final requestedActivePaneId = decoded['activePaneId']?.toString().trim();
      final activePaneId = panes.any((pane) => pane.id == requestedActivePaneId)
          ? requestedActivePaneId!
          : panes.first.id;
      return WorkspacePaneLayoutSnapshot(
        panes: List<WorkspacePaneLayoutPane>.unmodifiable(panes),
        activePaneId: activePaneId,
      );
    } catch (_) {
      return null;
    }
  }
}

class WorkspacePaneLayoutStore {
  static const String _layoutKeyPrefix = 'workspace.desktopSessionPanes';

  String _storageKey(String serverStorageKey) =>
      '$_layoutKeyPrefix::$serverStorageKey';

  Future<WorkspacePaneLayoutSnapshot?> load(String serverStorageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(serverStorageKey));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final snapshot = WorkspacePaneLayoutSnapshot.tryDecode(raw);
    if (snapshot != null) {
      return snapshot;
    }
    await prefs.remove(_storageKey(serverStorageKey));
    return null;
  }

  Future<void> save(
    String serverStorageKey,
    WorkspacePaneLayoutSnapshot snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(serverStorageKey), snapshot.encode());
  }

  Future<void> clear(String serverStorageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(serverStorageKey));
  }

  Future<void> transfer({
    required String fromServerStorageKey,
    required String toServerStorageKey,
  }) async {
    if (fromServerStorageKey == toServerStorageKey) {
      return;
    }
    final snapshot = await load(fromServerStorageKey);
    if (snapshot == null) {
      return;
    }
    await save(toServerStorageKey, snapshot);
    await clear(fromServerStorageKey);
  }
}

String? normalizeWorkspacePaneSessionId(String? sessionId) {
  final normalized = sessionId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
