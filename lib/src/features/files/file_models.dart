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

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'path': path,
    'type': type,
    'ignored': ignored,
  };
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

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'status': status,
    'added': added,
    'removed': removed,
  };
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

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'content': content,
  };
}

class FileDiffSummary {
  const FileDiffSummary({required this.path, required this.content});

  final String path;
  final String content;

  bool get isEmpty => content.trim().isEmpty;

  factory FileDiffSummary.fromJson(Map<String, Object?> json) {
    return FileDiffSummary(
      path: (json['path'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'content': content,
  };
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

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'lines': lines,
  };
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

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'kind': kind,
    'path': path,
  };
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

  FileBrowserBundle copyWith({
    List<FileNodeSummary>? nodes,
    List<String>? searchResults,
    List<TextMatchSummary>? textMatches,
    List<SymbolSummary>? symbols,
    List<FileStatusSummary>? statuses,
    FileContentSummary? preview,
    bool clearPreview = false,
    String? selectedPath,
    bool clearSelectedPath = false,
  }) {
    return FileBrowserBundle(
      nodes: nodes ?? this.nodes,
      searchResults: searchResults ?? this.searchResults,
      textMatches: textMatches ?? this.textMatches,
      symbols: symbols ?? this.symbols,
      statuses: statuses ?? this.statuses,
      preview: clearPreview ? null : (preview ?? this.preview),
      selectedPath: clearSelectedPath
          ? null
          : (selectedPath ?? this.selectedPath),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'nodes': nodes.map((item) => item.toJson()).toList(growable: false),
    'searchResults': searchResults,
    'textMatches': textMatches
        .map((item) => item.toJson())
        .toList(growable: false),
    'symbols': symbols.map((item) => item.toJson()).toList(growable: false),
    'statuses': statuses.map((item) => item.toJson()).toList(growable: false),
    'preview': preview?.toJson(),
    'selectedPath': selectedPath,
  };

  factory FileBrowserBundle.fromJson(Map<String, Object?> json) {
    return FileBrowserBundle(
      nodes: ((json['nodes'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => FileNodeSummary.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
      searchResults: ((json['searchResults'] as List?) ?? const <Object?>[])
          .map((item) => item.toString())
          .toList(growable: false),
      textMatches: ((json['textMatches'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) => TextMatchSummary.fromJson(item.cast<String, Object?>()),
          )
          .toList(growable: false),
      symbols: ((json['symbols'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => SymbolSummary.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
      statuses: ((json['statuses'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) => FileStatusSummary.fromJson(item.cast<String, Object?>()),
          )
          .toList(growable: false),
      preview: json['preview'] is Map
          ? FileContentSummary.fromJson(
              (json['preview'] as Map).cast<String, Object?>(),
            )
          : null,
      selectedPath: json['selectedPath'] as String?,
    );
  }
}
