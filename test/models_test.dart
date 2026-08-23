import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assessment protects its signal results from source mutation', () {
    final source = <SecuritySignal, SignalResult>{};
    final assessment = SecurityAssessment(
      platform: SecurityPlatform.iOS,
      operatingSystemVersion: '26.5',
      assessedAt: DateTime.utc(2026),
      signals: source,
    );

    source[SecuritySignal.jailbreak] = const SignalResult(
      signal: SecuritySignal.jailbreak,
      status: CheckStatus.detected,
      reasonCode: 'jailbreak_artifact',
    );

    expect(assessment.signals, isEmpty);
  });
}
