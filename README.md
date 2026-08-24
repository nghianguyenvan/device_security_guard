# device_security_guard

Flutter plugin giúp phát hiện các dấu hiệu cho thấy thiết bị hoặc ứng dụng có thể đã bị can thiệp trên Android và iOS.

Package chỉ làm nhiệm vụ **kiểm tra và trả kết quả**. Package không tự đóng ứng dụng, không hiển thị thông báo, không gửi dữ liệu và không quyết định cách xử lý thay cho ứng dụng tích hợp.

## Cài đặt

```bash
flutter pub add device_security_guard
```

Yêu cầu tối thiểu:

| Nền tảng | Phiên bản |
|---|---|
| Flutter | 3.44.0 |
| Dart | 3.12.0 |
| Android | API 23 |
| iOS | 15.0 |

Plugin không yêu cầu thêm quyền hệ thống.

## Bắt đầu nhanh

```dart
import 'package:device_security_guard/device_security_guard.dart';

Future<void> checkDeviceSecurity() async {
  final result = await DeviceSecurityGuard.assess();

  final detectedChecks = result.signals.entries
      .where((entry) => entry.value.status == CheckStatus.detected)
      .map((entry) => entry.key)
      .toList(growable: false);

  final incompleteChecks = result.signals.entries
      .where((entry) => entry.value.status == CheckStatus.inconclusive)
      .map((entry) => entry.key)
      .toList(growable: false);

  if (detectedChecks.isNotEmpty) {
    // Có dấu hiệu bất thường. Ứng dụng tự quyết định cách xử lý.
  } else if (incompleteChecks.isNotEmpty) {
    // Một số hạng mục chưa thể kết luận. Đây không phải là detected.
  } else {
    // Chưa phát hiện dấu hiệu bất thường trong các hạng mục đã kiểm tra.
  }
}
```

Giá trị trả về là một `SecurityAssessment`, bao gồm nền tảng, phiên bản hệ điều hành, thời điểm kiểm tra và kết quả của từng hạng mục. Mỗi hạng mục tương ứng với một `SecuritySignal`, chẳng hạn `root`, `jailbreak`, `debugger` hoặc `emulator`.

Mỗi hạng mục có `status` và `reasonCode`. `reasonCode` là mã nguyên nhân dành cho việc ghi log hoặc chẩn đoán kỹ thuật, không phải nội dung để hiển thị trực tiếp cho người dùng cuối.

## Kết quả trả về có nghĩa là gì?

| Trạng thái | Kết quả có nghĩa là gì? |
|---|---|
| `detected` | Plugin phát hiện dấu hiệu bất thường trong một hạng mục, chẳng hạn thiết bị đã root/jailbreak, debugger đang kết nối, ứng dụng chạy trên máy ảo hoặc chữ ký ứng dụng không khớp. |
| `notDetected` | Plugin đã hoàn tất hạng mục kiểm tra và chưa phát hiện dấu hiệu bất thường. Kết quả này không đảm bảo thiết bị an toàn tuyệt đối. |
| `inconclusive` | Plugin không thể đưa ra kết quả vì thiếu cấu hình, không đọc được dữ liệu hoặc xảy ra lỗi trong quá trình kiểm tra. Trạng thái này không phải là `detected`. |

Package chỉ trả các trạng thái trên. Ứng dụng tích hợp tự quyết định tiếp tục, giới hạn chức năng, yêu cầu xác minh bổ sung hay chặn một nghiệp vụ.

### Tổng hợp nhiều kết quả — không bắt buộc

Nếu muốn tổng hợp tất cả hạng mục thành một khuyến nghị duy nhất, bạn có thể dùng `Circular77Policy`:

```dart
Future<PolicyDecision> checkDeviceSecurityWithPolicy() async {
  final result = await DeviceSecurityGuard.assess();

  return Circular77Policy.evaluate(
    result,
    failClosed: false,
  );
}
```

- Có ít nhất một hạng mục `detected`: trả `RecommendedAction.block`.
- Không có `detected` nhưng có `inconclusive`: trả `RecommendedAction.indeterminate`.
- Tất cả hạng mục đều là `notDetected`: trả `RecommendedAction.allow`.
- Nếu đặt `failClosed: true`, trường hợp `inconclusive` cũng trả `RecommendedAction.block`.

`Circular77Policy` chỉ tính toán và trả khuyến nghị. Nó không tự chặn luồng, điều hướng, đóng ứng dụng hoặc hiển thị thông báo.

## Thời điểm nên kiểm tra

Không nên dùng một kết quả cho toàn bộ thời gian ứng dụng đang mở. Hãy gọi `assess()` tại các thời điểm phù hợp với mức độ rủi ro của ứng dụng, thường gồm:

- khi khởi động hoặc trước khi vào vùng cần bảo vệ;
- khi ứng dụng trở lại trạng thái hoạt động (`foreground`);
- trước giao dịch hoặc nghiệp vụ nhạy cảm.

