import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../connection/connection_models.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  static const _macOsOptions = MacOsOptions(
    accountName: 'ai.opencode.opencodeMobileRemote.credentials',
    accessibility: KeychainAccessibility.first_unlock,
    useDataProtectionKeyChain: false,
  );

  const FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage =
          storage ?? const FlutterSecureStorage(mOptions: _macOsOptions);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class SecureServerProfileStore {
  static const draftCredentialsKey = 'draft_server_profile_credentials';
  static const savedCredentialsPrefix = 'server_profile_credentials::';

  SecureServerProfileStore({
    SecureKeyValueStore? storage,
    Duration readTimeout = const Duration(seconds: 2),
    Duration writeTimeout = const Duration(seconds: 4),
    Duration deleteTimeout = const Duration(seconds: 2),
  }) : _storage = storage ?? const FlutterSecureKeyValueStore(),
       _readTimeout = readTimeout,
       _writeTimeout = writeTimeout,
       _deleteTimeout = deleteTimeout;

  final SecureKeyValueStore _storage;
  final Duration _readTimeout;
  final Duration _writeTimeout;
  final Duration _deleteTimeout;

  Future<List<ServerProfile>> hydrateSavedProfiles(
    Iterable<ServerProfile> profiles,
  ) async {
    final hydrated = <ServerProfile>[];
    for (final profile in profiles) {
      hydrated.add(await hydrateSavedProfile(profile));
    }
    return List<ServerProfile>.unmodifiable(hydrated);
  }

  Future<ServerProfile> hydrateSavedProfile(ServerProfile profile) {
    return _hydrateProfile(profile, _savedCredentialsKey(profile.id));
  }

  Future<void> writeSavedProfiles(Iterable<ServerProfile> profiles) async {
    for (final profile in profiles) {
      await _writeProfile(_savedCredentialsKey(profile.id), profile);
    }
  }

  Future<void> deleteSavedProfiles(Iterable<String> profileIds) async {
    for (final profileId in profileIds) {
      await _storage.delete(_savedCredentialsKey(profileId));
    }
  }

  Future<ServerProfile> hydrateDraftProfile(ServerProfile profile) {
    return _hydrateProfile(profile, draftCredentialsKey);
  }

  Future<void> writeDraftProfile(ServerProfile profile) {
    return _writeProfile(draftCredentialsKey, profile);
  }

  Future<void> clearDraftProfile() {
    return _storage.delete(draftCredentialsKey);
  }

  Future<ServerProfile> _hydrateProfile(
    ServerProfile profile,
    String key,
  ) async {
    final raw = await _safeRead(key);
    if (raw == null || raw.isEmpty) {
      return profile.copyWith(clearUsername: true, clearPassword: true);
    }

    final credentials = _StoredProfileCredentials.tryParse(raw);
    if (credentials == null) {
      await _safeDelete(key);
      return profile.copyWith(clearUsername: true, clearPassword: true);
    }

    return profile.copyWith(
      username: credentials.username,
      password: credentials.password,
      clearUsername: credentials.username == null,
      clearPassword: credentials.password == null,
    );
  }

  Future<void> _writeProfile(String key, ServerProfile profile) async {
    final credentials = _StoredProfileCredentials(
      username: profile.username,
      password: profile.password,
    );
    if (credentials.isEmpty) {
      await _safeDelete(key);
      return;
    }

    await _safeWrite(key, jsonEncode(credentials.toJson()));
  }

  Future<String?> _safeRead(String key) async {
    return _runWithRetry<String?>(
      action: 'read',
      key: key,
      timeout: _readTimeout,
      operation: () => _storage.read(key),
    );
  }

  Future<void> _safeWrite(String key, String value) async {
    await _runWithRetry<void>(
      action: 'write',
      key: key,
      timeout: _writeTimeout,
      operation: () => _storage.write(key, value),
    );
  }

  Future<void> _safeDelete(String key) async {
    await _runWithRetry<void>(
      action: 'delete',
      key: key,
      timeout: _deleteTimeout,
      operation: () => _storage.delete(key),
    );
  }

  Future<T?> _runWithRetry<T>({
    required String action,
    required String key,
    required Duration timeout,
    required Future<T> Function() operation,
  }) async {
    for (var attempt = 1; attempt <= 2; attempt += 1) {
      try {
        return await operation().timeout(timeout);
      } on TimeoutException catch (error) {
        if (attempt == 2) {
          debugPrint(
            'SecureServerProfileStore $action timed out for $key: $error',
          );
          return null;
        }
      } catch (error) {
        debugPrint('SecureServerProfileStore $action failed for $key: $error');
        return null;
      }
    }
    return null;
  }

  static String savedCredentialsKeyForProfile(String profileId) {
    return _savedCredentialsKey(profileId);
  }

  static String _savedCredentialsKey(String profileId) {
    return '$savedCredentialsPrefix$profileId';
  }
}

class _StoredProfileCredentials {
  const _StoredProfileCredentials({this.username, this.password});

  final String? username;
  final String? password;

  bool get isEmpty => username == null && password == null;

  Map<String, Object?> toJson() => {'username': username, 'password': password};

  factory _StoredProfileCredentials.fromJson(Map<String, Object?> json) {
    return _StoredProfileCredentials(
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }

  static _StoredProfileCredentials? tryParse(String raw) {
    final decoded = _decodeObject(raw);
    if (decoded == null) {
      return null;
    }

    if (_hasInvalidCredentialType(decoded, 'username') ||
        _hasInvalidCredentialType(decoded, 'password')) {
      return null;
    }

    return _StoredProfileCredentials.fromJson(decoded);
  }

  static Map<String, Object?>? _decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return decoded.cast<String, Object?>();
    } on FormatException {
      return null;
    }
  }

  static bool _hasInvalidCredentialType(Map<String, Object?> json, String key) {
    final value = json[key];
    return value != null && value is! String;
  }
}
