import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_security_guard_method_channel.dart';
import 'src/attestation.dart';
import 'src/models.dart';
import 'src/security_options.dart';

abstract class DeviceSecurityGuardPlatform extends PlatformInterface
    implements AttestationClient {
  /// Khởi tạo platform interface.
  DeviceSecurityGuardPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceSecurityGuardPlatform _instance =
      MethodChannelDeviceSecurityGuard();

  static const androidSignals = {
    SecuritySignal.debugger,
    SecuritySignal.emulator,
    SecuritySignal.adbEnabled,
    SecuritySignal.hooking,
    SecuritySignal.repackaging,
    SecuritySignal.root,
    SecuritySignal.bootloaderUnlocked,
  };

  static const iosSignals = {
    SecuritySignal.debugger,
    SecuritySignal.emulator,
    SecuritySignal.hooking,
    SecuritySignal.repackaging,
    SecuritySignal.jailbreak,
  };

  /// Instance [DeviceSecurityGuardPlatform] đang được sử dụng.
  ///
  /// Mặc định là [MethodChannelDeviceSecurityGuard].
  static DeviceSecurityGuardPlatform get instance => _instance;

  /// Cho phép implementation của nền tảng đăng ký instance riêng.
  static set instance(DeviceSecurityGuardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<SecurityAssessment> assessLocal(SecurityOptions options);

  @override
  Future<String> requestPlayIntegrityToken({
    required int cloudProjectNumber,
    required String requestHash,
  }) => Future.error(UnsupportedError('Play Integrity is not supported.'));

  @override
  Future<bool> isAppAttestSupported() => Future.value(false);

  @override
  Future<String> generateAppAttestKey() =>
      Future.error(UnsupportedError('App Attest is not supported.'));

  @override
  Future<Uint8List> attestAppAttestKey({
    required String keyId,
    required Uint8List clientDataHash,
  }) => Future.error(UnsupportedError('App Attest is not supported.'));

  @override
  Future<Uint8List> generateAppAttestAssertion({
    required String keyId,
    required Uint8List clientDataHash,
  }) => Future.error(UnsupportedError('App Attest is not supported.'));
}
