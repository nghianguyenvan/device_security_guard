import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_security_guard_method_channel.dart';
import 'src/models.dart';
import 'src/required_signals.dart';
import 'src/security_options.dart';

/// Hợp đồng platform implementation của `device_security_guard`.
abstract class DeviceSecurityGuardPlatform extends PlatformInterface {
  /// Khởi tạo platform interface.
  DeviceSecurityGuardPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceSecurityGuardPlatform _instance =
      MethodChannelDeviceSecurityGuard();

  /// Toàn bộ tín hiệu bắt buộc trong payload Android.
  static const androidSignals = androidRequiredSignals;

  /// Toàn bộ tín hiệu bắt buộc trong payload iOS.
  static const iosSignals = iosRequiredSignals;

  /// Instance [DeviceSecurityGuardPlatform] đang được sử dụng.
  ///
  /// Mặc định là [MethodChannelDeviceSecurityGuard].
  static DeviceSecurityGuardPlatform get instance => _instance;

  /// Cho phép implementation của nền tảng đăng ký instance riêng.
  static set instance(DeviceSecurityGuardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Chạy các detector cục bộ của nền tảng.
  Future<SecurityAssessment> assessLocal(SecurityOptions options);
}
