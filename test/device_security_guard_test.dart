import 'package:device_security_guard/device_security_guard.dart';
import 'package:device_security_guard/device_security_guard_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakePlatform extends DeviceSecurityGuardPlatform {
  FakePlatform(this.platform);

  final SecurityPlatform platform;
  var localAssessmentCalls = 0;

  @override
  Future<SecurityAssessment> assessLocal(SecurityOptions options) async {
    localAssessmentCalls++;
    final signals = platform == SecurityPlatform.android
        ? DeviceSecurityGuardPlatform.androidSignals
        : DeviceSecurityGuardPlatform.iosSignals;
    return SecurityAssessment(
      platform: platform,
      operatingSystemVersion: 'test',
      assessedAt: DateTime.utc(2026),
      signals: {
        for (final signal in signals)
          signal: SignalResult(
            signal: signal,
            status: CheckStatus.notDetected,
            reasonCode: 'not_detected',
          ),
      },
    );
  }
}

final class RecordingAdapter implements AttestationAdapter {
  final calls = <AttestationProvider>[];

  @override
  Future<AttestationAssessment> assess(
    AttestationProvider provider,
    AttestationClient client,
  ) async {
    calls.add(provider);
    return AttestationAssessment(
      provider: provider,
      status: AttestationStatus.trusted,
      reasonCode: 'backend_verified',
    );
  }
}

final class ThrowingAdapter implements AttestationAdapter {
  @override
  Future<AttestationAssessment> assess(
    AttestationProvider provider,
    AttestationClient client,
  ) => throw StateError('network failed');
}

void main() {
  late DeviceSecurityGuardPlatform initialPlatform;

  setUp(() {
    initialPlatform = DeviceSecurityGuardPlatform.instance;
  });

  tearDown(() {
    DeviceSecurityGuardPlatform.instance = initialPlatform;
  });

  test('attestation is disabled by default', () async {
    final platform = FakePlatform(SecurityPlatform.android);
    DeviceSecurityGuardPlatform.instance = platform;

    final result = await DeviceSecurityGuard.assess();

    expect(result.attestations, isEmpty);
    expect(platform.localAssessmentCalls, 1);
  });

  test('Android invokes only enabled Play Integrity adapter', () async {
    final adapter = RecordingAdapter();
    DeviceSecurityGuardPlatform.instance = FakePlatform(
      SecurityPlatform.android,
    );

    final result = await DeviceSecurityGuard.assess(
      options: SecurityOptions(
        enablePlayIntegrity: true,
        enableAppAttest: true,
        attestationAdapter: adapter,
      ),
    );

    expect(adapter.calls, [AttestationProvider.playIntegrity]);
    expect(result.attestations.single.status, AttestationStatus.trusted);
  });

  test('iOS invokes only enabled App Attest adapter', () async {
    final adapter = RecordingAdapter();
    DeviceSecurityGuardPlatform.instance = FakePlatform(SecurityPlatform.iOS);

    await DeviceSecurityGuard.assess(
      options: SecurityOptions(
        enablePlayIntegrity: true,
        enableAppAttest: true,
        attestationAdapter: adapter,
      ),
    );

    expect(adapter.calls, [AttestationProvider.appAttest]);
  });

  test('adapter failure becomes inconclusive evidence', () async {
    DeviceSecurityGuardPlatform.instance = FakePlatform(
      SecurityPlatform.android,
    );

    final result = await DeviceSecurityGuard.assess(
      options: SecurityOptions(
        enablePlayIntegrity: true,
        attestationAdapter: ThrowingAdapter(),
      ),
    );

    expect(result.attestations.single.status, AttestationStatus.inconclusive);
    expect(result.attestations.single.reasonCode, 'attestation_error');
  });
}
