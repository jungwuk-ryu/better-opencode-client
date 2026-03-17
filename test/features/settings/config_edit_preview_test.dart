import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/spec/raw_json_document.dart';
import 'package:opencode_mobile_remote/src/features/settings/config_edit_preview.dart';

void main() {
  test('builds change summary for nested config edits', () {
    final preview = buildConfigEditPreview(
      current: RawJsonDocument(<String, Object?>{
        'model': 'openai/gpt-5',
        'permission': <String, Object?>{'default': 'ask'},
        'x-future': <String, Object?>{'enabled': true},
      }),
      draft:
          '{"model":"anthropic/claude-sonnet-4.5","permission":{"default":"allow"},"x-future":{"enabled":true},"newKey":1}',
    );

    expect(preview.isValid, isTrue);
    expect(preview.changedPaths, contains('~model'));
    expect(preview.changedPaths, contains('~permission.default'));
    expect(preview.changedPaths, contains('+newKey'));
    expect(preview.changedPaths, isNot(contains('~x-future.enabled')));
  });

  test('reports invalid json drafts', () {
    final preview = buildConfigEditPreview(
      current: RawJsonDocument(<String, Object?>{'model': 'openai/gpt-5'}),
      draft: '{invalid',
    );

    expect(preview.isValid, isFalse);
    expect(preview.error, isNotNull);
  });
}
