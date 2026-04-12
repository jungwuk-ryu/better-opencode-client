import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';

enum LaunchConnectionStatus {
  unknown,
  ready,
  signInRequired,
  offline,
  specFetchFailure,
  incompatible,
}

enum LaunchServerInventory { noServers, oneServer, multipleServers }

enum LaunchRoutingStatus { projectMissing, sessionMissing, readyToResume }

final class LaunchHomeState {
  const LaunchHomeState({
    required this.serverState,
    required this.routingState,
  });

  factory LaunchHomeState.fromContext({
    required List<ServerProfile> savedServers,
    ServerProfile? selectedServer,
    LaunchConnectionStatus connectionStatus = LaunchConnectionStatus.unknown,
    ProjectTarget? project,
  }) {
    return LaunchHomeState(
      serverState: LaunchServerState(
        savedServers: savedServers,
        selectedServer: selectedServer,
        connectionStatus: connectionStatus,
      ),
      routingState: LaunchRoutingState.fromProject(project),
    );
  }

  final LaunchServerState serverState;
  final LaunchRoutingState routingState;
}

final class LaunchServerState {
  LaunchServerState({
    required List<ServerProfile> savedServers,
    this.selectedServer,
    this.connectionStatus = LaunchConnectionStatus.unknown,
  }) : savedServers = List<ServerProfile>.unmodifiable(savedServers);

  final List<ServerProfile> savedServers;
  final ServerProfile? selectedServer;
  final LaunchConnectionStatus connectionStatus;

  LaunchServerInventory get inventory {
    return switch (savedServers.length) {
      0 => LaunchServerInventory.noServers,
      1 => LaunchServerInventory.oneServer,
      _ => LaunchServerInventory.multipleServers,
    };
  }
}

final class LaunchRoutingState {
  const LaunchRoutingState.projectMissing()
    : status = LaunchRoutingStatus.projectMissing,
      project = null,
      session = null;

  const LaunchRoutingState.sessionMissing({required this.project})
    : status = LaunchRoutingStatus.sessionMissing,
      session = null;

  const LaunchRoutingState.readyToResume({
    required this.project,
    required this.session,
  }) : status = LaunchRoutingStatus.readyToResume;

  factory LaunchRoutingState.fromProject(ProjectTarget? project) {
    if (project == null) {
      return const LaunchRoutingState.projectMissing();
    }

    final session = _normalizedSession(project.lastSession);
    if (session == null) {
      return LaunchRoutingState.sessionMissing(project: project);
    }

    return LaunchRoutingState.readyToResume(project: project, session: session);
  }

  final LaunchRoutingStatus status;
  final ProjectTarget? project;
  final ProjectSessionHint? session;

  bool get canResume => status == LaunchRoutingStatus.readyToResume;

  static ProjectSessionHint? _normalizedSession(ProjectSessionHint? session) {
    if (session == null) {
      return null;
    }

    final title = session.title?.trim();
    final status = session.status?.trim();
    if (title == null || title.isEmpty) {
      return null;
    }

    return ProjectSessionHint(title: title, status: status);
  }
}
