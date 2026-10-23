# GooHan Patch v5.4 — iOS 27 LocalDev Readiness v3

**Trạng thái: bản FULL SOURCE THỬ NGHIỆM, không phải bản AirLift native đã hoàn tất.**

Nguồn: bản `GooHanPatch_iOS18_6_27_Diagnostics_v2_Full_Source.zip` đã gửi trong dự án. Không xóa hoặc thay thế License, Admin, patch-catalog, backup/restore và bộ quản lý màu sắc/giao diện.

## 1. Đã tích hợp thực tế

- `GHLocalDevReadiness.swift`: đánh giá tình trạng iOS 27.0–27.2 theo build và khả năng có engine native; *không gán quyền ghi chỉ dựa vào phiên bản hoặc VPN*.
- `ContentView.swift`: mục LocalDevVPN trong **Cài đặt**, ô đánh dấu người dùng tự xác nhận đã bật LocalDevVPN, link tải App Store và báo cáo rõ ràng.
- Nút **Sao chép báo cáo chẩn đoán engine** thêm tình trạng LocalDev và AirLift, không thu thập File Pair, dữ liệu cá nhân, token, UDID hoặc đường dẫn riêng tư.
- `ThreeOneOSFive.xcodeproj/project.pbxproj`: liên kết Swift file mới vào target iOS.
- `tests/IOS27ReadinessTests.swift`: kiểm thử các trạng thái iOS 27, kiểm tra không có tuyên bố thành công giả.
- `tests/run_dualengine_smoke.sh`: bổ sung chạy test mới trước khi Xcode build.

## 2. Cách hoạt động hiện tại

1. Người dùng có thể mở **LocalDevVPN** riêng và bật kết nối trên iPhone. GooHan **không tự bật/điều khiển** VPN của ứng dụng khác.
2. Trong GooHan → Cài đặt → iOS 27 • LocalDevVPN, người dùng có thể đánh dấu **đã bật**. Đây là *xác nhận thủ công*, không phải probe mạng có quyền đặc biệt.
3. GooHan tính trạng thái chẩn đoán theo build iOS, xác nhận thủ công và việc có native AirLift provider hay chưa.
4. Nếu **không có AirLift native**, trạng thái là `NATIVE_AIRLIFT_MISSING` trên iOS 27.0–27.2. Ở hai build `24A435` và `24A437`, legacy engine vẫn chưa được xác minh, ứng dụng không tiến hành ghi thử vì rủi ro dữ liệu.
5. Khi native AirLift implementation đủ điều kiện được phát triển và kiểm thử riêng, bộ `GHAirLiftProvider` có sẵn là điểm gắn. Chỉ khi driver thật tồn tại, `GHPatchEngineCoordinator` mới có thể chọn nó. Adapter phải kiểm tra quyền, thực hiện backup và xác minh biên nhận khôi phục trước khi nhận thành công.
6. Backend License, Admin Sync và nhận/gỡ Patch qua biên nhận của engine cũ vẫn giữ nguyên.

## 3. Giới hạn chưa được giải quyết

- **Không** có mã AirLift của 3105 Beta 5 trong repository hiện tại: IPA biên dịch và chuỗi debug không thể biến thành native module.
- **Không** tích hợp khai thác AirTraffic/AFC để vượt ranh giới sandbox của iOS. Không đánh dấu iOS 27.0–27.2 là có quyền ghi khi chưa được kiểm thử thực tế.
- **Không** nhập/đọc File Pair, không tự tạo pairing record, không dò UDID.
- **Không** xác minh trạng thái kết nối LocalDevVPN tự động: ứng dụng thứ ba không được tự suy ra quyền truy cập của ứng dụng VPN khác từ dấu tích.
- Các dự án cộng đồng sử dụng AirLift báo cáo các bản iOS 27.2 beta mới có thể đã vá đường exploit. **Đừng hiểu “27.2” là tương thích toàn bộ.**

## 4. Cập nhật GitHub để build

Dùng repository thử nghiệm `https://github.com/minhanhmod/Gohanpatchtest`, không ghi đè repository phát hành:

**Full source**: giải nén ZIP, upload các tập tin ở thư mục gốc và commit. Kiểm tra có `ThreeOneOSFive/helpers/GHLocalDevReadiness.swift` và `.github/workflows/build-goohan-ipa.yml`.

**Changed Only**: giải nén và sao chép đúng đường dẫn tương đối (bao gồm `.github` nếu có). Không upload nguyên file ZIP như một file vào repository.

GitHub → Actions → `Build GooHan Patch experimental IPA` → Run workflow trên nhánh test. Artifact IPA **unsigned**, cần ký đúng môi trường kiểm thử. Không cài đè bản người dùng đang sử dụng vì GooHan và 3105 dùng Bundle ID trùng nhau.

## 5. Kiểm thử

Đã chạy trong container Linux:

- `bash tests/run_dualengine_smoke.sh` — **PASS**, gồm coordinator, preflight, trạng thái iOS 27, cú pháp Swift và project plist.
- `python -m unittest discover -s tests -p 'test_*.py' -q` — **12/12 PASS**.

**Chưa** chạy `xcodebuild` vì môi trường hiện tại không có Xcode; **chưa** cài thử trên iPhone iOS 27.0–27.2.

## 6. Dùng báo cáo để xác định vấn đề còn lại

Cài đặt → Sao chép báo cáo chẩn đoán engine. Hãy gửi **text** có:
- iOS build (ví dụ 24A435, 24A437 hoặc build 27.1/27.2 tương ứng)
- `LocalDevVPN: ...`
- `AirLift: ...`
- `Trạng thái: NATIVE_AIRLIFT_MISSING` nếu chưa tích hợp
- Giai đoạn cuối

Không gửi Pair File, License Key, secret, chứng chỉ, container dữ liệu, UDID hoặc log không được kiểm tra trước.

## 7. Tài liệu tham khảo

- https://github.com/YangJiiii/3105 — 3105, giấy phép GPL-3.0 (phần gốc)
- https://github.com/jkcoxson/LocalDevVPN — ứng dụng VPN phát triển cục bộ độc lập
- https://github.com/jkcoxson/idevice_pair — tiện ích ghép đôi (không được nhúng trong bản này)
- https://github.com/Mak5er/AirCard-iOS — tham khảo cộng đồng, không sao chép mã exploit

Các phần mã nguồn bên thứ ba phải được rà soát điều khoản cấp phép và quyền sử dụng trước khi tích hợp/phân phối.
