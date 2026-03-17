import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/shell/opencode_shell_screen.dart';

void main() {
  const profile = ServerProfile(
    id: 'server-1',
    label: 'Mock server',
    baseUrl: 'http://127.0.0.1:8787',
  );
  const project = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const OpenCodeShellScreen(
          profile: profile,
          project: project,
          onExit: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop shell shows left rail and context utilities', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 1000));

    expect(find.text('Project and sessions'), findsOneWidget);
    expect(find.text('Context utilities'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
  });

  testWidgets('tablet portrait shell shows utilities drawer hint', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(820, 1180));

    expect(find.text('Utilities drawer'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('mobile shell keeps chat canvas visible', (tester) async {
    await pumpShell(tester, size: const Size(430, 932));

    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Back to projects'), findsOneWidget);
  });
}

void _noop() {}
