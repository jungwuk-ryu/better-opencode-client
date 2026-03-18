import 'dart:convert';

import '../chat/chat_models.dart';
import '../files/file_models.dart';
import '../tools/todo_models.dart';

List<TodoItem> sortTodosForDisplay(List<TodoItem> todos) {
  final sorted = todos.toList()
    ..sort((a, b) => _todoRank(a.status).compareTo(_todoRank(b.status)));
  return sorted;
}

Map<String, FileStatusSummary> indexFileStatuses(
  List<FileStatusSummary> fileStatuses,
) {
  return <String, FileStatusSummary>{
    for (final item in fileStatuses) item.path: item,
  };
}

String buildInspectorSessionJson(SessionSummary? session) {
  if (session == null) {
    return '{}';
  }
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'id': session.id,
    'directory': session.directory,
    'title': session.title,
    'version': session.version,
    'parentID': session.parentId,
  });
}

String buildInspectorMessageJson(ChatMessage? message) {
  if (message == null) {
    return '{}';
  }
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'id': message.info.id,
    'role': message.info.role,
    'providerID': message.info.providerId,
    'modelID': message.info.modelId,
    'parts': message.parts.map((part) => part.metadata).toList(growable: false),
  });
}

int _todoRank(String status) {
  return switch (status) {
    'in_progress' => 0,
    'pending' => 1,
    'completed' => 2,
    _ => 3,
  };
}
