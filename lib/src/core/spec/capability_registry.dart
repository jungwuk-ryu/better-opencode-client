import 'probe_snapshot.dart';

class CapabilityRegistry {
  const CapabilityRegistry({
    required this.canShareSession,
    required this.canForkSession,
    required this.canSummarizeSession,
    required this.canRevertSession,
    required this.canInitSession,
    required this.hasQuestions,
    required this.hasPermissions,
    required this.hasExperimentalTools,
    required this.hasProviderOAuth,
    required this.hasMcpAuth,
    required this.hasTuiControl,
    required this.hasProjects,
    required this.hasSessions,
    required this.hasSessionStatus,
    required this.hasEventStream,
    required this.hasTodos,
    required this.hasFiles,
    required this.hasFileSearch,
    required this.hasSymbolSearch,
    required this.hasShellCommands,
    required this.hasConfigRead,
    required this.hasConfigWrite,
  });

  final bool canShareSession;
  final bool canForkSession;
  final bool canSummarizeSession;
  final bool canRevertSession;
  final bool canInitSession;
  final bool hasQuestions;
  final bool hasPermissions;
  final bool hasExperimentalTools;
  final bool hasProviderOAuth;
  final bool hasMcpAuth;
  final bool hasTuiControl;
  final bool hasProjects;
  final bool hasSessions;
  final bool hasSessionStatus;
  final bool hasEventStream;
  final bool hasTodos;
  final bool hasFiles;
  final bool hasFileSearch;
  final bool hasSymbolSearch;
  final bool hasShellCommands;
  final bool hasConfigRead;
  final bool hasConfigWrite;

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
      canInitSession:
          hasPath('/session/{sessionID}/init') ||
          endpointReady('/session/{sessionID}/init'),
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
      hasProjects: hasPath('/project') && hasPath('/project/current'),
      hasSessions: hasPath('/session'),
      hasSessionStatus: hasPath('/session/status'),
      hasEventStream: hasPath('/event') || endpointReady('/event'),
      hasTodos: hasPath('/session/{sessionID}/todo'),
      hasFiles:
          hasPath('/file') &&
          hasPath('/file/content') &&
          hasPath('/file/status'),
      hasFileSearch: hasPath('/find/file') || hasPath('/find'),
      hasSymbolSearch: hasPath('/find/symbol'),
      hasShellCommands: hasPath('/session/{sessionID}/shell'),
      hasConfigRead: hasPath('/config') && hasPath('/config/providers'),
      hasConfigWrite: hasPath('/config'),
    );
  }

  Map<String, bool> asMap() {
    return {
      'canShareSession': canShareSession,
      'canForkSession': canForkSession,
      'canSummarizeSession': canSummarizeSession,
      'canRevertSession': canRevertSession,
      'canInitSession': canInitSession,
      'hasQuestions': hasQuestions,
      'hasPermissions': hasPermissions,
      'hasExperimentalTools': hasExperimentalTools,
      'hasProviderOAuth': hasProviderOAuth,
      'hasMcpAuth': hasMcpAuth,
      'hasTuiControl': hasTuiControl,
      'hasProjects': hasProjects,
      'hasSessions': hasSessions,
      'hasSessionStatus': hasSessionStatus,
      'hasEventStream': hasEventStream,
      'hasTodos': hasTodos,
      'hasFiles': hasFiles,
      'hasFileSearch': hasFileSearch,
      'hasSymbolSearch': hasSymbolSearch,
      'hasShellCommands': hasShellCommands,
      'hasConfigRead': hasConfigRead,
      'hasConfigWrite': hasConfigWrite,
    };
  }
}
