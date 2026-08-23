import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_security_guard_platform_interface.dart';

/// An implementation of [DeviceSecurityGuardPlatform] that uses method channels.
class MethodChannelDeviceSecurityGuard extends DeviceSecurityGuardPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('device_security_guard');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
