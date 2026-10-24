# GooHan Patch v4.5 — Own-Sandbox Backup / Write / Verify / Restore Test

**Trạng thái:** BẢN KIỂM THỬ, không phải bản Patch hoạt động trên iOS 27.
**Nguồn:** v4.4 (đã có AirLift FFI, LocalDev và phần kiểm tra phiên/container chỉ đọc).
**Phạm vi:** iOS 27.0 – iOS 27.2 Beta 2 theo kế hoạch nghiên cứu. Chưa kiểm chứng v4.5 trên iPhone thực tế.

## 1. Thay đổi

- `GHOwnSandboxTransactionCore.swift`: thực hiện giao dịch trên **tệp tổng hợp**, trong thư mục mới dành riêng cho bài test, không cho sử dụng lại thư mục đã tồn tại.
- `GHOwnSandboxTransactionReadiness.swift`: sử dụng **CryptoKit SHA-256 thực sự trên iOS** và tổng hợp báo cáo an toàn.
- Thử ba trường hợp trên iPhone: (1) Backup → Write → Verify → Restore; (2) giả lập lỗi ngay sau backup; (3) giả lập lỗi ngay sau write để kiểm chứng nhánh rollback.
- Các bài kiểm thử Swift tự động kiểm tra logic giao dịch, hai tình huống rollback và không làm thay đổi dữ liệu đã có.
- Giữ nguyên license, admin, các màn hình còn lại, firmware support policy, AirLift native link/pairing/session đã có; **không mở quyền ghi Patch iOS 27**.

## 2. Điều kiện và cách thử trên iPhone

1. Sử dụng iPhone thử nghiệm và **sao lưu dữ liệu của bạn**. Cài IPA v4.5 đã được ký hợp lệ từ GitHub Actions.
2. Bật LocalDevVPN nếu đang sử dụng nó cho phiên kết nối và mở GooHan → Cài đặt.
3. Chạy lại **Kiểm tra phiên AirLift (không ghi dữ liệu)** rồi **Kiểm tra container GooHan (AirLift, chỉ đọc)**. Yêu cầu `Session strict pass: yes` và `NATIVE_OWN_CONTAINER_READ_ONLY_OK` để mở khóa **bài test của chính GooHan**.
4. Tìm mục **iOS 27 • Giao dịch thử nghiệm v4.5**.
5. Lần lượt bấm ba nút: `1. Backup → Write → Verify → Restore`, `2. Giả lập lỗi sau Backup`, và `3. Giả lập lỗi sau Write`.
6. Nhấn **Sao chép báo cáo v4.5**, rồi gửi các **mã trạng thái**, không gửi Pair File, PIN, ID, đường dẫn hay license.

Dấu hiệu đạt mục tiêu giới hạn của v4.5:

```
V4.5 baseline roundtrip passed: yes
V4.5 rollback after backup passed: yes
V4.5 rollback after write passed: yes
V4.5 overall: V45_SELF_SANDBOX_ALL_TESTS_PASS_AIRLIFT_NOT_TESTED
V4.5 patch release gate: AIRLIFT_PATCH_DRIVER_MISSING
```

Các thử nghiệm lỗi sẽ cố ý phát sinh mã `V45_BACKUP_FAILED_ROLLED_BACK` hoặc `V45_REPLACE_FAILED_ROLLED_BACK`; đây là lỗi **được chủ động tạo ra** nhằm chứng minh rollback có thể hoạt động. Không diễn giải riêng chữ `FAILED` thành lỗi ứng dụng nếu dòng rollback được xác minh là `yes`.

## 3. Giới hạn quan trọng

- **Không có ghi AirLift trong v4.5.** Bài test chỉ sử dụng `Data.write(options: .atomic)` trong `Application Support/GHV45OwnSandboxFixtures` của **chính ứng dụng GooHan**.
- Tệp thử nghiệm chứa nội dung sinh ngẫu nhiên, không phải dữ liệu người dùng; mỗi lần chạy tạo một thư mục UUID mới. Thư mục được dọn khi thành công; khi thất bại giữ lại tệp nhỏ để tránh xóa mất bằng chứng và phục hồi lại bản sao lưu nếu đã được xác minh.
- Kết quả thành công **không chứng minh** đã xác thực toàn bộ Lockdown, có quyền ghi vào container ứng dụng thứ ba, có exploit hoạt động, xử lý được `.3105`, hay backup/restore khi tiến trình iOS bị kill đột ngột.
- AirLift Patch Driver vẫn thiếu. Không sửa/bỏ qua `SupportPolicy`, không biến bài kiểm tra này thành mở khóa ghi trên iOS 27.
- Thư viện `libairlift_ffi.a.zip` được giữ nguyên dạng nén để có thể upload qua GitHub giao diện web; workflow tự giải nén và xác minh như v4.4.

## 4. Cập nhật Gohanpatchtest

Nếu repo đang ở **v4.4 đầy đủ**: giải nén ZIP `Changed_Only`, upload đúng cấu trúc các file vào `Gohanpatchtest` gồm `ContentView.swift`, hai helper mới, Xcode pbxproj, workflow, hai test và tài liệu. `IOS27_STATUS_MANIFEST.json` cũng được cập nhật. **Không cần upload lại AirLift 15 MB**.

Chạy workflow `Build GooHan Patch experimental IPA` trong GitHub Actions. Khi build thành công, tải IPA unsigned để ký và cài thử. Không phát hành chính thức ở giai đoạn này.

Nếu repo chưa đủ file của v4.4, dùng Full Source v4.5 thay vì ZIP Changed Only.

## 5. Kiểm tra source đã thực hiện

- Test Swift giao dịch: success + 2 rollback + không ghi đè dữ liệu cũ: PASS (trên Linux).
- Smoke test Dual-Engine, localdev, native session, cấu hình Xcode: PASS.
- Swift parser và project plist: PASS.
- **Chưa chạy `xcodebuild` trên macOS và chưa có kết quả v4.5 trên iPhone thật.**

Bước phát triển sau test v4.5 không thể cam kết Patch thành công: cần một AirLift Patch Driver có quyền truy cập thực tế được kiểm chứng, xác minh sao lưu và khôi phục cho dữ liệu được phép xử lý, rồi thử end-to-end trên từng build iOS.
