import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.label,
    required this.baseUrl,
  });

  final String id;
  final String label;
  final String baseUrl;

  Map<String, String> toJson() => {
    'id': id,
    'label': label,
    'baseUrl': baseUrl,
  };

  factory ServerProfile.fromJson(Map<String, Object?> json) {
    return ServerProfile(
      id: json['id']! as String,
      label: json['label']! as String,
      baseUrl: json['baseUrl']! as String,
    );
  }
}

class ServerProfileStore {
  static const _profilesKey = 'server_profiles';

  Future<List<ServerProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_profilesKey) ?? const <String>[];
    return raw
        .map(
          (entry) =>
              ServerProfile.fromJson(jsonDecode(entry) as Map<String, Object?>),
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
}
