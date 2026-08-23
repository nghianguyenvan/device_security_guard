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

/// Nhà cung cấp attestation của nền tảng.
enum AttestationProvider { playIntegrity, appAttest }

/// Kết quả attestation do backend ứng dụng chủ xác minh.
enum AttestationStatus { trusted, untrusted, inconclusive }

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

/// Kết quả chuẩn hóa do attestation adapter của ứng dụng chủ trả về.
final class AttestationAssessment {
  const AttestationAssessment({
    required this.provider,
    required this.status,
    required this.reasonCode,
  });

  final AttestationProvider provider;
  final AttestationStatus status;
  final String reasonCode;
}

/// Kết quả đánh giá ứng dụng và môi trường thiết bị tại một thời điểm.
final class SecurityAssessment {
  SecurityAssessment({
    required this.platform,
    required this.operatingSystemVersion,
    required this.assessedAt,
    required Map<SecuritySignal, SignalResult> signals,
    List<AttestationAssessment> attestations = const [],
    Set<AttestationProvider> requestedAttestations = const {},
  }) : signals = UnmodifiableMapView(Map.of(signals)),
       attestations = List.unmodifiable(attestations),
       requestedAttestations = Set.unmodifiable(requestedAttestations);

  final SecurityPlatform platform;
  final String operatingSystemVersion;
  final DateTime assessedAt;
  final Map<SecuritySignal, SignalResult> signals;
  final List<AttestationAssessment> attestations;
  final Set<AttestationProvider> requestedAttestations;

  SecurityAssessment withAttestations(
    List<AttestationAssessment> values, {
    Set<AttestationProvider>? requestedAttestations,
  }) => SecurityAssessment(
    platform: platform,
    operatingSystemVersion: operatingSystemVersion,
    assessedAt: assessedAt,
    signals: signals,
    attestations: values,
    requestedAttestations: requestedAttestations ?? this.requestedAttestations,
  );
}

/// Kết quả áp dụng policy lên một [SecurityAssessment].
final class PolicyDecision {
  PolicyDecision({required this.action, required List<String> reasonCodes})
    : reasonCodes = List.unmodifiable(reasonCodes);

  final RecommendedAction action;
  final List<String> reasonCodes;
}
