## 0.1.1 - 2026-08-24

- Tăng cường Android detector với `TracerPid`, marker hook/root hiện đại, phân loại emulator và bootloader thận trọng hơn.
- Không đọc signing certificate Android khi allowlist chưa được cấu hình; kết quả vẫn là `inconclusive`.
- Giữ lỗi probe ghi ngoài sandbox iOS ở trạng thái `inconclusive` thay vì xem như thiết bị sạch.
- Mở rộng unit test và integration contract cho toàn bộ tín hiệu Android/iOS.
- Viết lại README bằng ngôn ngữ dành cho người tích hợp, giải thích rõ từng trạng thái, hướng dẫn xử lý kết quả và sửa toàn bộ liên kết tài liệu cho pub.dev.

## 0.1.0

- Thêm phát hiện debugger, emulator/simulator, ADB, hook, repackage, root/jailbreak và bootloader mở khóa trên nền tảng áp dụng.
- Thêm model kết quả ba trạng thái và `Circular77Policy` với tùy chọn `failClosed`.
- API v1 chỉ cung cấp detector cục bộ và policy helper, không yêu cầu dịch vụ hoặc backend ngoài.
- Hỗ trợ Android API 23–36 và iOS 15 trở lên.
- Bổ sung tài liệu tích hợp production, ma trận bao phủ kỹ thuật và hướng dẫn phát hành pub.dev.
