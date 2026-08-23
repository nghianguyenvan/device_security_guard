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

  test('requests a Play Integrity token with backend-bound data', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return 'encrypted-integrity-token';
        });

    final token = await platform.requestPlayIntegrityToken(
      cloudProjectNumber: 123456789,
      requestHash: 'base64url-request-hash',
    );

    expect(token, 'encrypted-integrity-token');
    expect(received?.method, 'requestPlayIntegrityToken');
    expect(received?.arguments, {
      'cloudProjectNumber': 123456789,
      'requestHash': 'base64url-request-hash',
    });
  });

  test('exposes App Attest primitives over the native channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isAppAttestSupported' => true,
            'generateAppAttestKey' => 'key-id',
            'attestAppAttestKey' => Uint8List.fromList([1, 2]),
            'generateAppAttestAssertion' => Uint8List.fromList([3, 4]),
            _ => null,
          };
        });

    expect(await platform.isAppAttestSupported(), isTrue);
    expect(await platform.generateAppAttestKey(), 'key-id');
    expect(
      await platform.attestAppAttestKey(
        keyId: 'key-id',
        clientDataHash: Uint8List.fromList([5, 6]),
      ),
      [1, 2],
    );
    expect(
      await platform.generateAppAttestAssertion(
        keyId: 'key-id',
        clientDataHash: Uint8List.fromList([7, 8]),
      ),
      [3, 4],
    );
    expect(calls.map((call) => call.method), [
      'isAppAttestSupported',
      'generateAppAttestKey',
      'attestAppAttestKey',
      'generateAppAttestAssertion',
    ]);
    expect(calls[2].arguments, {
      'keyId': 'key-id',
      'clientDataHash': Uint8List.fromList([5, 6]),
    });
  });
}
