# Chính sách bảo mật

## Phiên bản được hỗ trợ

Trong giai đoạn `0.x`, chỉ phiên bản mới nhất được nhận bản vá bảo mật. Người dùng nên nâng cấp lên release gần nhất trước khi báo cáo.

## Báo cáo lỗ hổng

Không công khai certificate riêng, thông tin ứng dụng nội bộ, exploit chưa vá hoặc dữ liệu khách hàng trong issue. Hãy dùng kênh báo cáo riêng của repository/publisher, kèm:

- phiên bản package và nền tảng;
- thiết bị/phiên bản hệ điều hành;
- bước tái hiện tối thiểu;
- ảnh hưởng và điều kiện attacker cần có;
- mã minh họa không chứa dữ liệu nhạy cảm.

Package không cam kết detector phía client không thể bị bypass. Một heuristic không phát hiện một thiết bị cụ thể chưa chắc là lỗ hổng; báo cáo nên chứng minh khả năng vượt policy, làm sai lệch kết quả hoặc tạo false positive có ảnh hưởng thực tế.

Không thử nghiệm trên hệ thống, tài khoản hoặc thiết bị của bên thứ ba khi chưa được phép.
