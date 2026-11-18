/// Hiện thực iOS của `jk_ocr_camera`. App dùng package `jk_ocr_camera`.
library;

import 'package:jk_ocr_camera_platform_interface/jk_ocr_camera_platform_interface.dart';

/// Dùng kênh `jk_ocr_camera`; phía native present `IdCardScanFlowViewController` của SDK OcrScanner.
class JkOcrCameraIOS extends MethodChannelJkOcrCamera {
  /// Flutter gọi khi đăng ký plugin.
  static void registerWith() {
    JkOcrCameraPlatform.instance = JkOcrCameraIOS();
  }
}
