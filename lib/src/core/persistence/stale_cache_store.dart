import 'dart:io';
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

class StaleCacheEntryMetadata {
  const StaleCacheEntryMetadata({
    required this.signature,
    required this.fetchedAt,
    this.itemCount,
    this.payloadLength,
  });

  final String signature;
  final DateTime fetchedAt;
  final int? itemCount;
  final int? payloadLength;

  Map<String, Object?> toJson() => <String, Object?>{
    'signature': signature,
    'fetchedAtMs': fetchedAt.millisecondsSinceEpoch,
    'itemCount': itemCount,
    'payloadLength': payloadLength,
  };

  factory StaleCacheEntryMetadata.fromJson(Map<String, Object?> json) {
    return StaleCacheEntryMetadata(
      signature: (json['signature'] as String?) ?? '',
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['fetchedAtMs'] as num?)?.toInt() ?? 0,
      ),
      itemCount: (json['itemCount'] as num?)?.toInt(),
      payloadLength: (json['payloadLength'] as num?)?.toInt(),
    );
  }
}

class StaleCacheStore {
  static const String cachePrefix = 'cache.v1.';
  static const String ttlKey = '${cachePrefix}ttlMs';
  static const int defaultTtlMs = 60000;

  Future<StaleCacheEntry?> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$cachePrefix$key';
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(storageKey);
        return null;
      }
      return StaleCacheEntry.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      await prefs.remove(storageKey);
      return null;
    }
  }

  Future<void> save(
    String key,
    Object? payload, {
    String? signature,
    int? itemCount,
  }) async {
    final payloadJson = jsonEncode(payload);
    final resolvedSignature =
        signature ?? '${payloadJson.length}:${payloadJson.hashCode}';
    final fetchedAt = DateTime.now();
    final entry = StaleCacheEntry(
      payloadJson: payloadJson,
      signature: resolvedSignature,
      fetchedAt: fetchedAt,
    );
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$cachePrefix$key';
    await prefs.setString(storageKey, jsonEncode(entry.toJson()));
  }

  Future<StaleCacheEntryMetadata?> loadMetadata(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$cachePrefix$key';
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(storageKey);
        return null;
      }
      final entry = StaleCacheEntry.fromJson(decoded.cast<String, Object?>());
      return StaleCacheEntryMetadata(
        signature: entry.signature,
        fetchedAt: entry.fetchedAt,
        payloadLength: entry.payloadJson.length,
      );
    } catch (_) {
      await prefs.remove(storageKey);
      return null;
    }
  }

  Future<bool> has(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$cachePrefix$key';
    final raw = prefs.getString(storageKey);
    return raw != null && raw.isNotEmpty;
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

class FileBackedStaleCacheStore extends StaleCacheStore {
  FileBackedStaleCacheStore({
    Directory? rootDirectory,
    this.namespace = 'spill-cache-v1',
  }) : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;
  final String namespace;

  @override
  Future<StaleCacheEntry?> load(String key) async {
    final file = await _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      if (raw.isEmpty) {
        await file.delete();
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await file.delete();
        return null;
      }
      return StaleCacheEntry.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> save(
    String key,
    Object? payload, {
    String? signature,
    int? itemCount,
  }) async {
    final payloadJson = jsonEncode(payload);
    final resolvedSignature =
        signature ?? '${payloadJson.length}:${payloadJson.hashCode}';
    final fetchedAt = DateTime.now();
    final entry = StaleCacheEntry(
      payloadJson: payloadJson,
      signature: resolvedSignature,
      fetchedAt: fetchedAt,
    );
    final metadata = StaleCacheEntryMetadata(
      signature: resolvedSignature,
      fetchedAt: fetchedAt,
      itemCount: itemCount,
      payloadLength: payloadJson.length,
    );
    final file = await _fileForKey(key);
    final metadataFile = await _metadataFileForKey(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(entry.toJson()), flush: true);
    await metadataFile.writeAsString(jsonEncode(metadata.toJson()), flush: true);
  }

  @override
  Future<StaleCacheEntryMetadata?> loadMetadata(String key) async {
    final metadataFile = await _metadataFileForKey(key);
    if (await metadataFile.exists()) {
      try {
        final raw = await metadataFile.readAsString();
        if (raw.isEmpty) {
          await metadataFile.delete();
          return null;
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          await metadataFile.delete();
          return null;
        }
        return StaleCacheEntryMetadata.fromJson(
          decoded.cast<String, Object?>(),
        );
      } catch (_) {
        try {
          await metadataFile.delete();
        } catch (_) {}
        return null;
      }
    }
    final file = await _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }
    return StaleCacheEntryMetadata(
      signature: '',
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<bool> has(String key) async {
    final metadataFile = await _metadataFileForKey(key);
    if (await metadataFile.exists()) {
      return true;
    }
    final file = await _fileForKey(key);
    return file.exists();
  }

  @override
  Future<void> remove(String key) async {
    final file = await _fileForKey(key);
    final metadataFile = await _metadataFileForKey(key);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    if (await metadataFile.exists()) {
      try {
        await metadataFile.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> clearAll() async {
    final directory = await _storageDirectory();
    if (!await directory.exists()) {
      return;
    }
    try {
      await directory.delete(recursive: true);
    } catch (_) {}
  }

  Future<Directory> _storageDirectory() async {
    final baseDirectory = _rootDirectory ?? Directory.systemTemp;
    final directory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}better-opencode-client${Platform.pathSeparator}$namespace',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _fileForKey(String key) async {
    final directory = await _storageDirectory();
    final name = _hashedFileName(key);
    return File('${directory.path}${Platform.pathSeparator}$name.json');
  }

  Future<File> _metadataFileForKey(String key) async {
    final directory = await _storageDirectory();
    final name = _hashedFileName(key);
    return File('${directory.path}${Platform.pathSeparator}$name.meta.json');
  }

  String _hashedFileName(String key) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(key)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
