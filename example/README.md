# Ví dụ device_security_guard

Ứng dụng minh họa chạy local assessment với attestation mặc định tắt, hiển thị từng tín hiệu và khuyến nghị của `Circular77Policy`.

Chạy bằng:

```bash
flutter run
```

Để kiểm tra repackage chính xác trong ứng dụng thực, hãy cấu hình SHA-256 certificate Android hoặc App ID Prefix iOS qua `SecurityOptions`. Xem README ở thư mục gốc để tích hợp Play Integrity/App Attest với backend.
