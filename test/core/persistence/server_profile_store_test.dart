import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/persistence/server_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('draft profile round-trips through local store', () async {
    final store = ServerProfileStore();
    const profile = ServerProfile(
      id: 'draft',
      label: 'Demo',
      baseUrl: 'https://demo.opencode.ai',
      username: 'opencode',
    );

    await store.saveDraftProfile(profile);
    final restored = await store.loadDraftProfile();

    expect(restored?.effectiveLabel, 'Demo');
    expect(restored?.normalizedBaseUrl, 'https://demo.opencode.ai');
  });

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
}
