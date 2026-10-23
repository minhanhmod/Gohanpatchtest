# GooHan Patch iOS 27 — Sửa build Xcode 16.4 (v3.1)

## Lỗi xác định từ logs_108363838167.zip

- Job: Build unsigned iPhone app (GitHub Actions).
- Xcode: 16.4; Swift iPhone arm64; cấu hình Release `-O -whole-module-optimization`.
- `ThreeOneOSFive/ContentView.swift:361:9: error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions`.
- `exit code 65` chỉ là mã thoát của xcodebuild; cảnh báo `UIApplication.shared.windows` không làm build thất bại.

## Đã sửa

Tách biểu thức ViewBuilder lớn trong `ContentView.settingsView` thành 5 section (Engine, LocalDevVPN, Diagnostics, Theme, Actions) và tính báo cáo chẩn đoán trong hàm riêng. Giữ nguyên nhãn, cấu hình, phần báo cáo, chức năng License, giao diện màu, Admin, đồng bộ, và hành vi Patch.

**Đây là sửa lỗi biên dịch UI, không phải tích hợp AirLift native hoặc chứng nhận hỗ trợ ghi Patch trên iOS 27.**

## Cập nhật lên GitHub

- Nếu dự án `Gohanpatchtest` của bạn đã sử dụng bộ source LocalDev Readiness v3, tải bản `Changed_Only` và thay **duy nhất** `ThreeOneOSFive/ContentView.swift` trong repo. Không tạo folder bọc bên ngoài `ThreeOneOSFive`.
- Nếu repo đã pha trộn nhiều bản thử nghiệm, sử dụng `Full_Source` trong một nhánh thử nghiệm sạch (lưu bản repo trước đó nếu có sửa đổi).
- Vào Actions, chạy workflow build iPhone unsigned. Nếu lỗi khác xuất hiện, tải log mới.

## Kiểm thử đã chạy tại đây

- `bash tests/run_dualengine_smoke.sh`: PASS tất cả test hiện có (Legacy/AirLift coordinator, kiểm tra prewrite, iOS27 readiness, iOS policy, parse Swift, `plutil` kiểm tra project).
- Tất cả Swift source files parse thành công.
- Chưa có khả năng gọi Xcode để xác nhận build iPhone hoàn chỉnh; xác nhận cuối cùng phải chạy trên GitHub Actions/macOS.

## Lưu ý

- Không nhập file pairing nhạy cảm lên GitHub, ChatGPT hoặc server Admin.
- Mục LocalDevVPN chỉ nhận xác nhận thủ công; không thực sự xác minh VPN/tunnel và không cấp quyền ghi.
