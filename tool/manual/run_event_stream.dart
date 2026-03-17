import 'dart:async';
import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/event_stream_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_event_stream.dart <server-url> <directory>',
    );
  }

  final service = EventStreamService();
  final seen = <EventEnvelope>[];

  await service.connect(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
    onEvent: seen.add,
  );

  await Future<void>.delayed(const Duration(milliseconds: 120));
  await service.disconnect();
  service.dispose();

  stdout.writeln('events=${seen.length}');
  if (seen.isNotEmpty) {
    stdout.writeln('first=${seen.first.type}');
  }
  if (seen.length > 1) {
    stdout.writeln('second=${seen[1].type}');
  }
}
