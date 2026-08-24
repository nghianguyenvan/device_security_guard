import 'dart:collection';

/// Dấu hiệu bảo mật được package kiểm tra.
enum SecuritySignal {
  /// Trình gỡ lỗi đang gắn hoặc đang chờ kết nối.
  debugger,

  /// Ứng dụng đang chạy trên emulator hoặc simulator.
  emulator,

  /// Android Debug Bridge đang được bật.
  adbEnabled,

  /// Có dấu hiệu framework hook hoặc thư viện chèn mã runtime.
  hooking,

  /// Danh tính ký của ứng dụng không khớp cấu hình mong đợi.
  repackaging,

  /// Có dấu hiệu thiết bị Android đã root.
  root,

  /// Có dấu hiệu thiết bị iOS đã jailbreak.
  jailbreak,

  /// Có dấu hiệu bootloader Android đã mở khóa.
  bootloaderUnlocked,
}

/// Trạng thái của một kiểm tra bảo mật cục bộ.
enum CheckStatus {
  /// Detector tìm thấy ít nhất một dấu hiệu rủi ro.
  detected,

  /// Detector đã chạy nhưng không tìm thấy dấu hiệu trong phạm vi kiểm tra.
  notDetected,

  /// Detector không có đủ dữ liệu để kết luận.
  inconclusive,
}

/// Nền tảng được plugin hỗ trợ.
enum SecurityPlatform {
  /// Android.
  android,

  /// iOS.
  iOS,
}

/// Hành động được policy khuyến nghị.
enum RecommendedAction {
  /// Cho phép tiếp tục theo các tín hiệu đã đánh giá.
  allow,

  /// Chặn luồng được bảo vệ.
  block,

  /// Chưa đủ bằng chứng; ứng dụng chủ phải quyết định cách xử lý.
  indeterminate,
}

/// Kết quả kiểm tra một [signal].
final class SignalResult {
  /// Tạo kết quả cho một [signal].
  const SignalResult({
    required this.signal,
    required this.status,
    required this.reasonCode,
  });

  /// Tín hiệu được kiểm tra.
  final SecuritySignal signal;

  /// Trạng thái chuẩn hóa của detector.
  final CheckStatus status;

  /// Mã máy đọc được để chẩn đoán nguyên nhân của [status].
  ///
  /// Mã này không dành để hiển thị trực tiếp cho người dùng cuối.
  final String reasonCode;
}

/// Kết quả đánh giá ứng dụng và môi trường thiết bị tại một thời điểm.
final class SecurityAssessment {
  /// Tạo một assessment bất biến.
  SecurityAssessment({
    required this.platform,
    required this.operatingSystemVersion,
    required this.assessedAt,
    required Map<SecuritySignal, SignalResult> signals,
  }) : signals = UnmodifiableMapView(Map.of(signals));

  /// Nền tảng đã thực hiện assessment.
  final SecurityPlatform platform;

  /// Phiên bản hệ điều hành do nền tảng báo cáo.
  final String operatingSystemVersion;

  /// Thời điểm native layer bắt đầu tạo kết quả, theo UTC.
  final DateTime assessedAt;

  /// Kết quả của các tín hiệu áp dụng cho [platform].
  final Map<SecuritySignal, SignalResult> signals;
}

/// Kết quả áp dụng policy lên một [SecurityAssessment].
final class PolicyDecision {
  /// Tạo quyết định policy bất biến.
  PolicyDecision({required this.action, required List<String> reasonCodes})
    : reasonCodes = List.unmodifiable(reasonCodes);

  /// Hành động được khuyến nghị.
  final RecommendedAction action;

  /// Các mã nguyên nhân dẫn đến [action].
  final List<String> reasonCodes;
}
