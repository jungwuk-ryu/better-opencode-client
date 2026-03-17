class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.directory,
    required this.title,
    required this.version,
    required this.updatedAt,
    this.parentId,
  });

  final String id;
  final String directory;
  final String title;
  final String version;
  final DateTime updatedAt;
  final String? parentId;

  factory SessionSummary.fromJson(Map<String, Object?> json) {
    final time = (json['time'] as Map?)?.cast<String, Object?>() ?? const {};
    final updated = time['updated'];
    return SessionSummary(
      id: json['id']! as String,
      directory: json['directory']! as String,
      title: (json['title'] as String?) ?? '',
      version: (json['version'] as String?) ?? '',
      updatedAt: updated is num
          ? DateTime.fromMillisecondsSinceEpoch(updated.toInt())
          : DateTime.fromMillisecondsSinceEpoch(0),
      parentId: json['parentID'] as String?,
    );
  }
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
}

class ChatMessage {
  const ChatMessage({required this.info, required this.parts});

  final ChatMessageInfo info;
  final List<ChatPart> parts;

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
}

class ChatMessageInfo {
  const ChatMessageInfo({
    required this.id,
    required this.role,
    this.modelId,
    this.providerId,
  });

  final String id;
  final String role;
  final String? modelId;
  final String? providerId;

  factory ChatMessageInfo.fromJson(Map<String, Object?> json) {
    return ChatMessageInfo(
      id: json['id']! as String,
      role: (json['role'] as String?) ?? 'assistant',
      modelId: json['modelID'] as String?,
      providerId: json['providerID'] as String?,
    );
  }
}

class ChatPart {
  const ChatPart({
    required this.id,
    required this.type,
    this.text,
    this.tool,
    this.filename,
    this.metadata = const {},
  });

  final String id;
  final String type;
  final String? text;
  final String? tool;
  final String? filename;
  final Map<String, Object?> metadata;

  factory ChatPart.fromJson(Map<String, Object?> json) {
    return ChatPart(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'unknown',
      text: json['text'] as String?,
      tool: json['tool'] as String?,
      filename: json['filename'] as String?,
      metadata: json,
    );
  }
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
}
