import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/request_headers.dart';

void main() {
  test('buildRequestHeaders adds browser user agent and auth', () {
    const profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'https://example.com',
      username: 'user',
      password: 'pass',
    );

    final headers = buildRequestHeaders(
      profile,
      accept: 'application/json',
      jsonBody: true,
    );

    expect(headers['accept'], 'application/json');
    expect(headers['content-type'], 'application/json');
    expect(headers['user-agent'], browserLikeUserAgent);
    expect(headers['authorization'], startsWith('Basic '));
  });
}
