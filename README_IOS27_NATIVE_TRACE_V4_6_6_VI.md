# GooHan Patch v4.6.6 — AirLift Connection Trace (thử nghiệm)

Bản này cập nhật từ v4.6.5, **không sửa thư viện Rust, không thay đổi lệnh gọi ghi hoặc mở khóa Patch Driver**.

## Thay đổi

- Ghi **số lượng** sự kiện callback theo sáu nhóm (pairing/auth, network, device service, permission, native-write, other).
- Ghi **nhóm sự kiện đầu tiên**, **cuối cùng** và **số lần đổi nhóm**, không lưu nội dung log thô.
- Ghi trạng thái lời gọi FFI và thời lượng cho lượt thử. `AL_TRACE_LAST_NETWORK` **không chứng minh network là nguyên nhân gốc**.
- Giữ giới hạn đích viết trong Application Support của GooHan và vẫn yêu cầu Session / Own Container / v4.5 pass. Khôi phục bằng Foundation khi thao tác FFI kết thúc.

## Cập nhật

Đối với repository đã dùng v4.6.5, thay các file từ ZIP Changed Only theo cấu trúc gốc, commit và chạy `Build GooHan Patch experimental IPA`. Không cần tải lại AirliftFFI.

## Thử trên iPhone dự phòng

1. Bật LocalDevVPN; dùng AppNew Routing như lượt trước.
2. Kiểm tra Native Session `rc=0`, `strict=yes`, sau đó Own Container và v4.5.
3. Chỉ khi bạn chấp nhận rủi ro của thư viện native, thử **một lần** trên fixture chỉ thuộc GooHan. Không chạy liên tục hoặc trên ứng dụng khác.
4. Xuất báo cáo bao gồm `Native rc`, `Native error class`, `Native trace hint`, `Native trace counters`, `Native phase`, `Native call duration ms`, Restore và Cleanup.
5. Nếu Native Write bị treo, không mở lại hoặc gỡ ứng dụng; gửi báo cáo lỗi/crash (không kèm Pair File, PIN, đường dẫn hay mã License).

Các bộ đếm không chứng minh tại sao native ghi lỗi. Bản thử này không áp dụng `.3105` trên iOS 27, chưa có AirLift Patch Driver. Chưa kiểm thử build/thiết bị iPhone trong môi trường tạo source.
