class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.directory,
    required this.worktree,
    required this.name,
    required this.vcs,
    required this.updatedAt,
  });

  final String id;
  final String directory;
  final String worktree;
  final String? name;
  final String? vcs;
  final DateTime? updatedAt;

  String get title {
    final candidate = name?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return directory;
  }

  factory ProjectSummary.fromJson(Map<String, Object?> json) {
    final time = (json['time'] as Map?)?.cast<String, Object?>();
    final updatedValue = time?['updated'];
    return ProjectSummary(
      id: (json['id'] as String?) ?? (json['directory'] as String? ?? ''),
      directory:
          (json['directory'] as String?) ?? (json['worktree'] as String? ?? ''),
      worktree:
          (json['worktree'] as String?) ?? (json['directory'] as String? ?? ''),
      name: json['name'] as String?,
      vcs: json['vcs'] as String?,
      updatedAt: updatedValue is num
          ? DateTime.fromMillisecondsSinceEpoch(updatedValue.toInt())
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'directory': directory,
    'worktree': worktree,
    'name': name,
    'vcs': vcs,
    'time': updatedAt == null
        ? null
        : <String, Object?>{'updated': updatedAt!.millisecondsSinceEpoch},
  };
}

class PathInfo {
  const PathInfo({
    required this.home,
    required this.state,
    required this.config,
    required this.worktree,
    required this.directory,
  });

  final String home;
  final String state;
  final String config;
  final String worktree;
  final String directory;

  factory PathInfo.fromJson(Map<String, Object?> json) {
    return PathInfo(
      home: (json['home'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      config: (json['config'] as String?) ?? '',
      worktree: (json['worktree'] as String?) ?? '',
      directory: (json['directory'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'home': home,
    'state': state,
    'config': config,
    'worktree': worktree,
    'directory': directory,
  };
}

class VcsInfo {
  const VcsInfo({required this.branch});

  final String branch;

  factory VcsInfo.fromJson(Map<String, Object?> json) {
    return VcsInfo(branch: (json['branch'] as String?) ?? '');
  }

  Map<String, Object?> toJson() => <String, Object?>{'branch': branch};
}

class ProjectSessionHint {
  const ProjectSessionHint({this.title, this.status});

  final String? title;
  final String? status;
}

class ProjectTarget {
  const ProjectTarget({
    required this.directory,
    required this.label,
    this.source,
    this.vcs,
    this.branch,
    this.lastSession,
  });

  final String directory;
  final String label;
  final String? source;
  final String? vcs;
  final String? branch;
  final ProjectSessionHint? lastSession;

  Map<String, Object?> toJson() => {
    'directory': directory,
    'label': label,
    'source': source,
    'vcs': vcs,
    'branch': branch,
    'lastSessionTitle': lastSession?.title,
    'lastSessionStatus': lastSession?.status,
  };

  factory ProjectTarget.fromJson(Map<String, Object?> json) {
    final title = json['lastSessionTitle'] as String?;
    final status = json['lastSessionStatus'] as String?;
    return ProjectTarget(
      directory: json['directory']! as String,
      label: json['label']! as String,
      source: json['source'] as String?,
      vcs: json['vcs'] as String?,
      branch: json['branch'] as String?,
      lastSession: title == null && status == null
          ? null
          : ProjectSessionHint(title: title, status: status),
    );
  }
}

class ProjectCatalog {
  const ProjectCatalog({
    required this.currentProject,
    required this.projects,
    required this.pathInfo,
    required this.vcsInfo,
  });

  final ProjectSummary? currentProject;
  final List<ProjectSummary> projects;
  final PathInfo? pathInfo;
  final VcsInfo? vcsInfo;

  Map<String, Object?> toJson() => <String, Object?>{
    'currentProject': currentProject?.toJson(),
    'projects': projects.map((item) => item.toJson()).toList(growable: false),
    'pathInfo': pathInfo?.toJson(),
    'vcsInfo': vcsInfo?.toJson(),
  };

  factory ProjectCatalog.fromJson(Map<String, Object?> json) {
    return ProjectCatalog(
      currentProject: json['currentProject'] is Map
          ? ProjectSummary.fromJson(
              (json['currentProject'] as Map).cast<String, Object?>(),
            )
          : null,
      projects: ((json['projects'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => ProjectSummary.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
      pathInfo: json['pathInfo'] is Map
          ? PathInfo.fromJson((json['pathInfo'] as Map).cast<String, Object?>())
          : null,
      vcsInfo: json['vcsInfo'] is Map
          ? VcsInfo.fromJson((json['vcsInfo'] as Map).cast<String, Object?>())
          : null,
    );
  }
}
