# GooHan Patch v3.2 — iOS 27 LocalDev TCP reachability test

## Hướng dẫn thử nghiệm

1. Dùng repository Gohanpatchtest, giữ bản v3.1 đã sửa lỗi biên dịch.
2. Upload 4 file thay đổi đúng vị trí hoặc dùng ZIP full source để thay toàn bộ nhánh thử nghiệm.
3. Chạy GitHub Actions workflow `Build GooHan Patch experimental IPA` trên macOS.
4. Cài IPA đã ký trên máy thử nghiệm iOS 27.0–27.2 Beta 2 và sao lưu dữ liệu trước mọi thao tác Patch.
5. Vào GooHan → Cài đặt → `Kiểm tra kết nối cục bộ (chỉ đọc)`.
6. Chụp báo cáo trước/sau khi bật LocalDevVPN. So sánh mã `LOCAL_TCP_PORT_REACHABLE_ONLY` hoặc `LOCAL_TCP_PORT_NOT_DETECTED`.

## Chính xác chức năng bản này

- Thử bắt tay TCP tới `10.7.0.1:62078`, sau đó `127.0.0.1:62078` với timeout 2 giây/địa chỉ.
- Không gọi dịch vụ lockdown, không tạo pairing, không đọc pairing record, không thay đổi dữ liệu ứng dụng khác.
- `LOCAL_TCP_PORT_REACHABLE_ONLY` chỉ xác nhận một dịch vụ phản hồi cổng TCP. Nó không chứng minh LocalDevVPN hoặc AirLift hoạt động.
- Không có phản hồi không chứng minh VPN đã tắt. Các bản iOS có thể đổi giao diện/địa chỉ/cổng hoặc giới hạn truy cập.
- Không có AirLiftFFI native; `GHAirLiftProvider.driverFactory` vẫn là nil.
- KHÔNG thể Patch trên iOS 27 bằng source này. Đây là bản kiểm tra tiền điều kiện, không phải ứng dụng hoàn chỉnh.

## Trạng thái triển khai engine

Nguồn mở `Mak5er/AirCard-iOS` sử dụng AirliftFFI.xcframework và mã Rust để triển khai AirTraffic. Thư viện này không có trong ZIP GooHan và chưa thể khẳng định tương thích với kế hoạch `.3105` hay biên nhận khôi phục của GooHan. Không tự liên kết hoặc đăng ký một provider chưa được kiểm thử.

Báo lỗi chi tiết và không ghi bừa khi không có backend. Giữ License, Admin, PatchProject, DevicePatchService và cơ chế Backup/Restore không thay đổi.
