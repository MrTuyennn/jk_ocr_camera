/// Quét giấy tờ tùy thân Việt Nam và OCR **offline**.
///
/// ```dart
/// final camera = JkOcrCamera();
/// final result = await camera.scanCard(side: CardSide.front);
/// if (result != null) {
///   print(result.cardImagePath);
///   print(result.cccdQr?.idNumber);
/// }
/// ```
library;

import 'package:jk_ocr_camera_platform_interface/jk_ocr_camera_platform_interface.dart';

export 'package:jk_ocr_camera_platform_interface/jk_ocr_camera_platform_interface.dart'
    show
        CaptureMode,
        CardSide,
        CccdQrData,
        FrameQuality,
        JkOcrErrorCode,
        JkOcrException,
        NormRect,
        ScanLocalized,
        ScanOptions,
        ScanResult,
        TextLine;

class JkOcrCamera {
  static JkOcrCameraPlatform get _platform => JkOcrCameraPlatform.instance;

  /// Mở màn hình quét một mặt giấy tờ (camera toàn màn hình, khung 16:9, báo lỗi realtime,
  /// nút "Chụp ảnh" khi giấy tờ đúng khung).
  ///
  /// - [side]: mặt trước / mặt sau. Dùng làm tiêu đề mặc định.
  /// - [options]: chế độ chụp, đọc QR, lưu ảnh, ngưỡng vị trí giấy tờ.
  /// - [localized]: đổi chữ hiển thị (tiêu đề, hướng dẫn, các thông báo lỗi).
  ///
  /// Trả về [ScanResult], hoặc `null` nếu người dùng bấm quay lại.
  /// Ném [JkOcrException] khi không có quyền camera ([JkOcrErrorCode.permissionDenied]),
  /// không mở được camera, hoặc đang có phiên quét khác.
  ///
  /// [ScanResult] là dữ liệu OCR thô + QR CCCD, **không** xác minh giấy tờ thật.
  Future<ScanResult?> scanCard({
    CardSide side = CardSide.front,
    ScanOptions? options,
    ScanLocalized? localized,
  }) {
    return _platform.scanCard(side: side, options: options, localized: localized);
  }
}
