import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:device_security_guard/device_security_guard_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDeviceSecurityGuard();
  const channel = MethodChannel('dev.vannghia/device_security_guard');

  const partialPayload = <String, Object?>{
    'schemaVersion': 1,
    'platform': 'android',
    'operatingSystemVersion': '16',
    'assessedAtEpochMs': 1787443200000,
    'signals': <String, Object?>{
      'debugger': <String, Object?>{
        'status': 'notDetected',
        'reasonCode': 'debugger_not_attached',
      },
    },
  };

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return partialPayload;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('assess sends expected identity configuration', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return partialPayload;
        });

    await platform.assessLocal(
      const SecurityOptions(
        expectedAndroidCertificateSha256: {'AABB'},
        expectedIosTeamIdentifiers: {'TEAM123'},
      ),
    );

    expect(received?.method, 'assess');
    expect(received?.arguments, {
      'expectedAndroidCertificateSha256': ['AABB'],
      'expectedIosTeamIdentifiers': ['TEAM123'],
    });
  });

  test('missing required signals become inconclusive', () async {
    final result = await platform.assessLocal(const SecurityOptions());

    expect(result.signals, hasLength(7));
    expect(
      result.signals[SecuritySignal.debugger]?.status,
      CheckStatus.notDetected,
    );
    expect(
      result.signals[SecuritySignal.root]?.status,
      CheckStatus.inconclusive,
    );
    expect(result.signals[SecuritySignal.root]?.reasonCode, 'missing_signal');
    expect(result.signals.containsKey(SecuritySignal.jailbreak), isFalse);
  });

  test('invalid schema is rejected', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return {...partialPayload, 'schemaVersion': 2};
        });

    expect(
      platform.assessLocal(const SecurityOptions()),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
  });
}
