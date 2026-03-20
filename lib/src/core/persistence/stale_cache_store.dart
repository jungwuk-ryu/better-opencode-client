import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StaleCacheEntry {
  const StaleCacheEntry({
    required this.payloadJson,
    required this.signature,
    required this.fetchedAt,
  });

  final String payloadJson;
  final String signature;
  final DateTime fetchedAt;

  bool isFresh(Duration ttl, DateTime now) {
    return now.difference(fetchedAt) <= ttl;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'payloadJson': payloadJson,
    'signature': signature,
    'fetchedAtMs': fetchedAt.millisecondsSinceEpoch,
  };

  factory StaleCacheEntry.fromJson(Map<String, Object?> json) {
    return StaleCacheEntry(
      payloadJson: (json['payloadJson'] as String?) ?? '{}',
      signature: (json['signature'] as String?) ?? '',
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['fetchedAtMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class StaleCacheStore {
  static const String cachePrefix = 'cache.v1.';
  static const String ttlKey = '${cachePrefix}ttlMs';
  static const int defaultTtlMs = 60000;

  Future<StaleCacheEntry?> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$cachePrefix$key');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return StaleCacheEntry.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  Future<void> save(String key, Object? payload) async {
    final payloadJson = jsonEncode(payload);
    final entry = StaleCacheEntry(
      payloadJson: payloadJson,
      signature: payloadJson,
      fetchedAt: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$cachePrefix$key', jsonEncode(entry.toJson()));
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$cachePrefix$key');
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(cachePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<Duration> loadTtl() async {
    final prefs = await SharedPreferences.getInstance();
    final ttlMs = prefs.getInt(ttlKey) ?? defaultTtlMs;
    return Duration(milliseconds: ttlMs);
  }

  Future<void> saveTtl(Duration ttl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(ttlKey, ttl.inMilliseconds);
  }
}
