# Thiết kế Device Security Guard

## Mục tiêu

`device_security_guard` là Flutter plugin dành cho Android và iOS, dùng để phát hiện các rủi ro bảo mật của thiết bị và môi trường thực thi có liên quan đến Thông tư 77/2025/TT-NHNN. Plugin trả về bằng chứng có cấu trúc và khuyến nghị xử lý theo policy. Plugin không tự đóng ứng dụng và không tuyên bố ứng dụng chủ đã tuân thủ pháp luật.

Phiên bản 1 bao phủ các dấu hiệu được quy định tại khoản 2 Điều 5 Thông tư 77/2025/TT-NHNN, sửa đổi khoản 4 Điều 8 Thông tư 50/2024/TT-NHNN:

- trình gỡ lỗi đang được gắn hoặc hoạt động;
- trình giả lập, simulator hoặc thiết bị ảo;
- Android Debug Bridge (ADB);
- hook, chèn mã bên ngoài hoặc can thiệp vào ứng dụng khi đang chạy;
- ứng dụng bị can thiệp hoặc đóng gói lại;
- thiết bị bị root hoặc jailbreak; và
- bootloader Android bị mở khóa.

Google Play Integrity và Apple App Attest là các nguồn chứng thực tùy chọn có độ tin cậy cao hơn nhờ được xác minh ở máy chủ. Cả hai mặc định đều tắt.

## Nền tảng hỗ trợ

### Android

- SDK tối thiểu: API 23.
- Compile SDK: API 36.
- Ứng dụng example target API 36.
- Ứng dụng chủ vẫn chịu trách nhiệm chọn target SDK đáp ứng chính sách Google Play.
- Ngôn ngữ native: Kotlin.

### iOS

- Deployment target: iOS 15.0.
- Bản build và CI dùng Xcode 26 trở lên với iOS 26 SDK khi môi trường cung cấp.
- Ngôn ngữ native: Swift.

Phiên bản đầu tiên chỉ hỗ trợ Android và iOS.

## Kiến trúc

Package sử dụng kiến trúc phân lớp:

1. Các detector native độc lập thu thập từng tín hiệu trên nền tảng.
2. Ranh giới platform channel chuyển payload native thành model Dart ổn định.
3. Dịch vụ đánh giá bằng Dart chạy các kiểm tra và tùy chọn gọi attestation.
4. `Circular77Policy` chuyển kết quả đánh giá thành hành động khuyến nghị.

Phiên bản 1 được phát hành dưới dạng một Flutter plugin duy nhất, chưa tách thành các federated package. Bên trong, các detector vẫn được cô lập để có thể tách package trong tương lai mà không phải thay đổi Dart API công khai.

## API công khai

Điểm truy cập chính là API bất đồng bộ:

```dart
final assessment = await DeviceSecurityGuard.assess(
  options: const SecurityOptions(
    enablePlayIntegrity: false,
    enableAppAttest: false,
  ),
);

final decision = Circular77Policy.evaluate(assessment);
```

`SecurityOptions` bao gồm:

- `enablePlayIntegrity`, mặc định là `false`;
- `enableAppAttest`, mặc định là `false`;
- danh sách SHA-256 của Android signing certificate mong đợi;
- danh sách iOS Team identifier mong đợi;
- một `AttestationAdapter` tùy chọn; và
- các tùy chọn detector độc lập với policy, chỉ được phép giảm những kiểm tra không bắt buộc và không được âm thầm biến một kiểm tra thất bại thành kết quả an toàn.

Nếu bật một attestation provider nhưng thiếu adapter hoặc cấu hình bắt buộc, kết quả attestation sẽ chứa lỗi cấu hình. Trường hợp này không bao giờ trả về verdict đáng tin cậy.

## Mô hình bảo mật

### Tín hiệu

```dart
enum SecuritySignal {
  debugger,
  emulator,
  adbEnabled,
  hooking,
  repackaging,
  root,
  jailbreak,
  bootloaderUnlocked,
}
```

Play Integrity và App Attest không phải tín hiệu bảo mật. Chúng là các nhà cung cấp chứng thực và được biểu diễn riêng.

### Trạng thái kiểm tra

```dart
enum CheckStatus {
  detected,
  notDetected,
  unknown,
  unsupported,
  notApplicable,
  error,
}
```

- `detected`: bằng chứng cho thấy rủi ro đang tồn tại.
- `notDetected`: kiểm tra đã hoàn tất và không phát hiện rủi ro.
- `unknown`: không đủ bằng chứng để kết luận.
- `unsupported`: tín hiệu có áp dụng trên nền tảng nhưng hệ điều hành hoặc thiết bị không thể thực hiện kiểm tra.
- `notApplicable`: tín hiệu không áp dụng trên nền tảng, ví dụ ADB trên iOS hoặc jailbreak trên Android.
- `error`: detector gặp lỗi ngoài dự kiến.

