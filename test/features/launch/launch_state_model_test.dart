import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/launch/launch_state_model.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

void main() {
  const firstServer = ServerProfile(
    id: 'server-1',
    label: 'Primary',
    baseUrl: 'https://one.example.com',
  );
  const secondServer = ServerProfile(
    id: 'server-2',
    label: 'Backup',
    baseUrl: 'https://two.example.com',
  );

  test('launch model reports no saved servers', () {
    final state = LaunchHomeState.fromContext(savedServers: const []);

    expect(state.serverState.inventory, LaunchServerInventory.noServers);
    expect(state.serverState.connectionStatus, LaunchConnectionStatus.unknown);
  });

  test('launch model reports one saved server', () {
    final state = LaunchHomeState.fromContext(
      savedServers: const <ServerProfile>[firstServer],
      selectedServer: firstServer,
      connectionStatus: LaunchConnectionStatus.ready,
    );

    expect(state.serverState.inventory, LaunchServerInventory.oneServer);
    expect(state.serverState.selectedServer?.id, 'server-1');
    expect(state.serverState.connectionStatus, LaunchConnectionStatus.ready);
  });

  test('launch model reports multiple saved servers', () {
    final state = LaunchHomeState.fromContext(
      savedServers: const <ServerProfile>[firstServer, secondServer],
      selectedServer: secondServer,
      connectionStatus: LaunchConnectionStatus.offline,
    );

    expect(state.serverState.inventory, LaunchServerInventory.multipleServers);
    expect(state.serverState.selectedServer?.id, 'server-2');
    expect(state.serverState.connectionStatus, LaunchConnectionStatus.offline);
  });

  test('launch routing reports project missing when nothing is selected', () {
    final state = LaunchHomeState.fromContext(
      savedServers: const <ServerProfile>[firstServer],
      selectedServer: firstServer,
      connectionStatus: LaunchConnectionStatus.ready,
    );

    expect(state.routingState.status, LaunchRoutingStatus.projectMissing);
    expect(state.routingState.project, isNull);
    expect(state.routingState.canResume, isFalse);
  });

  test(
    'launch routing reports session missing when project has no resume hint',
    () {
      final state = LaunchHomeState.fromContext(
        savedServers: const <ServerProfile>[firstServer],
        selectedServer: firstServer,
        connectionStatus: LaunchConnectionStatus.ready,
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
        ),
      );

      expect(state.routingState.status, LaunchRoutingStatus.sessionMissing);
      expect(state.routingState.project?.directory, '/workspace/demo');
      expect(state.routingState.session, isNull);
      expect(state.routingState.canResume, isFalse);
    },
  );

  test(
    'launch routing is ready when project includes last session details',
    () {
      final state = LaunchHomeState.fromContext(
        savedServers: const <ServerProfile>[firstServer],
        selectedServer: firstServer,
        connectionStatus: LaunchConnectionStatus.ready,
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
          lastSession: ProjectSessionHint(
            title: 'Resume me',
            status: 'running',
          ),
        ),
      );

      expect(state.routingState.status, LaunchRoutingStatus.readyToResume);
      expect(state.routingState.project?.directory, '/workspace/demo');
      expect(state.routingState.session?.title, 'Resume me');
      expect(state.routingState.session?.status, 'running');
      expect(state.routingState.canResume, isTrue);
    },
  );
}
