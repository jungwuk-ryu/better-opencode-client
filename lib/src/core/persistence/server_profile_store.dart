import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../connection/connection_models.dart';

class ServerProfileStore {
  static const _profilesKey = 'server_profiles';
  static const _recentConnectionsKey = 'recent_server_connections';
  static const _draftProfileKey = 'draft_server_profile';
  static const _pinnedProfilesKey = 'pinned_server_profiles';
  static const _recentConnectionLimit = 8;

  Future<List<ServerProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_profilesKey) ?? const <String>[];
    return raw
        .map(
          (entry) => ServerProfile.fromJson(
            (jsonDecode(entry) as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> save(List<ServerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _profilesKey,
      profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
  }

  Future<ServerProfile?> loadDraftProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftProfileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return ServerProfile.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  Future<void> saveDraftProfile(ServerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftProfileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearDraftProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftProfileKey);
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
}
