import 'dart:io';

import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/files/file_models.dart';
import 'package:opencode_mobile_remote/src/features/shell/shell_derived_data.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';

void main() {
  final sorted = sortTodosForDisplay(const <TodoItem>[
    TodoItem(id: 't3', content: 'Done', status: 'completed', priority: 'low'),
    TodoItem(
      id: 't1',
      content: 'Working',
      status: 'in_progress',
      priority: 'high',
    ),
    TodoItem(
      id: 't2',
      content: 'Queued',
      status: 'pending',
      priority: 'medium',
    ),
  ]);
  final index = indexFileStatuses(const <FileStatusSummary>[
    FileStatusSummary(
      path: 'lib/src/app.dart',
      status: 'modified',
      added: 10,
      removed: 3,
    ),
  ]);
  final sessionJson = buildInspectorSessionJson(
    SessionSummary(
      id: 'ses_demo',
      directory: '/demo',
      title: 'Demo session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
  final messageJson = buildInspectorMessageJson(
    const ChatMessage(
      info: ChatMessageInfo(id: 'msg_demo', role: 'assistant'),
      parts: <ChatPart>[ChatPart(id: 'part_demo', type: 'text', text: 'hello')],
    ),
  );

  stdout.writeln('todo order: ${sorted.map((item) => item.id).join(',')}');
  stdout.writeln('file index hit: ${index['lib/src/app.dart']?.status}');
  stdout.writeln(
    'session json has demo: ${sessionJson.contains('Demo session')}',
  );
  stdout.writeln(
    'message json has parts key: ${messageJson.contains('"parts"')}',
  );
}
