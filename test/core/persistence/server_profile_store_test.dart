import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/persistence/secure_server_profile_store.dart';
import 'package:opencode_mobile_remote/src/core/persistence/server_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('draft profile round-trips through local store', () async {
    final secureStore = _MemorySecureKeyValueStore();
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStore),
    );
    const profile = ServerProfile(
      id: 'draft',
      label: 'Demo',
      baseUrl: 'https://demo.opencode.ai',
      username: 'opencode',
      password: 'hunter2',
    );

    await store.saveDraftProfile(profile);
    final restored = await store.loadDraftProfile();

    expect(restored?.effectiveLabel, 'Demo');
    expect(restored?.normalizedBaseUrl, 'https://demo.opencode.ai');
    expect(restored?.username, 'opencode');
    expect(restored?.password, 'hunter2');
  });

  test('draft profile stores credentials outside shared preferences', () async {
    final secureStore = _MemorySecureKeyValueStore();
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStore),
    );
    const profile = ServerProfile(
      id: 'draft',
      label: 'Demo',
      baseUrl: 'demo.opencode.ai',
      username: 'opencode',
      password: 'hunter2',
    );

    await store.saveDraftProfile(profile);

    final prefs = await SharedPreferences.getInstance();
    final rawDraft = prefs.getString('draft_server_profile');
    final storedDraft = jsonDecode(rawDraft!) as Map<String, Object?>;

    expect(storedDraft['baseUrl'], 'https://demo.opencode.ai');
    expect(storedDraft.containsKey('username'), isFalse);
    expect(storedDraft.containsKey('password'), isFalse);
    expect(
      jsonDecode(
            secureStore.values[SecureServerProfileStore.draftCredentialsKey]!,
          )
          as Map<String, Object?>,
      <String, Object?>{'username': 'opencode', 'password': 'hunter2'},
    );
  });

  test('saved profiles store credentials outside shared preferences', () async {
    final secureStore = _MemorySecureKeyValueStore();
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStore),
    );
    const profile = ServerProfile(
      id: 'saved-1',
      label: 'Local Dev',
      baseUrl: 'demo.opencode.ai',
      username: 'operator',
      password: 'secret',
    );

    final savedProfiles = await store.upsertProfile(profile);

    final prefs = await SharedPreferences.getInstance();
    final rawProfiles = prefs.getStringList('server_profiles');
    final storedProfile =
        jsonDecode(rawProfiles!.single) as Map<String, Object?>;

    expect(savedProfiles, hasLength(1));
    expect(savedProfiles.single.effectiveLabel, 'Local Dev');
    expect(storedProfile['baseUrl'], 'https://demo.opencode.ai');
    expect(storedProfile.containsKey('username'), isFalse);
    expect(storedProfile.containsKey('password'), isFalse);
    expect(
      jsonDecode(
            secureStore
                .values[SecureServerProfileStore.savedCredentialsKeyForProfile(
              'saved-1',
            )]!,
          )
          as Map<String, Object?>,
      <String, Object?>{'username': 'operator', 'password': 'secret'},
    );
  });

  test(
    'saving a profile strips embedded url credentials into secure storage',
    () async {
      final secureStore = _MemorySecureKeyValueStore();
      final store = ServerProfileStore(
        secureStore: SecureServerProfileStore(storage: secureStore),
      );
      const profile = ServerProfile(
        id: 'saved-2',
        label: 'Embedded Auth',
        baseUrl: 'https://operator:secret@demo.opencode.ai/api/',
      );

      final savedProfiles = await store.upsertProfile(profile);

      final prefs = await SharedPreferences.getInstance();
      final rawProfiles = prefs.getStringList('server_profiles');
      final storedProfile =
          jsonDecode(rawProfiles!.single) as Map<String, Object?>;

      expect(
        savedProfiles.single.normalizedBaseUrl,
        'https://demo.opencode.ai/api',
      );
      expect(savedProfiles.single.username, 'operator');
      expect(savedProfiles.single.password, 'secret');
      expect(storedProfile['baseUrl'], 'https://demo.opencode.ai/api');
      expect(storedProfile.containsKey('username'), isFalse);
      expect(storedProfile.containsKey('password'), isFalse);
      expect(
        jsonDecode(
              secureStore
                  .values[SecureServerProfileStore.savedCredentialsKeyForProfile(
                'saved-2',
              )]!,
            )
            as Map<String, Object?>,
        <String, Object?>{'username': 'operator', 'password': 'secret'},
      );
    },
  );

  test('pinned profiles toggle on and off by storage key', () async {
    final store = ServerProfileStore();
    const profile = ServerProfile(
      id: '1',
      label: 'Pinned',
      baseUrl: 'https://demo.opencode.ai',
    );

    final pinned = await store.togglePinnedProfile(profile.storageKey);
    final unpinned = await store.togglePinnedProfile(profile.storageKey);

    expect(pinned.contains(profile.storageKey), isTrue);
    expect(unpinned.contains(profile.storageKey), isFalse);
  });

  test('malformed recent connections are skipped and rewritten', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'recent_server_connections': <String>[
        '{bad json',
        jsonEncode(<String, Object?>{
          'id': 'saved-1',
          'label': 'Local Dev',
          'baseUrl': 'https://demo.opencode.ai',
          'attemptedAt': '2026-03-26T00:00:00.000Z',
          'classification': 'ready',
          'summary': 'Ready',
        }),
      ],
    });
    final store = ServerProfileStore();

    final connections = await store.loadRecentConnections();
    final prefs = await SharedPreferences.getInstance();

    expect(connections, hasLength(1));
    expect(connections.single.id, 'saved-1');
    expect(prefs.getStringList('recent_server_connections'), hasLength(1));
  });
}

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
