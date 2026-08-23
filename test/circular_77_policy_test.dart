import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityAssessment assessment({
  required Map<SecuritySignal, SignalResult> signals,
  List<AttestationAssessment> attestations = const [],
  Set<AttestationProvider> requestedAttestations = const {},
}) => SecurityAssessment(
  platform: SecurityPlatform.android,
  operatingSystemVersion: '16',
  assessedAt: DateTime.utc(2026, 8, 23),
  signals: signals,
  attestations: attestations,
  requestedAttestations: requestedAttestations,
);

Map<SecuritySignal, SignalResult> cleanAndroidSignals() => {
  for (final signal in {
    SecuritySignal.debugger,
    SecuritySignal.emulator,
    SecuritySignal.adbEnabled,
    SecuritySignal.hooking,
    SecuritySignal.repackaging,
    SecuritySignal.root,
    SecuritySignal.bootloaderUnlocked,
  })
    signal: SignalResult(
      signal: signal,
      status: CheckStatus.notDetected,
      reasonCode: 'not_detected',
    ),
};

void main() {
  test('detected signal recommends block', () {
    final result = assessment(
      signals: const {
        SecuritySignal.root: SignalResult(
          signal: SecuritySignal.root,
          status: CheckStatus.detected,
          reasonCode: 'root_artifact',
        ),
      },
    );

    expect(Circular77Policy.evaluate(result).action, RecommendedAction.block);
  });

  test('untrusted attestation recommends block', () {
    final result = assessment(
      signals: const {
        SecuritySignal.root: SignalResult(
          signal: SecuritySignal.root,
          status: CheckStatus.notDetected,
          reasonCode: 'no_root_indicator',
        ),
      },
      attestations: const [
        AttestationAssessment(
          provider: AttestationProvider.playIntegrity,
          status: AttestationStatus.untrusted,
          reasonCode: 'device_integrity_failed',
        ),
      ],
    );

    expect(Circular77Policy.evaluate(result).action, RecommendedAction.block);
  });

  test('inconclusive recommends indeterminate', () {
    final result = assessment(
      signals: const {
        SecuritySignal.repackaging: SignalResult(
          signal: SecuritySignal.repackaging,
          status: CheckStatus.inconclusive,
          reasonCode: 'expected_identity_missing',
        ),
      },
    );

    expect(
      Circular77Policy.evaluate(result).action,
      RecommendedAction.indeterminate,
    );
  });

  test('fail-closed converts indeterminate into block', () {
    final result = assessment(
      signals: const {
        SecuritySignal.repackaging: SignalResult(
          signal: SecuritySignal.repackaging,
          status: CheckStatus.inconclusive,
          reasonCode: 'expected_identity_missing',
        ),
      },
    );

    expect(
      Circular77Policy.evaluate(result, failClosed: true).action,
      RecommendedAction.block,
    );
  });

  test('clean signals and trusted attestations recommend allow', () {
    final result = assessment(
      signals: cleanAndroidSignals(),
      attestations: const [
        AttestationAssessment(
          provider: AttestationProvider.playIntegrity,
          status: AttestationStatus.trusted,
          reasonCode: 'backend_verified',
        ),
      ],
      requestedAttestations: const {AttestationProvider.playIntegrity},
    );

    expect(Circular77Policy.evaluate(result).action, RecommendedAction.allow);
  });

  test('missing platform signal is indeterminate', () {
    final signals = cleanAndroidSignals()..remove(SecuritySignal.hooking);

    final decision = Circular77Policy.evaluate(assessment(signals: signals));

    expect(decision.action, RecommendedAction.indeterminate);
    expect(decision.reasonCodes, contains('missing_signal'));
  });

  test('requested attestation without a result is indeterminate', () {
    final result = assessment(
      signals: cleanAndroidSignals(),
      requestedAttestations: const {AttestationProvider.playIntegrity},
    );

    final decision = Circular77Policy.evaluate(result);

    expect(decision.action, RecommendedAction.indeterminate);
    expect(decision.reasonCodes, contains('missing_attestation'));
  });
}
