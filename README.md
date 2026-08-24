Flutter plugin thu thập các tín hiệu bảo mật cục bộ trên Android/iOS và chuyển chúng thành khuyến nghị policy rõ ràng cho ứng dụng có nghiệp vụ nhạy cảm.

> **Phạm vi v1:** package chỉ phát hiện và trả kết quả. Package không tự đóng ứng dụng, không gửi dữ liệu qua mạng và không chứng nhận ứng dụng đã tuân thủ pháp luật.

## Tính năng

| Tín hiệu | Android | iOS |
|---|:---:|:---:|
| Debugger | ✅ | ✅ |
| Emulator / simulator | ✅ | ✅ |
| ADB đang bật | ✅ | — |
| Hook / chèn mã runtime | ✅ | ✅ |
| Repackage / sai danh tính ký | ✅ | ✅, best-effort |
| Root | ✅ | — |
| Jailbreak | — | ✅ |
| Bootloader mở khóa | ✅ | — |

- API bất đồng bộ, không chặn UI thread trong lúc chạy detector native.
- Mỗi tín hiệu có ba trạng thái: `detected`, `notDetected`, `inconclusive`.
- `Circular77Policy` trả `allow`, `block` hoặc `indeterminate`.
- Không yêu cầu permission, dịch vụ ngoài hoặc backend.

## Yêu cầu nền tảng

| Nền tảng | Yêu cầu |
|---|---|
| Flutter | `>=3.44.0` |
| Dart | `>=3.12.0 <4.0.0` |
| Android | `minSdk 23`, `compileSdk 36` |
| iOS | deployment target `15.0` |

## Cài đặt

```bash
flutter pub add device_security_guard
```

Hoặc khai báo trong `pubspec.yaml`:

```yaml
dependencies:
  device_security_guard: ^0.1.0
```

## Bắt đầu nhanh

```dart
import 'package:device_security_guard/device_security_guard.dart';

final assessment = await DeviceSecurityGuard.assess(
  options: SecurityOptions(
    expectedAndroidCertificateSha256: {
      '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF',
    },
    expectedIosApplicationIdentifierPrefixes: {
      'ABCDE12345',
    },
  ),
);

final decision = Circular77Policy.evaluate(
  assessment,
  failClosed: true,
);

switch (decision.action) {
  case RecommendedAction.allow:
    // Tiếp tục nghiệp vụ.
    break;
  case RecommendedAction.block:
    // Dừng luồng được bảo vệ và thông báo cho người dùng.
    break;
  case RecommendedAction.indeterminate:
    // Chỉ xảy ra khi failClosed là false.
    // Áp dụng bước xác minh hoặc giới hạn rủi ro bổ sung.
    break;
}
```

`DeviceSecurityGuard.assess()` không có signing identity vẫn chạy, nhưng tín hiệu `repackaging` sẽ là `inconclusive`. Đây là thiết kế fail-safe: thiếu cấu hình không được coi là an toàn.

## Cấu hình production

### Android: SHA-256 certificate

Truyền SHA-256 của certificate thực sự ký APK cài trên thiết bị. Giá trị có thể viết liền hoặc phân cách từng byte bằng dấu `:`.

```bash
apksigner verify --print-certs app-release.apk
```

Nếu dùng Play App Signing, lấy SHA-256 của **App signing key certificate** trong Play Console, không lấy upload key. Chỉ thêm nhiều certificate khi đang chuyển đổi signing key có kiểm soát; không đưa certificate debug vào cấu hình production.

### iOS: App ID Prefix

Truyền App ID Prefix đứng trước dấu chấm trong Keychain access group, ví dụ `ABCDE12345` trong `ABCDE12345.com.example.bank`. App ID Prefix thường trùng Team ID nhưng có thể khác ở ứng dụng legacy; khi khác nhau phải dùng App ID Prefix.

Plugin tạo một Keychain item tạm thời để đọc access group do hệ thống cấp rồi xóa item đó. Nếu không đọc được danh tính, kết quả `repackaging` là `inconclusive`.

> Kiểm tra iOS này là best-effort, không phải chứng thực mật mã và không đảm bảo phát hiện mọi cách đóng gói lại.

## Tích hợp vào luồng ứng dụng

Không nên chỉ kiểm tra một lần rồi giữ kết quả cho toàn bộ phiên. Nên chạy assessment tại ba checkpoint:

