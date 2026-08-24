# Ví dụ tích hợp

Ứng dụng minh họa chạy assessment cục bộ tại ba checkpoint:

- sau khi mở app;
- khi app trở lại foreground;
- ngay trước giao dịch.

Kết quả từng tín hiệu và khuyến nghị của `Circular77Policy` được hiển thị trên màn hình.

Chạy bằng:

```bash
flutter run
```

Để kiểm tra repackage chính xác trong ứng dụng thực, hãy cấu hình SHA-256 certificate Android hoặc App ID Prefix iOS qua `SecurityOptions`. Ứng dụng chủ phải tự dừng thao tác được bảo vệ khi policy trả về `block`.

Example cố ý không cấu hình signing identity thật; vì vậy `repackaging` có thể là `inconclusive`. Không sao chép cấu hình placeholder vào production.
