# GooHan Patch v4.6.5 — AppNew Route Trial (iOS 27)

Bản thử nghiệm dựa trên GooHan v4.6.4 + ý tưởng chọn host AirLiftFFI từ AppNew.zip.
Không sao chép toàn bộ AppNew. Thư viện `libairlift_ffi.a` vẫn là cùng phiên bản từ ProxyApp/AppNew và KHÔNG có Rust source.

## Thay đổi kỹ thuật

- Công tắc **Thử định tuyến AirLift theo AppNew** (mặc định TẮT).
- Khi bật và bấm Session/Own Container/Native Write, native bridge thiết lập host chính `10.7.0.1`, danh sách ứng viên `10.7.0.1`, `10.7.1.1`, `127.0.0.1` qua `al_set_target_host`/`al_set_target_hosts`.
- Khi tắt, native bridge gọi `al_clear_target_hosts` trở về host mặc định của thư viện.
- `GHRunNativeReadOnlySessionProbe` thu **nhóm lỗi đã biên tập** từ `out_error`; không công bố raw error, Pair File, PIN, đường dẫn, key License.
- Nếu cấu hình host bị từ chối, báo `AL_SESSION_HOST_ROUTING_FAILED` thay vì cố sử dụng cấu hình chưa xác minh.
- Mọi bước ghi vẫn bị khóa nếu Session, Own Container hay Backup/Restore test không đạt. Bản này không tích hợp Patch Driver vào `.3105`.

## Cách dùng

1. Upload các file trong ZIP Changed Only lên `Gohanpatchtest` đang chạy v4.6.4 (không tải lại thư viện 15 MB), hoặc upload Full Source nếu repository chưa có v4.6.4.
2. Build bằng GitHub Actions, ký và cài IPA trên máy thử nghiệm có quyền sử dụng.
3. Bật LocalDevVPN. Với toggle AppNew **TẮT**, chạy `Kiểm tra phiên AirLift (không ghi dữ liệu)`, lưu `Native rc`, `Session error class`.
4. Bật toggle AppNew **BẬT**, chạy lại Session một lần để so sánh mã lỗi và trạng thái. Nếu đạt, kiểm tra Own Container (chỉ chính GooHan).
5. Không thử Native Write nếu Session `rc: 1`, và không lặp lại khi Restore/Cleanup thất bại. Không thử trên dữ liệu game hoặc ứng dụng khác.
6. Gửi báo cáo redacted từ app, **không gửi Pair File/PIN/License hoặc log native raw**.

## Tiêu chí đánh giá

- Sự khác biệt `rc` giữa toggle OFF và ON là dữ liệu hữu ích để khoanh vùng lỗi chọn host; `rc=0` + event là kiểm tra phiên, KHÔNG phải bằng chứng quyền ghi.
- Nếu cả hai trả `rc=1`, nguyên nhân có thể là Pairing, dịch vụ thiết bị, trạng thái kết nối hoặc hạn chế bên trong Rust FFI; file này không khắc phục các nguyên nhân đó.
- Thành công bản v4.5 (Foundation trong sandbox) không chứng minh AirLift hay quyền ghi vào ứng dụng khác.

## Giới hạn

Kiểm tra cú pháp Swift và static tests không thay được `xcodebuild` trên macOS hoặc test thiết bị thật. Trước khi phát hành cần xác nhận xuất xứ/giấy phép của XCFramework và sao lưu–khôi phục được kiểm chứng. Không bao giờ dùng nhánh báo pairing/unpatch thành công giả của AppNew.
