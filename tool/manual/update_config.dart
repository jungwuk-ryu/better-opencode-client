import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/update_config.dart <server-url> <directory>',
    );
  }

  final service = ConfigService();
  final updated = await service.updateConfig(
    profile: ServerProfile(id: 'manual', label: 'manual', baseUrl: args[0]),
    project: ProjectTarget(directory: args[1], label: args[1]),
    config: <String, Object?>{
      'model': 'anthropic/claude-sonnet-4.5',
      'x-future': <String, Object?>{'enabled': true},
    },
  );
  service.dispose();

  stdout.writeln('model=${updated.toJson()['model']}');
  stdout.writeln(
    'hasFuture=${(updated.toJson()['x-future'] as Map)['enabled']}',
  );
}
