import 'package:audioplayers/audioplayers.dart';

abstract class PendingRequestSoundService {
  Future<void> playPermissionRequestSound({required String dedupeKey});
}

final PendingRequestSoundService sharedPendingRequestSoundService =
    AssetPendingRequestSoundService();

class AssetPendingRequestSoundService implements PendingRequestSoundService {
  AssetPendingRequestSoundService();

  static const String _assetPath = 'audio/permission_request.wav';

  final Set<String> _playedKeys = <String>{};
  Future<AudioPool?>? _poolFuture;

  @override
  Future<void> playPermissionRequestSound({required String dedupeKey}) async {
    final normalizedKey = dedupeKey.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    if (!_playedKeys.add(normalizedKey)) {
      return;
    }
    try {
      final pool = await _ensurePool();
      if (pool == null) {
        _playedKeys.remove(normalizedKey);
        return;
      }
      await pool.start(volume: 0.92);
    } catch (_) {
      _playedKeys.remove(normalizedKey);
    }
  }

  Future<AudioPool?> _ensurePool() {
    _poolFuture ??= _createPool();
    return _poolFuture!;
  }

  Future<AudioPool?> _createPool() async {
    try {
      return AudioPool.createFromAsset(
        path: _assetPath,
        minPlayers: 1,
        maxPlayers: 1,
      );
    } catch (_) {
      _poolFuture = null;
      return null;
    }
  }
}
