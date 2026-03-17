import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/session_action_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_revert_actions.dart <server-url> <directory> <session-id>',
    );
  }

  final service = SessionActionService();
  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args[0],
  );
  final project = ProjectTarget(directory: args[1], label: args[1]);
  final sessionId = args[2];

  final reverted = await service.revertSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
    messageId: 'msg_1',
  );
  final restored = await service.unrevertSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
  );
  service.dispose();

  stdout.writeln('reverted=${reverted.title}');
  stdout.writeln('restored=${restored.title}');
}
