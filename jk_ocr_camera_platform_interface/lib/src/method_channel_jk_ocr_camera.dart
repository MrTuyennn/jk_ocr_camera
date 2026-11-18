import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'jk_ocr_camera_platform.dart';
import 'models/card_side.dart';
import 'models/jk_ocr_exception.dart';
import 'models/scan_localized.dart';
import 'models/scan_options.dart';
import 'models/scan_result.dart';

/// Hiện thực dùng [MethodChannel] `jk_ocr_camera`. Android và iOS dùng chung giao thức:
///
/// - method `scanCard`, tham số: map theo [buildScanArguments].
/// - kết quả: map theo [ScanResult.fromMap], hoặc `null` khi huỷ.
/// - lỗi: `PlatformException` với `code` là một trong [JkOcrErrorCode].
class MethodChannelJkOcrCamera extends JkOcrCameraPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('jk_ocr_camera');

  @override
  Future<ScanResult?> scanCard({
    CardSide side = CardSide.front,
    ScanOptions? options,
    ScanLocalized? localized,
  }) async {
    try {
      final raw = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'scanCard',
        buildScanArguments(side: side, options: options, localized: localized),
      );
      return raw == null ? null : ScanResult.fromMap(raw);
    } on PlatformException catch (e) {
      throw JkOcrException.fromPlatform(e);
    }
  }

  /// Tham số gửi xuống native (cùng schema với Android `IdCardScanOptions` / iOS `IdCardScanOptions`).
  @visibleForTesting
  static Map<String, Object?> buildScanArguments({
    required CardSide side,
    ScanOptions? options,
    ScanLocalized? localized,
  }) {
    final o = options ?? const ScanOptions();
    final l = localized ?? const ScanLocalized();
    return <String, Object?>{
      'side': side.wire,
      if (l.title != null) 'title': l.title,
      if (l.subtitle != null) 'subtitle': l.subtitle,
      if (l.captureButton != null) 'captureButtonText': l.captureButton,
      ...o.toMap(),
      'messages': l.messagesToMap(),
    };
  }
}
