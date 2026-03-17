enum SseConnectionHealth { connected, stale, reconnecting }

class SseConnectionMonitor {
  SseConnectionMonitor({required this.heartbeatTimeout});

  final Duration heartbeatTimeout;
  DateTime? _lastHeartbeatAt;
  DateTime? _lastFrameAt;
  bool _isReconnecting = false;

  void recordFrame(DateTime at) {
    _lastFrameAt = at;
  }

  void recordHeartbeat(DateTime at) {
    _lastHeartbeatAt = at;
    _lastFrameAt = at;
    _isReconnecting = false;
  }

  void markReconnecting() {
    _isReconnecting = true;
  }

  SseConnectionHealth healthAt(DateTime now) {
    if (_isReconnecting) {
      return SseConnectionHealth.reconnecting;
    }
    final reference = _lastHeartbeatAt ?? _lastFrameAt;
    if (reference == null) {
      return SseConnectionHealth.stale;
    }
    if (now.difference(reference) > heartbeatTimeout) {
      return SseConnectionHealth.stale;
    }
    return SseConnectionHealth.connected;
  }
}
