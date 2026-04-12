import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/opencode_server_probe.dart';

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
    'probe stays ready when /doc succeeds but the spec does not list /doc, and prefers health version',
    () async {
      server.listen((request) async {
        Object? body;
        if (request.uri.path == '/global/health') {
          body = <String, Object?>{'name': 'Mock', 'version': '1.2.27'};
        } else if (request.uri.path == '/doc') {
          body = <String, Object?>{
            'info': <String, Object?>{'title': 'Mock', 'version': '0.0.3'},
            'paths': <String, Object?>{
              '/global/health': <String, Object?>{},
              '/config': <String, Object?>{},
              '/config/providers': <String, Object?>{},
              '/provider': <String, Object?>{},
              '/agent': <String, Object?>{},
              '/project': <String, Object?>{},
              '/project/current': <String, Object?>{},
              '/session': <String, Object?>{},
              '/session/status': <String, Object?>{},
              '/event': <String, Object?>{},
            },
          };
        } else if ({
          '/config',
          '/config/providers',
          '/provider',
          '/agent',
          '/experimental/tool/ids',
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
      expect(report.snapshot.version, '1.2.27');
      expect(report.missingCapabilities, isEmpty);
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

  test(
    'probe stops after first auth failure to avoid extra challenged requests',
    () async {
      final requestedPaths = <String>[];

      server.listen((request) async {
        requestedPaths.add(request.uri.path);
        if (request.uri.path == '/global/health') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{'version': '1.0.0'}),
          );
        } else if (request.uri.path == '/doc') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{
              'info': <String, Object?>{'title': 'Mock', 'version': '1.0.0'},
              'paths': <String, Object?>{
                '/global/health': <String, Object?>{},
                '/doc': <String, Object?>{},
                '/config': <String, Object?>{},
                '/config/providers': <String, Object?>{},
                '/provider': <String, Object?>{},
                '/provider/auth': <String, Object?>{},
                '/agent': <String, Object?>{},
              },
            }),
          );
        } else if (request.uri.path == '/config') {
          request.response.statusCode = 401;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{'error': 'unauthorized'}),
          );
        } else {
          request.response.statusCode = 500;
        }
        await request.response.close();
      });

      final probe = OpenCodeServerProbe();
      final report = await probe.probe(
        ServerProfile(id: 'server', label: 'Mock', baseUrl: baseUri.toString()),
      );
      probe.dispose();

      expect(report.classification, ConnectionProbeClassification.authFailure);
      expect(
        requestedPaths,
        containsAll(<String>['/global/health', '/doc', '/config']),
      );
      expect(requestedPaths, isNot(contains('/config/providers')));
      expect(requestedPaths, isNot(contains('/provider')));
      expect(requestedPaths, isNot(contains('/provider/auth')));
      expect(requestedPaths, isNot(contains('/agent')));
    },
  );

  test(
    'probe returns immediately when the doc endpoint issues an auth challenge',
    () async {
      final requestedPaths = <String>[];

      server.listen((request) async {
        requestedPaths.add(request.uri.path);
        if (request.uri.path == '/global/health') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{'version': '1.0.0'}),
          );
        } else if (request.uri.path == '/doc') {
          request.response.statusCode = 401;
          request.response.headers.set(
            HttpHeaders.wwwAuthenticateHeader,
            'Basic realm="Secure Area"',
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{'error': 'unauthorized'}),
          );
        } else {
          request.response.statusCode = 500;
        }
        await request.response.close();
      });

      final probe = OpenCodeServerProbe();
      final report = await probe.probe(
        ServerProfile(id: 'server', label: 'Mock', baseUrl: baseUri.toString()),
      );
      probe.dispose();

      expect(report.classification, ConnectionProbeClassification.authFailure);
      expect(report.authScheme, 'Basic');
      expect(report.requiresBasicAuth, isTrue);
      expect(requestedPaths, <String>['/global/health', '/doc']);
    },
  );

  test(
    'probe treats hosts without opencode health or docs as offline',
    () async {
      final requestedPaths = <String>[];

      server.listen((request) async {
        requestedPaths.add(request.uri.path);
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html><body>Not Found</body></html>');
        await request.response.close();
      });

      final probe = OpenCodeServerProbe();
      final report = await probe.probe(
        ServerProfile(
          id: 'server',
          label: 'Example',
          baseUrl: baseUri.toString(),
        ),
      );
      probe.dispose();

      expect(
        report.classification,
        ConnectionProbeClassification.connectivityFailure,
      );
      expect(requestedPaths, <String>['/global/health', '/doc']);
      expect(report.summary, contains('does not look like an OpenCode server'));
    },
  );

  test('probe treats non-json health and missing docs as offline', () async {
    final requestedPaths = <String>[];

    server.listen((request) async {
      requestedPaths.add(request.uri.path);
      if (request.uri.path == '/global/health') {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html><body>OK</body></html>');
      } else {
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html><body>Not Found</body></html>');
      }
      await request.response.close();
    });

    final probe = OpenCodeServerProbe();
    final report = await probe.probe(
      ServerProfile(
        id: 'server',
        label: 'Example',
        baseUrl: baseUri.toString(),
      ),
    );
    probe.dispose();

    expect(
      report.classification,
      ConnectionProbeClassification.connectivityFailure,
    );
    expect(requestedPaths, <String>['/global/health', '/doc']);
  });
}
