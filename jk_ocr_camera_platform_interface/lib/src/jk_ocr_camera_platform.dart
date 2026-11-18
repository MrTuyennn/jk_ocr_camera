import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_jk_ocr_camera.dart';
import 'models/card_side.dart';
import 'models/scan_localized.dart';
import 'models/scan_options.dart';
import 'models/scan_result.dart';

/// Lớp nền mà mỗi nền tảng (`jk_ocr_camera_android`, `jk_ocr_camera_ios`) hiện thực.
abstract class JkOcrCameraPlatform extends PlatformInterface {
  JkOcrCameraPlatform() : super(token: _token);

  static final Object _token = Object();

  static JkOcrCameraPlatform _instance = MethodChannelJkOcrCamera();

  /// Hiện thực đang dùng. Mặc định [MethodChannelJkOcrCamera].
  static JkOcrCameraPlatform get instance => _instance;

  /// Package nền tảng gán hiện thực của mình khi đăng ký (`registerWith`).
  static set instance(JkOcrCameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Mở màn hình quét một mặt giấy tờ.
  ///
  /// Trả về [ScanResult], hoặc `null` nếu người dùng bấm quay lại.
  /// Ném `JkOcrException` khi không có quyền camera / không mở được camera.
  Future<ScanResult?> scanCard({
    CardSide side = CardSide.front,
    ScanOptions? options,
    ScanLocalized? localized,
  }) {
    throw UnimplementedError('scanCard() has not been implemented.');
  }
}
