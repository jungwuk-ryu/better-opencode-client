import 'dart:convert';

class RawJsonDocument {
  RawJsonDocument(Map<String, Object?> raw)
    : _raw = Map<String, Object?>.from(raw);

  final Map<String, Object?> _raw;

  Object? value(String key) => _raw[key];

  Map<String, Object?> toJson() => _deepCopy(_raw);

  RawJsonDocument merge(Map<String, Object?> patch) {
    final merged = _mergeMaps(_deepCopy(_raw), patch);
    return RawJsonDocument(merged);
  }

  static Map<String, Object?> _deepCopy(Map<String, Object?> input) {
    return (jsonDecode(jsonEncode(input)) as Map<String, Object?>);
  }

  static Map<String, Object?> _mergeMaps(
    Map<String, Object?> base,
    Map<String, Object?> patch,
  ) {
    for (final entry in patch.entries) {
      final baseValue = base[entry.key];
      final patchValue = entry.value;
      if (baseValue is Map && patchValue is Map) {
        base[entry.key] = _mergeMaps(
          Map<String, Object?>.from(baseValue.cast<String, Object?>()),
          Map<String, Object?>.from(patchValue.cast<String, Object?>()),
        );
      } else {
        base[entry.key] = patchValue;
      }
    }
    return base;
  }
}
