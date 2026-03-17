import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_submit_prompt.dart <server-url> <directory> <username> <password> [prompt]',
    );
  }

  final prompt = args.length > 4 ? args[4] : 'Reply with exactly the word OK.';
  final service = ChatService();
  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args[0],
    username: args[2],
    password: args[3],
  );
  final project = ProjectTarget(directory: args[1], label: args[1]);

  final session = await service.createSession(
    profile: profile,
    project: project,
  );
  final reply = await service.sendMessage(
    profile: profile,
    project: project,
    sessionId: session.id,
    prompt: prompt,
  );
  stdout.writeln('session=${session.id}');
  stdout.writeln('message=${reply.info.id}');
  stdout.writeln('parts=${reply.parts.length}');
  if (reply.parts.isNotEmpty) {
    stdout.writeln('firstPart=${reply.parts.first.type}');
  }
  service.dispose();
}
