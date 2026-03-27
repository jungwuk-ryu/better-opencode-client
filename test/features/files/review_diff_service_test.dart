import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/files/file_models.dart';
import 'package:opencode_mobile_remote/src/features/files/review_diff_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

void main() {
  test('fetches diff output through the official session diff api', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final client = MockClient((request) async {
      requestedUri = request.url;
      requestedHeaders = request.headers;
      return http.Response(
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'file': 'README.md',
            'before': 'Old title\n',
            'after': 'README preview\nMore docs\n',
            'additions': 2,
            'deletions': 1,
            'status': 'modified',
          },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final service = ReviewDiffService(client: client);

    final diff = await service.fetchDiff(
      profile: const ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'https://example.com/api',
        username: 'demo',
        password: 'secret',
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_1',
      status: const FileStatusSummary(
        path: 'README.md',
        status: 'modified',
        added: 1,
        removed: 1,
      ),
    );

    expect(
      requestedUri.toString(),
      'https://example.com/api/session/ses_1/diff',
    );
    expect(requestedHeaders['authorization'], isNotEmpty);
    expect(diff.path, 'README.md');
    expect(diff.content, contains('diff --git a/README.md b/README.md'));
    expect(diff.content, contains('--- a/README.md'));
    expect(diff.content, contains('+++ b/README.md'));
    expect(diff.content, contains('-Old title'));
    expect(diff.content, contains('+README preview'));
    expect(diff.content, contains('+More docs'));
  });

  test('returns an empty diff when the selected path is absent', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'file': 'docs/guide.md',
            'before': 'old\n',
            'after': 'new\n',
            'additions': 1,
            'deletions': 1,
            'status': 'modified',
          },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final service = ReviewDiffService(client: client);

    final diff = await service.fetchDiff(
      profile: const ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:4096',
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_1',
      status: const FileStatusSummary(
        path: 'README.md',
        status: 'modified',
        added: 1,
        removed: 1,
      ),
    );

    expect(diff.path, 'README.md');
    expect(diff.content, isEmpty);
  });

  test(
    'fetches the session review bundle without mixing in file status data',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:4096/session/ses_1/diff',
        );
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'file': 'README.md',
              'before': 'old\n',
              'after': 'new\n',
              'additions': 1,
              'deletions': 1,
              'status': 'modified',
            },
            <String, Object?>{
              'file': 'lib/main.dart',
              'before': '',
              'after': 'void main() {}\n',
              'additions': 1,
              'deletions': 0,
              'status': 'added',
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final service = ReviewDiffService(client: client);

      final bundle = await service.fetchSessionDiffs(
        profile: const ServerProfile(
          id: 'server',
          label: 'Mock',
          baseUrl: 'http://localhost:4096',
        ),
        sessionId: 'ses_1',
      );

      expect(bundle.statuses.map((item) => item.path), <String>[
        'README.md',
        'lib/main.dart',
      ]);
      expect(bundle.statuses.map((item) => item.status), <String>[
        'modified',
        'added',
      ]);
      expect(
        bundle.diffForPath('lib/main.dart')?.content,
        contains('diff --git a/lib/main.dart b/lib/main.dart'),
      );
    },
  );

  test('builds a unified diff for added files', () {
    final diff = buildReviewUnifiedDiff(
      path: '.env.example',
      status: 'added',
      before: '',
      after: 'API_KEY=demo\n',
    );

    expect(diff, contains('new file mode 100644'));
    expect(diff, contains('--- /dev/null'));
    expect(diff, contains('+++ b/.env.example'));
    expect(diff, contains('@@ -0,0 +1 @@'));
    expect(diff, contains('+API_KEY=demo'));
  });
}
