import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../connection/connection_models.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

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

  SecureServerProfileStore({SecureKeyValueStore? storage})
    : _storage = storage ?? const FlutterSecureKeyValueStore();

  final SecureKeyValueStore _storage;

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
    final raw = await _storage.read(key);
    if (raw == null || raw.isEmpty) {
      return profile.copyWith(clearUsername: true, clearPassword: true);
    }

    final credentials = _StoredProfileCredentials.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
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
      await _storage.delete(key);
      return;
    }

    await _storage.write(key, jsonEncode(credentials.toJson()));
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
}
