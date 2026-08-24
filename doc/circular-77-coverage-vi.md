# Ma trận bao phủ Thông tư 77/2025/TT-NHNN

Tài liệu ánh xạ detector của `device_security_guard` với nhóm dấu hiệu tại khoản 2 Điều 5 Thông tư 77/2025/TT-NHNN, nội dung sửa đổi khoản 4 Điều 8 Thông tư 50/2024/TT-NHNN.

Đây là mô tả kỹ thuật, không phải ý kiến pháp lý và không chứng nhận ứng dụng tích hợp package đã tuân thủ quy định.

## Phạm vi detector

| Nhóm dấu hiệu | Android | iOS | Giới hạn chính |
|---|---|---|---|
| Trình gỡ lỗi | `Debug.isDebuggerConnected`, trạng thái chờ debugger | cờ `P_TRACED` qua `sysctl` | Có thể bị hook để làm sai kết quả runtime. |
| Thiết bị ảo | build fingerprint/model/manufacturer/brand/device/product/hardware và `ro.kernel.qemu` | `targetEnvironment(simulator)` | Android dùng heuristic nên có nguy cơ false positive trên thiết bị/OEM đặc biệt. |
| ADB | `Settings.Global.ADB_ENABLED` | Không áp dụng | Chỉ phản ánh trạng thái ADB tại thời điểm assessment. |
| Hook/chèn mã | `/proc/self/maps`, marker Frida/Xposed/LSPosed/Substrate | loaded Mach-O images, `DYLD_INSERT_LIBRARIES`, marker Frida/Substrate/Substitute/ElleKit | Chỉ nhận diện indicator đã biết; framework được đổi tên hoặc ẩn có thể không bị phát hiện. |
| Repackage/danh tính ký | SHA-256 certificate của APK đang chạy so với allowlist | App ID Prefix trong Keychain access group so với allowlist | Phải cấu hình allowlist. iOS là kiểm tra best-effort, không phải chứng thực mật mã. |
| Root/jailbreak | test-keys, root artifacts, `ro.debuggable`, `ro.secure` | jailbreak artifacts và thử ghi ngoài sandbox | Root/jailbreak ẩn có thể vượt qua heuristic. Jailbreak trên simulator luôn `inconclusive`. |
| Bootloader mở khóa | verified boot state, flash lock và vbmeta device state | Không áp dụng | Một số OEM không công bố đủ system property; khi đó kết quả là `inconclusive`. |

## Quy ước kết quả

- `detected`: có indicator thuộc phạm vi detector.
- `notDetected`: detector đã chạy nhưng không tìm thấy indicator. Trạng thái này không chứng minh thiết bị an toàn tuyệt đối.
- `inconclusive`: thiếu cấu hình, dữ liệu không khả dụng hoặc detector gặp lỗi.

Tín hiệu không áp dụng cho nền tảng không được đưa vào `SecurityAssessment.signals`. Dart layer bổ sung `inconclusive/missing_signal` nếu native payload thiếu một tín hiệu bắt buộc.

## Policy mặc định

1. Có ít nhất một `detected` → `block`.
2. Không có `detected` nhưng có `inconclusive` → `indeterminate`.
3. `failClosed: true` chuyển `indeterminate` thành `block`.
4. Chỉ trả `allow` khi mọi tín hiệu bắt buộc của nền tảng đều là `notDetected`.

Đây là khuyến nghị. Package không tự dừng ứng dụng và không hiển thị thông báo. App chủ phải thực thi tại điểm kiểm soát phù hợp.

## Khoảng trống ngoài phạm vi v1

- Không xác minh tính toàn vẹn qua dịch vụ bên ngoài.
- Không chống giả mạo tuyệt đối khi attacker kiểm soát process hoặc hệ điều hành.
- Không quản trị phiên, hạn mức giao dịch, telemetry hay risk engine backend.
- Không tự động cập nhật indicator theo threat intelligence.
- Không thay thế kiểm thử xâm nhập, review pháp lý hoặc quy trình quản trị rủi ro của đơn vị vận hành.

## Khuyến nghị kiểm thử

- Thiết bị thật sạch của nhiều OEM và phiên bản hệ điều hành.
- Thiết bị root/jailbreak với nhiều kỹ thuật ẩn khác nhau.
- Debug/release build, signing key production và giai đoạn chuyển đổi key.
- Emulator/simulator và thiết bị có ADB bật/tắt.
- Runtime có framework hook phổ biến và bản đã đổi tên indicator.
- Trạng thái thiếu cấu hình, native error và payload không đầy đủ.

Nguồn chính thức: [Thông tư 77/2025/TT-NHNN](https://vanban.chinhphu.vn/?docid=216580&pageid=27160), ban hành ngày 31/12/2025, có hiệu lực từ 01/03/2026.
