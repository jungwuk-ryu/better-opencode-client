class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.directory,
    required this.title,
    required this.version,
    required this.updatedAt,
    this.createdAt,
    this.archivedAt,
    this.parentId,
    this.shareUrl,
    this.revertMessageId,
    this.revertPartId,
  });

  final String id;
  final String directory;
  final String title;
  final String version;
  final DateTime updatedAt;
  final DateTime? createdAt;
  final DateTime? archivedAt;
  final String? parentId;
  final String? shareUrl;
  final String? revertMessageId;
  final String? revertPartId;

  factory SessionSummary.fromJson(Map<String, Object?> json) {
    final time = (json['time'] as Map?)?.cast<String, Object?>() ?? const {};
    final created = time['created'];
    final updated = time['updated'];
    final archived = time['archived'];
    final share = (json['share'] as Map?)?.cast<String, Object?>();
    final revert = (json['revert'] as Map?)?.cast<String, Object?>();
    return SessionSummary(
      id: json['id']! as String,
      directory: json['directory']! as String,
      title: (json['title'] as String?) ?? '',
      version: (json['version'] as String?) ?? '',
      updatedAt: updated is num
          ? DateTime.fromMillisecondsSinceEpoch(updated.toInt())
          : DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
      archivedAt: archived is num
          ? DateTime.fromMillisecondsSinceEpoch(archived.toInt())
          : null,
      parentId: json['parentID'] as String?,
      shareUrl: share?['url']?.toString(),
      revertMessageId: revert?['messageID']?.toString(),
      revertPartId: revert?['partID']?.toString(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'directory': directory,
    'title': title,
    'version': version,
    'parentID': parentId,
    'share': shareUrl == null ? null : <String, Object?>{'url': shareUrl},
    'time': <String, Object?>{
      'created': createdAt?.millisecondsSinceEpoch,
      'updated': updatedAt.millisecondsSinceEpoch,
      'archived': archivedAt?.millisecondsSinceEpoch,
    },
    'revert': revertMessageId == null && revertPartId == null
        ? null
        : <String, Object?>{
            'messageID': revertMessageId,
            'partID': revertPartId,
          },
  };
}

class SessionStatusSummary {
  const SessionStatusSummary({required this.type, this.message, this.attempt});

  final String type;
  final String? message;
  final int? attempt;

  factory SessionStatusSummary.fromJson(Map<String, Object?> json) {
    return SessionStatusSummary(
      type: (json['type'] as String?) ?? 'idle',
      message: json['message'] as String?,
      attempt: (json['attempt'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'message': message,
    'attempt': attempt,
  };
}

class ChatMessage {
  const ChatMessage({required this.info, required this.parts});

  final ChatMessageInfo info;
  final List<ChatPart> parts;

  ChatMessage copyWith({ChatMessageInfo? info, List<ChatPart>? parts}) {
    return ChatMessage(info: info ?? this.info, parts: parts ?? this.parts);
  }

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      info: ChatMessageInfo.fromJson(
        (json['info']! as Map).cast<String, Object?>(),
      ),
      parts: ((json['parts'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => ChatPart.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'info': info.toJson(),
    'parts': parts.map((part) => part.toJson()).toList(growable: false),
  };
}

const int _metadataStringLimit = 16 * 1024;
const int _metadataDiffLimit = 24 * 1024;
const int _metadataCollectionLimit = 48;
const int _diagnosticsSampleFileLimit = 16;
const int _metadataMaxDepth = 5;

class ChatMessageInfo {
  const ChatMessageInfo({
    required this.id,
    required this.role,
    this.sessionId,
    this.modelId,
    this.providerId,
    this.agent,
    this.variant,
    this.systemPrompt,
    this.createdAt,
    this.completedAt,
    this.cost,
    this.totalTokens,
    this.inputTokens,
    this.outputTokens,
    this.reasoningTokens,
    this.cacheReadTokens,
    this.cacheWriteTokens,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String role;
  final String? sessionId;
  final String? modelId;
  final String? providerId;
  final String? agent;
  final String? variant;
  final String? systemPrompt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final double? cost;
  final int? totalTokens;
  final int? inputTokens;
  final int? outputTokens;
  final int? reasoningTokens;
  final int? cacheReadTokens;
  final int? cacheWriteTokens;
  final Map<String, Object?> metadata;

  ChatMessageInfo copyWith({
    String? id,
    String? role,
    String? sessionId,
    String? modelId,
    String? providerId,
    String? agent,
    String? variant,
    String? systemPrompt,
    DateTime? createdAt,
    DateTime? completedAt,
    double? cost,
    int? totalTokens,
    int? inputTokens,
    int? outputTokens,
    int? reasoningTokens,
    int? cacheReadTokens,
    int? cacheWriteTokens,
    Map<String, Object?>? metadata,
  }) {
    return ChatMessageInfo(
      id: id ?? this.id,
      role: role ?? this.role,
      sessionId: sessionId ?? this.sessionId,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      agent: agent ?? this.agent,
      variant: variant ?? this.variant,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      cost: cost ?? this.cost,
      totalTokens: totalTokens ?? this.totalTokens,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      cacheReadTokens: cacheReadTokens ?? this.cacheReadTokens,
      cacheWriteTokens: cacheWriteTokens ?? this.cacheWriteTokens,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ChatMessageInfo.fromJson(Map<String, Object?> json) {
    final model = (json['model'] as Map?)?.cast<String, Object?>();
    final time = (json['time'] as Map?)?.cast<String, Object?>();
    final tokens = (json['tokens'] as Map?)?.cast<String, Object?>();
    final cache = (tokens?['cache'] as Map?)?.cast<String, Object?>();
    final created = time?['created'];
    final completed = time?['completed'];
    return ChatMessageInfo(
      id: json['id']! as String,
      role: (json['role'] as String?) ?? 'assistant',
      sessionId: json['sessionID'] as String?,
      modelId:
          json['modelID'] as String? ?? model?['modelID']?.toString().trim(),
      providerId:
          json['providerID'] as String? ??
          model?['providerID']?.toString().trim(),
      agent: json['agent'] as String?,
      variant: json['variant'] as String?,
      systemPrompt: json['system'] as String?,
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
      completedAt: completed is num
          ? DateTime.fromMillisecondsSinceEpoch(completed.toInt())
          : null,
      cost: (json['cost'] as num?)?.toDouble(),
      totalTokens: (tokens?['total'] as num?)?.toInt(),
      inputTokens: (tokens?['input'] as num?)?.toInt(),
      outputTokens: (tokens?['output'] as num?)?.toInt(),
      reasoningTokens: (tokens?['reasoning'] as num?)?.toInt(),
      cacheReadTokens: (cache?['read'] as num?)?.toInt(),
      cacheWriteTokens: (cache?['write'] as num?)?.toInt(),
      metadata: _sanitizeMetadataMap(json),
    );
  }

  int get resolvedTotalTokens =>
      totalTokens ??
      (inputTokens ?? 0) +
          (outputTokens ?? 0) +
          (reasoningTokens ?? 0) +
          (cacheReadTokens ?? 0) +
          (cacheWriteTokens ?? 0);

  bool get hasTokenUsage => resolvedTotalTokens > 0;

  Map<String, Object?> toJson() => Map<String, Object?>.from(metadata)
    ..putIfAbsent('id', () => id)
    ..putIfAbsent('role', () => role)
    ..putIfAbsent('sessionID', () => sessionId)
    ..putIfAbsent('modelID', () => modelId)
    ..putIfAbsent('providerID', () => providerId)
    ..putIfAbsent('agent', () => agent)
    ..putIfAbsent('variant', () => variant)
    ..putIfAbsent('system', () => systemPrompt)
    ..putIfAbsent(
      'time',
      () => <String, Object?>{
        'created': createdAt?.millisecondsSinceEpoch,
        'completed': completedAt?.millisecondsSinceEpoch,
      },
    )
    ..putIfAbsent('cost', () => cost)
    ..putIfAbsent(
      'tokens',
      () => <String, Object?>{
        'total': totalTokens,
        'input': inputTokens ?? 0,
        'output': outputTokens ?? 0,
        'reasoning': reasoningTokens ?? 0,
        'cache': <String, Object?>{
          'read': cacheReadTokens ?? 0,
          'write': cacheWriteTokens ?? 0,
        },
      },
    );
}

class ChatPart {
  const ChatPart({
    required this.id,
    required this.type,
    this.text,
    this.tool,
    this.filename,
    this.messageId,
    this.sessionId,
    this.metadata = const {},
  });

  final String id;
  final String type;
  final String? text;
  final String? tool;
  final String? filename;
  final String? messageId;
  final String? sessionId;
  final Map<String, Object?> metadata;

  ChatPart copyWith({
    String? id,
    String? type,
    String? text,
    String? tool,
    String? filename,
    String? messageId,
    String? sessionId,
    Map<String, Object?>? metadata,
  }) {
    return ChatPart(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      tool: tool ?? this.tool,
      filename: filename ?? this.filename,
      messageId: messageId ?? this.messageId,
      sessionId: sessionId ?? this.sessionId,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ChatPart.fromJson(Map<String, Object?> json) {
    return ChatPart(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'unknown',
      text: json['text']?.toString() ?? json['content']?.toString(),
      tool: json['tool'] as String?,
      filename: json['filename'] as String?,
      messageId: json['messageID'] as String?,
      sessionId: json['sessionID'] as String?,
      metadata: _sanitizePartMetadata(json),
    );
  }

  Map<String, Object?> toJson() => Map<String, Object?>.from(metadata)
    ..putIfAbsent('id', () => id)
    ..putIfAbsent('type', () => type)
    ..putIfAbsent('text', () => text)
    ..putIfAbsent('tool', () => tool)
    ..putIfAbsent('filename', () => filename)
    ..putIfAbsent('messageID', () => messageId)
    ..putIfAbsent('sessionID', () => sessionId);
}

Map<String, Object?> _sanitizePartMetadata(Map<String, Object?> json) {
  final sanitized = _sanitizeMetadataMap(json);
  if ((json['type'] as String?) != 'tool') {
    return sanitized;
  }
  final state = (json['state'] as Map?)?.cast<String, Object?>();
  if (state == null) {
    return sanitized;
  }
  return Map<String, Object?>.unmodifiable(
    <String, Object?>{
      ...sanitized,
      'state': _sanitizeToolState(
        tool: json['tool']?.toString(),
        state: state,
      ),
    },
  );
}

Map<String, Object?> _sanitizeToolState({
  required String? tool,
  required Map<String, Object?> state,
}) {
  final sanitized = _sanitizeMetadataMap(state);
  final metadata = (state['metadata'] as Map?)?.cast<String, Object?>();
  return Map<String, Object?>.unmodifiable(
    <String, Object?>{
      ...sanitized,
      if (metadata != null)
        'metadata': _sanitizeToolStateMetadata(
          tool: tool?.trim().toLowerCase(),
          metadata: metadata,
        ),
    },
  );
}

Map<String, Object?> _sanitizeToolStateMetadata({
  required String? tool,
  required Map<String, Object?> metadata,
}) {
  final sanitized = _sanitizeMetadataMap(metadata);
  if (tool != 'apply_patch') {
    return sanitized;
  }
  final next = <String, Object?>{...sanitized};
  final diagnostics = metadata['diagnostics'];
  if (diagnostics is Map) {
    next['diagnostics'] = <String, Object?>{
      'omitted': true,
      'fileCount': diagnostics.length,
      'sampleFiles': diagnostics.keys
          .take(_diagnosticsSampleFileLimit)
          .map((key) => key.toString())
          .toList(growable: false),
    };
    next['truncated'] = true;
  }
  final diff = metadata['diff'];
  if (diff is String && diff.length > _metadataDiffLimit) {
    next['diff'] = _truncateMetadataString(diff, limit: _metadataDiffLimit);
    next['truncated'] = true;
  }
  return Map<String, Object?>.unmodifiable(next);
}

Map<String, Object?> _sanitizeMetadataMap(
  Map<String, Object?> source, {
  int depth = 0,
}) {
  if (source.isEmpty) {
    return const <String, Object?>{};
  }
  final result = <String, Object?>{};
  for (final entry in source.entries.take(_metadataCollectionLimit)) {
    result[entry.key] = _sanitizeMetadataValue(
      entry.value,
      key: entry.key,
      depth: depth + 1,
    );
  }
  if (source.length > _metadataCollectionLimit) {
    result['truncatedKeys'] = source.length - _metadataCollectionLimit;
  }
  return Map<String, Object?>.unmodifiable(result);
}

Object? _sanitizeMetadataValue(
  Object? value, {
  required String key,
  required int depth,
}) {
  if (value == null || value is num || value is bool) {
    return value;
  }
  if (value is String) {
    return _truncateMetadataString(
      value,
      limit: key == 'diff' ? _metadataDiffLimit : _metadataStringLimit,
    );
  }
  if (value is Map) {
    if (depth >= _metadataMaxDepth) {
      return <String, Object?>{
        'omitted': true,
        'entryCount': value.length,
      };
    }
    return _sanitizeMetadataMap(value.cast<String, Object?>(), depth: depth);
  }
  if (value is List) {
    if (depth >= _metadataMaxDepth) {
      return <String, Object?>{
        'omitted': true,
        'length': value.length,
      };
    }
    final items = value
        .take(_metadataCollectionLimit)
        .map(
          (item) => _sanitizeMetadataValue(
            item,
            key: key,
            depth: depth + 1,
          ),
        )
        .toList(growable: false);
    if (value.length <= _metadataCollectionLimit) {
      return items;
    }
    return <Object?>[
      ...items,
      <String, Object?>{
        'omitted': true,
        'remaining': value.length - _metadataCollectionLimit,
      },
    ];
  }
  return value.toString();
}

String _truncateMetadataString(String value, {required int limit}) {
  if (value.length <= limit) {
    return value;
  }
  return '${value.substring(0, limit)}\n...[truncated ${value.length - limit} chars]';
}

class ChatSessionBundle {
  const ChatSessionBundle({
    required this.sessions,
    required this.statuses,
    required this.messages,
    this.selectedSessionId,
  });

  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final List<ChatMessage> messages;
  final String? selectedSessionId;

  Map<String, Object?> toJson() => <String, Object?>{
    'sessions': sessions.map((item) => item.toJson()).toList(growable: false),
    'statuses': statuses.map((key, value) => MapEntry(key, value.toJson())),
    'messages': messages.map((item) => item.toJson()).toList(growable: false),
    'selectedSessionId': selectedSessionId,
  };

  factory ChatSessionBundle.fromJson(Map<String, Object?> json) {
    final statusesMap = (json['statuses'] as Map?)?.cast<String, Object?>();
    return ChatSessionBundle(
      sessions: ((json['sessions'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => SessionSummary.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
      statuses: statusesMap == null
          ? const <String, SessionStatusSummary>{}
          : statusesMap.map(
              (key, value) => MapEntry(
                key,
                SessionStatusSummary.fromJson(
                  (value as Map).cast<String, Object?>(),
                ),
              ),
            ),
      messages: ((json['messages'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((item) => ChatMessage.fromJson(item.cast<String, Object?>()))
          .toList(growable: false),
      selectedSessionId: json['selectedSessionId'] as String?,
    );
  }
}

class ChatMessagePage {
  const ChatMessagePage({required this.messages, this.nextCursor});

  final List<ChatMessage> messages;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
