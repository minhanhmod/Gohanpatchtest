# GooHan Patch — iOS 27 Final Prerequisite Test v3.3

**Trạng thái: TEST / KHÔNG PHẢI BẢN ĐÃ PATCH ĐƯỢC iOS 27.** Ứng dụng chưa có AirLiftFFI native, chưa kết nối pairing native, chưa có AirLift writer / backup + restore cho `.3105`.

## Mục tiêu lần test

Kiểm tra riêng tình huống thiết bị iOS 27.0 tới iOS 27.2 Beta 2 chạy 3105 Beta 5 thành công và GooHan không chạy được. Lần thử này phân biệt 3 cấp bằng chứng: (1) TCP cục bộ của GooHan phản hồi, (2) người thử nghiệm xác nhận trạng thái 3105 trên cùng điện thoại, (3) GooHan có native engine thật — hiện chưa.

## Hướng dẫn (không cần Pair File gửi cho ai)

1. Upload toàn bộ ZIP full source vào repo test **Gohanpatchtest**, hoặc ghi đè đúng các file trong ZIP Changed Only nếu repo đang ở v3.2. Chạy GitHub Actions **Build GooHan Patch experimental IPA**. Ký IPA bằng chứng chỉ của bạn, chỉ cài trên máy test.
2. Trên máy iOS 27.0/27.1/27.2 Beta 1–2, bật LocalDevVPN, mở 3105 Beta 5, xác nhận trạng thái **Kết nối tunnel Hoạt động** và **Pairing Sẵn sàng**. Nếu có thể, kiểm chứng cùng một file `.3105` trong 3105 nhưng không cần thử ghi lại nếu đã xác nhận thành công trên chính máy này. Không xuất pairing record.
3. Mở GooHan → **Cài đặt** → **iOS 27 • LocalDevVPN — Final Test v3.3**. Bật xác nhận LocalDev đã bật, nhấn **Kiểm tra kết nối cục bộ (chỉ đọc)**. Thử các tuyến mẫu có timeout ngắn, KHÔNG gửi dữ liệu pairing hoặc áp dụng Patch.
4. Trong mục **Đối chiếu với 3105 Beta 5 (cùng iPhone)**, bật đúng các xác nhận đã kiểm chứng. Không đánh dấu mục “áp dụng cùng gói” nếu chưa xác minh.
5. Nhấn **Sao chép báo cáo Final Test v3.3** và gửi nguyên báo cáo dạng text. Nếu an toàn, thêm ảnh cài đặt 3105 (ẩn mã ghép đôi, UDID, tài khoản). Nếu muốn đối chứng, lặp lại phép thử TCP khi LocalDevVPN tắt, ghi mã lỗi khác nhau (không cần chạy lại Patch).
6. Ghi rõ phiên bản/build chính xác. Đặc biệt, **27.2 Beta 3+ không nằm trong phạm vi**, nhưng chỉ hiển thị phiên bản 27.2 không đủ chứng minh build là Beta 1–2.

## Cách đọc mã

- `LOCAL_TCP_PORT_REACHABLE_ONLY`: Có tuyến TCP phản hồi, **không chứng minh VPN/pairing/ghi file**.
- `LOCAL_TCP_PORT_NOT_DETECTED`: Không mở được cổng mẫu, **không chứng minh VPN tắt** (RSD có cổng động).
- `BETA5_PAIRING_NOT_OBSERVED`: Chưa có đối chiếu pairing từ Beta 5 trên cùng máy.
- `IOS27_2_BUILD_OUTSIDE_BETA_1_2_SCOPE`: Build 27.2 không phải Beta 1 `24B5084k` hoặc Beta 2 `24B5089g`; không nằm trong phạm vi bạn yêu cầu.
- `NATIVE_AIRLIFT_IMPLEMENTATION_REQUIRED`: Thiếu engine AirLift thực, dù các điều kiện tiền kiểm người dùng đã xác nhận.
- `NATIVE_DRIVER_REQUIRES_AUTH_AND_RESTORE_TEST`: Provider đã đăng ký trong source tương lai, vẫn cần test quyền, backup, restore.

## Mức độ và ranh giới

- Không thay đổi `SupportPolicy.swift`; không gỡ hàng rào ghi iOS 27.
- Không nhập, đọc, lưu hoặc gửi Pair File; các thông tin người thử nghiệm xác nhận từ 3105 không được coi là pairing đã được GooHan xác thực.
- Không mở container bên thứ ba hoặc ghi file qua network probe. Tối đa 5 TCP endpoint mẫu với timeout 1,3 giây.
- Giữ nguyên Admin, License, UI chính và khôi phục cũ.
- Mã nguồn Swift parse và unit smoke chạy được trên Linux; build IPA bằng Xcode/macOS và kiểm thử trên iPhone phải thực hiện qua GitHub Actions, không thể xác nhận tại đây.

## Tiêu chí để công bố bản chính thức có AirLift

**Tất cả** phải đạt trên thiết bị thật: AirLift native build/link; kết nối RSD/Lockdown có ghép đôi hợp lệ; xác nhận quyền truy cập mục tiêu; backup trước ghi và khôi phục sau ghi; kiểm tra dữ liệu/biên nhận; xử lý lỗi ghi một phần mà không thử fallback nguy hiểm; kiểm thử 27.0 `24A435`, `24A437` và các build 27.1/27.2 Beta 1–2 cụ thể. Chỉ kiểm tra TCP hay ảnh 3105 là **chưa đủ**.

Nguồn công khai: https://github.com/Mak5er/AirCard-iOS và https://github.com/jkcoxson/LocalDevVPN . AirCard tập trung Wallet/Passcode/Wallpaper, không phải mã thay thế `.3105` đã xác minh.
