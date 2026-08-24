import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('trả assessment native của nền tảng', (_) async {
    final assessment = await DeviceSecurityGuard.assess();

    expect(assessment.signals, isNotEmpty);
    expect(
      assessment.platform,
      anyOf(SecurityPlatform.android, SecurityPlatform.iOS),
    );
    final expectedSignals = switch (assessment.platform) {
      SecurityPlatform.android => {
        SecuritySignal.debugger,
        SecuritySignal.emulator,
        SecuritySignal.adbEnabled,
        SecuritySignal.hooking,
        SecuritySignal.repackaging,
        SecuritySignal.root,
        SecuritySignal.bootloaderUnlocked,
      },
      SecurityPlatform.iOS => {
        SecuritySignal.debugger,
        SecuritySignal.emulator,
        SecuritySignal.hooking,
        SecuritySignal.repackaging,
        SecuritySignal.jailbreak,
      },
    };
    expect(assessment.signals.keys.toSet(), expectedSignals);
    if (assessment.platform == SecurityPlatform.android) {
      expect(
        assessment.signals[SecuritySignal.emulator]?.status,
        CheckStatus.detected,
      );
      expect(
        assessment.signals[SecuritySignal.adbEnabled]?.status,
        CheckStatus.detected,
      );
      expect(
        assessment.signals[SecuritySignal.repackaging]?.status,
        CheckStatus.inconclusive,
      );
    } else {
      expect(
        assessment.signals[SecuritySignal.emulator]?.status,
        CheckStatus.detected,
      );
      expect(
        assessment.signals[SecuritySignal.repackaging]?.status,
        CheckStatus.inconclusive,
      );
      expect(
        assessment.signals[SecuritySignal.jailbreak]?.status,
        CheckStatus.inconclusive,
      );
    }
  });
}
