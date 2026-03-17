import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/settings/integration_status_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/start_auth_flows.dart <server-url> <directory>',
    );
  }

  final service = IntegrationStatusService();
  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args[0],
  );
  final project = ProjectTarget(directory: args[1], label: args[1]);

  final providerUrl = await service.startProviderAuth(
    profile: profile,
    project: project,
    providerId: 'openai',
  );
  final mcpUrl = await service.startMcpAuth(
    profile: profile,
    project: project,
    name: 'github',
  );
  service.dispose();

  stdout.writeln('providerUrl=${providerUrl ?? '-'}');
  stdout.writeln('mcpUrl=${mcpUrl ?? '-'}');
}
