import 'package:flutter/services.dart';

import 'device_security_guard_platform_interface.dart';
import 'src/models.dart';
import 'src/security_options.dart';

/// Cài đặt [DeviceSecurityGuardPlatform] bằng method channel.
class MethodChannelDeviceSecurityGuard extends DeviceSecurityGuardPlatform {
  /// Method channel dùng để giao tiếp với nền tảng native.
  final methodChannel = const MethodChannel(
    'dev.vannghia/device_security_guard',
  );

  @override
  Future<SecurityAssessment> assessLocal(SecurityOptions options) async {
    final payload = await methodChannel
        .invokeMethod<Object?>('assess', <String, Object?>{
          'expectedAndroidCertificateSha256':
              options.expectedAndroidCertificateSha256.toList()..sort(),
          'expectedIosApplicationIdentifierPrefixes':
              options.expectedIosApplicationIdentifierPrefixes.toList()..sort(),
        });
    return _parseAssessment(payload);
  }

  SecurityAssessment _parseAssessment(Object? payload) {
    try {
      if (payload is! Map || payload['schemaVersion'] != 1) {
        throw const FormatException();
      }
      final platform = switch (payload['platform']) {
        'android' => SecurityPlatform.android,
        'ios' => SecurityPlatform.iOS,
        _ => throw const FormatException(),
      };
      final operatingSystemVersion = payload['operatingSystemVersion'];
      final assessedAtEpochMs = payload['assessedAtEpochMs'];
      final rawSignals = payload['signals'];
      if (operatingSystemVersion is! String ||
          assessedAtEpochMs is! int ||
          assessedAtEpochMs.abs() > 8640000000000000 ||
          rawSignals is! Map) {
        throw const FormatException();
      }

      final results = <SecuritySignal, SignalResult>{};
      for (final entry in rawSignals.entries) {
        final signal = _parseSignal(entry.key);
        final value = entry.value;
        if (value is! Map ||
            value['reasonCode'] is! String ||
            value['status'] is! String) {
          throw const FormatException();
        }
        results[signal] = SignalResult(
          signal: signal,
          status: _parseStatus(value['status'] as String),
          reasonCode: value['reasonCode'] as String,
        );
      }

      final requiredSignals = platform == SecurityPlatform.android
          ? DeviceSecurityGuardPlatform.androidSignals
          : DeviceSecurityGuardPlatform.iosSignals;
      results.removeWhere((signal, _) => !requiredSignals.contains(signal));
      for (final signal in requiredSignals) {
        results.putIfAbsent(
          signal,
          () => SignalResult(
            signal: signal,
            status: CheckStatus.inconclusive,
            reasonCode: 'missing_signal',
          ),
        );
      }

      return SecurityAssessment(
        platform: platform,
        operatingSystemVersion: operatingSystemVersion,
        assessedAt: DateTime.fromMillisecondsSinceEpoch(
          assessedAtEpochMs,
          isUtc: true,
        ),
        signals: results,
      );
    } on FormatException {
      throw PlatformException(
        code: 'invalid_payload',
        message: 'Native assessment payload is invalid.',
      );
    }
  }

  SecuritySignal _parseSignal(Object? value) => switch (value) {
    'debugger' => SecuritySignal.debugger,
    'emulator' => SecuritySignal.emulator,
    'adbEnabled' => SecuritySignal.adbEnabled,
    'hooking' => SecuritySignal.hooking,
    'repackaging' => SecuritySignal.repackaging,
    'root' => SecuritySignal.root,
    'jailbreak' => SecuritySignal.jailbreak,
    'bootloaderUnlocked' => SecuritySignal.bootloaderUnlocked,
    _ => throw const FormatException(),
  };

  CheckStatus _parseStatus(String value) => switch (value) {
    'detected' => CheckStatus.detected,
    'notDetected' => CheckStatus.notDetected,
    'inconclusive' => CheckStatus.inconclusive,
    _ => throw const FormatException(),
  };
}
