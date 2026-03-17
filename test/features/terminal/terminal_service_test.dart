import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/terminal_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      if (request.uri.path != '/session/ses_1/shell') {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      final body = {
        'id': 'msg_shell_1',
        'sessionID': 'ses_1',
        'providerID': 'openai',
        'modelID': 'gpt-5',
      };
      request.response.headers.contentType = ContentType.json;
      request.response.add(utf8.encode(jsonEncode(body)));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('runs shell command for selected session', () async {
    final service = TerminalService();
    final result = await service.runShellCommand(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_1',
      command: 'pwd',
    );

    expect(result.messageId, 'msg_shell_1');
    expect(result.modelId, 'gpt-5');
    service.dispose();
  });
}
