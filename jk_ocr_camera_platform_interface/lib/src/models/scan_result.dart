import 'card_side.dart';

/// Hình chữ nhật chuẩn hóa 0..1, gốc trên-trái. Trong [ScanResult] toạ độ theo **khung quét**.
class NormRect {
  const NormRect({required this.left, required this.top, required this.right, required this.bottom});

  factory NormRect.fromMap(Map<Object?, Object?> m) => NormRect(
        left: _d(m['left']),
        top: _d(m['top']),
        right: _d(m['right']),
        bottom: _d(m['bottom']),
      );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  String toString() => 'NormRect($left, $top, $right, $bottom)';
}

/// Một dòng chữ OCR.
class TextLine {
  const TextLine({required this.text, required this.box, this.confidence});

  factory TextLine.fromMap(Map<Object?, Object?> m) => TextLine(
        text: m['text'] as String? ?? '',
        box: NormRect.fromMap(_map(m['box'])),
        confidence: (m['confidence'] as num?)?.toDouble(),
      );

  final String text;

  /// Vị trí theo khung quét (0..1), có thể hơi vượt nếu dòng chữ tràn ra ngoài khung.
  final NormRect box;

  /// 0..1, `null` nếu engine không cung cấp.
  final double? confidence;
}

/// Dữ liệu QR trên CCCD gắn chip. Chứa dữ liệu cá nhân: không log.
class CccdQrData {
  const CccdQrData({
    required this.idNumber,
    this.oldIdNumber,
    this.fullName,
    this.dateOfBirth,
    this.sex,
    this.address,
    this.issueDate,
    this.rawFields = const [],
  });

  factory CccdQrData.fromMap(Map<Object?, Object?> m) => CccdQrData(
        idNumber: m['idNumber'] as String? ?? '',
        oldIdNumber: m['oldIdNumber'] as String?,
        fullName: m['fullName'] as String?,
        dateOfBirth: m['dateOfBirth'] as String?,
        sex: m['sex'] as String?,
        address: m['address'] as String?,
        issueDate: m['issueDate'] as String?,
        rawFields: (m['rawFields'] as List<Object?>? ?? const []).map((e) => '$e').toList(),
      );

  final String idNumber;
  final String? oldIdNumber;
  final String? fullName;

  /// dd/MM/yyyy
  final String? dateOfBirth;
  final String? sex;
  final String? address;

  /// dd/MM/yyyy
  final String? issueDate;

  /// Các trường gốc (tách theo `|`).
  final List<String> rawFields;

  @override
  String toString() => 'CccdQrData(<redacted>, fields=${rawFields.length})';
}

/// Chỉ số chất lượng ảnh lúc chụp.
class FrameQuality {
  const FrameQuality({required this.meanLuma, required this.glareRatio, required this.sharpness});

  factory FrameQuality.fromMap(Map<Object?, Object?> m) => FrameQuality(
        meanLuma: _d(m['meanLuma']),
        glareRatio: _d(m['glareRatio']),
        sharpness: _d(m['sharpness']),
      );

  /// Độ sáng trung bình 0..255.
  final double meanLuma;

  /// Tỉ lệ điểm cháy sáng 0..1.
  final double glareRatio;

  /// Phương sai Laplacian (càng lớn càng nét).
  final double sharpness;
}

/// Kết quả một lần quét.
///
/// Đây là **dữ liệu OCR thô** (dòng chữ + vị trí) và **QR CCCD đã tách trường**. Chưa phân loại
/// giấy tờ / parse theo từng loại / validation, và **không xác minh giấy tờ thật**.
/// Chứa dữ liệu cá nhân: không log.
class ScanResult {
  const ScanResult({
    required this.side,
    required this.lines,
    required this.quality,
    this.imagePath,
    this.cardImagePath,
    this.qrRaw,
    this.cccdQr,
    this.cardBounds,
  });

  factory ScanResult.fromMap(Map<Object?, Object?> m) => ScanResult(
        side: CardSide.fromWire(m['side']),
        imagePath: m['imagePath'] as String?,
        cardImagePath: m['cardImagePath'] as String?,
        qrRaw: m['qrRaw'] as String?,
        cccdQr: m['cccdQr'] == null ? null : CccdQrData.fromMap(_map(m['cccdQr'])),
        cardBounds: m['cardBounds'] == null ? null : NormRect.fromMap(_map(m['cardBounds'])),
        quality: FrameQuality.fromMap(_map(m['quality'])),
        lines: (m['lines'] as List<Object?>? ?? const []).map((e) => TextLine.fromMap(_map(e))).toList(),
      );

  final CardSide side;

  /// Ảnh khung hình đầy đủ (JPEG). `null` nếu tắt `saveImages` hoặc lưu lỗi.
  final String? imagePath;

  /// Ảnh cắt theo giấy tờ (JPEG).
  final String? cardImagePath;

  /// Dòng chữ trong khung, từ trên xuống, trái sang phải.
  final List<TextLine> lines;

  /// Chuỗi QR gốc.
  final String? qrRaw;

  /// QR đã tách theo định dạng CCCD.
  final CccdQrData? cccdQr;

  /// Biên giấy tờ theo khung quét.
  final NormRect? cardBounds;

  final FrameQuality quality;

  /// Toàn bộ chữ, mỗi dòng một hàng.
  String get fullText => lines.map((l) => l.text).join('\n');

  @override
  String toString() =>
      'ScanResult(side=${side.wire}, lines=${lines.length}, hasQr=${qrRaw != null}, cccdQr=${cccdQr != null})';
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

Map<Object?, Object?> _map(Object? v) => (v as Map<Object?, Object?>?) ?? const {};
