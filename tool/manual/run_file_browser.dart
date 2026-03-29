import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/files/file_browser_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_file_browser.dart <server-url> <directory> <query>',
    );
  }

  final service = FileBrowserService();
  final bundle = await service.fetchBundle(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
    searchQuery: args[2],
  );
  service.dispose();

  stdout.writeln('nodes=${bundle.nodes.length}');
  stdout.writeln('results=${bundle.searchResults.length}');
  stdout.writeln('textMatches=${bundle.textMatches.length}');
  stdout.writeln('symbols=${bundle.symbols.length}');
  stdout.writeln('selected=${bundle.selectedPath ?? '-'}');
  stdout.writeln('preview=${bundle.preview?.content ?? '-'}');
}
