import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/persistence/secure_server_profile_store.dart';

void main() {
  test('hydrates saved and draft profiles from secure storage', () async {
    final storage = _MemorySecureKeyValueStore();
    final store = SecureServerProfileStore(storage: storage);
    const savedProfile = ServerProfile(
      id: 'saved-1',
      label: 'Demo',
      baseUrl: 'demo.opencode.ai/',
      username: ' operator ',
      password: 'secret',
    );
    const draftProfile = ServerProfile(
      id: 'draft',
      label: 'Draft',
      baseUrl: 'draft.opencode.ai',
      username: 'draft-user',
      password: 'draft-pass',
    );

    await store.writeSavedProfiles(<ServerProfile>[savedProfile]);
    await store.writeDraftProfile(draftProfile);

    final hydratedSaved = await store.hydrateSavedProfile(
      const ServerProfile(
        id: 'saved-1',
        label: 'Demo',
        baseUrl: 'https://demo.opencode.ai',
      ),
    );
    final hydratedDraft = await store.hydrateDraftProfile(
      const ServerProfile(
        id: 'draft',
        label: 'Draft',
        baseUrl: 'https://draft.opencode.ai',
      ),
    );

    expect(hydratedSaved.username, ' operator ');
    expect(hydratedSaved.password, 'secret');
    expect(hydratedSaved.storageKey, 'https://demo.opencode.ai|operator');
    expect(hydratedDraft.username, 'draft-user');
    expect(hydratedDraft.password, 'draft-pass');
  });

  test('deletes saved and draft credentials when cleared', () async {
    final storage = _MemorySecureKeyValueStore();
    final store = SecureServerProfileStore(storage: storage);

    await store.writeSavedProfiles(const <ServerProfile>[
      ServerProfile(
        id: 'saved-1',
        label: 'Demo',
        baseUrl: 'https://demo.opencode.ai',
        username: 'operator',
        password: 'secret',
      ),
    ]);
    await store.writeDraftProfile(
      const ServerProfile(
        id: 'draft',
        label: 'Draft',
        baseUrl: 'https://draft.opencode.ai',
        username: 'draft-user',
        password: 'draft-pass',
      ),
    );

    await store.deleteSavedProfiles(const <String>['saved-1']);
    await store.clearDraftProfile();

    expect(
      storage.values.containsKey(
        SecureServerProfileStore.savedCredentialsKeyForProfile('saved-1'),
      ),
      isFalse,
    );
    expect(
      storage.values.containsKey(SecureServerProfileStore.draftCredentialsKey),
      isFalse,
    );
  });

  test('deletes secure payload when profile has no credentials', () async {
    final storage = _MemorySecureKeyValueStore();
    final store = SecureServerProfileStore(storage: storage);

    await store.writeDraftProfile(
      const ServerProfile(
        id: 'draft',
        label: 'Draft',
        baseUrl: 'https://draft.opencode.ai',
        username: 'draft-user',
        password: 'draft-pass',
      ),
    );
    await store.writeDraftProfile(
      const ServerProfile(
        id: 'draft',
        label: 'Draft',
        baseUrl: 'https://draft.opencode.ai',
      ),
    );

    expect(
      storage.values.containsKey(SecureServerProfileStore.draftCredentialsKey),
      isFalse,
    );
  });

  test(
    'ignores malformed secure payloads and clears invalid credentials',
    () async {
      final storage = _MemorySecureKeyValueStore()
        ..values[SecureServerProfileStore.draftCredentialsKey] = '{bad json';
      final store = SecureServerProfileStore(storage: storage);

      final hydrated = await store.hydrateDraftProfile(
        const ServerProfile(
          id: 'draft',
          label: 'Draft',
          baseUrl: 'https://draft.opencode.ai',
          username: 'stale-user',
          password: 'stale-pass',
        ),
      );

      expect(hydrated.username, isNull);
      expect(hydrated.password, isNull);
      expect(
        storage.values.containsKey(
          SecureServerProfileStore.draftCredentialsKey,
        ),
        isFalse,
      );
    },
  );

  test('ignores partial secure payloads with invalid field types', () async {
    final storage = _MemorySecureKeyValueStore()
      ..values[SecureServerProfileStore.savedCredentialsKeyForProfile(
        'saved-1',
      )] = jsonEncode(<String, Object?>{
        'username': 'operator',
        'password': 123,
      });
    final store = SecureServerProfileStore(storage: storage);

    final hydrated = await store.hydrateSavedProfile(
      const ServerProfile(
        id: 'saved-1',
        label: 'Demo',
        baseUrl: 'https://demo.opencode.ai',
        username: 'stale-user',
        password: 'stale-pass',
      ),
    );

    expect(hydrated.username, isNull);
    expect(hydrated.password, isNull);
    expect(
      storage.values.containsKey(
        SecureServerProfileStore.savedCredentialsKeyForProfile('saved-1'),
      ),
      isFalse,
    );
  });

  test('write operations time out instead of hanging forever', () async {
    final store = SecureServerProfileStore(
      storage: _HangingSecureKeyValueStore(),
      writeTimeout: const Duration(milliseconds: 10),
    );

    await store.writeDraftProfile(
      const ServerProfile(
        id: 'draft',
        label: 'Draft',
        baseUrl: 'https://draft.opencode.ai',
        username: 'draft-user',
        password: 'draft-pass',
      ),
    );
    await store.writeSavedProfiles(const <ServerProfile>[
      ServerProfile(
        id: 'saved-1',
        label: 'Demo',
        baseUrl: 'https://demo.opencode.ai',
        username: 'operator',
        password: 'secret',
      ),
    ]);
  });

  test('read operations time out instead of hanging forever', () async {
    final store = SecureServerProfileStore(
      storage: _HangingSecureKeyValueStore(),
      readTimeout: const Duration(milliseconds: 10),
    );

    final hydrated = await store.hydrateDraftProfile(
      const ServerProfile(
        id: 'draft',
        label: 'Draft',
        baseUrl: 'https://draft.opencode.ai',
        username: 'stale-user',
        password: 'stale-pass',
      ),
    );

    expect(hydrated.username, isNull);
    expect(hydrated.password, isNull);
  });

  test('write retries once when the first secure call times out', () async {
    final storage = _RetryingSecureKeyValueStore();
    final store = SecureServerProfileStore(
      storage: storage,
      writeTimeout: const Duration(milliseconds: 10),
    );

    await store.writeSavedProfiles(const <ServerProfile>[
      ServerProfile(
        id: 'saved-1',
        label: 'Demo',
        baseUrl: 'https://demo.opencode.ai',
        username: 'operator',
        password: 'secret',
      ),
    ]);

    expect(
      jsonDecode(
            storage.values[SecureServerProfileStore.savedCredentialsKeyForProfile(
              'saved-1',
            )]!,
          )
          as Map<String, Object?>,
      <String, Object?>{'username': 'operator', 'password': 'secret'},
    );
    expect(
      storage.writeAttempts[
        SecureServerProfileStore.savedCredentialsKeyForProfile('saved-1')
      ],
      2,
    );
  });

  test('read retries once when the first secure call times out', () async {
    final key = SecureServerProfileStore.savedCredentialsKeyForProfile(
      'saved-1',
    );
    final storage = _RetryingSecureKeyValueStore()
      ..values[key] = jsonEncode(<String, Object?>{
        'username': 'operator',
        'password': 'secret',
      });
    final store = SecureServerProfileStore(
      storage: storage,
      readTimeout: const Duration(milliseconds: 10),
    );

    final hydrated = await store.hydrateSavedProfile(
      const ServerProfile(
        id: 'saved-1',
        label: 'Demo',
        baseUrl: 'https://demo.opencode.ai',
      ),
    );

    expect(hydrated.username, 'operator');
    expect(hydrated.password, 'secret');
    expect(storage.readAttempts[key], 2);
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
    jsonDecode(value);
  }
}

class _HangingSecureKeyValueStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) => Completer<void>().future;

  @override
  Future<String?> read(String key) => Completer<String?>().future;

  @override
  Future<void> write(String key, String value) => Completer<void>().future;
}

class _RetryingSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};
  final Map<String, int> readAttempts = <String, int>{};
  final Map<String, int> writeAttempts = <String, int>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    final attempt = (readAttempts[key] ?? 0) + 1;
    readAttempts[key] = attempt;
    if (attempt == 1) {
      return Completer<String?>().future;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    final attempt = (writeAttempts[key] ?? 0) + 1;
    writeAttempts[key] = attempt;
    if (attempt == 1) {
      return Completer<void>().future;
    }
    values[key] = value;
  }
}
