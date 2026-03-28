import '../../features/chat/chat_models.dart';
import '../../features/tools/todo_models.dart';

List<SessionSummary> applySessionUpsertEvent(
  List<SessionSummary> sessions,
  Map<String, Object?> properties,
) {
  final infoJson = _asObjectMap(properties['info']);
  if (infoJson == null) {
    return sessions;
  }

  SessionSummary nextSession;
  try {
    nextSession = SessionSummary.fromJson(infoJson);
  } catch (_) {
    return sessions;
  }

  final next = List<SessionSummary>.from(sessions);
  final index = next.indexWhere((session) => session.id == nextSession.id);
  if (index >= 0) {
    next[index] = nextSession;
  } else {
    next.add(nextSession);
  }
  next.sort(_compareSessionsByRecency);
  return List<SessionSummary>.unmodifiable(next);
}

List<SessionSummary> applySessionDeletedEvent(
  List<SessionSummary> sessions,
  Map<String, Object?> properties,
) {
  final sessionId =
      properties['sessionID']?.toString() ??
      _asObjectMap(properties['info'])?['id']?.toString();
  if (sessionId == null || sessionId.isEmpty) {
    return sessions;
  }

  final next = sessions
      .where((session) => session.id != sessionId)
      .toList(growable: false);
  return next.length == sessions.length ? sessions : next;
}

Map<String, SessionStatusSummary> applySessionStatusEvent(
  Map<String, SessionStatusSummary> statuses,
  Map<String, Object?> properties,
) {
  final sessionId = properties['sessionID']?.toString();
  if (sessionId == null || sessionId.isEmpty) {
    return statuses;
  }

  final rawStatus = properties['status'];
  final nextStatus = switch (rawStatus) {
    final String value => SessionStatusSummary(type: value),
    final Map value => SessionStatusSummary.fromJson(
      value.cast<String, Object?>(),
    ),
    _ => null,
  };
  if (nextStatus == null) {
    return statuses;
  }

  return <String, SessionStatusSummary>{...statuses, sessionId: nextStatus};
}

Map<String, SessionStatusSummary> removeSessionStatusEvent(
  Map<String, SessionStatusSummary> statuses,
  Map<String, Object?> properties,
) {
  final sessionId =
      properties['sessionID']?.toString() ??
      _asObjectMap(properties['info'])?['id']?.toString();
  if (sessionId == null ||
      sessionId.isEmpty ||
      !statuses.containsKey(sessionId)) {
    return statuses;
  }

  final next = Map<String, SessionStatusSummary>.from(statuses)
    ..remove(sessionId);
  return next;
}

List<ChatMessage> applyMessageUpdatedEvent(
  List<ChatMessage> messages,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final infoJson = _asObjectMap(properties['info']);
  if (infoJson == null) {
    return messages;
  }

  final sessionId = infoJson['sessionID']?.toString();
  if (!_matchesSelectedSession(
    selectedSessionId,
    sessionId,
    allowMissing: false,
  )) {
    return messages;
  }

  final messageId = infoJson['id']?.toString();
  if (messageId == null || messageId.isEmpty) {
    return messages;
  }

  final index = messages.indexWhere((message) => message.info.id == messageId);
  if (index < 0) {
    return <ChatMessage>[
      ...messages,
      ChatMessage(info: _mergeInfo(null, infoJson), parts: const <ChatPart>[]),
    ];
  }

  final next = List<ChatMessage>.from(messages);
  next[index] = next[index].copyWith(
    info: _mergeInfo(next[index].info, infoJson),
  );
  return next;
}

List<ChatMessage> applyMessageRemovedEvent(
  List<ChatMessage> messages,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final sessionId = properties['sessionID']?.toString();
  if (!_matchesSelectedSession(
    selectedSessionId,
    sessionId,
    allowMissing: false,
  )) {
    return messages;
  }

  final messageId = properties['messageID']?.toString();
  if (messageId == null || messageId.isEmpty) {
    return messages;
  }

  return messages
      .where((message) => message.info.id != messageId)
      .toList(growable: false);
}

