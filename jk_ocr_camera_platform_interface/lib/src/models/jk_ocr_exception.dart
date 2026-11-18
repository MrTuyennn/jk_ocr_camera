import 'package:flutter/services.dart';

/// Mã lỗi native trả về.
enum JkOcrErrorCode {
  /// Người dùng từ chối quyền camera.
  permissionDenied('permission_denied'),

  /// Thiết bị không có camera / không mở được camera.
  cameraUnavailable('camera_unavailable'),

  /// Đang có một phiên quét khác mở.
  busy('busy'),

  /// Không tìm thấy Activity / ViewController để mở màn hình quét.
  noActivity('no_activity'),

  /// Lỗi khác.
  unknown('unknown');

  const JkOcrErrorCode(this.wire);
  final String wire;

  static JkOcrErrorCode fromWire(String? v) =>
      JkOcrErrorCode.values.firstWhere((c) => c.wire == v, orElse: () => JkOcrErrorCode.unknown);
}

/// Lỗi khi mở màn hình quét. Người dùng bấm quay lại **không** phải lỗi (`scanCard` trả `null`).
class JkOcrException implements Exception {
  const JkOcrException(this.code, [this.message]);

  factory JkOcrException.fromPlatform(PlatformException e) =>
      JkOcrException(JkOcrErrorCode.fromWire(e.code), e.message);

  final JkOcrErrorCode code;
  final String? message;

  @override
  String toString() => 'JkOcrException(${code.wire}${message == null ? '' : ': $message'})';
}
