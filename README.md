# device_security_guard

Flutter plugin giúp phát hiện các dấu hiệu cho thấy thiết bị hoặc ứng dụng có thể đã bị can thiệp trên Android và iOS.

Package chỉ **kiểm tra và trả kết quả**. Package không tự đóng ứng dụng, không hiển thị thông báo, không gửi dữ liệu và không quyết định cách xử lý thay cho ứng dụng tích hợp.

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

## Hiểu kết quả trước khi tích hợp

`DeviceSecurityGuard.assess()` trả về một `SecurityAssessment`: ảnh chụp kết quả kiểm tra tại thời điểm gọi hàm. Assessment bao gồm nền tảng, phiên bản hệ điều hành, thời điểm kiểm tra và các hạng mục áp dụng cho nền tảng hiện tại.

Mỗi hạng mục có một trong ba trạng thái:

| Trạng thái | Ý nghĩa |
|---|---|
| `detected` | Plugin phát hiện dấu hiệu bất thường, ví dụ thiết bị đã root, debugger đang kết nối hoặc ứng dụng chạy trên máy ảo. |
| `notDetected` | Hạng mục đã được kiểm tra và chưa phát hiện dấu hiệu bất thường trong phạm vi kiểm tra. |
| `inconclusive` | Plugin không thể kết luận vì thiếu cấu hình, không đọc được dữ liệu hoặc xảy ra lỗi khi kiểm tra. Trạng thái này không phải là `detected`. |

`notDetected` không chứng minh thiết bị an toàn tuyệt đối. `reasonCode` là mã nguyên nhân dành cho log và chẩn đoán kỹ thuật, không phải nội dung để hiển thị trực tiếp cho người dùng cuối.

## Chọn cách đọc phù hợp

Không có một cách đọc phù hợp cho mọi ứng dụng. Hãy chọn theo lượng thông tin mà nghiệp vụ của bạn cần giữ lại:

| Nhu cầu | Cách dùng |
|---|---|
| Chỉ cần biết một dấu hiệu đã được phát hiện hay chưa | Dùng các getter như `isRooted`, `isDebuggerAttached` |
| Cần phân biệt `notDetected`, `inconclusive` và hạng mục không áp dụng | Đọc `signals[SecuritySignal...]` |
| Cần xử lý mọi hạng mục bằng cùng một quy tắc | Duyệt `signals.values` |
| Cần một khuyến nghị tổng hợp | Dùng `Circular77Policy` |

### 1. Đọc nhanh các dấu hiệu đã phát hiện

Dùng getter khi nghiệp vụ chỉ quan tâm một dấu hiệu có đang ở trạng thái `detected` hay không:

```dart
import 'package:device_security_guard/device_security_guard.dart';

Future<void> checkDetectedRisks() async {
  final result = await DeviceSecurityGuard.assess();

  if (result.isRooted || result.isJailbroken) {
    // Phát hiện dấu hiệu root hoặc jailbreak.
  }

  if (result.isDebuggerAttached) {
    // Phát hiện debugger đang kết nối.
  }

  if (result.isEmulator) {
    // Phát hiện ứng dụng đang chạy trên máy ảo.
  }
}
```

Các getter rủi ro chỉ trả `true` khi trạng thái tương ứng là `detected`. Chúng trả `false` cho cả `notDetected`, `inconclusive` và hạng mục không áp dụng. Vì vậy, không dùng getter nếu nghiệp vụ cần phân biệt các trường hợp này.

`isRealDevice` là trường hợp đặc biệt: getter chỉ trả `true` khi hạng mục máy ảo đã hoàn tất với `notDetected`. Giá trị `false` có thể có nghĩa là đã phát hiện máy ảo hoặc chưa đủ dữ liệu để kết luận; getter này không chứng nhận thiết bị vật lý tuyệt đối.

### 2. Đọc đầy đủ một hạng mục

Dùng `signals` khi mỗi trạng thái cần một cách xử lý riêng. Ví dụ với hạng mục root:

```dart
void handleRootCheck(SecurityAssessment result) {
  final rootCheck = result.signals[SecuritySignal.root];

  if (rootCheck == null) {
    // Hạng mục root không áp dụng cho nền tảng hiện tại.
    return;
  }

  switch (rootCheck.status) {
    case CheckStatus.detected:
      // Phát hiện dấu hiệu root.
      break;
    case CheckStatus.notDetected:
      // Đã kiểm tra và chưa phát hiện dấu hiệu root.
      break;
    case CheckStatus.inconclusive:
      // Không đủ dữ liệu để kết luận; đây không phải là detected.
      break;
  }
}
```

Cách này giữ nguyên toàn bộ thông tin Android/iOS trả về, bao gồm `reasonCode` và trạng thái `inconclusive`.

### 3. Xử lý tất cả hạng mục

Duyệt toàn bộ `signals` khi ứng dụng áp dụng cùng một luồng xử lý cho mọi hạng mục:

