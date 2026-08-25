/// Phát hiện tín hiệu bảo mật cục bộ trên Android/iOS và đánh giá policy.
library;

import 'device_security_guard_platform_interface.dart';
import 'src/models.dart';
import 'src/security_options.dart';

export 'src/circular_77_policy.dart';
export 'src/models.dart';
export 'src/security_assessment_extensions.dart';
export 'src/security_options.dart';

/// Điểm truy cập cho đánh giá bảo mật cục bộ trên thiết bị.
abstract final class DeviceSecurityGuard {
  /// Chạy toàn bộ detector áp dụng cho nền tảng hiện tại.
  ///
  /// [options] chứa danh tính ký mong đợi để kiểm tra dấu hiệu đóng gói lại.
  /// Hàm ném [ArgumentError] nếu cấu hình danh tính không hợp lệ và có thể
  /// chuyển tiếp lỗi nền tảng nếu native plugin không hoàn tất được assessment.
  static Future<SecurityAssessment> assess({SecurityOptions? options}) async {
    options ??= SecurityOptions();
    options.validate();
    return DeviceSecurityGuardPlatform.instance.assessLocal(options);
  }
}
