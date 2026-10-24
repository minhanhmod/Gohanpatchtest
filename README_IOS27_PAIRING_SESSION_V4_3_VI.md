# GooHan Patch v4.3 — Native Pairing / Read-Only Session Test

**Phạm vi:** iOS 27.0–27.1 và 27.2 Beta 1/2 theo build `24B5084k`/`24B5089g`. Chỉ là phạm vi chẩn đoán, KHÔNG tuyên bố mọi build áp dụng Patch được.

## Chức năng mới

- Gọi **thật** `al_pairing_run_host` của AirliftFFI arm64 trên luồng nền; sử dụng callback service ID, cổng và Bonjour TXT để phát `_remotepairing-pairable-host._tcp.`.
- Hiển thị PIN chỉ trên màn hình thiết bị; không đưa PIN, pairing record, UDID, đường dẫn vào báo cáo.
- Chỉ công nhận native pairing khi mã trả về 0 **và** record đầu ra tồn tại trong thư mục bảo vệ nội bộ; thành công này chưa đủ chứng minh phiên vẫn hợp lệ.
- Có nút thăm dò phiên **chỉ đọc** bằng `al_syslog_stream_start` và `al_syslog_stream_stop` (5 giây). Chỉ ghi nhận có callback hay không; KHÔNG lưu, hiển thị hoặc gửi đi dòng syslog nào. Tín hiệu phiên không phải quyền ghi.
- Tắt chức năng ghi Patch AirLift: `GHInstalledPatchEngine.airLiftReady` vẫn `false`, chưa có receipt/restore xác thực.

## Cách chạy

1. Build trên GitHub Actions bằng Xcode/iOS arm64. Workflow tự giải nén `libairlift_ffi.a.zip` trước build.
2. Cài bản thử trên iPhone riêng, sao lưu dữ liệu. Bật LocalDevVPN; mở GooHan > Cài đặt > AirLift native pairing/session v4.3.
3. Bấm **Kiểm tra thư viện native** (đã xác nhận v4.2). Sau đó bấm **Bắt đầu ghép đôi trực tiếp**.
4. Mở Cài đặt iOS > Quyền riêng tư & Bảo mật > Chế độ nhà phát triển, làm theo thông báo của hệ thống nếu có. Nhập PIN hiển thị tại GooHan khi được iOS yêu cầu. Đôi khi iOS tạm dừng GooHan khi chuyển ứng dụng; việc này có thể làm pairing hết hạn.
5. Chỉ khi thấy `NATIVE_PAIRING_RETURNED_SUCCESS_RECORD_STORED`, thử **Kiểm tra phiên AirLift (không ghi dữ liệu)**. Sao chép báo cáo native v4.3.

**Phân biệt kết quả:**
- `NATIVE_PIN_PROMPT_SHOWN` / `BONJOUR_PUBLISHED`: máy chủ và thông báo PIN đang chạy, chưa hoàn tất pairing.
- `NATIVE_PAIRING_RETURNED_SUCCESS_RECORD_STORED`: native trả thành công và record đã được lưu (không phải đã Patch).
- `NATIVE_SYSLOG_EVENT_RECEIVED_NO_CONTENT`: native nhận được ít nhất một sự kiện từ phiên stream. Không lưu nội dung; không suy ra quyền ghi hay tương thích mọi ứng dụng.
- `NATIVE_SESSION_UNVERIFIED_*`: lỗi không đặc hiệu, có thể do tunnel, pairing, iOS, dịch vụ syslog hoặc giới hạn thực thi nền.
- `NATIVE_AIRLIFT_MISSING`: **vẫn xuất hiện** vì engine GOOHAN áp dụng/khôi phục Patch chưa được triển khai. Khác với native FFI hiện hữu.

**Không upload Pair File**, ảnh PIN, UDID, License, đường dẫn container. Không dùng bản này trên ứng dụng chứa dữ liệu quan trọng. Không có engine ghi và chưa xác minh trên thiết bị iOS 27.2 Beta 2.

## Kiểm tra trước phát hành

Mã này chưa được `xcodebuild` trong môi trường Linux; kiểm tra cú pháp Swift, cấu hình project, workflow và unit tests chỉ bắt lỗi tĩnh. Native host là tác vụ blocking; có thể không dừng đúng hạn trong nền iOS. Để phát hành sản phẩm Patch thực tế cần thư viện có nguồn gốc/giấy phép rõ ràng, kiểm tra pairing, quyền truy cập đích, transaction thật và chứng minh restore trước.
