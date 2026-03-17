import 'dart:io';

import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw ArgumentError(
      'Usage: dart run tool/manual/run_connection_probe.dart <server-url> [--username USER] [--password PASS]',
    );
  }

  String? username;
  String? password;
  for (var index = 1; index < args.length; index += 1) {
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

  final profile = ServerProfile(
    id: 'manual',
    label: 'manual',
    baseUrl: args.first,
    username: username,
    password: password,
  );
  final probe = OpenCodeServerProbe();
  final report = await probe.probe(profile);
  probe.dispose();

  stdout.writeln('classification=${report.classification.name}');
  stdout.writeln('version=${report.snapshot.version}');
  stdout.writeln('sseReady=${report.sseReady}');
  for (final entry in report.capabilityRegistry.asMap().entries) {
    stdout.writeln('${entry.key}=${entry.value}');
  }
}
