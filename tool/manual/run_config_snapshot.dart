import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_config_snapshot.dart <server-url> <directory>',
    );
  }

  final service = ConfigService();
  final snapshot = await service.fetch(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
  );
  service.dispose();

  stdout.writeln('model=${snapshot.config.toJson()['model']}');
  stdout.writeln(
    'hasFuture=${(snapshot.config.toJson()['x-future'] as Map)['enabled']}',
  );
  stdout.writeln(
    'defaultOpenAI=${(snapshot.providerConfig.toJson()['default'] as Map)['openai']}',
  );
}
