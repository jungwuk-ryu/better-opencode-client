import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/opencode_server_probe.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/features/connection/connection_status_mapper.dart';
import 'package:better_opencode_client/src/features/launch/launch_state_model.dart';

void main() {
  test('maps ready probe reports to ready status', () {
    final status = mapLaunchConnectionStatus(
      _report(ConnectionProbeClassification.ready),
    );

    expect(status, LaunchConnectionStatus.ready);
  });

  test('maps auth failures to sign-in required status', () {
    final status = mapLaunchConnectionStatus(
      _report(ConnectionProbeClassification.authFailure),
    );

    expect(status, LaunchConnectionStatus.signInRequired);
  });

  test('maps connectivity failures to offline status', () {
    final status = mapLaunchConnectionStatus(
      _report(ConnectionProbeClassification.connectivityFailure),
    );

    expect(status, LaunchConnectionStatus.offline);
  });

  test('maps spec fetch failures to incompatible status', () {
    final status = mapLaunchConnectionStatus(
      _report(ConnectionProbeClassification.specFetchFailure),
    );

    expect(status, LaunchConnectionStatus.incompatible);
  });

  test('maps unsupported capabilities to incompatible status', () {
    final status = mapLaunchConnectionStatus(
      _report(ConnectionProbeClassification.unsupportedCapabilities),
    );

    expect(status, LaunchConnectionStatus.incompatible);
  });

  test('maps missing reports to unknown status', () {
    final status = mapLaunchConnectionStatus(null);

    expect(status, LaunchConnectionStatus.unknown);
  });
}

ServerProbeReport _report(ConnectionProbeClassification classification) {
  final snapshot = ProbeSnapshot(
    name: 'Demo server',
    version: '1.0.0',
    paths: <String>{'/global/health', '/doc', '/config'},
    endpoints: <String, ProbeEndpointResult>{},
  );

  return ServerProbeReport(
    snapshot: snapshot,
    capabilityRegistry: CapabilityRegistry.fromSnapshot(snapshot),
    classification: classification,
    summary: classification.name,
    checkedAt: DateTime(2026),
    missingCapabilities: const <String>[],
    discoveredExperimentalPaths: const <String>[],
    sseReady: classification == ConnectionProbeClassification.ready,
  );
}