1. Khi mở ứng dụng, trước khi hiển thị chức năng ngân hàng.
2. Khi ứng dụng trở lại foreground.
3. Ngay trước đăng nhập, thêm người thụ hưởng, chuyển tiền hoặc thao tác nhạy cảm khác.

Khi cần chặn, hãy điều hướng sang màn hình thông báo hoặc dừng riêng luồng nghiệp vụ. Không nên gọi `exit(0)` trên iOS; việc chủ động kết thúc process có thể tạo trải nghiệm xấu và không phải cách thực thi phù hợp trên nền tảng này.

Ứng dụng mẫu trong [`example/lib/main.dart`](example/lib/main.dart) minh họa kiểm tra khi mở app, resume và trước giao dịch.

## Kết quả và policy

### `CheckStatus`

| Trạng thái | Ý nghĩa |
|---|---|
| `detected` | Detector tìm thấy ít nhất một dấu hiệu rủi ro. |
| `notDetected` | Detector đã chạy nhưng không thấy indicator trong phạm vi kiểm tra. Không đồng nghĩa thiết bị chắc chắn an toàn. |
| `inconclusive` | Thiếu cấu hình, thiếu dữ liệu hoặc detector không thể kết luận. |

### `RecommendedAction`

| Hành động | Điều kiện mặc định |
|---|---|
| `block` | Có tín hiệu `detected`; hoặc có `inconclusive` khi `failClosed: true`. |
| `indeterminate` | Không có `detected` nhưng có ít nhất một `inconclusive`. |
| `allow` | Mọi tín hiệu bắt buộc của nền tảng đều là `notDetected`. |

`reasonCode` dành cho log kỹ thuật và telemetry nội bộ. Không hiển thị trực tiếp mã này cho người dùng và không xây business logic phụ thuộc vào nội dung thông báo tiếng Anh của `PlatformException`.

## Xử lý lỗi

- `ArgumentError`: certificate hoặc App ID Prefix sai định dạng.
- `PlatformException(code: 'invalid_payload')`: native layer trả payload không hợp lệ.
- Các lỗi platform khác: plugin chưa được đăng ký hoặc assessment native không hoàn tất.

Với nghiệp vụ fail-closed, ứng dụng chủ nên coi lỗi gọi API như một assessment chưa thể kết luận và dừng luồng nhạy cảm theo policy nội bộ.

## Liên hệ với Thông tư 77/2025/TT-NHNN

Khoản 2 Điều 5 Thông tư 77/2025/TT-NHNN sửa đổi khoản 4 Điều 8 Thông tư 50/2024/TT-NHNN, bổ sung yêu cầu Mobile Banking nhận diện các môi trường như debugger, thiết bị ảo, ADB, hook, repackage, root/jailbreak và bootloader mở khóa; khi phát hiện phải dừng/thoát và thông báo theo quy định.

Package cung cấp lớp **phát hiện** và **policy helper** cho các nhóm tín hiệu này. Ứng dụng chủ vẫn phải:

- thực thi việc dừng luồng hoặc chặn truy cập;
- hiển thị thông báo phù hợp;
- kiểm thử trên ma trận thiết bị thực tế;
- thực hiện đánh giá pháp lý và bảo mật độc lập.

Xem [ma trận bao phủ kỹ thuật](doc/circular-77-coverage-vi.md). Văn bản chính thức được ban hành ngày 31/12/2025 và có hiệu lực từ 01/03/2026: [Cổng Thông tin điện tử Chính phủ](https://vanban.chinhphu.vn/?docid=216580&pageid=27160).

## Giới hạn bảo mật

Detector phía client là một lớp defense-in-depth và có thể có false positive, false negative hoặc bị hook/bypass khi attacker kiểm soát đủ sâu ứng dụng hay hệ điều hành. Không dùng kết quả package làm bằng chứng tuyệt đối hoặc lớp bảo vệ duy nhất.

Với nghiệp vụ rủi ro cao, nên kết hợp kiểm soát giao dịch tại backend, quản trị phiên, giới hạn rủi ro, telemetry và kiểm thử xâm nhập. Package không thu thập dữ liệu, không gửi telemetry và không thực hiện request mạng.

## Tài liệu

- [Ma trận bao phủ Thông tư 77](doc/circular-77-coverage-vi.md)
- [Hướng dẫn phát hành lên pub.dev](doc/publishing-vi.md)
- [Chính sách bảo mật](SECURITY.md)
- [Lịch sử thay đổi](CHANGELOG.md)

Phát hành theo giấy phép [MIT](LICENSE).
