import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/chat/session_action_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_session_actions.dart <server-url> <directory> <session-id> [--username USER] [--password PASS]',
    );
  }

  String? username;
  String? password;
  for (var index = 3; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == '--username' && index + 1 < args.length) {
      username = args[index + 1];
      index += 1;
      continue;
    }
    if (arg == '--password' && index + 1 < args.length) {
      password = args[index + 1];
      index += 1;
    }
  }

  final service = SessionActionService();
  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args[0],
    username: username,
    password: password,
  );
  final project = ProjectTarget(directory: args[1], label: args[1]);
  final sessionId = args[2];

  final forked = await service.forkSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
  );
  final aborted = await service.abortSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
  );
  final shared = await service.shareSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
  );
  final unshared = await service.unshareSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
  );
  final renamed = await service.updateSession(
    profile: profile,
    project: project,
    sessionId: sessionId,
    title: 'Renamed from manual action',
  );
  final deleted = await service.deleteSession(
    profile: profile,
    project: project,
    sessionId: forked.id,
  );
  service.dispose();

  stdout.writeln('forked=${forked.id}');
  stdout.writeln('aborted=$aborted');
  stdout.writeln('shared=$shared');
  stdout.writeln('unshared=$unshared');
  stdout.writeln('renamed=${renamed.title}');
  stdout.writeln('deleted=$deleted');
}