List<ChatMessage> applyMessagePartUpdatedEvent(
  List<ChatMessage> messages,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final partJson = _asObjectMap(properties['part']);
  if (partJson == null) {
    return messages;
  }

  final sessionId = partJson['sessionID']?.toString();
  if (!_matchesSelectedSession(
    selectedSessionId,
    sessionId,
    allowMissing: false,
  )) {
    return messages;
  }

  final messageId = partJson['messageID']?.toString();
  final partId = partJson['id']?.toString();
  if (messageId == null ||
      messageId.isEmpty ||
      partId == null ||
      partId.isEmpty) {
    return messages;
  }

  final messageIndex = messages.indexWhere((message) => message.info.id == messageId);
  final currentMessage = messageIndex >= 0 ? messages[messageIndex] : null;
  var partIndex = -1;
  ChatPart? currentPart;
  if (currentMessage != null) {
    for (var index = 0; index < currentMessage.parts.length; index += 1) {
      final candidate = currentMessage.parts[index];
      if (candidate.id == partId) {
        partIndex = index;
        currentPart = candidate;
        break;
      }
    }
  }
  final mergedPart = _mergePart(
    currentPart,
    partJson,
    fallbackMessageId: messageId,
    fallbackSessionId: selectedSessionId ?? sessionId,
  );

  if (messageIndex < 0) {
    return <ChatMessage>[
      ...messages,
      ChatMessage(
        info: ChatMessageInfo(
          id: messageId,
          role: 'assistant',
          sessionId: selectedSessionId ?? sessionId,
        ),
        parts: <ChatPart>[mergedPart],
      ),
    ];
  }

  if (currentPart != null && _chatPartEquals(currentPart, mergedPart)) {
    return messages;
  }

  final parts = List<ChatPart>.from(currentMessage!.parts);
  if (partIndex < 0) {
    parts.add(mergedPart);
  } else {
    parts[partIndex] = mergedPart;
  }
  final next = List<ChatMessage>.from(messages);
  next[messageIndex] = currentMessage.copyWith(
    parts: parts.toList(growable: false),
  );
  return next;
}

List<TodoItem> applyTodoUpdatedEvent(
  List<TodoItem> todos,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final sessionId = properties['sessionID']?.toString();
  if (!_matchesSelectedSession(
    selectedSessionId,
    sessionId,
    allowMissing: false,
  )) {
    return todos;
  }

  final rawTodos = properties['todos'];
  if (rawTodos is List) {
    return TodoItem.listFromJson(rawTodos);
  }

  final todoId = properties['todoID']?.toString();
  final status = properties['status']?.toString();
  if (todoId == null || todoId.isEmpty || status == null || status.isEmpty) {
    return todos;
  }

  final next = List<TodoItem>.from(todos);
  final index = next.indexWhere((todo) => todo.id == todoId);
  if (index < 0) {
    return todos;
  }

  next[index] = TodoItem(
    id: next[index].id,
    content: next[index].content,
    status: status,
    priority: next[index].priority,
  );
  return next;
}

bool _matchesSelectedSession(
  String? selectedSessionId,
  String? eventSessionId, {
  required bool allowMissing,
}) {
  return selectedSessionId == null ||
      (allowMissing && eventSessionId == null) ||
      selectedSessionId == eventSessionId;
}

Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return null;
}

int _compareSessionsByRecency(SessionSummary left, SessionSummary right) {
  final updated = right.updatedAt.compareTo(left.updatedAt);
  if (updated != 0) {
    return updated;
  }

  final leftCreated = left.createdAt;
  final rightCreated = right.createdAt;
  if (leftCreated != null && rightCreated != null) {
    final created = rightCreated.compareTo(leftCreated);
    if (created != 0) {
      return created;
    }
  } else if (leftCreated == null && rightCreated != null) {
    return 1;
  } else if (leftCreated != null && rightCreated == null) {
    return -1;
  }

  return right.id.compareTo(left.id);
}

ChatMessageInfo _mergeInfo(
  ChatMessageInfo? current,
  Map<String, Object?> json,
) {
  return ChatMessageInfo.fromJson(<String, Object?>{
    ...?current?.toJson(),
    ...json,
  });
}

ChatPart _mergePart(
  ChatPart? current,
  Map<String, Object?> json, {
  required String fallbackMessageId,
  required String? fallbackSessionId,
}) {
  final hasStreamingText =
      json.containsKey('text') || json.containsKey('content');
  return ChatPart(
    id: json['id']?.toString() ?? current?.id ?? '',
    type: json['type']?.toString() ?? current?.type ?? 'unknown',
    text: hasStreamingText
        ? (json['text'] ?? json['content'])?.toString()
        : current?.text,
    tool: json.containsKey('tool') ? json['tool']?.toString() : current?.tool,
    filename: json.containsKey('filename')
        ? json['filename']?.toString()
        : current?.filename,
    messageId:
        json['messageID']?.toString() ??
        current?.messageId ??
        fallbackMessageId,
    sessionId:
        json['sessionID']?.toString() ??
        current?.sessionId ??
        fallbackSessionId,
    metadata: <String, Object?>{
      ...?current?.metadata,
      ...json,
      if (hasStreamingText) '_streaming': true,
    },
  );
}

bool _chatPartEquals(ChatPart left, ChatPart right) {
  return left.id == right.id &&
      left.type == right.type &&
      left.text == right.text &&
      left.tool == right.tool &&
      left.filename == right.filename &&
      left.messageId == right.messageId &&
      left.sessionId == right.sessionId &&
      _objectMapEquals(left.metadata, right.metadata);
}

bool _objectMapEquals(Map<String, Object?> left, Map<String, Object?> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
