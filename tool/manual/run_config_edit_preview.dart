import 'dart:io';

import 'package:opencode_mobile_remote/src/core/spec/raw_json_document.dart';
import 'package:opencode_mobile_remote/src/features/settings/config_edit_preview.dart';

void main() {
  final preview = buildConfigEditPreview(
    current: RawJsonDocument(<String, Object?>{
      'model': 'openai/gpt-5',
      'x-future': <String, Object?>{'enabled': true},
      'permission': <String, Object?>{'default': 'ask'},
    }),
    draft:
        '{"model":"anthropic/claude-sonnet-4.5","x-future":{"enabled":true},"permission":{"default":"allow"},"newKey":1}',
  );

  stdout.writeln(preview.changedPaths.join(','));
}
