import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test(
    'probe reports ready and discovers extra experimental tool paths',
    () async {
      server.listen((request) async {
        Object? body;
        if (request.uri.path == '/global/health') {
          body = <String, Object?>{'name': 'Mock', 'version': '1.2.3'};
        } else if (request.uri.path == '/doc') {
          body = <String, Object?>{
            'info': <String, Object?>{'title': 'Mock', 'version': '1.2.3'},
            'paths': <String, Object?>{
              '/global/health': <String, Object?>{},
              '/doc': <String, Object?>{},
              '/config': <String, Object?>{},
              '/config/providers': <String, Object?>{},
              '/provider': <String, Object?>{},
              '/provider/auth': <String, Object?>{},
              '/agent': <String, Object?>{},
              '/experimental/tool/ids': <String, Object?>{},
              '/experimental/tool/schema': <String, Object?>{},
            },
          };
        } else if ({
          '/config',
          '/config/providers',
          '/provider',
          '/provider/auth',
          '/agent',
          '/experimental/tool/ids',
          '/experimental/tool/schema',
        }.contains(request.uri.path)) {
          body = <String, Object?>{};
        }
        if (body == null) {
          request.response.statusCode = 404;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(body));
        }
        await request.response.close();
      });

      final probe = OpenCodeServerProbe();
      final report = await probe.probe(
        ServerProfile(id: 'server', label: 'Mock', baseUrl: baseUri.toString()),
      );
      probe.dispose();

      expect(report.classification, ConnectionProbeClassification.ready);
      expect(
        report.discoveredExperimentalPaths,
        contains('/experimental/tool/schema'),
      );
      expect(report.capabilityRegistry.hasExperimentalTools, isTrue);
    },
  );

  test(
    'probe reports auth failure for auth-sensitive unauthorized endpoints',
    () async {
      server.listen((request) async {
        if (request.uri.path == '/global/health') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{'version': '1.0.0'}),
          );
        } else {
          request.response.statusCode = 403;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{'error': 'forbidden'}),
          );
        }
        await request.response.close();
      });

      final probe = OpenCodeServerProbe();
      final report = await probe.probe(
        ServerProfile(id: 'server', label: 'Mock', baseUrl: baseUri.toString()),
      );
      probe.dispose();

      expect(report.classification, ConnectionProbeClassification.authFailure);
    },
  );
}
