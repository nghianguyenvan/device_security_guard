# Ví dụ device_security_guard

Ứng dụng minh họa chạy local assessment khi mở app, khi app resume và trước giao dịch; sau đó hiển thị từng tín hiệu cùng khuyến nghị của `Circular77Policy`.

Chạy bằng:

```bash
flutter run
```

Để kiểm tra repackage chính xác trong ứng dụng thực, hãy cấu hình SHA-256 certificate Android hoặc App ID Prefix iOS qua `SecurityOptions`. Ứng dụng chủ phải tự dừng thao tác được bảo vệ khi policy trả về `block`.
