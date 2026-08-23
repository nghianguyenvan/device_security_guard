library;

import 'device_security_guard_platform_interface.dart';
import 'src/models.dart';
import 'src/security_options.dart';

export 'src/circular_77_policy.dart';
export 'src/models.dart';
export 'src/security_options.dart';

/// Điểm truy cập cho đánh giá bảo mật cục bộ trên thiết bị.
abstract final class DeviceSecurityGuard {
  static Future<SecurityAssessment> assess({SecurityOptions? options}) async {
    options ??= SecurityOptions();
    options.validate();
    return DeviceSecurityGuardPlatform.instance.assessLocal(options);
  }
}
