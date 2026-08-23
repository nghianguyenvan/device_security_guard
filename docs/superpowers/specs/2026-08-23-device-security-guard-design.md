# Thiết kế device_security_guard v1

## Phạm vi

Package chỉ thu thập tín hiệu bảo mật cục bộ và đưa ra khuyến nghị policy. Package không tự đóng ứng dụng, không gọi mạng và không thay ứng dụng chủ chứng nhận tuân thủ.

## API

- `DeviceSecurityGuard.assess(options:)` trả `SecurityAssessment`.
- `SecurityOptions` nhận SHA-256 certificate Android và App ID Prefix iOS mong đợi.
- Mỗi `SignalResult` có trạng thái `detected`, `notDetected` hoặc `inconclusive` cùng `reasonCode`.
- `Circular77Policy.evaluate` trả `allow`, `block` hoặc `indeterminate`; `failClosed` đổi `indeterminate` thành `block`.

## Detector

- Android: debugger, emulator, ADB, hook/chèn mã, repackage, root và bootloader mở khóa.
- iOS: debugger, simulator, hook/chèn mã, repackage và jailbreak.
- Detector không áp dụng cho nền tảng không xuất hiện trong kết quả.
- Thiếu cấu hình hoặc không đủ bằng chứng trả `inconclusive`, không coi là an toàn.

## Tích hợp

Ứng dụng chủ nên kiểm tra lúc khởi động, khi trở về foreground và trước mỗi thao tác nhạy cảm. Ứng dụng chủ chịu trách nhiệm thực thi quyết định policy tại đúng điểm bảo vệ.

## Giới hạn

Mọi detector phía client đều là best-effort và có thể bị bypass. Nghiệp vụ rủi ro cao cần thêm kiểm soát giao dịch, phiên và giám sát ở phía máy chủ của ứng dụng chủ.
