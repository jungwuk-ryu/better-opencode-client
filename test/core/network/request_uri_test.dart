import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/network/request_uri.dart';

void main() {
  test('preserves base path prefixes for request paths', () {
    final uri = buildRequestUri(
      Uri.parse('https://example.com/api'),
      path: '/project/current',
    );

    expect(uri.toString(), 'https://example.com/api/project/current');
  });

  test('preserves base query parameters when adding request query', () {
    final uri = buildRequestUri(
      Uri.parse('https://example.com/api?token=abc'),
      path: '/event',
      queryParameters: const <String, String>{'directory': '/workspace/demo'},
    );

    expect(
      uri.toString(),
      'https://example.com/api/event?token=abc&directory=%2Fworkspace%2Fdemo',
    );
    expect(uri.queryParameters, <String, String>{
      'token': 'abc',
      'directory': '/workspace/demo',
    });
  });

  test('request query parameters override duplicate base keys', () {
    final uri = buildRequestUri(
      Uri.parse('https://example.com/api?token=abc&directory=/workspace/base'),
      path: '/event',
      queryParameters: const <String, String>{
        'directory': '/workspace/override',
        'cursor': '42',
      },
    );

    expect(uri.queryParameters, <String, String>{
      'token': 'abc',
      'directory': '/workspace/override',
      'cursor': '42',
    });
  });

  test('keeps a clean request uri when no query parameters are present', () {
    final uri = buildRequestUri(
      Uri.parse('https://example.com'),
      path: 'project',
    );

    expect(uri.toString(), 'https://example.com/project');
    expect(uri.hasQuery, isFalse);
    expect(uri.queryParameters, isEmpty);
  });
}
