# GooHan Patch — Điều tra tương thích iOS 18.6 / iOS 27.0 (Diagnostic v2)

**Đây là bản CHẨN ĐOÁN, không phải bản vá AirLift hoặc bản chứng minh hỗ trợ iOS 27.0.**

## Các lỗi đã phân loại từ báo cáo thiết bị

- iOS 18.6.0 / 22G86: chính sách hỗ trợ cho phép, `DevicePatchService` được chọn, `prewrite` thất bại; không bắt đầu ghi tệp.
- iOS 27.0 / 24A435: bị dừng ở SupportPolicy trước khi gọi engine.
- iOS 27.0 / 24A437: bị dừng ở SupportPolicy trước khi gọi engine.
- Người dùng nói 3105 Beta 5 hoạt động trên cả hai build iOS 27, không nhập Pair File thủ công. Chưa có kết quả tái hiện độc lập ở đây.

## Thay đổi trong bản này

1. `GHInstalledPatchEngine.swift`: mã lỗi cố định `TARGET_CONTAINER_UNRESOLVED`, `PATCH_PACKAGE_PREFLIGHT_ERROR`, `CONTAINER_PREFLIGHT_ERROR` cho các trường hợp thất bại *trước khi ghi*; phân biệt riêng build 24A435 và 24A437 trong báo cáo.
2. `GHPatchEngineCoordinator.swift`: ghi mã lỗi prewrite vào nhật ký an toàn, không ghi đường dẫn/container ID.
3. `ContentView.swift`: khi sao chép chẩn đoán, kèm trạng thái quyền truy cập từ `AppState` và sandbox probe ở mức có/không; trên iOS 17–18, sandbox probe không thay thế chỉ báo kernel R/W.
4. `tests/DualEngineWiringTests.swift`: khẳng định mã phân loại xuất hiện đúng khi preflight thất bại.

## Kiểm thử

- `bash tests/run_dualengine_smoke.sh`: đạt (Linux Swift 6.2.1, kiểm tra cú pháp toàn bộ Swift và project pbxproj).
- `python -m unittest discover -s tests -p 'test_*.py' -q`: 12/12 đạt.
- Chưa biên dịch ứng dụng iOS bằng Xcode, chưa cài trên thiết bị thực; kiểm tra cú pháp không thay thế kiểm tra type-check/linked iOS frameworks.

## Cập nhật repository thử nghiệm

- Dùng ZIP `Changed_Only` nếu repository đã có bản `GooHanPatch_v5_4_iOS18_6_Preflight_Diagnostics_Full_Source` từ lần trước.
- Với `Full_Source`, tải mã nguồn vào nhánh thử nghiệm riêng, **không ghi đè dữ liệu/IPA phát hành**.
- File Swift trong Changed_Only phải vào đúng `ThreeOneOSFive/helpers/` và `ThreeOneOSFive/ContentView.swift`.
- Giữ nguyên Bundle ID, chứng chỉ, License, Admin và dữ liệu khôi phục; không tự ý nhập hay tải lên pairing record.

## Cách thu thập chẩn đoán

1. Dùng thiết bị thử nghiệm với tệp dữ liệu không nhạy cảm và đã sao lưu.
2. Trong GooHan: Cài đặt → Sao chép báo cáo chẩn đoán engine.
3. Gửi chỉ *báo cáo đã loại thông tin cá nhân*, cùng iOS version/build, loại thiết bị và lỗi hiển thị; **không gửi** Pair File, dữ liệu game, UDID, key, token hoặc file chứa dữ liệu cá nhân.
4. Nếu iOS 18.6 ghi `Trạng thái quyền truy cập (phiên): Not attempted`, cần biết kernel access chưa được thiết lập từ luồng khởi động hiện tại; không được suy ra chắc chắn đây là nguyên nhân duy nhất.
5. Nếu `TARGET_CONTAINER_UNRESOLVED`, hãy kiểm tra ứng dụng đích được cài hợp lệ và log MHA-C2 *sau khi đã làm sạch dữ liệu nhạy cảm*. Không thử ghi khi trạng thái không xác định.

## Không nên làm

- Không đổi `SupportPolicy` thành hỗ trợ toàn bộ iOS 27 chỉ vì 3105 Beta 5 hoạt động: engine AirLift native chưa được tích hợp.
- Không thêm tên/hàm AirLift giả hay ghi thành công giả.
- Không thử hai engine liên tiếp nếu thao tác ghi trước có thể đã diễn ra một phần.
- Không trộn chức năng khai thác kernel/thoát sandbox vào bản phân phối cho người dùng khi chưa đánh giá an toàn, quyền sử dụng và tác động pháp lý.

Xem `APPLE_FEEDBACK_DRAFT_EN.md` và `APPLE_SECURITY_RESEARCH_NOTES_EN.md` trong bản Full Source.
