import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  Map<String, Object?>? lastCreateBody;
  Map<String, Object?>? lastUpdateBody;

  setUp(() async {
    lastCreateBody = null;
    lastUpdateBody = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      final requestBody = await utf8.decoder.bind(request).join();
      final decodedBody = requestBody.trim().isEmpty
          ? null
          : jsonDecode(requestBody) as Object?;

      if (request.uri.path == '/pty' &&
          request.method == 'POST' &&
          decodedBody is Map) {
        lastCreateBody = decodedBody.cast<String, Object?>();
      }
      if (request.uri.path == '/pty/pty_1' &&
          request.method == 'PUT' &&
          decodedBody is Map) {
        lastUpdateBody = decodedBody.cast<String, Object?>();
      }

      final body = switch ((request.method, request.uri.path)) {
        ('GET', '/pty') => <Map<String, Object?>>[
          <String, Object?>{
            'id': 'pty_1',
            'title': 'Terminal 1',
            'command': '/bin/zsh',
            'args': <String>['-l'],
            'cwd': '/workspace/demo',
            'status': 'running',
            'pid': 1201,
          },
        ],
        ('POST', '/pty') => <String, Object?>{
          'id': 'pty_2',
          'title': 'Terminal 2',
          'command': '/bin/zsh',
          'args': <String>['-l'],
          'cwd': '/workspace/demo',
          'status': 'running',
          'pid': 1202,
        },
        ('GET', '/pty/pty_1') => <String, Object?>{
          'id': 'pty_1',
          'title': 'Terminal 1',
          'command': '/bin/zsh',
          'args': <String>['-l'],
          'cwd': '/workspace/demo',
          'status': 'running',
          'pid': 1201,
        },
        ('PUT', '/pty/pty_1') => <String, Object?>{
          'id': 'pty_1',
          'title': 'Renamed Terminal',
          'command': '/bin/zsh',
          'args': <String>['-l'],
          'cwd': '/workspace/demo',
          'status': 'running',
          'pid': 1201,
        },
        ('DELETE', '/pty/pty_1') => true,
        _ => null,
      };

      expect(request.uri.queryParameters['directory'], '/workspace/demo');
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

  test('lists, creates, updates, and removes PTY sessions', () async {
    final service = PtyService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );

    final sessions = await service.listSessions(
      profile: profile,
      directory: '/workspace/demo',
    );
    final created = await service.createSession(
      profile: profile,
      directory: '/workspace/demo',
      title: 'Terminal 2',
      cwd: '/workspace/demo',
    );
    final fetched = await service.getSession(
      profile: profile,
      directory: '/workspace/demo',
      ptyId: 'pty_1',
    );
    final updated = await service.updateSession(
      profile: profile,
      directory: '/workspace/demo',
      ptyId: 'pty_1',
      title: 'Renamed Terminal',
      size: const PtySessionSize(cols: 120, rows: 32),
    );
    await service.removeSession(
      profile: profile,
      directory: '/workspace/demo',
      ptyId: 'pty_1',
    );

    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'pty_1');
    expect(created.id, 'pty_2');
    expect(fetched?.id, 'pty_1');
    expect(updated.title, 'Renamed Terminal');
    expect(lastCreateBody, <String, Object?>{
      'title': 'Terminal 2',
      'cwd': '/workspace/demo',
    });
    expect(lastUpdateBody, <String, Object?>{
      'title': 'Renamed Terminal',
      'size': <String, Object?>{'cols': 120, 'rows': 32},
    });
    service.dispose();
  });

  test('builds websocket uri with basic auth and cursor', () {
    final uri = buildPtyWebSocketUri(
      profile: const ServerProfile(
        id: 'server',
        label: 'auth',
        baseUrl: 'https://example.com/api',
        username: 'demo',
        password: 'secret',
      ),
      directory: '/workspace/demo',
      ptyId: 'pty_1',
      cursor: 42,
    );

    expect(uri.scheme, 'wss');
    expect(uri.host, 'example.com');
    expect(uri.path, '/api/pty/pty_1/connect');
    expect(uri.userInfo, 'demo:secret');
    expect(uri.queryParameters, <String, String>{
      'directory': '/workspace/demo',
      'cursor': '42',
    });
  });
}
