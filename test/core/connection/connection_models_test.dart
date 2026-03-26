import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';

void main() {
  test('canonicalize strips embedded credentials from base url', () {
    const profile = ServerProfile(
      id: 'server',
      label: 'Demo',
      baseUrl: 'https://operator:secret@example.com/api/',
    );

    final canonical = profile.canonicalize();

    expect(canonical.normalizedBaseUrl, 'https://example.com/api');
    expect(canonical.username, 'operator');
    expect(canonical.password, 'secret');
    expect(canonical.basicAuthHeader, startsWith('Basic '));
  });

  test('uriOrNull rejects unsupported schemes', () {
    const profile = ServerProfile(
      id: 'server',
      label: 'Demo',
      baseUrl: 'ftp://example.com',
    );

    expect(profile.uriOrNull, isNull);
  });
}
