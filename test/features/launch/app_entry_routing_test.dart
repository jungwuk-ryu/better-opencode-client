import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/app/app.dart';
import 'package:opencode_mobile_remote/src/features/connection/connection_home_screen.dart';
import 'package:opencode_mobile_remote/src/features/home/workspace_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app launch routes into the workspace home scaffold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OpenCodeRemoteApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceHomeScreen), findsOneWidget);
    expect(find.byType(ConnectionHomeScreen), findsNothing);
    expect(find.text('OpenCode Remote'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Add server'), findsWidgets);
    expect(find.text('Projects and sessions'), findsOneWidget);
    expect(find.text('Probe server'), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);
  });
}
