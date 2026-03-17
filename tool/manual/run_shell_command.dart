import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/terminal_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_shell_command.dart <server-url> <directory> <session-id> <command>',
    );
  }

  final service = TerminalService();
  final result = await service.runShellCommand(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
    sessionId: args[2],
    command: args[3],
  );
  service.dispose();

  stdout.writeln('message=${result.messageId}');
  stdout.writeln('session=${result.sessionId}');
  stdout.writeln('model=${result.modelId ?? '-'}');
  stdout.writeln('provider=${result.providerId ?? '-'}');
}
