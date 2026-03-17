import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/event_stream_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      if (request.uri.path != '/event') {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write('event: session.status\n');
      request.response.write(
        'data: ${jsonEncode({
          'properties': {'sessionID': 'ses_1', 'status': 'busy'},
        })}\n\n',
      );
      request.response.write('event: permission.asked\n');
      request.response.write(
        'data: ${jsonEncode({
          'properties': {'id': 'per_1'},
        })}\n\n',
      );
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('parses streamed events into envelopes', () async {
    final service = EventStreamService();
    final seen = <EventEnvelope>[];

    await service.connect(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      onEvent: seen.add,
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    await service.disconnect();
    service.dispose();

    expect(seen.length, 2);
    expect(seen.first.type, 'session.status');
    expect(seen.first.properties['sessionID'], 'ses_1');
    expect(seen.last.type, 'permission.asked');
  });
}