`assess()` chạy bất đồng bộ. Không gọi liên tục trong phương thức `build()` hoặc mỗi lần giao diện được vẽ lại.

## Cấu hình kiểm tra danh tính ứng dụng — không bắt buộc

Bạn có thể cung cấp thông tin ký ứng dụng được tin cậy để bật hạng mục kiểm tra `repackaging`:

```dart
Future<SecurityAssessment> checkWithTrustedAppIdentity() {
  return DeviceSecurityGuard.assess(
    options: SecurityOptions(
      expectedAndroidCertificateSha256: {
        '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF',
      },
      expectedIosApplicationIdentifierPrefixes: {
        'ABCDE12345',
      },
    ),
  );
}
```

### Android

Dùng mã SHA-256 của chứng thư (`certificate`) thực sự ký APK/AAB. Nếu sử dụng Google Play App Signing, hãy lấy **App signing key certificate**, không lấy upload key. Có thể cấu hình nhiều SHA-256 khi đang chuyển đổi khóa ký.

### iOS

Dùng App ID Prefix đứng trước dấu chấm trong Keychain access group, ví dụ `ABCDE12345` trong `ABCDE12345.com.example.app`. Với một số ứng dụng cũ, App ID Prefix có thể khác Team ID.

Do giới hạn của iOS, hạng mục này chỉ đối chiếu dữ liệu hệ điều hành cho phép ứng dụng đọc được. Nó không thể đảm bảo tuyệt đối rằng ứng dụng chưa bị đóng gói lại.

Nếu không cung cấp cấu hình cho một nền tảng, plugin bỏ qua việc đọc thông tin ký trên nền tảng đó và trả `repackaging: inconclusive`. Điều này có nghĩa là hạng mục chưa được kiểm tra, không có nghĩa là plugin đã phát hiện ứng dụng bị đóng gói lại.

## Plugin kiểm tra những gì?

| Hạng mục kiểm tra | Android | iOS |
|---|:---:|:---:|
| Debugger đang kết nối | ✅ | ✅ |
| Máy ảo (emulator / simulator) | ✅ | ✅ |
| ADB đang bật | ✅ | — |
| Công cụ can thiệp hoặc chèn mã (hook) | ✅ | ✅ |
| Thông tin ký ứng dụng không khớp cấu hình | ✅ | ✅, có giới hạn |
| Thiết bị Android đã root | ✅ | — |
| Thiết bị iOS đã jailbreak | — | ✅ |
| Bootloader mở khóa | ✅ | — |

Hạng mục không áp dụng cho nền tảng hiện tại sẽ không xuất hiện trong `SecurityAssessment.signals`.

## Lỗi và giới hạn

- `assess()` ném `ArgumentError` nếu SHA-256 hoặc App ID Prefix sai định dạng.
- Nếu toàn bộ lần kiểm tra bên Android/iOS không thể hoàn thành, `assess()` có thể ném `PlatformException`. Ứng dụng nên bắt lỗi tại nơi gọi hàm.
- Nếu chỉ một hạng mục thiếu dữ liệu hoặc gặp lỗi, hạng mục đó trả `inconclusive`, không trả `detected`.
- Package chỉ là một lớp kiểm tra bổ sung. Trên thiết bị đã bị can thiệp sâu, công cụ tấn công có thể che giấu dấu hiệu hoặc làm sai kết quả kiểm tra.
- `notDetected` chỉ có nghĩa là plugin chưa phát hiện dấu hiệu bất thường trong phạm vi kiểm tra; nó không chứng minh thiết bị an toàn tuyệt đối.

Package hỗ trợ kiểm tra một số dấu hiệu kỹ thuật có liên quan đến Thông tư 77/2025/TT-NHNN nhưng không phải chứng nhận tuân thủ. Ứng dụng tích hợp vẫn chịu trách nhiệm về cách xử lý kết quả, trải nghiệm người dùng, kiểm thử trên thiết bị thực và đánh giá bảo mật/pháp lý.

## Tài liệu liên quan

- [Ví dụ tích hợp](https://pub.dev/packages/device_security_guard/example)
- [Tài liệu API](https://pub.dev/documentation/device_security_guard/latest/)
- [Ma trận bao phủ kỹ thuật](https://github.com/nghianguyenvan/device_security_guard/blob/main/doc/circular-77-coverage-vi.md)
- [Cách báo cáo vấn đề bảo mật](https://github.com/nghianguyenvan/device_security_guard/blob/main/SECURITY.md)
- [Lịch sử thay đổi](https://pub.dev/packages/device_security_guard/changelog)
- [Hướng dẫn phát hành dành cho maintainer](https://github.com/nghianguyenvan/device_security_guard/blob/main/doc/publishing-vi.md)
- [Issue tracker](https://github.com/nghianguyenvan/device_security_guard/issues)

Phát hành theo giấy phép [MIT](https://pub.dev/packages/device_security_guard/license).
