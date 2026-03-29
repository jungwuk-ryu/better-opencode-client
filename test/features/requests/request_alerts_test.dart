import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/features/requests/request_alerts.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';

void main() {
  test('question alert triggers only for newly inserted request ids', () {
    final previous = <QuestionRequestSummary>[
      const QuestionRequestSummary(
        id: 'que_existing',
        sessionId: 'ses_1',
        questions: <QuestionPromptSummary>[],
      ),
    ];
    final next = <QuestionRequestSummary>[
      ...previous,
      const QuestionRequestSummary(
        id: 'que_new',
        sessionId: 'ses_1',
        questions: <QuestionPromptSummary>[
          QuestionPromptSummary(
            question: 'Proceed with the edit?',
            header: 'Confirmation required',
            options: <QuestionOptionSummary>[],
            multiple: false,
          ),
        ],
      ),
    ];

    final alert = buildQuestionAskedAlert(previous: previous, next: next);
    final duplicateAlert = buildQuestionAskedAlert(previous: next, next: next);

    expect(alert?.requestId, 'que_new');
    expect(alert?.summary, 'Confirmation required');
    expect(alert?.detail, 'Proceed with the edit?');
    expect(duplicateAlert, isNull);
  });

  test('permission alert uses permission name and patterns', () {
    final next = <PermissionRequestSummary>[
      const PermissionRequestSummary(
        id: 'per_new',
        sessionId: 'ses_1',
        permission: 'bash',
        patterns: <String>['npm test', 'dart analyze'],
      ),
    ];

    final alert = buildPermissionAskedAlert(
      previous: const <PermissionRequestSummary>[],
      next: next,
    );

    expect(alert?.requestId, 'per_new');
    expect(alert?.summary, 'bash');
    expect(alert?.detail, 'npm test, dart analyze');
  });
}
