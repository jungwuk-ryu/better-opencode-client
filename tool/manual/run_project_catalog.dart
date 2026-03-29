import 'dart:io';

import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_catalog_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_project_catalog.dart <server-url> <directory>',
    );
  }

  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args[0],
  );
  final service = ProjectCatalogService();

  final catalog = await service.fetchCatalog(profile);
  final inspected = await service.inspectDirectory(
    profile: profile,
    directory: args[1],
  );
  service.dispose();

  stdout.writeln('current=${catalog.currentProject?.directory ?? '-'}');
  stdout.writeln('projects=${catalog.projects.length}');
  stdout.writeln('branch=${catalog.vcsInfo?.branch ?? '-'}');
  stdout.writeln('manual.directory=${inspected.directory}');
  stdout.writeln('manual.label=${inspected.label}');
  stdout.writeln('manual.branch=${inspected.branch ?? '-'}');
}
