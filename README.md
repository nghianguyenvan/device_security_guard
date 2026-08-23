# device_security_guard

Flutter plugin trả về các tín hiệu bảo mật của thiết bị/môi trường chạy và policy helper cho ứng dụng ngân hàng. Phạm vi v1 bám theo nhóm dấu hiệu tại Thông tư 77/2025/TT-NHNN: debugger, emulator/simulator, ADB, hook/chèn mã, ứng dụng bị đóng gói lại, root/jailbreak và bootloader Android mở khóa.

Package không tự đóng ứng dụng và không tự chứng nhận tuân thủ pháp luật. Ứng dụng chủ phải tự thẩm định pháp lý, kiểm thử bảo mật và quyết định cách xử lý cuối cùng.

## Nền tảng

- Android: `minSdk 23`, `compileSdk 36`.
- iOS: deployment target `15.0`.
- Play Integrity và App Attest là tùy chọn, mặc định tắt.

## Cài đặt

```yaml
dependencies:
  device_security_guard: ^0.1.0
```

## Kiểm tra cục bộ

```dart
final assessment = await DeviceSecurityGuard.assess(
  options: const SecurityOptions(
    expectedAndroidCertificateSha256: {
      '0123456789ABCDEF...',
    },
    expectedIosTeamIdentifiers: {
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
    // Ứng dụng chủ quyết định chặn chức năng phù hợp.
    break;
  case RecommendedAction.indeterminate:
    // Không đủ bằng chứng; có thể yêu cầu kiểm tra bổ sung.
    break;
}
```

Nếu muốn mọi kết quả chưa thể kết luận đều được khuyến nghị chặn:

```dart
final decision = Circular77Policy.evaluate(
  assessment,
  failClosed: true,
);
```

Không cấu hình certificate Android hoặc Team ID iOS sẽ làm tín hiệu `repackaging` trả về `inconclusive`, không mặc định coi là an toàn.

## Ý nghĩa trạng thái

### Tín hiệu cục bộ

- `CheckStatus.detected`: phát hiện dấu hiệu rủi ro.
- `CheckStatus.notDetected`: kiểm tra đã chạy và chưa phát hiện dấu hiệu.
- `CheckStatus.inconclusive`: không đủ dữ liệu hoặc detector gặp lỗi.

### Attestation

- `AttestationStatus.trusted`: backend ứng dụng chủ đã xác minh hợp lệ.
- `AttestationStatus.untrusted`: backend xác minh và kết luận không tin cậy.
- `AttestationStatus.inconclusive`: timeout, provider không khả dụng, phản hồi lỗi hoặc chưa đủ bằng chứng.

Attestation đang tắt sẽ không xuất hiện trong kết quả. Package không có trạng thái `unsupported` riêng; trường hợp không thể kiểm tra được biểu diễn bằng `inconclusive` cùng `reasonCode`.

## Cấu hình danh tính ứng dụng

### Android

Truyền SHA-256 của certificate dùng để ký bản cài trên thiết bị, viết hoa và có thể có hoặc không có dấu `:`. Nếu dùng Play App Signing, lấy certificate **App signing key** trong Play Console, không lấy upload key.

Có thể kiểm tra một APK đã ký bằng:

```bash
apksigner verify --print-certs app-release.apk
```

### iOS

Truyền Team ID của tài khoản ký ứng dụng. Kiểm tra cục bộ Team ID là best-effort; bản App Store có thể không cho phép đọc đủ thông tin và khi đó kết quả là `inconclusive`. App Attest được backend xác minh là lớp bảo vệ mạnh hơn cho danh tính ứng dụng production.

## Play Integrity và App Attest

Hai provider chỉ chạy khi bật cờ tương ứng và cung cấp `AttestationAdapter`:

```dart
final assessment = await DeviceSecurityGuard.assess(
  options: SecurityOptions(
    enablePlayIntegrity: true,
    attestationAdapter: MyBackendAttestationAdapter(),
  ),
);
```

Adapter do ứng dụng chủ triển khai phải thực hiện luồng sau:

1. Lấy challenge dùng một lần từ backend.
2. Tạo `requestHash` cho Play Integrity hoặc `clientDataHash` cho App Attest.
3. Gọi primitive tương ứng trên `AttestationClient`.
4. Gửi token/attestation/assertion về backend.
5. Backend xác minh độ mới, chống replay, package/bundle ID, certificate/Team ID và verdict bắt buộc.
6. Adapter trả `AttestationAssessment`; chỉ trả `trusted` sau khi backend xác minh thành công.

Các primitive có sẵn:

```dart
client.requestPlayIntegrityToken(
  cloudProjectNumber: cloudProjectNumber,
  requestHash: requestHash,
);

client.isAppAttestSupported();
client.generateAppAttestKey();
client.attestAppAttestKey(
  keyId: keyId,
  clientDataHash: clientDataHash,
);
client.generateAppAttestAssertion(
  keyId: keyId,
  clientDataHash: clientDataHash,
);
```

Với App Attest, ứng dụng chủ cần bật capability App Attest, cấu hình entitlement môi trường phù hợp và lưu `keyId` an toàn. Không đặt credential backend, khóa dịch vụ Google hoặc secret Apple trong ứng dụng.

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

Mọi kiểm tra phía client đều có thể bị bypass nếu attacker kiểm soát đủ sâu ứng dụng hoặc hệ điều hành. Không dùng một tín hiệu đơn lẻ làm bằng chứng tuyệt đối. Với nghiệp vụ rủi ro cao, nên kết hợp attestation xác minh tại backend, anti-replay, quản trị phiên, telemetry và kiểm thử trên thiết bị thật.

Package không gửi telemetry. Khi attestation tắt, package không gọi Play Integrity, App Attest hoặc backend. Raw token và assertion không được ghi log bởi package.

Văn bản tham chiếu: [Thông tư 77/2025/TT-NHNN trên Cổng Thông tin điện tử Chính phủ](https://vanban.chinhphu.vn/?docid=216580&pageid=27160).
