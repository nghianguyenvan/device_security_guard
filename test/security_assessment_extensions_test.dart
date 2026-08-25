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
  test('isRooted is true only when root is detected', () {
    expect(
      assessmentWith({SecuritySignal.root: CheckStatus.detected}).isRooted,
      isTrue,
    );
    expect(
      assessmentWith({SecuritySignal.root: CheckStatus.notDetected}).isRooted,
      isFalse,
    );
    expect(
      assessmentWith({SecuritySignal.root: CheckStatus.inconclusive}).isRooted,
      isFalse,
    );
    expect(assessmentWith({}).isRooted, isFalse);
  });

  test('risk getters read only their matching detected signal', () {
    final cases =
        <
          ({
            SecuritySignal signal,
            bool Function(SecurityAssessment assessment) read,
          })
        >[
          (
            signal: SecuritySignal.jailbreak,
            read: (assessment) => assessment.isJailbroken,
          ),
          (
            signal: SecuritySignal.debugger,
            read: (assessment) => assessment.isDebuggerAttached,
          ),
          (
            signal: SecuritySignal.emulator,
            read: (assessment) => assessment.isEmulator,
          ),
          (
            signal: SecuritySignal.adbEnabled,
            read: (assessment) => assessment.isAdbEnabled,
          ),
          (
            signal: SecuritySignal.hooking,
            read: (assessment) => assessment.isHookingDetected,
          ),
          (
            signal: SecuritySignal.repackaging,
            read: (assessment) => assessment.isRepackaged,
          ),
          (
            signal: SecuritySignal.bootloaderUnlocked,
            read: (assessment) => assessment.isBootloaderUnlocked,
          ),
        ];

    for (final testCase in cases) {
      expect(
        testCase.read(assessmentWith({testCase.signal: CheckStatus.detected})),
        isTrue,
        reason: '${testCase.signal.name} detected',
      );
      expect(
        testCase.read(
          assessmentWith({testCase.signal: CheckStatus.notDetected}),
        ),
        isFalse,
        reason: '${testCase.signal.name} not detected',
      );
      expect(
        testCase.read(
          assessmentWith({testCase.signal: CheckStatus.inconclusive}),
        ),
        isFalse,
        reason: '${testCase.signal.name} inconclusive',
      );
      expect(
        testCase.read(assessmentWith({})),
        isFalse,
        reason: '${testCase.signal.name} missing',
      );
    }
  });

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
