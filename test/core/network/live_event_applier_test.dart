import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/network/live_event_applier.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';

void main() {
  test('session.status preserves structured retry payloads', () {
    final updated = applySessionStatusEvent(
      const <String, SessionStatusSummary>{},
      <String, Object?>{
        'sessionID': 'ses_1',
        'status': <String, Object?>{
          'type': 'retry',
          'attempt': 2,
          'message': 'network timeout',
        },
      },
    );

    expect(updated['ses_1']?.type, 'retry');
    expect(updated['ses_1']?.attempt, 2);
    expect(updated['ses_1']?.message, 'network timeout');
  });

  test('message.updated adds and merges message info for selected session', () {
    final seeded = <ChatMessage>[
      ChatMessage(
        info: const ChatMessageInfo(id: 'msg_2', role: 'assistant'),
        parts: const <ChatPart>[],
      ),
    ];

    final inserted = applyMessageUpdatedEvent(seeded, <String, Object?>{
      'info': <String, Object?>{
        'id': 'msg_1',
        'role': 'user',
        'sessionID': 'ses_1',
      },
    }, selectedSessionId: 'ses_1');
    final merged = applyMessageUpdatedEvent(inserted, <String, Object?>{
      'info': <String, Object?>{
        'id': 'msg_2',
        'role': 'assistant',
        'sessionID': 'ses_1',
        'providerID': 'openai',
      },
    }, selectedSessionId: 'ses_1');

    expect(merged.map((message) => message.info.id), <String>[
      'msg_2',
      'msg_1',
    ]);
    expect(merged.first.info.providerId, 'openai');
  });

  test('message.part.updated creates placeholder message and merges parts', () {
    final created = applyMessagePartUpdatedEvent(
      const <ChatMessage>[],
      <String, Object?>{
        'part': <String, Object?>{
          'id': 'prt_2',
          'messageID': 'msg_1',
          'sessionID': 'ses_1',
          'type': 'text',
          'text': 'draft',
        },
      },
      selectedSessionId: 'ses_1',
    );
    final updated = applyMessagePartUpdatedEvent(created, <String, Object?>{
      'part': <String, Object?>{
        'id': 'prt_2',
        'messageID': 'msg_1',
        'sessionID': 'ses_1',
        'type': 'text',
        'text': 'final',
      },
    }, selectedSessionId: 'ses_1');

    expect(updated, hasLength(1));
    expect(updated.single.info.id, 'msg_1');
    expect(updated.single.parts.single.text, 'final');
  });

  test('message.part.updated treats content payloads as text parts', () {
    final updated = applyMessagePartUpdatedEvent(
      const <ChatMessage>[],
      <String, Object?>{
        'part': <String, Object?>{
          'id': 'prt_content',
          'messageID': 'msg_1',
          'sessionID': 'ses_1',
          'type': 'text',
          'content': 'streamed content',
        },
      },
      selectedSessionId: 'ses_1',
    );

    expect(updated, hasLength(1));
    expect(updated.single.parts.single.text, 'streamed content');
  });

  test('message.part.updated ignores events without a matching session id', () {
    final updated = applyMessagePartUpdatedEvent(
      const <ChatMessage>[],
      <String, Object?>{
        'part': <String, Object?>{
          'id': 'prt_2',
          'messageID': 'msg_1',
          'type': 'text',
          'text': 'draft',
        },
      },
      selectedSessionId: 'ses_1',
    );

    expect(updated, isEmpty);
  });

  test(
    'message.removed ignores other sessions and removes selected message',
    () {
      final messages = <ChatMessage>[
        ChatMessage(
          info: const ChatMessageInfo(
            id: 'msg_1',
            role: 'user',
            sessionId: 'ses_1',
          ),
          parts: const <ChatPart>[],
        ),
      ];

      final unchanged = applyMessageRemovedEvent(
        messages,
        const <String, Object?>{'sessionID': 'ses_2', 'messageID': 'msg_1'},
        selectedSessionId: 'ses_1',
      );
      final removed = applyMessageRemovedEvent(
        messages,
        const <String, Object?>{'sessionID': 'ses_1', 'messageID': 'msg_1'},
        selectedSessionId: 'ses_1',
      );

      expect(unchanged, hasLength(1));
      expect(removed, isEmpty);
    },
  );

  test(
    'todo.updated accepts full snapshots and single-item status updates',
    () {
      final seeded = <TodoItem>[
        const TodoItem(
          id: 'todo_1',
          content: 'Write tests',
          status: 'pending',
          priority: 'high',
        ),
      ];

      final patched = applyTodoUpdatedEvent(seeded, const <String, Object?>{
        'sessionID': 'ses_1',
        'todoID': 'todo_1',
        'status': 'in_progress',
      }, selectedSessionId: 'ses_1');
      final replaced = applyTodoUpdatedEvent(patched, <String, Object?>{
        'sessionID': 'ses_1',
        'todos': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'todo_2',
            'content': 'Ship update',
            'status': 'completed',
            'priority': 'medium',
          },
        ],
      }, selectedSessionId: 'ses_1');

      expect(patched.single.status, 'in_progress');
      expect(replaced.single.id, 'todo_2');
    },
  );
}
