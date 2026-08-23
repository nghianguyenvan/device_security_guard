# device_security_guard

Flutter plugin trả về tín hiệu bảo mật cục bộ và policy helper cho ứng dụng ngân hàng. Phạm vi v1 bám theo nhóm dấu hiệu tại Thông tư 77/2025/TT-NHNN: debugger, emulator/simulator, ADB, hook/chèn mã, ứng dụng bị đóng gói lại, root/jailbreak và bootloader Android mở khóa.

Package không tự đóng ứng dụng và không tự chứng nhận tuân thủ pháp luật. Ứng dụng chủ phải thẩm định pháp lý, kiểm thử bảo mật và quyết định cách xử lý cuối cùng.

## Nền tảng

- Android: `minSdk 23`, `compileSdk 36`.
- iOS: deployment target `15.0`.
- Không cần cấu hình dịch vụ hoặc backend để chạy detector của package.

## Cài đặt

```yaml
dependencies:
  device_security_guard: ^0.1.0
```

## Sử dụng

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

final decision = Circular77Policy.evaluate(assessment);

switch (decision.action) {
  case RecommendedAction.allow:
    // Cho phép tiếp tục.
    break;
  case RecommendedAction.block:
    // Dừng hoặc chặn chức năng theo chính sách của ứng dụng chủ.
    break;
  case RecommendedAction.indeterminate:
    // Không đủ bằng chứng; yêu cầu kiểm tra hoặc xử lý bổ sung.
    break;
}
```

Nên chạy lại khi mở ứng dụng, khi ứng dụng trở về foreground và ngay trước thao tác nhạy cảm. App chủ phải thực sự chặn thao tác nếu policy yêu cầu; kết quả lưu từ lần khởi động có thể đã cũ.

Muốn mọi kết quả chưa thể kết luận đều được khuyến nghị chặn:

```dart
final decision = Circular77Policy.evaluate(
  assessment,
  failClosed: true,
);
```

Không cấu hình certificate Android hoặc App ID Prefix iOS sẽ làm tín hiệu `repackaging` trả về `inconclusive`, không mặc định coi là an toàn.

## Ý nghĩa trạng thái

- `CheckStatus.detected`: phát hiện dấu hiệu rủi ro.
- `CheckStatus.notDetected`: kiểm tra đã chạy và chưa phát hiện dấu hiệu.
- `CheckStatus.inconclusive`: không đủ dữ liệu hoặc detector gặp lỗi.

Policy khuyến nghị `block` khi có tín hiệu `detected`, `indeterminate` khi có kết quả `inconclusive`, và chỉ `allow` khi mọi tín hiệu áp dụng đều là `notDetected`. Với `failClosed: true`, `indeterminate` được chuyển thành `block`.

## Cấu hình danh tính ứng dụng

### Android

Truyền SHA-256 của certificate dùng để ký bản cài trên thiết bị, viết hoa và có thể có hoặc không có dấu `:`. Nếu dùng Play App Signing, lấy certificate **App signing key** trong Play Console, không lấy upload key.

```bash
apksigner verify --print-certs app-release.apk
```

### iOS

Truyền App ID Prefix đứng trước dấu chấm trong Keychain access group của ứng dụng, thường có 10 ký tự. Giá trị này thường trùng Team ID nhưng có thể khác ở ứng dụng legacy. Plugin đọc access group qua Security framework công khai; nếu hệ thống không trả được danh tính, kết quả là `inconclusive`.

## Phạm vi tín hiệu

| Tín hiệu | Android | iOS |
|---|:---:|:---:|
| Debugger | Có | Có |
| Emulator/simulator | Có | Có |
| ADB | Có | Không áp dụng |
| Hook/chèn mã runtime | Có | Có |
| Repackage/danh tính ký | Có | Có, best-effort |
| Root | Có | Không áp dụng |
| Jailbreak | Không áp dụng | Có |
| Bootloader mở khóa | Có | Không áp dụng |

Chi tiết kỹ thuật và giới hạn nằm trong [ma trận bao phủ Thông tư 77](doc/circular-77-coverage-vi.md).

## Giới hạn bảo mật

Detector phía client là heuristic defense-in-depth: có thể có false positive, false negative và có thể bị hook/bypass khi attacker kiểm soát đủ sâu ứng dụng hoặc hệ điều hành. Không dùng một tín hiệu đơn lẻ làm bằng chứng tuyệt đối. Với nghiệp vụ rủi ro cao, nên kết hợp kiểm soát giao dịch ở backend, quản trị phiên, telemetry, giới hạn rủi ro và kiểm thử trên thiết bị thật.

Package không gửi dữ liệu qua mạng và không thu thập telemetry.

Văn bản tham chiếu: [Thông tư 77/2025/TT-NHNN trên Cổng Thông tin điện tử Chính phủ](https://vanban.chinhphu.vn/?docid=216580&pageid=27160).
