## 1.0.1

Quét giấy tờ **cầm trên tay** ổn định hơn (trước đây chủ yếu chỉ quét được khi đặt trên bàn trơn).

- Android: viết lại bộ dò cạnh giấy tờ. Không còn chọn "đường biên ngoài cùng" cho từng cạnh, mà chọn **cả bộ 4
  cạnh** theo tỉ lệ thẻ, độ liền mạch, phía trong đồng nhất / khác bên ngoài. Hết lỗi lấy nhầm biên của **nền rối
  phía sau** (báo sai "lệch trên/dưới" hoặc "không có giấy tờ"). Chịu được ngón tay che tới ~35% giữa cạnh và nền gần
  màu thẻ (ngưỡng tương phản tự điều chỉnh).
- iOS: Vision lấy tối đa 10 ứng viên và ưu tiên đúng tỉ lệ thẻ; sửa lỗi thẻ **xoay** bị loại nhầm (tỉ lệ tính theo cạnh
  thật thay vì hình bao); khi Vision không thấy (vd. ngón tay che góc thẻ) thì dùng bộ dò biên làm dự phòng.
- Cả hai: bám theo giấy tờ giữa các khung hình, trượt 1–3 khung khi rung tay không làm trạng thái nhảy sang
  "không có giấy tờ". Chỉ chụp khi chính khung hiện tại thấy giấy tờ.
- `ScanOptions.jpegQuality` mặc định 90 → 95; thêm `maxImageBytes` (mặc định 5 MB mỗi ảnh, `0` = không giới hạn). Vượt giới hạn thì giảm chất lượng (>= 50) rồi thu nhỏ kích thước.
- `ScanOptions.maxSkewDegrees` giữ mặc định 5°; chụp cầm tay có thể đặt `maxSkewDegrees: 8` cho dễ chụp hơn.

## 1.0.0

Bản phát hành đầu tiên.

- `JkOcrCamera().scanCard(side:, options:, localized:)` mở màn hình quét giấy tờ native, trả `ScanResult?`
  (`null` khi người dùng bấm quay lại), ném `JkOcrException` khi không có quyền / không mở được camera.
- Màn hình quét: camera toàn màn hình, khung 16:9, blur xung quanh, thông báo lỗi realtime (tối, sáng, lóa, mờ,
  lệch trên/dưới/trái/phải, xô lệch, quá gần, quá xa, không có giấy tờ), nút "Chụp ảnh" khi đúng khung,
  hoặc tự chụp (`CaptureMode.auto`).
- Kết quả: ảnh JPEG (khung hình + cắt theo giấy tờ), dòng chữ OCR kèm vị trí, QR CCCD đã tách trường.
- Chạy offline hoàn toàn: Android dùng ML Kit bundled + CameraX, iOS dùng Apple Vision + AVFoundation.
- Toàn bộ chữ hiển thị đổi được qua `ScanLocalized` (khoá `ekyc_*`).
