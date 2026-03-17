import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/files/file_browser_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      final body = switch (request.uri.path) {
        '/file' => [
          {
            'name': 'lib',
            'path': 'lib',
            'absolute': '/workspace/demo/lib',
            'type': 'directory',
            'ignored': false,
          },
          {
            'name': 'README.md',
            'path': 'README.md',
            'absolute': '/workspace/demo/README.md',
            'type': 'file',
            'ignored': false,
          },
        ],
        '/file/status' => [
          {'path': 'README.md', 'added': 4, 'removed': 1, 'status': 'modified'},
        ],
        '/find/file' => ['README.md', 'lib/main.dart'],
        '/find' => [
          {'path': 'README.md', 'lines': 'Demo search line'},
        ],
        '/find/symbol' => [
          {
            'name': 'main',
            'kind': 'function',
            'location': {'path': 'lib/main.dart'},
          },
        ],
        '/file/content' => {'type': 'text', 'content': '# Demo'},
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

  test('fetches file browser bundle with preview', () async {
    final service = FileBrowserService();
    final bundle = await service.fetchBundle(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      searchQuery: 'read',
    );

    expect(bundle.nodes.length, 2);
    expect(bundle.statuses.first.status, 'modified');
    expect(bundle.searchResults.first, 'README.md');
    expect(bundle.textMatches.first.path, 'README.md');
    expect(bundle.symbols.first.name, 'main');
    expect(bundle.preview?.content, '# Demo');
    service.dispose();
  });
}
