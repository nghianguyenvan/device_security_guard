import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityAssessment assessmentWith(Map<SecuritySignal, CheckStatus> statuses) =>
    SecurityAssessment(
      platform: SecurityPlatform.android,
      operatingSystemVersion: '16',
      assessedAt: DateTime.utc(2026),
      signals: statuses.map(
        (signal, status) => MapEntry(
          signal,
          SignalResult(
            signal: signal,
            status: status,
            reasonCode: 'test_${signal.name}_${status.name}',
          ),
        ),
      ),
    );

void main() {
  test('isRealDevice is true only when emulator is not detected', () {
    expect(
      assessmentWith({
        SecuritySignal.emulator: CheckStatus.notDetected,
      }).isRealDevice,
      isTrue,
    );
    expect(
      assessmentWith({
        SecuritySignal.emulator: CheckStatus.detected,
      }).isRealDevice,
      isFalse,
    );
    expect(
      assessmentWith({
        SecuritySignal.emulator: CheckStatus.inconclusive,
      }).isRealDevice,
      isFalse,
    );
    expect(assessmentWith({}).isRealDevice, isFalse);
  });
}
