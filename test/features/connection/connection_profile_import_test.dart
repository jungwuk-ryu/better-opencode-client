import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/connection/connection_profile_import.dart';

void main() {
  test('encodes and decodes a v1 import payload roundtrip', () {
    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com/',
      username: 'operator',
      password: 'secret',
    );
    final issuedAt = DateTime.utc(2026, 3, 31, 12);
    final payload = ConnectionProfileImportPayload.fromProfile(
      profile,
      issuedAt: issuedAt,
      expiresIn: const Duration(days: 7),
    );

    expect(payload.version, ConnectionProfileImportPayload.latestVersion);
    expect(payload.authTypeRaw, 'basic');
    expect(payload.expiresAt, issuedAt.add(const Duration(days: 7)));

    final token = payload.toToken();
    final decoded = decodeConnectionProfileImportPayload(token);
    expect(decoded, isNotNull);
    expect(decoded!.label, 'Studio');
    expect(decoded.baseUrl, 'https://studio.example.com');
    expect(decoded.authType, ConnectionProfileImportAuthType.basic);
    expect(decoded.username, 'operator');
    expect(decoded.password, 'secret');

    final validator = const ConnectionProfileImportValidator();
    final result = validator.validateToken(token, now: issuedAt);
    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('flags unsupported auth types and invalid server urls', () {
    final token = _encodeRawImportPayload(<String, Object?>{
      'version': ConnectionProfileImportPayload.latestVersion,
      'label': 'Broken',
      'baseUrl': '',
      'authType': 'oauth',
    });

    final result = const ConnectionProfileImportValidator().validateToken(
      token,
      now: DateTime.utc(2026, 3, 31),
    );

    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<String>['unsupported_auth_type', 'invalid_base_url']),
    );
  });

  test('flags expired payloads and missing basic credentials', () {
    final payload = ConnectionProfileImportPayload(
      version: ConnectionProfileImportPayload.latestVersion,
      label: 'Expired',
      baseUrl: 'https://expired.example.com',
      authType: ConnectionProfileImportAuthType.basic,
      authTypeRaw: 'basic',
      issuedAt: DateTime.utc(2026, 3, 1),
      expiresAt: DateTime.utc(2026, 3, 10),
    );

    final result = const ConnectionProfileImportValidator().validate(
      payload,
      now: DateTime.utc(2026, 3, 31),
    );

    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<String>['missing_credentials', 'expired_payload']),
    );
  });

  test('parses connection import routes from query and path forms', () {
    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );
    final token = ConnectionProfileImportPayload.fromProfile(profile).toToken();

    final queryRoute = AppRouteData.parse(
      '/connect?payload=${Uri.encodeComponent(token)}',
    );
    expect(queryRoute, isA<HomeRouteData>());
    final queryHome = queryRoute as HomeRouteData;
    expect(queryHome.connectionImport, isNotNull);
    expect(queryHome.connectionImport!.hasValidPayload, isTrue);
    expect(queryHome.connectionImport!.rawPayload, token);
    expect(queryHome.connectionImport!.payload.label, 'Studio');

    final pathRoute = AppRouteData.parse('/connection/$token');
    expect(pathRoute, isA<HomeRouteData>());
    final pathHome = pathRoute as HomeRouteData;
    expect(pathHome.connectionImport, isNotNull);
    expect(pathHome.connectionImport!.rawPayload, token);
    expect(pathHome.connectionImport!.hasValidPayload, isTrue);
  });

  test('parses custom-scheme deep links that use the host as the route', () {
    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );
    final token = ConnectionProfileImportPayload.fromProfile(profile).toToken();
    final deepLink = buildConnectionImportDeepLink(rawPayload: token);

    final route = AppRouteData.parse(deepLink.toString());
    expect(route, isA<HomeRouteData>());
    final home = route as HomeRouteData;
    expect(home.connectionImport, isNotNull);
    expect(home.connectionImport!.rawPayload, token);
    expect(home.connectionImport!.hasValidPayload, isTrue);
    expect(home.connectionImport!.location, '/connect?payload=${Uri.encodeComponent(token)}');
  });
}

String _encodeRawImportPayload(Map<String, Object?> json) {
  return base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
}
