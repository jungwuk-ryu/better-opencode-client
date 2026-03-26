import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/persistence/secure_server_profile_store.dart';
import 'package:opencode_mobile_remote/src/core/persistence/server_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('migrates legacy saved and draft credentials once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'server_profiles': <String>[
        jsonEncode(<String, Object?>{
          'id': 'saved-1',
          'label': 'Local Dev',
          'baseUrl': 'demo.opencode.ai',
          'username': 'operator',
          'password': 'secret',
        }),
      ],
      'draft_server_profile': jsonEncode(<String, Object?>{
        'id': 'draft',
        'label': 'Draft',
        'baseUrl': 'draft.opencode.ai',
        'username': 'draft-user',
        'password': 'draft-pass',
      }),
    });

    final secureStorage = _MemorySecureKeyValueStore();
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStorage),
    );

    final profiles = await store.load();
    final draft = await store.loadDraftProfile();
    final prefs = await SharedPreferences.getInstance();
    final storedProfile =
        jsonDecode(prefs.getStringList('server_profiles')!.single)
            as Map<String, Object?>;
    final storedDraft =
        jsonDecode(prefs.getString('draft_server_profile')!)
            as Map<String, Object?>;

    expect(profiles.single.username, 'operator');
    expect(profiles.single.password, 'secret');
    expect(profiles.single.storageKey, 'https://demo.opencode.ai|operator');
    expect(draft?.username, 'draft-user');
    expect(draft?.password, 'draft-pass');
    expect(storedProfile.containsKey('username'), isFalse);
    expect(storedProfile.containsKey('password'), isFalse);
    expect(storedDraft.containsKey('username'), isFalse);
    expect(storedDraft.containsKey('password'), isFalse);
    expect(
      secureStorage.values.keys,
      containsAll(<String>[
        SecureServerProfileStore.savedCredentialsKeyForProfile('saved-1'),
        SecureServerProfileStore.draftCredentialsKey,
      ]),
    );
  });

  test('migration stays idempotent across repeated loads', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'server_profiles': <String>[
        jsonEncode(<String, Object?>{
          'id': 'saved-1',
          'label': 'Local Dev',
          'baseUrl': 'https://demo.opencode.ai',
          'username': 'operator',
          'password': 'secret',
        }),
      ],
      'draft_server_profile': jsonEncode(<String, Object?>{
        'id': 'draft',
        'label': 'Draft',
        'baseUrl': 'https://draft.opencode.ai',
        'username': 'draft-user',
        'password': 'draft-pass',
      }),
    });

    final secureStorage = _MemorySecureKeyValueStore();
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStorage),
    );

    await store.load();
    await store.loadDraftProfile();
    final firstSnapshot = Map<String, String>.from(secureStorage.values);

    await store.load();
    final secondDraft = await store.loadDraftProfile();
    final prefs = await SharedPreferences.getInstance();

    expect(secureStorage.values, firstSnapshot);
    expect(secondDraft?.password, 'draft-pass');
    expect(
      (jsonDecode(prefs.getStringList('server_profiles')!.single) as Map)
          .containsKey('password'),
      isFalse,
    );
    expect(
      (jsonDecode(prefs.getString('draft_server_profile')!) as Map).containsKey(
        'password',
      ),
      isFalse,
    );
  });

  test('migrates embedded url credentials into secure storage', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'server_profiles': <String>[
        jsonEncode(<String, Object?>{
          'id': 'saved-embedded',
          'label': 'Embedded',
          'baseUrl': 'https://operator:secret@demo.opencode.ai/api/',
        }),
      ],
    });

    final secureStorage = _MemorySecureKeyValueStore();
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStorage),
    );

    final profiles = await store.load();
    final prefs = await SharedPreferences.getInstance();
    final storedProfile =
        jsonDecode(prefs.getStringList('server_profiles')!.single)
            as Map<String, Object?>;

    expect(profiles.single.normalizedBaseUrl, 'https://demo.opencode.ai/api');
    expect(profiles.single.username, 'operator');
    expect(profiles.single.password, 'secret');
    expect(storedProfile['baseUrl'], 'https://demo.opencode.ai/api');
    expect(storedProfile.containsKey('username'), isFalse);
    expect(storedProfile.containsKey('password'), isFalse);
    expect(
      jsonDecode(
            secureStorage
                .values[SecureServerProfileStore.savedCredentialsKeyForProfile(
              'saved-embedded',
            )]!,
          )
          as Map<String, Object?>,
      <String, Object?>{'username': 'operator', 'password': 'secret'},
    );
  });

  test(
    'skips malformed and partial legacy saved profiles without throwing',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'server_profiles': <String>[
          '{bad json',
          jsonEncode(<String, Object?>{
            'id': 'missing-url',
            'label': 'Broken',
            'username': 'operator',
            'password': 'secret',
          }),
          jsonEncode(<String, Object?>{
            'id': 'saved-1',
            'label': 'Local Dev',
            'baseUrl': 'demo.opencode.ai',
            'username': 'operator',
            'password': 'secret',
          }),
        ],
      });

      final secureStorage = _MemorySecureKeyValueStore();
      final store = ServerProfileStore(
        secureStore: SecureServerProfileStore(storage: secureStorage),
      );

      final profiles = await store.load();
      final prefs = await SharedPreferences.getInstance();
      final storedProfiles = prefs.getStringList('server_profiles')!;

      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'saved-1');
      expect(profiles.single.username, 'operator');
      expect(storedProfiles, hasLength(1));
      expect(
        (jsonDecode(storedProfiles.single) as Map<String, Object?>).containsKey(
          'password',
        ),
        isFalse,
      );
      expect(
        secureStorage.values.keys,
        contains(
          SecureServerProfileStore.savedCredentialsKeyForProfile('saved-1'),
        ),
      );
    },
  );

  test('clears malformed legacy draft payloads without throwing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'draft_server_profile': '{bad json',
    });

    final secureStorage = _MemorySecureKeyValueStore()
      ..values[SecureServerProfileStore.draftCredentialsKey] = jsonEncode(
        <String, Object?>{'username': 'stale-user', 'password': 'stale-pass'},
      );
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStorage),
    );

    final draft = await store.loadDraftProfile();
    final prefs = await SharedPreferences.getInstance();

    expect(draft, isNull);
    expect(prefs.getString('draft_server_profile'), isNull);
    expect(
      secureStorage.values.containsKey(
        SecureServerProfileStore.draftCredentialsKey,
      ),
      isFalse,
    );
  });

  test('drops invalid secure credentials during draft hydration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'draft_server_profile': jsonEncode(<String, Object?>{
        'id': 'draft',
        'label': 'Draft',
        'baseUrl': 'draft.opencode.ai',
      }),
    });

    final secureStorage = _MemorySecureKeyValueStore()
      ..values[SecureServerProfileStore.draftCredentialsKey] = jsonEncode(
        <String, Object?>{'username': true, 'password': 'secret'},
      );
    final store = ServerProfileStore(
      secureStore: SecureServerProfileStore(storage: secureStorage),
    );

    final draft = await store.loadDraftProfile();

    expect(draft, isNotNull);
    expect(draft?.username, isNull);
    expect(draft?.password, isNull);
    expect(
      secureStorage.values.containsKey(
        SecureServerProfileStore.draftCredentialsKey,
      ),
      isFalse,
    );
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
