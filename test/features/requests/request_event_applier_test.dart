import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/features/requests/request_event_applier.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';

void main() {
  test('question.asked inserts and updates matching session requests', () {
    final created = applyQuestionAskedEvent(
      const <QuestionRequestSummary>[],
      <String, Object?>{
        'id': 'que_1',
        'sessionID': 'ses_1',
        'questions': <Map<String, Object?>>[
          <String, Object?>{
            'question': 'Proceed?',
            'header': 'Confirm',
            'custom': false,
            'options': <Map<String, Object?>>[
              <String, Object?>{'label': 'Yes', 'description': 'Allow'},
            ],
          },
        ],
      },
      selectedSessionId: 'ses_1',
    );
    final updated = applyQuestionAskedEvent(created, <String, Object?>{
      'id': 'que_1',
      'sessionID': 'ses_1',
      'questions': <Map<String, Object?>>[
        <String, Object?>{
          'question': 'Proceed now?',
          'header': 'Updated',
          'options': <Map<String, Object?>>[
            <String, Object?>{'label': 'Yes', 'description': 'Allow'},
          ],
        },
      ],
    }, selectedSessionId: 'ses_1');

    expect(updated, hasLength(1));
    expect(updated.single.questions.single.header, 'Updated');
    expect(created.single.questions.single.custom, isFalse);
    expect(updated.single.questions.single.custom, isTrue);
  });

  test(
    'question.asked ignores malformed payloads and still applies later valid events',
    () {
      final existing = <QuestionRequestSummary>[
        const QuestionRequestSummary(
          id: 'que_existing',
          sessionId: 'ses_1',
          questions: <QuestionPromptSummary>[
            QuestionPromptSummary(
              question: 'Keep current state?',
              header: 'Current',
              multiple: false,
              options: <QuestionOptionSummary>[],
            ),
          ],
        ),
      ];

      final afterMalformed = applyQuestionAskedEvent(
        existing,
        const <String, Object?>{
          'id': 'que_bad',
          'sessionID': 'ses_1',
          'questions': 'invalid',
        },
        selectedSessionId: 'ses_1',
      );
      final afterValid = applyQuestionAskedEvent(
        afterMalformed,
        const <String, Object?>{
          'id': 'que_2',
          'sessionID': 'ses_1',
          'questions': <Object?>[
            <String, Object?>{
              'question': 'Proceed after malformed event?',
              'header': 'Recovered',
              'multiple': false,
              'options': <Object?>[],
            },
          ],
        },
        selectedSessionId: 'ses_1',
      );

      expect(afterMalformed, same(existing));
      expect(afterValid.map((item) => item.id), <String>[
        'que_existing',
        'que_2',
      ]);
    },
  );

  test('question resolved removes only matching session request', () {
    final questions = <QuestionRequestSummary>[
      const QuestionRequestSummary(
        id: 'que_1',
        sessionId: 'ses_1',
        questions: <QuestionPromptSummary>[],
      ),
    ];

    final unchanged = applyQuestionResolvedEvent(
      questions,
      const <String, Object?>{'sessionID': 'ses_2', 'requestID': 'que_1'},
      selectedSessionId: 'ses_1',
    );
    final removed = applyQuestionResolvedEvent(
      questions,
      const <String, Object?>{'sessionID': 'ses_1', 'requestID': 'que_1'},
      selectedSessionId: 'ses_1',
    );

    expect(unchanged, hasLength(1));
    expect(removed, isEmpty);
  });

  test('permission.asked inserts and updates matching session requests', () {
    final created = applyPermissionAskedEvent(
      const <PermissionRequestSummary>[],
      <String, Object?>{
        'id': 'per_1',
        'sessionID': 'ses_1',
        'permission': 'bash',
        'patterns': <String>['npm test'],
      },
      selectedSessionId: 'ses_1',
    );
    final updated = applyPermissionAskedEvent(created, <String, Object?>{
      'id': 'per_1',
      'sessionID': 'ses_1',
      'permission': 'edit',
      'patterns': <String>['lib/**'],
    }, selectedSessionId: 'ses_1');

    expect(updated, hasLength(1));
    expect(updated.single.permission, 'edit');
  });

  test(
    'permission.asked ignores malformed payloads and still applies later valid events',
    () {
      final existing = <PermissionRequestSummary>[
        const PermissionRequestSummary(
          id: 'per_existing',
          sessionId: 'ses_1',
          permission: 'bash',
          patterns: <String>['npm test'],
        ),
      ];

      final afterMalformed =
          applyPermissionAskedEvent(existing, const <String, Object?>{
            'id': 'per_bad',
            'sessionID': 'ses_1',
            'permission': 'edit',
            'patterns': 'invalid',
          }, selectedSessionId: 'ses_1');
      final afterValid = applyPermissionAskedEvent(
        afterMalformed,
        const <String, Object?>{
          'id': 'per_2',
          'sessionID': 'ses_1',
          'permission': 'edit',
          'patterns': <Object?>['lib/**'],
        },
        selectedSessionId: 'ses_1',
      );

      expect(afterMalformed, same(existing));
      expect(afterValid.map((item) => item.id), <String>[
        'per_existing',
        'per_2',
      ]);
    },
  );

  test('permission resolved removes only matching session request', () {
    final permissions = <PermissionRequestSummary>[
      const PermissionRequestSummary(
        id: 'per_1',
        sessionId: 'ses_1',
        permission: 'bash',
        patterns: <String>['npm test'],
      ),
    ];

    final unchanged = applyPermissionResolvedEvent(
      permissions,
      const <String, Object?>{'sessionID': 'ses_2', 'requestID': 'per_1'},
      selectedSessionId: 'ses_1',
    );
    final removed = applyPermissionResolvedEvent(
      permissions,
      const <String, Object?>{'sessionID': 'ses_1', 'requestID': 'per_1'},
      selectedSessionId: 'ses_1',
    );

    expect(unchanged, hasLength(1));
    expect(removed, isEmpty);
  });
}
