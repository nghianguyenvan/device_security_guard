import 'package:flutter_test/flutter_test.dart';
import 'package:device_security_guard/device_security_guard.dart';
import 'package:device_security_guard/device_security_guard_platform_interface.dart';
import 'package:device_security_guard/device_security_guard_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceSecurityGuardPlatform
    with MockPlatformInterfaceMixin
    implements DeviceSecurityGuardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DeviceSecurityGuardPlatform initialPlatform = DeviceSecurityGuardPlatform.instance;

  test('$MethodChannelDeviceSecurityGuard is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceSecurityGuard>());
  });

  test('getPlatformVersion', () async {
    DeviceSecurityGuard deviceSecurityGuardPlugin = DeviceSecurityGuard();
    MockDeviceSecurityGuardPlatform fakePlatform = MockDeviceSecurityGuardPlatform();
    DeviceSecurityGuardPlatform.instance = fakePlatform;

    expect(await deviceSecurityGuardPlugin.getPlatformVersion(), '42');
  });
}
