import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      if (request.method == 'PATCH' && request.uri.path == '/project/project-1') {
        final payload = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final body = <String, Object?>{
          'id': 'project-1',
          'directory': '/workspace/demo',
          'worktree': '/workspace/demo',
          'name': payload['name'],
          'vcs': 'git',
          'icon': payload['icon'],
          'commands': payload['commands'],
          'time': {'updated': 1710000000000},
        };
        final encoded = utf8.encode(jsonEncode(body));
        request.response.headers.contentType = ContentType.json;
        request.response.add(encoded);
        await request.response.close();
        return;
      }
      final body = switch (request.uri.path) {
        '/project' => [
          {
            'id': 'project-1',
            'directory': '/workspace/demo',
            'worktree': '/workspace/demo',
            'name': 'Demo',
            'vcs': 'git',
            'icon': {
              'url': 'data:image/png;base64,AAAA',
              'color': 'mint',
            },
            'commands': {'start': 'bun install'},
            'time': {'updated': 1710000000000},
          },
        ],
        '/project/current' => {
          'id': 'project-1',
          'directory':
              request.uri.queryParameters['directory'] ?? '/workspace/demo',
          'worktree':
              request.uri.queryParameters['directory'] ?? '/workspace/demo',
          'name': 'Demo',
          'vcs': 'git',
          'icon': {
            'url': 'data:image/png;base64,AAAA',
            'color': 'mint',
          },
          'commands': {'start': 'bun install'},
          'time': {'updated': 1710000000000},
        },
        '/path' => {
          'home': '/home/ubuntu',
          'state': '/state',
          'config': '/config',
          'worktree':
              request.uri.queryParameters['directory'] ?? '/workspace/demo',
          'directory':
              request.uri.queryParameters['directory'] ?? '/workspace/demo',
        },
        '/vcs' => {'branch': 'main'},
        _ => null,
      };

      if (body == null) {
        request.response.statusCode = 404;
      } else {
        final encoded = utf8.encode(jsonEncode(body));
        request.response.headers.contentType = ContentType.json;
        request.response.add(encoded);
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('fetches project catalog from current server context', () async {
    final service = ProjectCatalogService();
    final profile = ServerProfile(
      id: '1',
      label: 'demo',
      baseUrl: baseUri.toString(),
    );

    final catalog = await service.fetchCatalog(profile);

    expect(catalog.currentProject?.directory, '/workspace/demo');
    expect(catalog.currentProject?.icon?.color, 'mint');
    expect(catalog.currentProject?.commands?.start, 'bun install');
    expect(catalog.projects.length, 1);
    expect(catalog.vcsInfo?.branch, 'main');
    service.dispose();
  });

  test('inspects manual directory using directory query routing', () async {
    final service = ProjectCatalogService();
    final profile = ServerProfile(
      id: '1',
      label: 'demo',
      baseUrl: baseUri.toString(),
    );

    final target = await service.inspectDirectory(
      profile: profile,
      directory: '/workspace/manual',
    );

    expect(target.directory, '/workspace/manual');
    expect(target.branch, 'main');
    service.dispose();
  });

  test('updates project metadata through patch route', () async {
    final service = ProjectCatalogService();
    final profile = ServerProfile(
      id: '1',
      label: 'demo',
      baseUrl: baseUri.toString(),
    );

    final target = await service.updateProject(
      profile: profile,
      project: const ProjectTarget(
        id: 'project-1',
        directory: '/workspace/demo',
        label: 'Demo',
      ),
      name: 'Renamed Demo',
      icon: const ProjectIconInfo(
        url: 'data:image/png;base64,BBBB',
        override: 'data:image/png;base64,BBBB',
        color: 'pink',
      ),
      commands: const ProjectCommandsInfo(start: 'pnpm install'),
    );

    expect(target.name, 'Renamed Demo');
    expect(target.icon?.effectiveImage, 'data:image/png;base64,BBBB');
    expect(target.commands?.start, 'pnpm install');
    service.dispose();
  });
}
