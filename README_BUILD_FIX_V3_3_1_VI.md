# GooHan Patch — Final Test v3.3.1: sửa lỗi GitHub Actions

## Lỗi trong logs_108393438450.zip

Workflow `Build GooHan Patch experimental IPA` dừng ở bước `Verify dual-engine coordinator and iOS compatibility policy`, với `AssertionError` tại `tests/check_localdev_probe_wiring.py` khi kiểm tra chuỗi `GHLocalDevProbe.swift in Sources` trong `ThreeOneOSFive.xcodeproj/project.pbxproj`.

Nguyên nhân: Gói `Final_Test_v3_3_Changed_Only.zip` trước đó thiếu `project.pbxproj` đã cập nhật. Việc chỉ đưa 7 file thay đổi lên GitHub khiến file Swift mới chưa được khai báo trong Xcode target, mặc dù kiểm thử Swift trước đó chạy thành công.

## Cài bản sửa tối thiểu

1. Giải nén `GooHanPatch_iOS27_v3_3_1_Project_Fix_Only.zip`.
2. Trên nhánh `main` của repository thử nghiệm `Gohanpatchtest`, thay file `ThreeOneOSFive.xcodeproj/project.pbxproj` bằng phiên bản trong ZIP (giữ đúng đường dẫn).
3. Giữ nguyên 7 file v3.3 trước đó, nhất là `ThreeOneOSFive/helpers/GHLocalDevProbe.swift` và `ThreeOneOSFive/helpers/GHLocalDevReadiness.swift`.
4. Commit; chạy lại workflow `Build GooHan Patch experimental IPA` từ Actions.
5. Nếu có lỗi mới ở bước Xcode build, tải ZIP log mới để phân tích. Lỗi đầu tiên trong log này xảy ra **trước khi xcodebuild bắt đầu**, vì thế log chưa tiết lộ liệu các bước biên dịch tiếp theo có thành công.

Nếu repo đã có nhiều sửa đổi khác ở file `.pbxproj`, nên so sánh trước khi ghi đè. Bản Full Source v3.3.1 là bộ source đồng nhất để thay thế cho repo thử nghiệm khi cần.

## Phạm vi kiểm tra

- Xác nhận `GHLocalDevProbe.swift` tồn tại trong `PBXFileReference`, `PBXBuildFile` và `PBXSourcesBuildPhase`.
- `bash tests/run_dualengine_smoke.sh` chạy thành công ở môi trường hiện tại; dự án `.pbxproj` qua `plutil -lint`.
- Chưa có build iOS hoàn chỉnh trên Xcode, chưa có AirLift native hoặc khả năng Patch iOS 27.

Không phát hành bản này làm engine Patch iOS 27 chính thức.
