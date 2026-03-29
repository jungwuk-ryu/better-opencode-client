import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';

void main() {
  Map<String, Object?> load(String path) {
    return (jsonDecode(File(path).readAsStringSync()) as Map)
        .cast<String, Object?>();
  }

  test('unknown fields survive nested merges', () {
    final document = RawJsonDocument(
      load('assets/fixtures/config/config_with_unknown_fields.json'),
    );
    final merged = document.merge({
      'model': 'anthropic/claude-sonnet-4.5',
      'provider': {'default': 'anthropic'},
    });

    final json = merged.toJson();
    expect((json['x-ui'] as Map)['density'], 'comfortable');
    expect(((json['providers'] as List).first as Map)['x-extra'], isNotNull);
  });
}
