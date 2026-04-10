import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';

void main() {
  ProbeSnapshot load(String path) {
    final source = File(path).readAsStringSync();
    return ProbeSnapshot.fromJsonString(source);
  }

  test('full capability probe enables advanced flags', () {
    final snapshot = load(
      'assets/fixtures/probes/full_capability_snapshot.json',
    );
    final registry = CapabilityRegistry.fromSnapshot(snapshot);

    expect(registry.canShareSession, isTrue);
    expect(registry.canForkSession, isTrue);
    expect(registry.canSummarizeSession, isTrue);
    expect(registry.hasExperimentalTools, isTrue);
    expect(registry.hasProviderOAuth, isTrue);
    expect(registry.hasMcpAuth, isTrue);
    expect(registry.hasTuiControl, isTrue);
  });

  test('legacy probe degrades without failing optional capabilities', () {
    final snapshot = load('assets/fixtures/probes/legacy_server_snapshot.json');
    final registry = CapabilityRegistry.fromSnapshot(snapshot);

    expect(registry.canForkSession, isTrue);
    expect(registry.canRevertSession, isTrue);
    expect(registry.hasExperimentalTools, isFalse);
    expect(registry.hasPermissions, isFalse);
    expect(registry.hasQuestions, isFalse);
  });

  test(
    'probe errors still keep unknown and unauthorized capabilities alive',
    () {
      final snapshot = load('assets/fixtures/probes/probe_error_snapshot.json');
      final registry = CapabilityRegistry.fromSnapshot(snapshot);

      expect(registry.canForkSession, isTrue);
      expect(registry.hasProviderOAuth, isTrue);
      expect(registry.hasQuestions, isTrue);
      expect(registry.hasExperimentalTools, isFalse);
    },
  );

  test('prompt_async support enables session compaction actions', () {
    final registry = CapabilityRegistry.fromSnapshot(
      ProbeSnapshot(
        name: 'prompt-async-only',
        version: '1.0.0',
        paths: const <String>{'/session/{sessionID}/prompt_async'},
        endpoints: const <String, ProbeEndpointResult>{},
      ),
    );

    expect(registry.canSummarizeSession, isTrue);
  });
}
