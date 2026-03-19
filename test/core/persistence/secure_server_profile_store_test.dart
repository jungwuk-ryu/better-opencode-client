import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/persistence/secure_server_profile_store.dart';

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
