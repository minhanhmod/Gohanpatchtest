# GooHan Dual-Engine Diagnostics v1 — tích hợp vào source được gửi

## Kết quả kiểm tra source

- Input: `GooHanPatch-Native-gohan-rebrand-no3105.zip` (Info.plist: GooHan 5.4, build 8, không phải IPA 5.3 đã gửi trước).
- Source hiện tại chặn iOS 27.0 bản chính thức: `ExploitSupportPolicy.isSupported` chỉ có allowlist iOS 27 Beta 1–4. `AppState.detectSupport` và `KernelExploit.isApplicable` đều dựa vào đó.
- `DevicePatchService.apply` bắt buộc `ContainerStore.resolveAppContainerPath` thành công, sau đó mới gọi `PatchTransaction.apply`. Thiếu container => báo lỗi; không có engine khác thay thế.

## Đã tích hợp

1. `GHPatchEngineCoordinator.swift`: serialize tác vụ apply, phân loại lựa chọn engine, kiểm tra receipt, chỉ fallback khi driver đảm bảo chưa có ghi tệp.
2. `GHInstalledPatchEngine.swift`: nối đường apply GooHan hiện có vào coordinator và xác minh receipt cũ trước khi báo thành công.
3. `GHAirLiftProvider.swift`: điểm cắm adapter AirLift, **chưa có thư viện native, chưa đăng ký driver thật**.
4. `ContentView.swift`: tùy chọn Tự động / GooHan cũ / AirLift (bị vô hiệu); hiển thị trạng thái engine, báo cáo chẩn đoán sao chép được; thông báo rõ build iOS chưa xác nhận trước khi ghi; giữ đường Restore cũ hoạt động.
5. `ThreeOneOSFive.xcodeproj/project.pbxproj`: thêm ba file Swift mới vào target GOHAN.

## Những gì KHÔNG được khẳng định

- Chưa hỗ trợ viết qua AirLift / CoreDevice trên iOS 27.0. IPA 3105 Beta 5 chứa chuỗi ký tự, không phải source AirLift.
- Không chỉnh allowlist exploit để chạy trên iOS 27.0 vì chưa kiểm chứng offsets/cơ chế quyền.
- Không thể build IPA iOS hoặc thử thực tế iPhone trong container Linux (không có Xcode).

## Cách build bản thử nghiệm

1. Sao lưu repo của bạn. Chép source từ ZIP này vào repository GitHub, không xóa dữ liệu server hay License.
2. Actions → `Build GooHan Patch experimental IPA` → `Run workflow` (build unsigned trong Xcode trên macOS).
3. Ký IPA bằng chứng chỉ phù hợp và kiểm tra lại `com.apple.mobile.MobileHouseArrest` trước khi cài.
4. Trên thiết bị đã được phép thao tác, kiểm tra iOS 18.x/26.x và mục Cài đặt → `Sao chép báo cáo chẩn đoán engine`. iOS 27.0 sẽ hiện chưa được xác minh, không cưỡng ép exploit.
5. Chỉ gắn adapter AirLift sau khi có mã nguồn tương thích thật, restore/rollback, biên nhận và kiểm thử trên thiết bị.

Không bao giờ quảng bá phiên bản này là bản sửa iOS 27.0 cho đến khi đã thử nghiệm thành công.
