import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
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
  final capabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'test',
      version: '1.0.0',
      paths: const <String>{
        '/project',
        '/project/current',
        '/session',
        '/session/status',
        '/event',
        '/session/{sessionID}/todo',
        '/file',
        '/file/content',
        '/file/status',
        '/find/file',
        '/find/symbol',
        '/session/{sessionID}/shell',
        '/config',
        '/config/providers',
        '/question',
        '/permission',
        '/session/{sessionID}/share',
        '/session/{sessionID}/fork',
        '/session/{sessionID}/summarize',
        '/session/{sessionID}/revert',
        '/session/{sessionID}/init',
        '/provider/{providerID}/oauth/authorize',
        '/mcp/{name}/auth',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );
  final minimalCapabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'minimal',
      version: '1.0.0',
      paths: const <String>{'/project', '/project/current'},
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );

  Future<void> pumpShellWithCapabilities(
    WidgetTester tester, {
    required Size size,
    required CapabilityRegistry capabilitiesToUse,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OpenCodeShellScreen(
          profile: profile,
          project: project,
          capabilities: capabilitiesToUse,
          onExit: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    await pumpShellWithCapabilities(
      tester,
      size: size,
      capabilitiesToUse: capabilities,
    );
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

  testWidgets('minimal capabilities hide unsupported shell controls', (
    tester,
  ) async {
    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1000),
      capabilitiesToUse: minimalCapabilities,
    );

    expect(find.text('Fork'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Terminal'), findsNothing);
    expect(find.text('Config'), findsNothing);
  });
}

void _noop() {}