```dart
void handleAllChecks(SecurityAssessment result) {
  for (final check in result.signals.values) {
    switch (check.status) {
      case CheckStatus.detected:
        // Dùng check.signal và check.reasonCode để xử lý hoặc ghi log.
        break;
      case CheckStatus.notDetected:
        // Hạng mục đã hoàn tất và chưa phát hiện dấu hiệu bất thường.
        break;
      case CheckStatus.inconclusive:
        // Hạng mục chưa thể đưa ra kết luận.
        break;
    }
  }
}
```

Chỉ các hạng mục áp dụng cho nền tảng hiện tại mới xuất hiện trong `result.signals`.

### 4. Nhận một khuyến nghị tổng hợp — không bắt buộc

`Circular77Policy` tổng hợp toàn bộ assessment thành một `RecommendedAction`:

```dart
Future<PolicyDecision> checkWithPolicy() async {
  final result = await DeviceSecurityGuard.assess();

  return Circular77Policy.evaluate(
    result,
    failClosed: false,
  );
}
```

| Kết quả assessment | Khuyến nghị |
|---|---|
| Có ít nhất một `detected` | `RecommendedAction.block` |
| Không có `detected` nhưng có `inconclusive` | `RecommendedAction.indeterminate` |
| Tất cả đều là `notDetected` | `RecommendedAction.allow` |
| Có `inconclusive` và `failClosed: true` | `RecommendedAction.block` |

Policy chỉ trả khuyến nghị. Package không tự chặn luồng, điều hướng, đóng ứng dụng hoặc hiển thị thông báo.

## Tham chiếu getter

| Getter | Trả về `true` khi |
|---|---|
| `result.isRooted` | Phát hiện dấu hiệu thiết bị Android đã root. |
| `result.isJailbroken` | Phát hiện dấu hiệu thiết bị iOS đã jailbreak. |
| `result.isDebuggerAttached` | Phát hiện debugger đang gắn hoặc chờ kết nối. |
| `result.isEmulator` | Phát hiện ứng dụng đang chạy trên emulator hoặc simulator. |
| `result.isRealDevice` | Kiểm tra máy ảo hoàn tất và không phát hiện máy ảo. |
| `result.isAdbEnabled` | Phát hiện ADB đang bật trên Android. |
| `result.isHookingDetected` | Phát hiện công cụ hook hoặc mã được chèn lúc chạy. |
| `result.isRepackaged` | Thông tin ký ứng dụng không khớp cấu hình tin cậy. |
| `result.isBootloaderUnlocked` | Phát hiện bootloader Android đã mở khóa. |

## Thời điểm nên kiểm tra

Assessment chỉ phản ánh trạng thái tại thời điểm chạy. Không nên lưu một kết quả cho toàn bộ thời gian ứng dụng đang mở. Các thời điểm thường cần gọi lại `assess()` gồm:

- khi khởi động hoặc trước khi vào vùng cần bảo vệ;
- khi ứng dụng trở lại trạng thái hoạt động (`foreground`);
- trước giao dịch hoặc nghiệp vụ nhạy cảm.

`assess()` chạy bất đồng bộ. Không gọi liên tục trong phương thức `build()` hoặc mỗi lần giao diện được vẽ lại.

## Cấu hình kiểm tra thông tin ký — không bắt buộc

Cung cấp thông tin ký tin cậy nếu ứng dụng cần bật hạng mục `repackaging`:

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

Dùng SHA-256 của chứng thư (`certificate`) thực sự ký APK/AAB. Với Google Play App Signing, dùng **App signing key certificate**, không dùng upload key. Có thể cấu hình nhiều SHA-256 khi đang chuyển đổi khóa ký.

### iOS

Dùng App ID Prefix đứng trước dấu chấm trong Keychain access group, ví dụ `ABCDE12345` trong `ABCDE12345.com.example.app`. Với một số ứng dụng cũ, App ID Prefix có thể khác Team ID.

Do giới hạn của iOS, hạng mục này chỉ đối chiếu dữ liệu hệ điều hành cho phép ứng dụng đọc được. Nó không thể đảm bảo tuyệt đối rằng ứng dụng chưa bị đóng gói lại.

Nếu không cung cấp cấu hình cho một nền tảng, plugin bỏ qua việc đọc thông tin ký trên nền tảng đó và trả `repackaging: inconclusive`. Điều này có nghĩa là hạng mục chưa được kiểm tra, không có nghĩa là ứng dụng bị đóng gói lại.

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

## Lỗi và giới hạn

- `assess()` ném `ArgumentError` nếu SHA-256 hoặc App ID Prefix sai định dạng.
- Nếu toàn bộ lần kiểm tra bên Android/iOS không thể hoàn thành, `assess()` có thể ném `PlatformException`. Ứng dụng nên bắt lỗi tại nơi gọi hàm.
- Nếu chỉ một hạng mục thiếu dữ liệu hoặc gặp lỗi, hạng mục đó trả `inconclusive`, không trả `detected`.
- Package chỉ là một lớp kiểm tra bổ sung. Trên thiết bị đã bị can thiệp sâu, công cụ tấn công có thể che giấu dấu hiệu hoặc làm sai kết quả kiểm tra.
- `notDetected` không chứng minh thiết bị an toàn tuyệt đối.

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
