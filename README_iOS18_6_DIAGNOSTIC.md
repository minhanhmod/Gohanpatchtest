# GooHan Patch — iOS 18.6 diagnostic update

## Báo cáo gốc

```
iOS 18.6.0 | build 22G86 | bản source hỗ trợ: có | AirLift: chưa tích hợp
DevicePatchService | select | Selected based on adapter availability
DevicePatchService | apply | Failure (possible partial write)
Giai đoạn cuối: Áp dụng Patch qua engine
```

**Không thể suy ra dữ liệu đã bị ghi dở chỉ từ thông báo trên**. Trước đây bộ điều phối ghi cùng một thông báo cho mọi lỗi từ `apply()`, kể cả lỗi tìm container.

## Thay đổi trong gói này

- `DevicePatchService.swift`: thêm `preflight(project:)`, chỉ thử phân giải danh sách container đích trước khi thực hiện giao dịch. Không thao tác thay thế tệp trong bước kiểm tra này. Nó **không đảm bảo quyền ghi**.
- `GHInstalledPatchEngine.swift`: nếu không tìm được container ở bước kiểm tra, báo nguyên nhân rõ hơn và phân loại lỗi xảy ra **trước thao tác ghi**.
- `GHPatchEngineCoordinator.swift`: tách lỗi `prewrite` và lỗi sau khi `apply()` bắt đầu; những trường hợp sau vẫn **không được tự động thử engine khác**, đồng thời chỉ ghi loại lỗi không nhạy cảm vào báo cáo.
- `tests/DualEngineWiringTests.swift`: bổ sung test container không sẵn sàng, xác nhận engine không tiến hành apply.

Không thay đổi API/License, chính sách hỗ trợ iOS, engine AirLift, dữ liệu Patch và logic Restore. Không bổ sung exploit, không khẳng định hỗ trợ iOS 27.0.

## Cách cập nhật GitHub

Sử dụng ZIP Changed Only; tải file đúng thư mục tương ứng của repo `minhanhmod/Gohanpatchtest`, commit lên nhánh thử nghiệm, chạy Actions. Không chép `README_iOS18_6_DIAGNOSTIC.md` vào `ThreeOneOSFive/helpers`.

## Kịch bản kiểm thử trên iPhone iOS 18.6

1. Sao lưu dữ liệu, bảo đảm ứng dụng đích đã cài và đóng hẳn trước khi áp dụng.
2. Trong GooHan xem trạng thái **Kernel Exploit**. Dòng "bản source hỗ trợ: có" không xác nhận quyền truy cập đã được kích hoạt. Nếu chưa kích hoạt, làm theo luồng chính thức trên thiết bị thử nghiệm phù hợp trước khi thử Patch.
3. Thử áp dụng **một** Patch không quan trọng với tệp đích mà bạn sở hữu/quản lý.
4. Mở phần Cài đặt > Chẩn đoán engine > Sao chép báo cáo; gửi nguyên báo cáo và **dòng thông báo lỗi dưới giao diện** (nếu có), sau khi lược bỏ mã khóa, đường dẫn cá nhân và dữ liệu nhạy cảm.
5. Nếu bản mới ghi `prewrite`, quá trình bị dừng trước khi thay thế tệp. Hãy kiểm tra app đích có tồn tại và trạng thái quyền truy cập.
6. Nếu ghi `apply` với `write status unknown`, không bật thử nhiều lần liên tiếp. Cần xác minh biên nhận/khôi phục trước vì có thể giao dịch đã ghi một phần.

Các bài kiểm thử trên máy phát triển không thay thế cho build Xcode hoặc thử trên thiết bị iOS thực tế.
