import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_git_models.dart';
import 'package:better_opencode_client/src/features/projects/project_git_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_git_sheet.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_inbox_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('git sheet keeps large file and branch lists navigable', (
    tester,
  ) async {
    final service = _FakeProjectGitService(
      snapshot: RepoStatusSnapshot(
        hasGit: true,
        currentBranch: 'main',
        changedFiles: List<RepoChangedFile>.generate(
          80,
          (index) => RepoChangedFile(
            path: 'lib/file_${index.toString().padLeft(3, '0')}.dart',
            statusCode: 'M',
            staged: index.isEven,
            unstaged: !index.isEven,
            conflicted: false,
            untracked: false,
          ),
          growable: false,
        ),
        generatedAt: DateTime(2026, 4, 10),
      ),
      branches: List<RepoBranchOption>.generate(
        60,
        (index) => RepoBranchOption(
          name: index == 0
              ? 'main'
              : 'feature/branch_${index.toString().padLeft(3, '0')}',
          current: index == 0,
          upstream: index == 0 ? 'origin/main' : 'origin/branch_$index',
        ),
        growable: false,
      ),
    );

    await tester.pumpWidget(
      _SheetHarness(
        child: WorkspaceGitSheet(
          profile: const ServerProfile(
            id: 'server',
            label: 'Mock',
            baseUrl: 'http://localhost:3000',
          ),
          project: const ProjectTarget(
            directory: '/workspace/demo',
            label: 'Demo',
            source: 'server',
            vcs: 'git',
            branch: 'main',
          ),
          sessionId: 'ses_git',
          service: service,
          onOpenTerminalFallback: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Git Workflow'), findsOneWidget);
    expect(find.text('Changed Files'), findsOneWidget);
    expect(find.textContaining('80 total'), findsOneWidget);
    expect(find.text('lib/file_000.dart'), findsOneWidget);
    expect(find.text('lib/file_079.dart'), findsNothing);

    await tester.tap(find.text('Branches'));
    await tester.pumpAndSettle();

    expect(find.text('Branches'), findsWidgets);
    expect(find.text('main'), findsWidgets);
    expect(find.text('feature/branch_059'), findsNothing);
    await tester.dragUntilVisible(
      find.text('feature/branch_059'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('feature/branch_059'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('lib/file_079.dart'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('lib/file_079.dart'), findsOneWidget);
  });

  testWidgets('inbox sheet keeps section summaries and late rows visible', (
    tester,
  ) async {
    final now = DateTime(2026, 4, 10, 14, 0);
    final questions = List<QuestionRequestSummary>.generate(
      20,
      (index) => QuestionRequestSummary(
        id: 'q$index',
        sessionId: index.isEven ? 'ses_a' : 'ses_b',
        questions: <QuestionPromptSummary>[
          QuestionPromptSummary(
            question: 'Choose a plan for item $index',
            header: 'Question ${index.toString().padLeft(2, '0')}',
            options: const <QuestionOptionSummary>[],
            multiple: false,
          ),
        ],
      ),
      growable: false,
    );
    final permissions = List<PermissionRequestSummary>.generate(
      15,
      (index) => PermissionRequestSummary(
        id: 'p$index',
        sessionId: index.isEven ? 'ses_b' : 'ses_a',
        permission: 'permission_${index.toString().padLeft(2, '0')}',
        patterns: <String>['/workspace/demo/$index/**'],
      ),
      growable: false,
    );
    await tester.pumpWidget(
      _SheetHarness(
        child: WorkspaceInboxSheet(
          sessions: <SessionSummary>[
            SessionSummary(
              id: 'ses_a',
              directory: '/workspace/demo',
              title: 'Alpha Session',
              version: '1',
              updatedAt: DateTime(2026, 4, 10, 14, 0),
              createdAt: DateTime(2026, 4, 10, 13, 0),
            ),
            SessionSummary(
              id: 'ses_b',
              directory: '/workspace/demo',
              title: 'Beta Session',
              version: '1',
              updatedAt: DateTime(2026, 4, 10, 14, 0),
              createdAt: DateTime(2026, 4, 10, 13, 0),
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_a': SessionStatusSummary(type: 'running'),
            'ses_b': SessionStatusSummary(type: 'waiting'),
          },
          pendingRequests: PendingRequestBundle(
            questions: questions,
            permissions: permissions,
          ),
          notifications: List<WorkspaceNotificationEntry>.generate(
            30,
            (index) => WorkspaceNotificationEntry(
              directory: '/workspace/demo/notification_$index',
              sessionId: index.isEven ? 'ses_a' : 'ses_b',
              timeMs: now
                  .subtract(Duration(minutes: index))
                  .millisecondsSinceEpoch,
              viewed: false,
              type: index % 5 == 0
                  ? WorkspaceNotificationType.error
                  : WorkspaceNotificationType.activity,
            ),
            growable: false,
          ),
          onOpenSession: (_) async {},
          onAllowPermission: (_) async {},
          onRejectPermission: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('20 questions'), findsOneWidget);
    expect(find.text('15 approvals'), findsOneWidget);
    expect(find.text('30 unread events'), findsOneWidget);
    expect(find.textContaining('Alpha Session'), findsWidgets);
    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('Approvals'), findsNothing);
    expect(find.text('Question 19'), findsNothing);
    expect(find.text('permission_14'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Approvals'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approvals'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Unread Activity'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unread Activity'), findsOneWidget);
    expect(find.text('/workspace/demo/notification_29'), findsNothing);

    await tester.dragUntilVisible(
      find.text('/workspace/demo/notification_29'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('/workspace/demo/notification_29'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Question 19'),
      find.byType(CustomScrollView),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Question 19'), findsOneWidget);
  });
}

class _SheetHarness extends StatelessWidget {
  const _SheetHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    );
  }
}

class _FakeProjectGitService extends ProjectGitService {
  _FakeProjectGitService({required this.snapshot, required this.branches});

  final RepoStatusSnapshot snapshot;
  final List<RepoBranchOption> branches;

  @override
  Future<RepoStatusSnapshot> loadStatus({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    return snapshot;
  }

  @override
  Future<List<RepoBranchOption>> loadBranches({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    return branches;
  }
}
