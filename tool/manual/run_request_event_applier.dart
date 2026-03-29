import 'dart:convert';
import 'dart:io';

import 'package:better_opencode_client/src/features/requests/request_event_applier.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';

void main() {
  var questions = const <QuestionRequestSummary>[];
  var permissions = const <PermissionRequestSummary>[];

  questions = applyQuestionAskedEvent(questions, <String, Object?>{
    'id': 'que_1',
    'sessionID': 'ses_1',
    'questions': <Map<String, Object?>>[
      <String, Object?>{
        'question': 'Continue?',
        'header': 'Question',
        'options': <Map<String, Object?>>[
          <String, Object?>{'label': 'Yes', 'description': 'Continue'},
        ],
      },
    ],
  }, selectedSessionId: 'ses_1');
  permissions = applyPermissionAskedEvent(permissions, <String, Object?>{
    'id': 'per_1',
    'sessionID': 'ses_1',
    'permission': 'bash',
    'patterns': <String>['npm test'],
  }, selectedSessionId: 'ses_1');
  questions = applyQuestionResolvedEvent(questions, const <String, Object?>{
    'sessionID': 'ses_1',
    'requestID': 'que_1',
  }, selectedSessionId: 'ses_1');

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'questionCount': questions.length,
      'permissionCount': permissions.length,
      'permissionType': permissions.single.permission,
    }),
  );
}
