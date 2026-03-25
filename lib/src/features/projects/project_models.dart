class ProjectIconInfo {
  const ProjectIconInfo({this.url, this.override, this.color});

  final String? url;
  final String? override;
  final String? color;

  String? get effectiveImage {
    final overrideValue = override?.trim();
    if (overrideValue != null && overrideValue.isNotEmpty) {
      return overrideValue;
    }
    final urlValue = url?.trim();
    if (urlValue != null && urlValue.isNotEmpty) {
      return urlValue;
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'override': override,
    'color': color,
  };

  factory ProjectIconInfo.fromJson(Map<String, Object?> json) {
    return ProjectIconInfo(
      url: json['url'] as String?,
      override: json['override'] as String?,
      color: json['color'] as String?,
    );
  }

  ProjectIconInfo copyWith({
    String? url,
    String? override,
    String? color,
    bool clearUrl = false,
    bool clearOverride = false,
    bool clearColor = false,
  }) {
    return ProjectIconInfo(
      url: clearUrl ? null : (url ?? this.url),
      override: clearOverride ? null : (override ?? this.override),
      color: clearColor ? null : (color ?? this.color),
    );
  }
}

class ProjectCommandsInfo {
  const ProjectCommandsInfo({this.start});

  final String? start;

  Map<String, Object?> toJson() => <String, Object?>{'start': start};

  factory ProjectCommandsInfo.fromJson(Map<String, Object?> json) {
    return ProjectCommandsInfo(start: json['start'] as String?);
  }

  ProjectCommandsInfo copyWith({String? start, bool clearStart = false}) {
    return ProjectCommandsInfo(
      start: clearStart ? null : (start ?? this.start),
    );
  }
}

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.directory,
    required this.worktree,
    required this.name,
    required this.vcs,
    required this.updatedAt,
    this.icon,
    this.commands,
  });

  final String id;
  final String directory;
  final String worktree;
  final String? name;
  final String? vcs;
  final DateTime? updatedAt;
  final ProjectIconInfo? icon;
  final ProjectCommandsInfo? commands;

  String get title {
    final candidate = name?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return projectDisplayLabel(directory);
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
      icon: json['icon'] is Map
          ? ProjectIconInfo.fromJson(
              (json['icon'] as Map).cast<String, Object?>(),
            )
          : null,
      commands: json['commands'] is Map
          ? ProjectCommandsInfo.fromJson(
              (json['commands'] as Map).cast<String, Object?>(),
            )
          : null,
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
    'icon': icon?.toJson(),
    'commands': commands?.toJson(),
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
  const ProjectSessionHint({this.id, this.title, this.status});

  final String? id;
  final String? title;
  final String? status;
}

class ProjectTarget {
  const ProjectTarget({
    required this.directory,
    required this.label,
    this.id,
    this.name,
    this.source,
    this.vcs,
    this.branch,
    this.icon,
    this.commands,
    this.lastSession,
  });

  final String directory;
  final String label;
  final String? id;
  final String? name;
  final String? source;
  final String? vcs;
  final String? branch;
  final ProjectIconInfo? icon;
  final ProjectCommandsInfo? commands;
  final ProjectSessionHint? lastSession;

  String get title {
    final candidate = name?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return label.trim().isNotEmpty ? label : projectDisplayLabel(directory);
  }

  Map<String, Object?> toJson() => {
    'directory': directory,
    'label': label,
    'id': id,
    'name': name,
    'source': source,
    'vcs': vcs,
    'branch': branch,
    'icon': icon?.toJson(),
    'commands': commands?.toJson(),
    'lastSessionId': lastSession?.id,
    'lastSessionTitle': lastSession?.title,
    'lastSessionStatus': lastSession?.status,
  };

  factory ProjectTarget.fromJson(Map<String, Object?> json) {
    final id = json['lastSessionId'] as String?;
    final title = json['lastSessionTitle'] as String?;
    final status = json['lastSessionStatus'] as String?;
    return ProjectTarget(
      directory: json['directory']! as String,
      label: json['label']! as String,
      id: json['id'] as String?,
      name: json['name'] as String?,
      source: json['source'] as String?,
      vcs: json['vcs'] as String?,
      branch: json['branch'] as String?,
      icon: json['icon'] is Map
          ? ProjectIconInfo.fromJson(
              (json['icon'] as Map).cast<String, Object?>(),
            )
          : null,
      commands: json['commands'] is Map
          ? ProjectCommandsInfo.fromJson(
              (json['commands'] as Map).cast<String, Object?>(),
            )
          : null,
      lastSession: id == null && title == null && status == null
          ? null
          : ProjectSessionHint(id: id, title: title, status: status),
    );
  }

  ProjectTarget copyWith({
    String? directory,
    String? label,
    String? id,
    String? name,
    String? source,
    String? vcs,
    String? branch,
    ProjectIconInfo? icon,
    ProjectCommandsInfo? commands,
    ProjectSessionHint? lastSession,
    bool clearId = false,
    bool clearName = false,
    bool clearIcon = false,
    bool clearCommands = false,
    bool clearLastSession = false,
  }) {
    return ProjectTarget(
      directory: directory ?? this.directory,
      label: label ?? this.label,
      id: clearId ? null : (id ?? this.id),
      name: clearName ? null : (name ?? this.name),
      source: source ?? this.source,
      vcs: vcs ?? this.vcs,
      branch: branch ?? this.branch,
      icon: clearIcon ? null : (icon ?? this.icon),
      commands: clearCommands ? null : (commands ?? this.commands),
      lastSession: clearLastSession ? null : (lastSession ?? this.lastSession),
    );
  }
}

String projectDisplayLabel(String directory, {String? name}) {
  final candidate = name?.trim();
  if (candidate != null && candidate.isNotEmpty) {
    return candidate;
  }
  final normalized = directory.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final parts = normalized.split(RegExp(r'[\\/]'));
  for (var index = parts.length - 1; index >= 0; index -= 1) {
    final part = parts[index].trim();
    if (part.isNotEmpty) {
      return part;
    }
  }
  return normalized;
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
