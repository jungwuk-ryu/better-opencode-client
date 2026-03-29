import 'dart:convert';
import 'dart:io';

import 'package:better_opencode_client/src/core/network/live_event_applier.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';

void main() {
  var messages = const <ChatMessage>[];
  var statuses = const <String, SessionStatusSummary>{};
  var todos = const <TodoItem>[
    TodoItem(
      id: 'todo_1',
      content: 'Stream updates',
      status: 'pending',
      priority: 'high',
    ),
  ];

  messages = applyMessageUpdatedEvent(messages, const <String, Object?>{
    'info': <String, Object?>{
      'id': 'msg_1',
      'role': 'assistant',
      'sessionID': 'ses_1',
    },
  }, selectedSessionId: 'ses_1');
  messages = applyMessagePartUpdatedEvent(messages, const <String, Object?>{
    'part': <String, Object?>{
      'id': 'prt_1',
      'messageID': 'msg_1',
      'sessionID': 'ses_1',
      'type': 'text',
      'text': 'streamed answer',
    },
  }, selectedSessionId: 'ses_1');
  todos = applyTodoUpdatedEvent(todos, const <String, Object?>{
    'sessionID': 'ses_1',
    'todoID': 'todo_1',
    'status': 'completed',
  }, selectedSessionId: 'ses_1');
  statuses = applySessionStatusEvent(statuses, const <String, Object?>{
    'sessionID': 'ses_1',
    'status': <String, Object?>{
      'type': 'retry',
      'attempt': 2,
      'message': 'network timeout',
    },
  });

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'messageCount': messages.length,
      'messageId': messages.single.info.id,
      'partText': messages.single.parts.single.text,
      'todoStatus': todos.single.status,
      'sessionStatusType': statuses['ses_1']?.type,
      'sessionStatusAttempt': statuses['ses_1']?.attempt,
    }),
  );
}
