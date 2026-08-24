# Hướng dẫn phát hành lên pub.dev

Quy trình này dành cho các bản cập nhật của `device_security_guard` trên pub.dev.

## 1. Chuẩn bị tài khoản và metadata

1. Đăng nhập [pub.dev](https://pub.dev) bằng tài khoản có quyền upload package.
2. Kiểm tra repository và issue tracker trong `pubspec.yaml` vẫn chính xác:

   ```yaml
   repository: https://github.com/<owner>/device_security_guard
   issue_tracker: https://github.com/<owner>/device_security_guard/issues
   ```

3. Kiểm tra `LICENSE`, `README.md`, `CHANGELOG.md`, version và quyền phân phối toàn bộ nội dung trong archive.

Không dùng URL placeholder khi phát hành.

## 2. Chạy preflight

Từ thư mục gốc package:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/integration_test
flutter analyze
flutter test --coverage
dart doc --dry-run
flutter pub publish --dry-run
git status --short
```

Kết quả yêu cầu:

- formatter không tạo thay đổi;
- analyzer và test đều pass;
- `dart doc` không có warning/error;
- publish dry-run có `0 warnings`;
- working tree sạch;
- archive không chứa secret, build output, `.dart_tool`, coverage hoặc tài liệu nội bộ.

Kiểm tra native trước mỗi release:

```bash
cd example/android
./gradlew :device_security_guard:testDebugUnitTest :device_security_guard:lintDebug
./gradlew assembleDebug

cd ..
flutter build ios --simulator --no-codesign
```

Lệnh iOS cần chạy trên macOS có Xcode và CocoaPods.

## 3. Phát hành phiên bản mới

Sau khi review chính xác archive hiển thị bởi dry-run:

```bash
dart pub publish
```

CLI sẽ yêu cầu xác nhận và mở luồng đăng nhập/ủy quyền khi cần. Đọc lại tên package, version và danh sách file trước khi xác nhận.

Lưu ý quan trọng:

- Package/version đã publish được xem là lâu dài; không dựa vào khả năng xóa để sửa sai.
- Không thể publish lại cùng một version. Nếu cần sửa, tăng version theo semantic versioning và cập nhật `CHANGELOG.md`.
- Pub.dev cho phép retract một version trong cửa sổ giới hạn, nhưng retract không phải xóa package.
- Tài khoản thực hiện lệnh phải là uploader hoặc thành viên publisher sở hữu package.

## 4. Chuyển sang verified publisher

Theo quy trình chính thức, package mới được publish lần đầu bằng tài khoản cá nhân. Sau đó:

1. Mở `https://pub.dev/packages/device_security_guard/admin`.
2. Chọn chuyển package sang verified publisher đã tạo.
3. Mời ít nhất một thành viên dự phòng vào publisher nếu package thuộc tổ chức.

Việc chuyển từ tài khoản cá nhân sang publisher không thể đảo ngược về lại cá nhân, nên kiểm tra đúng domain và quyền admin trước khi xác nhận.

## 5. Gắn tag release

Tag phải trỏ đúng commit đã tạo archive phát hành:

```bash
git tag -a v0.1.1 -m "device_security_guard 0.1.1"
git push origin main
git push origin v0.1.1
```

Chỉ chạy sau khi đã cấu hình đúng `origin`. Nếu publish thủ công trước khi tạo tag, không chỉnh sửa source rồi mới tag; tag phải khớp đúng code đã upload.

## 6. Publish tự động cho các phiên bản sau

Pub.dev chỉ hỗ trợ automated publishing cho package đã tồn tại. Phương án khuyến nghị là GitHub Actions dùng OIDC, không lưu token dài hạn:

```yaml
name: Publish to pub.dev

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'

jobs:
  publish:
    permissions:
      id-token: write
    uses: dart-lang/setup-dart/.github/workflows/publish.yml@v1
```

Trong Admin của package, bật GitHub Actions, khai báo repository và tag pattern `v{{version}}`. Version trong `pubspec.yaml` phải trùng tag. Nên bật tag protection hoặc GitHub Environment có required reviewer cho production release.

## Tài liệu chính thức

- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Writing package pages](https://dart.dev/tools/pub/writing-package-pages)
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)
- [Automated publishing](https://dart.dev/tools/pub/automated-publishing)
