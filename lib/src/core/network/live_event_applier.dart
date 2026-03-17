import '../../features/chat/chat_models.dart';
import '../../features/tools/todo_models.dart';

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

  final next = List<ChatMessage>.from(messages);
  final messageIndex = next.indexWhere(
    (message) => message.info.id == messageId,
  );
  final currentPart = messageIndex >= 0
      ? next[messageIndex].parts
            .where((part) => part.id == partId)
            .cast<ChatPart?>()
            .firstOrNull
      : null;
  final mergedPart = _mergePart(
    currentPart,
    partJson,
    fallbackMessageId: messageId,
    fallbackSessionId: selectedSessionId ?? sessionId,
  );

  if (messageIndex < 0) {
    return <ChatMessage>[
      ...next,
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

  final parts = List<ChatPart>.from(next[messageIndex].parts);
  final partIndex = parts.indexWhere((part) => part.id == partId);
  if (partIndex < 0) {
    parts.add(mergedPart);
  } else {
    parts[partIndex] = mergedPart;
  }
  next[messageIndex] = next[messageIndex].copyWith(
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
    return rawTodos
        .whereType<Map>()
        .map((item) => TodoItem.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
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

ChatMessageInfo _mergeInfo(
  ChatMessageInfo? current,
  Map<String, Object?> json,
) {
  return ChatMessageInfo(
    id: json['id']?.toString() ?? current?.id ?? '',
    role: json['role']?.toString() ?? current?.role ?? 'assistant',
    sessionId: json['sessionID']?.toString() ?? current?.sessionId,
    modelId: json.containsKey('modelID')
        ? json['modelID']?.toString()
        : current?.modelId,
    providerId: json.containsKey('providerID')
        ? json['providerID']?.toString()
        : current?.providerId,
  );
}

ChatPart _mergePart(
  ChatPart? current,
  Map<String, Object?> json, {
  required String fallbackMessageId,
  required String? fallbackSessionId,
}) {
  return ChatPart(
    id: json['id']?.toString() ?? current?.id ?? '',
    type: json['type']?.toString() ?? current?.type ?? 'unknown',
    text: json.containsKey('text') ? json['text']?.toString() : current?.text,
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
    metadata: <String, Object?>{...?current?.metadata, ...json},
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
