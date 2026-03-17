import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_todos.dart <server-url> <directory> <session-id>',
    );
  }

  final service = TodoService();
  final todos = await service.fetchTodos(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
    sessionId: args[2],
  );
  service.dispose();

  stdout.writeln('todos=${todos.length}');
  if (todos.isNotEmpty) {
    stdout.writeln('first=${todos.first.content}');
    stdout.writeln('status=${todos.first.status}');
  }
}
