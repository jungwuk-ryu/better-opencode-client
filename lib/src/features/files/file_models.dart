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

class TextMatchSummary {
  const TextMatchSummary({required this.path, required this.lines});

  final String path;
  final String lines;

  factory TextMatchSummary.fromJson(Map<String, Object?> json) {
    return TextMatchSummary(
      path: (json['path'] as String?) ?? '',
      lines: (json['lines'] as String?) ?? (json['text'] as String?) ?? '',
    );
  }
}

class SymbolSummary {
  const SymbolSummary({required this.name, this.kind, this.path});

  final String name;
  final String? kind;
  final String? path;

  factory SymbolSummary.fromJson(Map<String, Object?> json) {
    final location = (json['location'] as Map?)?.cast<String, Object?>();
    return SymbolSummary(
      name: (json['name'] as String?) ?? '',
      kind: json['kind']?.toString(),
      path: location?['path']?.toString() ?? json['path']?.toString(),
    );
  }
}

class FileBrowserBundle {
  const FileBrowserBundle({
    required this.nodes,
    required this.searchResults,
    required this.textMatches,
    required this.symbols,
    required this.statuses,
    required this.preview,
    required this.selectedPath,
  });

  final List<FileNodeSummary> nodes;
  final List<String> searchResults;
  final List<TextMatchSummary> textMatches;
  final List<SymbolSummary> symbols;
  final List<FileStatusSummary> statuses;
  final FileContentSummary? preview;
  final String? selectedPath;
}
