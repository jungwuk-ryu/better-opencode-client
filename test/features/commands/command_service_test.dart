import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/commands/command_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      final body = switch (request.uri.path) {
        '/command' => <Object?>[
          <String, Object?>{
            'name': 'share',
            'description': 'Share this session',
            'source': 'command',
            'hints': <String>[r'$ARGUMENTS'],
          },
          <String, Object?>{
            'name': 'websearch:help',
            'description': 'Search the web',
            'source': 'mcp',
            'hints': <String>[],
          },
        ],
        _ => null,
      };
      if (body == null) {
        request.response.statusCode = 404;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.add(utf8.encode(jsonEncode(body)));
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('fetches command definitions from the server', () async {
    final service = CommandService();
    final commands = await service.fetchCommands(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
    );

    expect(commands, hasLength(2));
    expect(commands.first.name, 'share');
    expect(commands.first.description, 'Share this session');
    expect(commands.first.source, 'command');
    expect(commands.first.hints, <String>[r'$ARGUMENTS']);
    expect(commands.last.name, 'websearch:help');
    expect(commands.last.source, 'mcp');
    service.dispose();
  });
}
