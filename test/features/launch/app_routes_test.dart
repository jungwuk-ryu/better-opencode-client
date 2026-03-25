import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';

void main() {
  test('encodes and decodes workspace routes', () {
    const directory = '/workspace/demo-project';

    final route = buildWorkspaceRoute(directory, sessionId: 'session-123');
    final parsed = AppRouteData.parse(route);

    expect(parsed, isA<WorkspaceRouteData>());
    final workspace = parsed as WorkspaceRouteData;
    expect(workspace.directory, directory);
    expect(workspace.sessionId, 'session-123');
  });

  test('parses project route without explicit session id', () {
    const directory = '/workspace/new-session';

    final route = buildWorkspaceRoute(directory);
    final parsed = AppRouteData.parse(route) as WorkspaceRouteData;

    expect(parsed.directory, directory);
    expect(parsed.sessionId, isNull);
  });

  test('falls back to home for invalid encoded routes', () {
    final parsed = AppRouteData.parse('/not-valid-base64/session');
    expect(parsed, isA<HomeRouteData>());
  });
}