`notApplicable` là trạng thái trung lập khi đánh giá policy. `unknown`, `unsupported` và `error` không bao giờ được xem là bằng chứng an toàn.

### Kết quả đánh giá

`SecurityAssessment` bao gồm:

- thông tin nền tảng và phiên bản hệ điều hành;
- thời điểm thực hiện đánh giá;
- một `SignalResult` cho mỗi `SecuritySignal`;
- không hoặc nhiều `AttestationAssessment`; và
- các mã nguyên nhân chẩn đoán đã được làm sạch.

Bằng chứng trả về Dart sử dụng các mã nguyên nhân ổn định. Kết quả không để lộ đường dẫn tệp không cần thiết, token, secret, certificate thô hoặc dữ liệu khác có thể hỗ trợ việc bypass hay làm lộ thông tin người dùng.

### Attestation

Trạng thái attestation được tách khỏi trạng thái tín hiệu cục bộ:

```dart
enum AttestationStatus {
  trusted,
  untrusted,
  unknown,
  disabled,
  unsupported,
  error,
}
```

`AttestationAssessment` xác định provider, trạng thái chuẩn hóa và các mã nguyên nhân. Kết quả chỉ được chấp nhận là `trusted` sau khi backend của ứng dụng chủ đã xác minh artifact của provider, tính ràng buộc với request, độ mới, danh tính ứng dụng mong đợi và các trường verdict bắt buộc.

Package cung cấp các primitive phía client để yêu cầu Play Integrity token, đồng thời hỗ trợ vòng đời key, attestation và assertion của App Attest. `AttestationAdapter` do ứng dụng chủ triển khai sẽ chịu trách nhiệm lấy challenge, giao tiếp với backend và chuyển phản hồi máy chủ thành kết quả attestation chuẩn hóa. Package không chứa service-account credential, secret phía Apple hoặc backend production.

Không có request tới attestation SDK hoặc callback mạng nào được thực hiện nếu provider chưa được bật rõ ràng.

## Policy

```dart
enum RecommendedAction {
  allow,
  block,
  indeterminate,
}
```

`Circular77Policy` mặc định hoạt động như sau:

- Nếu bất kỳ tín hiệu áp dụng nào thuộc Thông tư 77 có trạng thái `detected`, khuyến nghị `block`.
- Nếu attestation đã bật trả về `untrusted`, khuyến nghị `block`.
- Nếu một kiểm tra áp dụng có trạng thái `unknown`, `unsupported` hoặc `error`, khuyến nghị `indeterminate`, trừ khi một kết quả khác đã yêu cầu `block`.
- Nếu attestation đã bật nhưng thiếu kết quả, không hợp lệ, hoặc có trạng thái `unknown`, `unsupported`, `error`, khuyến nghị `indeterminate`, trừ khi một kết quả khác đã yêu cầu `block`.
- Nếu tất cả kiểm tra cục bộ áp dụng đều là `notDetected`, các kiểm tra không áp dụng đều là `notApplicable`, và mọi attestation provider đã bật đều là `trusted`, khuyến nghị `allow`.

Tùy chọn policy `failClosed` chuyển khuyến nghị `indeterminate` thành `block`. Tùy chọn này không thay đổi dữ liệu đánh giá gốc.

Ứng dụng chủ quyết định có dừng chức năng Mobile Banking, kết thúc tiến trình, thông báo lý do cho khách hàng, ghi telemetry hoặc cung cấp hướng khắc phục hay không. Các side effect này nằm ngoài phạm vi plugin.

## Phát hiện theo nền tảng

### Android

Các detector Kotlin độc lập bao phủ:

- debugger đang gắn và trạng thái chờ debugger;
- dấu hiệu emulator hoặc thiết bị ảo từ nhiều system property;
- trạng thái bật ADB;
- dấu hiệu hook và chèn mã khi chạy thường gặp;
- signing certificate của ứng dụng không khớp danh sách SHA-256 đã cấu hình;
- các artifact root và dấu hiệu hệ thống bị can thiệp thường gặp; và
- trạng thái verified boot và bootloader khi có thể truy cập.

Tín hiệu jailbreak trả về `notApplicable` trên Android.

### iOS

Các detector Swift độc lập bao phủ:

- debugger đang gắn;
- môi trường simulator;
- image đáng ngờ đang được nạp và dấu hiệu hook khi chạy thường gặp;
- danh tính ứng dụng không khớp danh sách Team identifier đã cấu hình; và
- artifact jailbreak, hành vi vượt sandbox và các dấu hiệu liên quan.

Các tín hiệu ADB, Android root và Android bootloader trả về `notApplicable` trên iOS.

