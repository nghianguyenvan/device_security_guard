Flutter plugin phát hiện các tín hiệu rủi ro cục bộ trên Android và iOS. Package trả về kết quả có cấu trúc; ứng dụng tích hợp tự quyết định việc chặn luồng, điều hướng hoặc thông báo.

Package không tự đóng ứng dụng, không yêu cầu permission, không gửi dữ liệu và không sử dụng backend.

## Tín hiệu hỗ trợ

| Tín hiệu | Android | iOS |
|---|:---:|:---:|
| Debugger | ✅ | ✅ |
| Emulator / simulator | ✅ | ✅ |
| ADB đang bật | ✅ | — |
| Hook / thư viện chèn runtime | ✅ | ✅ |
| Repackaging / sai danh tính ký | ✅ | ✅, best-effort |
| Root | ✅ | — |
| Jailbreak | — | ✅ |
| Bootloader mở khóa | ✅ | — |

Mỗi tín hiệu có một trong ba trạng thái: `detected`, `notDetected` hoặc `inconclusive`.

## Yêu cầu

| Nền tảng | Phiên bản tối thiểu |
|---|---|
| Flutter | 3.44.0 |
| Dart | 3.12.0 |
| Android | API 23 |
| iOS | 15.0 |

## Cài đặt

```bash
flutter pub add device_security_guard
```

## Sử dụng

```dart
import 'package:device_security_guard/device_security_guard.dart';

final assessment = await DeviceSecurityGuard.assess();

final detectedSignals = assessment.signals.values
    .where((result) => result.status == CheckStatus.detected)
    .toList(growable: false);
```

`DeviceSecurityGuard.assess()` chạy native detector bất đồng bộ và trả `SecurityAssessment` bất biến. Nên assessment lại khi ứng dụng trở về foreground và trước các nghiệp vụ nhạy cảm; không lưu một kết quả cho toàn bộ phiên.

### Cấu hình danh tính ký — không bắt buộc

```dart
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
```

- Android: dùng SHA-256 của certificate thực sự ký APK. Với Play App Signing, dùng **App signing key certificate**, không dùng upload key.
- iOS: dùng App ID Prefix đứng trước dấu chấm trong Keychain access group, ví dụ `ABCDE12345` trong `ABCDE12345.com.example.app`. Giá trị này có thể khác Team ID ở ứng dụng legacy.

Nếu không cấu hình danh tính của một nền tảng, plugin bỏ qua việc đọc danh tính native và trả tín hiệu `repackaging` là `inconclusive`; đây không phải một phát hiện rủi ro.

Kiểm tra App ID Prefix trên iOS là best-effort, không phải chứng thực mật mã.

## Đọc kết quả

| Trạng thái | Ý nghĩa |
|---|---|
| `detected` | Tìm thấy ít nhất một indicator thuộc tín hiệu đó. |
| `notDetected` | Detector đã chạy và không thấy indicator trong phạm vi kiểm tra. |
| `inconclusive` | Thiếu cấu hình, thiếu dữ liệu hoặc detector gặp lỗi nên không thể kết luận. |

`reasonCode` dành cho log kỹ thuật; không hiển thị trực tiếp cho người dùng.

Package có policy helper tùy chọn:

```dart
final decision = Circular77Policy.evaluate(
  assessment,
  failClosed: true,
);
```

`detected` tạo khuyến nghị `block`. `inconclusive` tạo `indeterminate`, hoặc `block` khi `failClosed: true`. Helper chỉ trả khuyến nghị và không thực thi hành động trong ứng dụng.

## Giới hạn

Detector phía client là một lớp defense-in-depth. Thiết bị hoặc công cụ đã bị kiểm soát sâu có thể che giấu indicator, hook hoặc làm sai kết quả; `notDetected` không chứng minh thiết bị an toàn tuyệt đối.

Package hỗ trợ các nhóm tín hiệu kỹ thuật liên quan đến Thông tư 77/2025/TT-NHNN nhưng không phải chứng nhận tuân thủ. Ứng dụng tích hợp vẫn chịu trách nhiệm về policy, trải nghiệm người dùng, kiểm thử thiết bị thực và đánh giá bảo mật/pháp lý.

## Tài liệu

- [Ma trận bao phủ kỹ thuật](doc/circular-77-coverage-vi.md)
- [Hướng dẫn phát hành](doc/publishing-vi.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Example](example/lib/main.dart)

Giấy phép [MIT](LICENSE).
