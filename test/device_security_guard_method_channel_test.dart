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
      SecurityOptions(
        expectedAndroidCertificateSha256: {'AABB'},
        expectedIosApplicationIdentifierPrefixes: {'ABCDE12345'},
      ),
    );

    expect(received?.method, 'assess');
    expect(received?.arguments, {
      'expectedAndroidCertificateSha256': ['AABB'],
      'expectedIosApplicationIdentifierPrefixes': ['ABCDE12345'],
    });
  });

  test('missing required signals become inconclusive', () async {
    final result = await platform.assessLocal(SecurityOptions());

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

  test('complete Android payload preserves every signal status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            ...partialPayload,
            'signals': <String, Object?>{
              'debugger': <String, Object?>{
                'status': 'detected',
                'reasonCode': 'debugger_attached',
              },
              'emulator': <String, Object?>{
                'status': 'notDetected',
                'reasonCode': 'emulator_not_detected',
              },
              'adbEnabled': <String, Object?>{
                'status': 'notDetected',
                'reasonCode': 'adb_disabled',
              },
              'hooking': <String, Object?>{
                'status': 'notDetected',
                'reasonCode': 'hook_framework_not_detected',
              },
              'repackaging': <String, Object?>{
                'status': 'inconclusive',
                'reasonCode': 'signing_certificate_unconfigured',
              },
              'root': <String, Object?>{
                'status': 'notDetected',
                'reasonCode': 'root_indicator_not_detected',
              },
              'bootloaderUnlocked': <String, Object?>{
                'status': 'notDetected',
                'reasonCode': 'bootloader_locked',
              },
            },
          };
        });

    final result = await platform.assessLocal(SecurityOptions());

    expect(result.signals, hasLength(7));
    expect(
      result.signals[SecuritySignal.debugger]?.status,
      CheckStatus.detected,
    );
    expect(
      result.signals[SecuritySignal.repackaging]?.status,
      CheckStatus.inconclusive,
    );
    expect(
      result.signals[SecuritySignal.bootloaderUnlocked]?.reasonCode,
      'bootloader_locked',
    );
  });

  test('invalid schema is rejected', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return {...partialPayload, 'schemaVersion': 2};
        });

    expect(
      platform.assessLocal(SecurityOptions()),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
  });

  test('invalid assessment timestamp is rejected consistently', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return {...partialPayload, 'assessedAtEpochMs': double.nan};
        });

    await expectLater(
      platform.assessLocal(SecurityOptions()),
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
