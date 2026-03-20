import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../launch/launch_state_model.dart';

LaunchConnectionStatus mapLaunchConnectionStatus(ServerProbeReport? report) {
  if (report == null) {
    return LaunchConnectionStatus.unknown;
  }

  return switch (report.classification) {
    ConnectionProbeClassification.ready => LaunchConnectionStatus.ready,
    ConnectionProbeClassification.authFailure =>
      LaunchConnectionStatus.signInRequired,
    ConnectionProbeClassification.connectivityFailure =>
      LaunchConnectionStatus.offline,
    ConnectionProbeClassification.specFetchFailure ||
    ConnectionProbeClassification.unsupportedCapabilities =>
      LaunchConnectionStatus.incompatible,
  };
}
