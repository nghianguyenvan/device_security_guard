# Ma trận bao phủ Thông tư 77/2025/TT-NHNN

Tài liệu này ánh xạ các detector của `device_security_guard` với nhóm dấu hiệu thiết bị/môi trường chạy được nêu tại khoản 2 Điều 5 Thông tư 77/2025/TT-NHNN, sửa đổi khoản 4 Điều 8 Thông tư 50/2024/TT-NHNN.

Đây là tài liệu kỹ thuật, không phải ý kiến pháp lý và không chứng nhận ứng dụng sử dụng package đã tuân thủ quy định.

| Nhóm dấu hiệu | Android | iOS | Kết quả khi thiếu dữ liệu |
|---|---|---|---|
| Trình gỡ lỗi | `Debug.isDebuggerConnected`, trạng thái chờ debugger | cờ `P_TRACED` qua `sysctl` | `inconclusive` nếu truy vấn lỗi |
| Thiết bị ảo | build fields và `ro.kernel.qemu` | `targetEnvironment(simulator)` | `inconclusive` nếu detector lỗi |
| ADB | `Settings.Global.ADB_ENABLED` | Không áp dụng | `inconclusive` nếu truy vấn lỗi |
| Hook/chèn mã runtime | `/proc/self/maps`, marker Frida/Xposed/Substrate | loaded images, `DYLD_INSERT_LIBRARIES`, marker hook phổ biến | `inconclusive` nếu detector lỗi |
| Repackage/can thiệp ứng dụng | SHA-256 signing certificate | Team ID từ Keychain access group do hệ thống ký cấp | `inconclusive` nếu chưa cấu hình hoặc không đọc được danh tính |
| Root/jailbreak | build tags, root artifacts và system properties | jailbreak artifacts và thử ghi ngoài sandbox | `inconclusive` khi detector lỗi; jailbreak trên simulator không được coi là an toàn |
| Bootloader mở khóa | verified boot, flash lock và vbmeta state | Không áp dụng | `inconclusive` nếu không có trạng thái nhận diện được |

## Attestation tùy chọn

- Play Integrity là nguồn chứng thực riêng, không phải một `SecuritySignal`. Package chỉ tạo Standard Integrity token gắn với `requestHash`.
- App Attest là nguồn chứng thực riêng. Package chỉ cung cấp kiểm tra hỗ trợ, tạo key, attestation và assertion.
- Chỉ backend ứng dụng chủ được phép kết luận `trusted` sau khi xác minh artifact, challenge dùng một lần, độ mới, định danh ứng dụng và verdict/counter bắt buộc.
- Provider tắt mặc định và không tạo kết quả attestation.

## Quy tắc policy mặc định

- Có ít nhất một `detected` hoặc attestation `untrusted`: `block`.
- Không có bằng chứng chặn nhưng có `inconclusive`: `indeterminate`.
- `failClosed: true`: chuyển `indeterminate` thành `block`.
- Chỉ `allow` khi mọi tín hiệu áp dụng đều `notDetected` và mọi attestation đã bật đều `trusted`.

## Giới hạn

Detector cục bộ là heuristic defense-in-depth và có thể có false positive, false negative hoặc bị hook/bypass. Cần kiểm thử trên ma trận thiết bị thật, kết hợp kiểm soát backend và cập nhật indicator theo threat intelligence của đơn vị vận hành.

Nguồn chính thức: [Thông tư 77/2025/TT-NHNN](https://vanban.chinhphu.vn/?docid=216580&pageid=27160), ban hành ngày 31/12/2025 và có hiệu lực từ 01/03/2026.
