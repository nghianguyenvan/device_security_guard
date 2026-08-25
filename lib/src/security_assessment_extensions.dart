import 'models.dart';

/// Cách đọc nhanh kết quả của từng hạng mục kiểm tra.
///
/// Getter rủi ro chỉ trả về `true` khi hạng mục tương ứng có trạng thái
/// [CheckStatus.detected]. Trạng thái [CheckStatus.notDetected],
/// [CheckStatus.inconclusive] hoặc hạng mục không tồn tại đều trả về `false`.
extension SecurityAssessmentChecks on SecurityAssessment {
  /// `true` khi package phát hiện dấu hiệu thiết bị Android đã root.
  bool get isRooted =>
      signals[SecuritySignal.root]?.status == CheckStatus.detected;

  /// `true` khi package phát hiện dấu hiệu thiết bị iOS đã jailbreak.
  bool get isJailbroken =>
      signals[SecuritySignal.jailbreak]?.status == CheckStatus.detected;

  /// `true` khi package phát hiện debugger đang gắn hoặc chờ kết nối.
  bool get isDebuggerAttached =>
      signals[SecuritySignal.debugger]?.status == CheckStatus.detected;

  /// `true` khi package phát hiện ứng dụng đang chạy trên máy ảo.
  bool get isEmulator =>
      signals[SecuritySignal.emulator]?.status == CheckStatus.detected;

  /// `true` khi kiểm tra máy ảo hoàn tất và không phát hiện máy ảo.
  ///
  /// Kết quả `false` có thể là máy ảo đã được phát hiện hoặc hạng mục kiểm tra
  /// chưa thể kết luận. Getter này không chứng nhận thiết bị vật lý tuyệt đối.
  bool get isRealDevice =>
      signals[SecuritySignal.emulator]?.status == CheckStatus.notDetected;

  /// `true` khi package phát hiện Android Debug Bridge đang bật.
  bool get isAdbEnabled =>
      signals[SecuritySignal.adbEnabled]?.status == CheckStatus.detected;

  /// `true` khi package phát hiện công cụ hook hoặc mã được chèn lúc chạy.
  bool get isHookingDetected =>
      signals[SecuritySignal.hooking]?.status == CheckStatus.detected;

  /// `true` khi thông tin ký ứng dụng không khớp cấu hình tin cậy.
  bool get isRepackaged =>
      signals[SecuritySignal.repackaging]?.status == CheckStatus.detected;

  /// `true` khi package phát hiện bootloader Android đã mở khóa.
  bool get isBootloaderUnlocked =>
      signals[SecuritySignal.bootloaderUnlocked]?.status ==
      CheckStatus.detected;
}
