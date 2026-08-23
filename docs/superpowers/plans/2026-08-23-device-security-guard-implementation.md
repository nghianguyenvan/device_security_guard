# Kế hoạch triển khai device_security_guard v1

## Kiến trúc

Kotlin và Swift thu thập detector native trên worker queue rồi trả payload versioned qua `MethodChannel`. Dart chuẩn hóa payload thành model ba trạng thái và đánh giá `Circular77Policy`.

## Thành phần

1. Model, options, parser channel và policy helper trong `lib/`.
2. Android detector cho API 23–36 trong `android/`.
3. iOS detector với deployment target 15.0 trong `ios/`.
4. Unit test Dart, Kotlin, Swift và widget test example.
5. Example kiểm tra lúc mở app, resume và trước giao dịch.
6. Tài liệu tích hợp, ma trận bao phủ và giới hạn bảo mật.

## Điều kiện hoàn thành

- Không có SDK dịch vụ ngoài hoặc lời gọi mạng trong package.
- Tất cả tín hiệu áp dụng được trả về; lỗi/thiếu dữ liệu không bị coi là an toàn.
- Public API chỉ gồm local assessment và policy helper.
- Flutter analyze/test, Android unit/lint, iOS test/build, tài liệu và publish dry-run đều thành công.
