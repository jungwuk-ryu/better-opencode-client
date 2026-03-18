import 'dart:io';

import 'package:opencode_mobile_remote/src/features/requests/request_alerts.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';

void main() {
  final questionAlert = buildQuestionAskedAlert(
    previous: const <QuestionRequestSummary>[],
    next: const <QuestionRequestSummary>[
      QuestionRequestSummary(
        id: 'que_demo',
        sessionId: 'ses_demo',
        questions: <QuestionPromptSummary>[
          QuestionPromptSummary(
            question: 'Apply the generated patch?',
            header: 'Review request',
            options: <QuestionOptionSummary>[],
            multiple: false,
          ),
        ],
      ),
    ],
  );
  final duplicateQuestionAlert = buildQuestionAskedAlert(
    previous: const <QuestionRequestSummary>[
      QuestionRequestSummary(
        id: 'que_demo',
        sessionId: 'ses_demo',
        questions: <QuestionPromptSummary>[],
      ),
    ],
    next: const <QuestionRequestSummary>[
      QuestionRequestSummary(
        id: 'que_demo',
        sessionId: 'ses_demo',
        questions: <QuestionPromptSummary>[],
      ),
    ],
  );
  final permissionAlert = buildPermissionAskedAlert(
    previous: const <PermissionRequestSummary>[],
    next: const <PermissionRequestSummary>[
      PermissionRequestSummary(
        id: 'per_demo',
        sessionId: 'ses_demo',
        permission: 'bash',
        patterns: <String>['dart analyze'],
      ),
    ],
  );

  stdout.writeln(
    'question alert: ${questionAlert?.requestId} ${questionAlert?.summary}',
  );
  stdout.writeln(
    'question duplicate: ${duplicateQuestionAlert == null ? 'suppressed' : 'unexpected'}',
  );
  stdout.writeln(
    'permission alert: ${permissionAlert?.requestId} ${permissionAlert?.summary} ${permissionAlert?.detail}',
  );
}
