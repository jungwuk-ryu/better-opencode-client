import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/network/sse_connection_monitor.dart';

void main() {
  test('monitor becomes stale after heartbeat timeout', () {
    final monitor = SseConnectionMonitor(
      heartbeatTimeout: const Duration(seconds: 5),
    );
    final start = DateTime.utc(2026, 1, 1, 0, 0, 0);

    monitor.recordHeartbeat(start);

    expect(
      monitor.healthAt(start.add(const Duration(seconds: 3))),
      SseConnectionHealth.connected,
    );
    expect(
      monitor.healthAt(start.add(const Duration(seconds: 6))),
      SseConnectionHealth.stale,
    );
  });

  test('monitor uses later frames after the initial heartbeat', () {
    final monitor = SseConnectionMonitor(
      heartbeatTimeout: const Duration(seconds: 5),
    );
    final start = DateTime.utc(2026, 1, 1, 0, 0, 0);

    monitor.recordHeartbeat(start);
    monitor.recordFrame(start.add(const Duration(seconds: 4)));

    expect(
      monitor.healthAt(start.add(const Duration(seconds: 7))),
      SseConnectionHealth.connected,
    );
    expect(
      monitor.healthAt(start.add(const Duration(seconds: 10))),
      SseConnectionHealth.stale,
    );
  });

  test('monitor exposes reconnecting state', () {
    final monitor = SseConnectionMonitor(
      heartbeatTimeout: const Duration(seconds: 5),
    );

    monitor.markReconnecting();

    expect(
      monitor.healthAt(DateTime.utc(2026, 1, 1)),
      SseConnectionHealth.reconnecting,
    );
  });
}
