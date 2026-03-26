import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/persistence/stale_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load drops malformed cache envelopes instead of throwing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${StaleCacheStore.cachePrefix}broken': '{bad json',
    });
    final store = StaleCacheStore();

    final entry = await store.load('broken');
    final prefs = await SharedPreferences.getInstance();

    expect(entry, isNull);
    expect(prefs.containsKey('${StaleCacheStore.cachePrefix}broken'), isFalse);
  });

  test('load keeps valid cache envelopes intact', () async {
    final payload = <String, Object?>{'hello': 'world'};
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${StaleCacheStore.cachePrefix}ok': jsonEncode(<String, Object?>{
        'payloadJson': jsonEncode(payload),
        'signature': 'sig',
        'fetchedAtMs': DateTime(2026, 3, 26).millisecondsSinceEpoch,
      }),
    });
    final store = StaleCacheStore();

    final entry = await store.load('ok');

    expect(entry, isNotNull);
    expect(entry?.payloadJson, jsonEncode(payload));
    expect(entry?.signature, 'sig');
  });
}
