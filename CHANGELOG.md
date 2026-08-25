## 0.1.3 - 2026-08-25

- Thêm extension trên `SecurityAssessment` để đọc nhanh kết quả qua `isRooted`, `isJailbroken`, `isDebuggerAttached`, `isEmulator`, `isRealDevice` và các getter tương ứng với toàn bộ hạng mục kiểm tra.
- Viết lại hướng dẫn tích hợp theo nhu cầu sử dụng: getter đọc nhanh, kết quả ba trạng thái đầy đủ, xử lý toàn bộ hạng mục và policy tổng hợp.

## 0.1.2 - 2026-08-24

- Viết lại README bằng ngôn ngữ dành cho người tích hợp, giải thích rõ từng trạng thái và hướng dẫn cách sử dụng package.
- Chuyển toàn bộ liên kết tài liệu sang URL tuyệt đối để hoạt động ổn định trên pub.dev.

## 0.1.1 - 2026-08-24

- Tăng cường Android detector với `TracerPid`, marker hook/root hiện đại, phân loại emulator và bootloader thận trọng hơn.
- Không đọc signing certificate Android khi allowlist chưa được cấu hình; kết quả vẫn là `inconclusive`.
- Giữ lỗi probe ghi ngoài sandbox iOS ở trạng thái `inconclusive` thay vì xem như thiết bị sạch.
- Mở rộng unit test và integration contract cho toàn bộ tín hiệu Android/iOS.
- Rút gọn README theo đúng phạm vi detector và chuẩn bị metadata phát hành pub.dev.

## 0.1.0

- Thêm phát hiện debugger, emulator/simulator, ADB, hook, repackage, root/jailbreak và bootloader mở khóa trên nền tảng áp dụng.
- Thêm model kết quả ba trạng thái và `Circular77Policy` với tùy chọn `failClosed`.
- API v1 chỉ cung cấp detector cục bộ và policy helper, không yêu cầu dịch vụ hoặc backend ngoài.
- Hỗ trợ Android API 23–36 và iOS 15 trở lên.
- Bổ sung tài liệu tích hợp production, ma trận bao phủ kỹ thuật và hướng dẫn phát hành pub.dev.
