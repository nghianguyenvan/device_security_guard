import 'dart:collection';

/// Dấu hiệu bảo mật được package kiểm tra.
enum SecuritySignal {
  debugger,
  emulator,
  adbEnabled,
  hooking,
  repackaging,
  root,
  jailbreak,
  bootloaderUnlocked,
}

/// Trạng thái của một kiểm tra bảo mật cục bộ.
enum CheckStatus { detected, notDetected, inconclusive }

/// Nền tảng được plugin hỗ trợ.
enum SecurityPlatform { android, iOS }

/// Hành động được policy khuyến nghị.
enum RecommendedAction { allow, block, indeterminate }

/// Kết quả kiểm tra một [signal].
final class SignalResult {
  const SignalResult({
    required this.signal,
    required this.status,
    required this.reasonCode,
  });

  final SecuritySignal signal;
  final CheckStatus status;
  final String reasonCode;
}

/// Kết quả đánh giá ứng dụng và môi trường thiết bị tại một thời điểm.
final class SecurityAssessment {
  SecurityAssessment({
    required this.platform,
    required this.operatingSystemVersion,
    required this.assessedAt,
    required Map<SecuritySignal, SignalResult> signals,
  }) : signals = UnmodifiableMapView(Map.of(signals));

  final SecurityPlatform platform;
  final String operatingSystemVersion;
  final DateTime assessedAt;
  final Map<SecuritySignal, SignalResult> signals;
}

/// Kết quả áp dụng policy lên một [SecurityAssessment].
final class PolicyDecision {
  PolicyDecision({required this.action, required List<String> reasonCodes})
    : reasonCodes = List.unmodifiable(reasonCodes);

  final RecommendedAction action;
  final List<String> reasonCodes;
}
