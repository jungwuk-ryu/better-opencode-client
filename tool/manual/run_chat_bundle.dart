import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_chat_bundle.dart <server-url> <directory>',
    );
  }

  final service = ChatService();
  final bundle = await service.fetchBundle(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
  );
  service.dispose();

  stdout.writeln('sessions=${bundle.sessions.length}');
  stdout.writeln('selectedSession=${bundle.selectedSessionId ?? '-'}');
  stdout.writeln('messages=${bundle.messages.length}');
  stdout.writeln(
    'lastPart=${bundle.messages.isEmpty || bundle.messages.last.parts.isEmpty ? '-' : bundle.messages.last.parts.last.type}',
  );
}
