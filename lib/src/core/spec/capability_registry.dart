import 'probe_snapshot.dart';

class CapabilityRegistry {
  const CapabilityRegistry({
    required this.canShareSession,
    required this.canForkSession,
    required this.canSummarizeSession,
    required this.canRevertSession,
    required this.hasQuestions,
    required this.hasPermissions,
    required this.hasExperimentalTools,
    required this.hasProviderOAuth,
    required this.hasMcpAuth,
    required this.hasTuiControl,
  });

  final bool canShareSession;
  final bool canForkSession;
  final bool canSummarizeSession;
  final bool canRevertSession;
  final bool hasQuestions;
  final bool hasPermissions;
  final bool hasExperimentalTools;
  final bool hasProviderOAuth;
  final bool hasMcpAuth;
  final bool hasTuiControl;

  factory CapabilityRegistry.fromSnapshot(ProbeSnapshot snapshot) {
    bool hasPath(String path) => snapshot.paths.contains(path);
    bool endpointReady(String path) {
      final endpoint = snapshot.endpoints[path];
      if (endpoint == null) {
        return false;
      }
      return switch (endpoint.status) {
        ProbeStatus.success => true,
        ProbeStatus.unauthorized => true,
        ProbeStatus.unknown => true,
        ProbeStatus.unsupported => false,
        ProbeStatus.failure => false,
      };
    }

    return CapabilityRegistry(
      canShareSession:
          hasPath('/session/{sessionID}/share') ||
          endpointReady('/session/{sessionID}/share'),
      canForkSession:
          hasPath('/session/{sessionID}/fork') ||
          endpointReady('/session/{sessionID}/fork'),
      canSummarizeSession:
          hasPath('/session/{sessionID}/summarize') ||
          endpointReady('/session/{sessionID}/summarize'),
      canRevertSession:
          hasPath('/session/{sessionID}/revert') ||
          endpointReady('/session/{sessionID}/revert'),
      hasQuestions: hasPath('/question') || endpointReady('/question'),
      hasPermissions: hasPath('/permission') || endpointReady('/permission'),
      hasExperimentalTools:
          hasPath('/experimental/tool/ids') ||
          endpointReady('/experimental/tool/ids'),
      hasProviderOAuth:
          hasPath('/provider/{providerID}/oauth/authorize') ||
          endpointReady('/provider/auth'),
      hasMcpAuth: snapshot.paths.any(
        (path) => path.startsWith('/mcp/') && path.contains('/auth/'),
      ),
      hasTuiControl:
          snapshot.paths.any((path) => path.startsWith('/tui/')) ||
          endpointReady('/tui/control/next'),
    );
  }

  Map<String, bool> asMap() {
    return {
      'canShareSession': canShareSession,
      'canForkSession': canForkSession,
      'canSummarizeSession': canSummarizeSession,
      'canRevertSession': canRevertSession,
      'hasQuestions': hasQuestions,
      'hasPermissions': hasPermissions,
      'hasExperimentalTools': hasExperimentalTools,
      'hasProviderOAuth': hasProviderOAuth,
      'hasMcpAuth': hasMcpAuth,
      'hasTuiControl': hasTuiControl,
    };
  }
}
