import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/requests/request_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/reply_pending_requests.dart <server-url> <directory>',
    );
  }

  final service = RequestService();
  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args[0],
  );
  final project = ProjectTarget(directory: args[1], label: args[1]);

  final permissionOk = await service.replyToPermission(
    profile: profile,
    project: project,
    requestId: 'per_1',
    reply: 'once',
  );
  final questionOk = await service.replyToQuestion(
    profile: profile,
    project: project,
    requestId: 'que_1',
    answers: const <List<String>>[
      <String>['Yes'],
    ],
  );
  final rejectOk = await service.rejectQuestion(
    profile: profile,
    project: project,
    requestId: 'que_1',
  );
  service.dispose();

  stdout.writeln('permissionReply=$permissionOk');
  stdout.writeln('questionReply=$questionOk');
  stdout.writeln('questionReject=$rejectOk');
}
