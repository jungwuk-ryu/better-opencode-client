import 'dart:io';

import 'package:opencode_mobile_remote/src/core/network/sse_connection_monitor.dart';

void main() {
  final monitor = SseConnectionMonitor(
    heartbeatTimeout: const Duration(seconds: 5),
  );
  final start = DateTime.utc(2026, 1, 1, 0, 0, 0);

  monitor.recordHeartbeat(start);
  final connected = monitor.healthAt(start.add(const Duration(seconds: 1)));
  final stale = monitor.healthAt(start.add(const Duration(seconds: 7)));
  monitor.markReconnecting();
  final reconnecting = monitor.healthAt(start.add(const Duration(seconds: 8)));

  stdout.writeln(
    'connected=${connected.name},stale=${stale.name},reconnecting=${reconnecting.name}',
  );
}