Mỗi detector cục bộ về root, jailbreak, hook, emulator và can thiệp ứng dụng chỉ là một lớp phòng vệ theo nguyên tắc defense in depth và có tính best-effort. Kiểm tra phía client có thể bị bypass khi ứng dụng hoặc hệ điều hành đã bị xâm phạm đủ sâu. Tài liệu phải nêu rõ giới hạn này và khuyến nghị attestation được backend xác minh khi cần độ tin cậy cao hơn.

## Luồng dữ liệu

Đối với đánh giá chỉ dùng kiểm tra cục bộ:

1. Dart kiểm tra tính hợp lệ của options.
2. Dart yêu cầu native assessment qua platform channel.
3. Native chạy các detector độc lập và trả về payload có version.
4. Dart kiểm tra và chuẩn hóa payload.
5. Dart tạo `SecurityAssessment`.
6. Ứng dụng chủ có thể đánh giá kết quả bằng `Circular77Policy`.

Đối với attestation đã được bật:

1. Adapter của ứng dụng chủ yêu cầu challenge dùng một lần từ backend.
2. Provider client của package ràng buộc request với challenge hoặc request hash và lấy artifact từ nền tảng.
3. Adapter gửi artifact tới backend của ứng dụng chủ.
4. Backend xác minh artifact với Google hoặc theo quy trình xác minh App Attest của Apple, kiểm tra chống replay và danh tính ứng dụng mong đợi, sau đó trả verdict đã chuẩn hóa.
5. Adapter cung cấp verdict đó cho dịch vụ đánh giá.
6. Policy kết hợp tín hiệu cục bộ và attestation mà không sửa dữ liệu của từng nguồn.

## Xử lý lỗi

- Cấu hình Dart không hợp lệ thất bại sớm bằng typed configuration exception trước khi chạy native.
- Mỗi native detector tự xử lý lỗi dự kiến và trả về `unknown`, `unsupported` hoặc `error` cùng mã nguyên nhân ổn định.
- Lỗi của một detector không làm mất kết quả thành công từ detector khác.
- Payload platform channel sai định dạng hoặc không tương thích version trở thành typed protocol error, không trở thành kết quả an toàn.
- Timeout, throttling, lỗi mạng, phản hồi backend không hợp lệ và provider service không khả dụng không bao giờ trở thành `trusted`.
- Không ghi log raw provider token hoặc assertion.

## Kiểm thử

Kiểm thử được tổ chức theo từng lớp:

- Dart unit test bao phủ serialize model, bảng chân trị policy, kiểm tra options, hành vi adapter, payload sai định dạng và attestation mặc định tắt.
- Kotlin unit test bao phủ heuristic của detector thông qua các environment wrapper có thể inject.
- Swift unit test bao phủ heuristic của detector thông qua các environment wrapper có thể inject.
- Flutter platform-interface test xác minh tên channel, method, schema payload và chuẩn hóa lỗi.
- Test của example app minh họa local-only, cách kết nối attestation tùy chọn và enforcement phía ứng dụng chủ mà không thật sự kết thúc tiến trình test.
- Static analysis, format, package validation, Android compilation và iOS compilation phải chạy trước khi phát hành.

Các test không tuyên bố simulator có thể chứng minh khả năng phát hiện root hoặc jailbreak trên thiết bị thật. Release checklist bao gồm kiểm tra có kiểm soát trên các thiết bị vật lý đại diện cho trạng thái root, jailbreak, bootloader mở khóa, hook, repackage và sạch.

## Package và phát hành

Repository bao gồm:

- tài liệu Dart API công khai;
- một ứng dụng Flutter example;
- `README.md`, `CHANGELOG.md`, `LICENSE` và `SECURITY.md`;
- ma trận bao phủ Thông tư 77;
- hướng dẫn tích hợp Play Integrity và App Attest;
- ghi chú về quyền riêng tư và threat model; và
- metadata pub.dev cùng screenshot chỉ khi chúng thực sự hỗ trợ việc tích hợp.

README nêu rõ package hỗ trợ các biện pháp kiểm soát kỹ thuật nhưng không tự chứng nhận việc tuân thủ pháp luật hoặc quy định. Người dùng package phải tự thực hiện đánh giá pháp lý, bảo mật, penetration test và vận hành phù hợp.

## Ngoài phạm vi phiên bản 1

- Backend attestation production.
- Tự động kết thúc tiến trình hoặc hiển thị dialog.
- Quản lý policy từ xa hoặc thu thập telemetry.
- Tích hợp giải pháp RASP/chống can thiệp thương mại.
- Hỗ trợ web, desktop, Wear OS, Android TV, Android Automotive hoặc Android XR.
- Bảo đảm tuyệt đối rằng client đã bị xâm phạm không thể bypass mọi kiểm tra cục bộ.
