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
