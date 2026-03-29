import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/integration_status_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_integration_status.dart <server-url> <directory>',
    );
  }

  final service = IntegrationStatusService();
  final snapshot = await service.fetch(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
  );
  service.dispose();

  final firstProvider = snapshot.providerAuth.isEmpty
      ? '-'
      : snapshot.providerAuth.keys.first;
  final firstMcp = snapshot.mcpStatus.isEmpty
      ? '-'
      : snapshot.mcpStatus.keys.first;

  stdout.writeln('providerAuth=${snapshot.providerAuth.length}');
  stdout.writeln('mcp=${snapshot.mcpStatus.length}');
  stdout.writeln('lsp=${snapshot.lspStatus.length}');
  stdout.writeln('formatter=${snapshot.formatterStatus.length}');
  stdout.writeln('firstProvider=$firstProvider');
  stdout.writeln('firstMcp=$firstMcp');
}
