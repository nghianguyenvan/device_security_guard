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

void main() {
  late DeviceSecurityGuardPlatform initialPlatform;

  setUp(() {
    initialPlatform = DeviceSecurityGuardPlatform.instance;
  });

  tearDown(() {
    DeviceSecurityGuardPlatform.instance = initialPlatform;
  });

  test('each assessment delegates to the local platform', () async {
    final platform = FakePlatform(SecurityPlatform.android);
    DeviceSecurityGuardPlatform.instance = platform;

    final first = await DeviceSecurityGuard.assess();
    final second = await DeviceSecurityGuard.assess();

    expect(first.platform, SecurityPlatform.android);
    expect(second.platform, SecurityPlatform.android);
    expect(platform.localAssessmentCalls, 2);
  });

  test('invalid identity fails before invoking native assessment', () async {
    final platform = FakePlatform(SecurityPlatform.android);
    DeviceSecurityGuardPlatform.instance = platform;

    await expectLater(
      DeviceSecurityGuard.assess(
        options: SecurityOptions(expectedAndroidCertificateSha256: {'invalid'}),
      ),
      throwsArgumentError,
    );
    expect(platform.localAssessmentCalls, 0);
  });
}
