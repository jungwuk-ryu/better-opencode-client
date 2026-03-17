class FileNodeSummary {
  const FileNodeSummary({
    required this.name,
    required this.path,
    required this.type,
    required this.ignored,
  });

  final String name;
  final String path;
  final String type;
  final bool ignored;

  factory FileNodeSummary.fromJson(Map<String, Object?> json) {
    return FileNodeSummary(
      name: json['name']! as String,
      path: json['path']! as String,
      type: json['type']! as String,
      ignored: (json['ignored'] as bool?) ?? false,
    );
  }
}

class FileStatusSummary {
  const FileStatusSummary({
    required this.path,
    required this.status,
    required this.added,
    required this.removed,
  });

  final String path;
  final String status;
  final int added;
  final int removed;

  factory FileStatusSummary.fromJson(Map<String, Object?> json) {
    return FileStatusSummary(
      path: json['path']! as String,
      status: json['status']! as String,
      added: (json['added'] as num?)?.toInt() ?? 0,
      removed: (json['removed'] as num?)?.toInt() ?? 0,
    );
  }
}

class FileContentSummary {
  const FileContentSummary({required this.type, required this.content});

  final String type;
  final String content;

  factory FileContentSummary.fromJson(Map<String, Object?> json) {
    return FileContentSummary(
      type: json['type']! as String,
      content: (json['content'] as String?) ?? '',
    );
  }
}

class FileBrowserBundle {
  const FileBrowserBundle({
    required this.nodes,
    required this.searchResults,
    required this.statuses,
    required this.preview,
    required this.selectedPath,
  });

  final List<FileNodeSummary> nodes;
  final List<String> searchResults;
  final List<FileStatusSummary> statuses;
  final FileContentSummary? preview;
  final String? selectedPath;
}
