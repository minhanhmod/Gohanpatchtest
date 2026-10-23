# GooHan Patch — iOS 27 Native Link Test v4 (Full Source)

## Mục đích
Kiểm chứng rằng thư viện AirliftFFI do bạn cung cấp có thể được liên kết vào GooHan và gọi được trên iPhone iOS 27.0 và 27.2 Beta 2; không đồng nhất việc liên kết thành công với khả năng ghi Patch.

## Những gì bản này có
- Source GooHan đầy đủ từ v3.3.1; giữ License, Admin, hệ thống tải .3105 và sao lưu/khôi phục cũ.
- Framework AirliftFFI.xcframework arm64 từ proxyapp-main.zip; được thêm vào Xcode target và gọi hàm FFI cấu hình host không ghi dữ liệu.
- Cài đặt → iOS 27 • AirLift native link test: nút kiểm tra thư viện, nhập/xóa pairing file từ Files theo yêu cầu, không gửi lên server.
- Phép thử TCP LocalDev từ v3.3, nhật ký không bao gồm pairing hay License.
- Chính sách iOS 27 vẫn chặn thao tác Patch khi chưa có driver có xác thực và biên nhận khôi phục thật.

## Kết quả trên màn hình
- `NATIVE_FFI_CALL_OK_ONLY`: Swift→Objective-C→Rust FFI chạy thành công. KHÔNG xác minh LocalDev, pairing, quyền ghi.
- `PAIRING_FILE_STORED_NOT_AUTHENTICATED`: file pairing được nhập, CHƯA xác minh cryptographic handshake.
- `LOCAL_TCP_PORT_REACHABLE_ONLY`: có phản hồi TCP, chưa xác thực dịch vụ.
- `NATIVE_AIRLIFT_MISSING`: engine ghi Patch chưa được tích hợp. Đây là trạng thái đúng, không phải lỗi build.

## Cách build thử
1. Dùng ZIP Full Source, tải nguyên cấu trúc repository lên nhánh test của `Gohanpatchtest`, không chồng những file lẻ của v3.3 nếu không chắc đầy đủ.
2. Actions → Build GooHan Patch experimental IPA → Run workflow. Build arm64 iPhone, unsigned IPA.
3. Nếu build lỗi, tải nguyên log Actions và gửi. Lỗi Rust static link có thể đòi hỏi hiệu chỉnh thư viện; môi trường Linux không có Xcode để xác nhận.
4. Ký IPA bằng chứng chỉ hợp pháp của bạn, cài trên máy thử có sao lưu. Chỉ chạy LocalDev probe, Native FFI test và nhập pairing nếu cần; không tải pairing lên GitHub/ChatGPT.
5. Đối chiếu kết quả trên iOS 27.0 và iOS 27.2 beta 2. Với beta 2 phải đọc đúng build OS.

## Vì sao chưa Patch được trên iOS 27
Thư viện FFI có hàm ghi AirTraffic, nhưng source ProxyApp triển khai `isPaired` thiếu xác thực thật, lưu recovery receipt giả và có đường ghi không thể khôi phục. Các phần đó không được chuyển sang GooHan. Cần bộ adapter được đánh giá bảo mật, pairing thực sự được xác nhận, đọc bản gốc/sao lưu, xác minh hash sau ghi và restore thực sự. Không sử dụng binary chưa xác minh để vượt bảo vệ container.

## An toàn
Chỉ sửa thông tin thử nghiệm trong sandbox ứng dụng do chính bạn sở hữu/quản lý. Không tự động đánh dấu engine ready. Không giả lập phiếu khôi phục. Không gửi key/pairing record/PIN lên admin. Không xác nhận iOS 27.2 beta 3+ hoạt động.
