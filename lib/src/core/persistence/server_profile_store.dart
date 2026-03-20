import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../connection/connection_models.dart';
import 'secure_server_profile_store.dart';

class ServerProfileStore {
  static const _profilesKey = 'server_profiles';
  static const _recentConnectionsKey = 'recent_server_connections';
  static const _draftProfileKey = 'draft_server_profile';
  static const _pinnedProfilesKey = 'pinned_server_profiles';
  static const _recentConnectionLimit = 8;

  ServerProfileStore({SecureServerProfileStore? secureStore})
    : _secureStore = secureStore ?? SecureServerProfileStore();

  final SecureServerProfileStore _secureStore;

  Future<List<ServerProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyCredentials(prefs);
    final raw = prefs.getStringList(_profilesKey) ?? const <String>[];
    final profiles = raw
        .map(_decodeProfileOrNull)
        .whereType<ServerProfile>()
        .toList(growable: false);
    return _secureStore.hydrateSavedProfiles(profiles);
  }

  Future<void> save(List<ServerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyCredentials(prefs);
    final existingIds = _storedProfileIds(prefs);
    await _secureStore.writeSavedProfiles(profiles);
    await prefs.setStringList(
      _profilesKey,
      profiles.map(_encodeSanitizedProfile).toList(growable: false),
    );
    final nextIds = profiles.map((profile) => profile.id).toSet();
    await _secureStore.deleteSavedProfiles(existingIds.difference(nextIds));
  }

  Future<ServerProfile?> loadDraftProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyCredentials(prefs);
    final raw = prefs.getString(_draftProfileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final draft = _decodeProfileOrNull(raw);
    if (draft == null) {
      await prefs.remove(_draftProfileKey);
      await _secureStore.clearDraftProfile();
      return null;
    }

    return _secureStore.hydrateDraftProfile(draft);
  }

  Future<void> saveDraftProfile(ServerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyCredentials(prefs);
    await _secureStore.writeDraftProfile(profile);
    await prefs.setString(_draftProfileKey, _encodeSanitizedProfile(profile));
  }

  Future<void> clearDraftProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftProfileKey);
    await _secureStore.clearDraftProfile();
  }

  Future<Set<String>> loadPinnedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pinnedProfilesKey) ?? const <String>[])
        .toSet();
  }

  Future<Set<String>> togglePinnedProfile(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final next = await loadPinnedProfiles();
    if (!next.add(storageKey)) {
      next.remove(storageKey);
    }
    await prefs.setStringList(_pinnedProfilesKey, next.toList(growable: false));
    return next;
  }

  Future<List<RecentConnection>> loadRecentConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentConnectionsKey) ?? const <String>[];
    final connections = raw
        .map(
          (entry) => RecentConnection.fromJson(
            (jsonDecode(entry) as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
    final sorted = connections.toList()
      ..sort((a, b) => b.attemptedAt.compareTo(a.attemptedAt));
    return List<RecentConnection>.unmodifiable(sorted);
  }

  Future<void> saveRecentConnections(List<RecentConnection> connections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentConnectionsKey,
      connections.map((connection) => jsonEncode(connection.toJson())).toList(),
    );
  }

  Future<List<RecentConnection>> recordRecentConnection(
    RecentConnection connection,
  ) async {
    final current = await loadRecentConnections();
    final next = <RecentConnection>[connection];
    for (final item in current) {
      if (item.storageKey == connection.storageKey) {
        continue;
      }
      next.add(item);
      if (next.length >= _recentConnectionLimit) {
        break;
      }
    }
    await saveRecentConnections(next);
    return next;
  }

  Future<List<ServerProfile>> upsertProfile(ServerProfile profile) async {
    final profiles = (await load()).toList();
    final existingIndex = profiles.indexWhere(
      (entry) =>
          entry.id == profile.id || entry.storageKey == profile.storageKey,
    );
    if (existingIndex >= 0) {
      profiles[existingIndex] = profile;
    } else {
      profiles.insert(0, profile);
    }
    await save(profiles);
    return List<ServerProfile>.unmodifiable(profiles);
  }

  Future<List<ServerProfile>> deleteProfile(String profileId) async {
    final profiles = (await load())
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
    await save(profiles);
    final existing = await loadPinnedProfiles();
    final nextPinned = profiles.map((profile) => profile.storageKey).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _pinnedProfilesKey,
      existing.where(nextPinned.contains).toList(growable: false),
    );
    return profiles;
  }

  Future<void> _migrateLegacyCredentials(SharedPreferences prefs) async {
    await _migrateLegacySavedProfiles(prefs);
    await _migrateLegacyDraftProfile(prefs);
  }

  Future<void> _migrateLegacySavedProfiles(SharedPreferences prefs) async {
    final rawProfiles = prefs.getStringList(_profilesKey) ?? const <String>[];
    if (rawProfiles.isEmpty) {
      return;
    }

    var needsRewrite = false;
    final profiles = <ServerProfile>[];
    for (final entry in rawProfiles) {
      final decoded = _decodeJsonObject(entry);
      if (decoded == null) {
        needsRewrite = true;
        continue;
      }

      if (_containsLegacyCredentials(decoded)) {
        needsRewrite = true;
      }

      final profile = _profileFromJsonOrNull(decoded);
      if (profile == null) {
        needsRewrite = true;
        continue;
      }

      profiles.add(profile);
    }

    if (!needsRewrite) {
      return;
    }

    await _secureStore.writeSavedProfiles(profiles);
    await prefs.setStringList(
      _profilesKey,
      profiles.map(_encodeSanitizedProfile).toList(growable: false),
    );
  }

  Future<void> _migrateLegacyDraftProfile(SharedPreferences prefs) async {
    final rawDraft = prefs.getString(_draftProfileKey);
    if (rawDraft == null || rawDraft.isEmpty) {
      return;
    }

    final decoded = _decodeJsonObject(rawDraft);
    if (decoded == null) {
      await prefs.remove(_draftProfileKey);
      await _secureStore.clearDraftProfile();
      return;
    }

    if (!_containsLegacyCredentials(decoded)) {
      return;
    }

    final profile = _profileFromJsonOrNull(decoded);
    if (profile == null) {
      await prefs.remove(_draftProfileKey);
      await _secureStore.clearDraftProfile();
      return;
    }

    await _secureStore.writeDraftProfile(profile);
    await prefs.setString(_draftProfileKey, _encodeSanitizedProfile(profile));
  }

  bool _containsLegacyCredentials(Map<String, Object?> json) {
    return json.containsKey('username') || json.containsKey('password');
  }

  ServerProfile? _decodeProfileOrNull(String entry) {
    final decoded = _decodeJsonObject(entry);
    if (decoded == null) {
      return null;
    }
    return _profileFromJsonOrNull(decoded);
  }

  String _encodeSanitizedProfile(ServerProfile profile) {
    return jsonEncode(<String, Object?>{
      'id': profile.id,
      'label': profile.label,
      'baseUrl': profile.normalizedBaseUrl,
    });
  }

  Set<String> _storedProfileIds(SharedPreferences prefs) {
    final rawProfiles = prefs.getStringList(_profilesKey) ?? const <String>[];
    return rawProfiles
        .map(_decodeProfileOrNull)
        .whereType<ServerProfile>()
        .map((profile) => profile.id)
        .toSet();
  }

  Map<String, Object?>? _decodeJsonObject(String raw) {
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

  ServerProfile? _profileFromJsonOrNull(Map<String, Object?> json) {
    final id = json['id'];
    final baseUrl = json['baseUrl'];
    final label = json['label'];
    final username = json['username'];
    final password = json['password'];

    if (id is! String || id.isEmpty || baseUrl is! String || baseUrl.isEmpty) {
      return null;
    }
    if (label != null && label is! String) {
      return null;
    }
    if (username != null && username is! String) {
      return null;
    }
    if (password != null && password is! String) {
      return null;
    }

    return ServerProfile(
      id: id,
      label: label as String? ?? '',
      baseUrl: baseUrl,
      username: username as String?,
      password: password as String?,
    );
  }
}
