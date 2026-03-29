import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/requests/request_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_pending_requests.dart <server-url> <directory>',
    );
  }

  final service = RequestService();
  final result = await service.fetchPending(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
  );
  service.dispose();

  stdout.writeln('questions=${result.questions.length}');
  stdout.writeln('permissions=${result.permissions.length}');
  if (result.questions.isNotEmpty) {
    stdout.writeln(
      'questionHeader=${result.questions.first.questions.first.header}',
    );
  }
  if (result.permissions.isNotEmpty) {
    stdout.writeln('permission=${result.permissions.first.permission}');
  }
}
