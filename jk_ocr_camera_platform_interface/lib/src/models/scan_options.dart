/// Cách chụp khi giấy tờ đã đạt.
enum CaptureMode {
  /// Khung xanh + nút "Chụp ảnh", người dùng bấm mới chụp. (Mặc định)
  manual('manual'),

  /// Tự chụp khi giấy tờ đạt và đứng yên.
  auto('auto');

  const CaptureMode(this.wire);
  final String wire;
}

/// Tuỳ chọn màn hình quét.
class ScanOptions {
  const ScanOptions({
    this.captureMode = CaptureMode.manual,
    this.readQr = true,
    this.saveImages = true,
    this.jpegQuality = 90,
    this.edgeTolerance = 0.04,
    this.minWidthRatio = 0.6,
    this.maxSkewDegrees = 5,
  })  : assert(jpegQuality >= 1 && jpegQuality <= 100),
        assert(edgeTolerance >= 0 && edgeTolerance <= 0.5),
        assert(minWidthRatio > 0 && minWidthRatio <= 1),
        assert(maxSkewDegrees >= 0);

  final CaptureMode captureMode;

  /// Đọc QR (CCCD gắn chip có QR ở mặt trước).
  final bool readQr;

  /// Lưu ảnh khung hình + ảnh cắt theo thẻ (JPEG, thư mục cache của app). App tự xoá khi dùng xong.
  final bool saveImages;

  /// Chất lượng JPEG 1..100.
  final int jpegQuality;

  /// Cho phép giấy tờ lấn ra ngoài khung tối đa bấy nhiêu (tỉ lệ kích thước khung).
  /// Lấn nhiều hơn → báo lệch trên / dưới / trái / phải.
  final double edgeTolerance;

  /// Giấy tờ phải rộng ít nhất bấy nhiêu phần chiều rộng khung. Nhỏ hơn → báo "quá xa".
  final double minWidthRatio;

  /// Cạnh giấy tờ lệch quá bấy nhiêu độ so với khung → báo "xô lệch".
  final double maxSkewDegrees;

  Map<String, Object?> toMap() => <String, Object?>{
        'captureMode': captureMode.wire,
        'readQr': readQr,
        'saveImages': saveImages,
        'jpegQuality': jpegQuality,
        'placement': <String, Object?>{
          'edgeTolerance': edgeTolerance,
          'minWidthRatio': minWidthRatio,
          'maxSkewDegrees': maxSkewDegrees,
        },
      };
}
