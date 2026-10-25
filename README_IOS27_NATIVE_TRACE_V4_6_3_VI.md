# GooHan v4.6.3 — chẩn đoán giai đoạn native AirLift (iOS 27)

## Bằng chứng hiện tại
- iOS 27.0 `24A435`: phiên syslog `rc=0`, tra cứu container GooHan thành công.
- Thử ghi native vào fixture của chính GooHan: `rc=1`, `AL_ERROR_UNCLASSIFIED`.
- Staging SHA-256, sao lưu, khôi phục và cleanup thành công.
- CHƯA xác minh AirLift có thể ghi hoặc Patch được iOS 27.

## Thay đổi so với v4.6.2
Thay `NULL` trong tham số callback log của `al_exploit_write_dir` bằng callback chỉ ghi nhận **gợi ý giai đoạn cho phép**. Không lưu/truyền/copy các dòng log thô, đường dẫn, tài khoản hay thông tin pairing.

Báo cáo thêm `Native trace hint (redacted)`:
- `AL_TRACE_HINT_PAIRING_OR_AUTH`
- `AL_TRACE_HINT_TUNNEL_OR_NETWORK`
- `AL_TRACE_HINT_DEVICE_SERVICE`
- `AL_TRACE_HINT_PERMISSION`
- `AL_TRACE_HINT_NATIVE_WRITE`
- `AL_TRACE_LOGS_SEEN_UNCLASSIFIED`
- `AL_TRACE_NO_LOG_CALLBACKS`

Lưu ý: đây là **gợi ý từ dòng log cuối có từ khóa**, KHÔNG phải bằng chứng nguyên nhân lỗi. `Native rc:1` vẫn là kết quả thất bại.

## Quan trọng
Không cần kiểm tra lại TCP hoặc ghi liên tục. Bản thử vẫn chỉ làm việc với fixture của chính GooHan. Không dùng để ghi ứng dụng khác. Nếu muốn thử một lần nữa, chỉ chạy trên thiết bị dự phòng, giữ bản sao lưu, yêu cầu Session/Own Container và v4.5 đạt trước.

## Cập nhật
Cập nhật các file trong ZIP Changed Only lên `Gohanpatchtest` đang dùng v4.6.2, giữ nguyên cấu trúc thư mục. Không cần tải lại libairlift nén 15MB.
Chạy GitHub Actions; chưa có kết quả `xcodebuild`/thiết bị thật cho v4.6.3.

## Hạn chế còn lại
Phần native Rust đóng gói trong `libairlift_ffi.a` không có source Rust tương ứng trong source được cung cấp. Xác định nguyên nhân tuyệt đối có thể cần source Rust hoặc log gốc được bảo vệ cục bộ; chỉ số FFI và từ khóa chưa đủ.
