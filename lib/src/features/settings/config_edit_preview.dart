import 'dart:convert';

import '../../core/spec/raw_json_document.dart';

class ConfigEditPreview {
  const ConfigEditPreview({
    required this.isValid,
    required this.error,
    required this.changedPaths,
  });

  final bool isValid;
  final String? error;
  final List<String> changedPaths;
}

ConfigEditPreview buildConfigEditPreview({
  required RawJsonDocument current,
  required String draft,
}) {
  final trimmed = draft.trim();
  if (trimmed.isEmpty) {
    return const ConfigEditPreview(
      isValid: false,
      error: 'Config draft is empty.',
      changedPaths: <String>[],
    );
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw const FormatException('Config must be a JSON object.');
    }
    final next = decoded.cast<String, Object?>();
    final changes = <String>[];
    _collectDiff('', current.toJson(), next, changes);
    changes.sort();
    return ConfigEditPreview(isValid: true, error: null, changedPaths: changes);
  } on FormatException catch (error) {
    return ConfigEditPreview(
      isValid: false,
      error: error.message,
      changedPaths: const <String>[],
    );
  }
}

void _collectDiff(
  String prefix,
  Map<String, Object?> before,
  Map<String, Object?> after,
  List<String> changes,
) {
  final keys = <String>{...before.keys, ...after.keys}.toList()..sort();
  for (final key in keys) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    final beforeHasKey = before.containsKey(key);
    final afterHasKey = after.containsKey(key);
    if (!beforeHasKey) {
      changes.add('+$path');
      continue;
    }
    if (!afterHasKey) {
      changes.add('-$path');
      continue;
    }

    final beforeValue = before[key];
    final afterValue = after[key];
    if (beforeValue is Map && afterValue is Map) {
      _collectDiff(
        path,
        beforeValue.cast<String, Object?>(),
        afterValue.cast<String, Object?>(),
        changes,
      );
      continue;
    }
    if (beforeValue != afterValue) {
      changes.add('~$path');
    }
  }
}
