import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/chat/session_action_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_summarize_session.dart <server-url> <directory> <session-id>',
    );
  }

  final service = SessionActionService();
  final ok = await service.summarizeSession(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
    sessionId: args[2],
    providerId: 'openai',
    modelId: 'gpt-5',
  );
  service.dispose();

  stdout.writeln('summarize=$ok');
}
