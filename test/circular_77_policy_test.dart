import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityAssessment assessment({
  required Map<SecuritySignal, SignalResult> signals,
  List<AttestationAssessment> attestations = const [],
}) => SecurityAssessment(
  platform: SecurityPlatform.android,
  operatingSystemVersion: '16',
  assessedAt: DateTime.utc(2026, 8, 23),
  signals: signals,
  attestations: attestations,
);

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
          status: AttestationStatus.trusted,
          reasonCode: 'backend_verified',
        ),
      ],
    );

    expect(Circular77Policy.evaluate(result).action, RecommendedAction.allow);
  });
}
