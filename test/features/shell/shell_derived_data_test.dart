import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/files/file_models.dart';
import 'package:better_opencode_client/src/features/shell/shell_derived_data.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';

void main() {
  test(
    'sortTodosForDisplay prioritizes in-progress before pending/completed',
    () {
      final sorted = sortTodosForDisplay(const <TodoItem>[
        TodoItem(
          id: '3',
          content: 'done',
          status: 'completed',
          priority: 'low',
        ),
        TodoItem(
          id: '1',
          content: 'active',
          status: 'in_progress',
          priority: 'high',
        ),
        TodoItem(
          id: '2',
          content: 'queued',
          status: 'pending',
          priority: 'medium',
        ),
      ]);

      expect(sorted.map((item) => item.id).toList(), <String>['1', '2', '3']);
    },
  );

  test('indexFileStatuses maps rows by path', () {
    final index = indexFileStatuses(const <FileStatusSummary>[
      FileStatusSummary(
        path: 'lib/main.dart',
        status: 'modified',
        added: 4,
        removed: 1,
      ),
    ]);

    expect(index['lib/main.dart']?.status, 'modified');
    expect(index['lib/main.dart']?.added, 4);
  });

  test('inspector builders emit compact pretty json payloads', () {
    final sessionJson = buildInspectorSessionJson(
      SessionSummary(
        id: 'ses_1',
        directory: '/tmp/project',
        title: 'Demo',
        version: '1',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    final messageJson = buildInspectorMessageJson(
      const ChatMessage(
        info: ChatMessageInfo(id: 'msg_1', role: 'assistant'),
        parts: <ChatPart>[ChatPart(id: 'part_1', type: 'text', text: 'hello')],
      ),
    );

    expect(sessionJson, contains('"directory": "/tmp/project"'));
    expect(messageJson, contains('"id": "msg_1"'));
    expect(messageJson, contains('"parts"'));
  });
}
