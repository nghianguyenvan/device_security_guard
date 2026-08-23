import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_security_guard_method_channel.dart';

abstract class DeviceSecurityGuardPlatform extends PlatformInterface {
  /// Constructs a DeviceSecurityGuardPlatform.
  DeviceSecurityGuardPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceSecurityGuardPlatform _instance =
      MethodChannelDeviceSecurityGuard();

  /// The default instance of [DeviceSecurityGuardPlatform] to use.
  ///
  /// Defaults to [MethodChannelDeviceSecurityGuard].
  static DeviceSecurityGuardPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DeviceSecurityGuardPlatform] when
  /// they register themselves.
  static set instance(DeviceSecurityGuardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
