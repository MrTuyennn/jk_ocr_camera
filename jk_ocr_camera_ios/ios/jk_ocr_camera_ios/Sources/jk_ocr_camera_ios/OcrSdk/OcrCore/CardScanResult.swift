import Foundation

/// Một dòng chữ OCR, trung lập với engine.
public struct TextLine: Equatable {
    public var text: String
    /// Vị trí chuẩn hóa theo **ô quét** (0..1, gốc trên-trái), có thể hơi vượt 0..1.
    public var box: NormRect
    /// 0..1, nil nếu engine không cung cấp.
    public var confidence: Float?

    public init(text: String, box: NormRect, confidence: Float?) {
        self.text = text
        self.box = box
        self.confidence = confidence
    }
}

/// Kết quả một lần quét thẻ (chưa phân loại / parse theo loại giấy tờ: các phase sau).
public struct CardScanResult: CustomStringConvertible {
    /// Dòng chữ trong ô quét, từ trên xuống, trái sang phải.
    public var lines: [TextLine]
    /// Chuỗi QR gốc nếu đọc được.
    public var qrRaw: String?
    /// QR đã parse theo định dạng CCCD.
    public var cccdQr: CccdQrData?
    public var quality: FrameQuality
    /// Biên thẻ, chuẩn hóa theo ô quét.
    public var cardBounds: NormRect?
    /// Ảnh khung hình đầy đủ (JPEG) nếu bật lưu ảnh. App tự xoá khi dùng xong.
    public var imagePath: String?
    /// Ảnh cắt theo thẻ (hoặc theo ô quét nếu không có biên thẻ). App tự xoá khi dùng xong.
    public var cardImagePath: String?

    public init(lines: [TextLine], qrRaw: String?, cccdQr: CccdQrData?, quality: FrameQuality, cardBounds: NormRect?,
                imagePath: String? = nil, cardImagePath: String? = nil) {
        self.lines = lines
        self.qrRaw = qrRaw
        self.cccdQr = cccdQr
        self.quality = quality
        self.cardBounds = cardBounds
        self.imagePath = imagePath
        self.cardImagePath = cardImagePath
    }

    public var fullText: String { lines.map(\.text).joined(separator: "\n") }

    public var description: String {
        "CardScanResult(lines=\(lines.count), hasQr=\(qrRaw != nil), cccdQr=\(cccdQr != nil))"
    }

    /// Gom dòng thành hàng (tâm dọc lệch ít hơn nửa chiều cao dòng đầu hàng), hàng từ trên xuống,
    /// trong hàng từ trái sang phải.
    public static func sortReadingOrder(_ lines: [TextLine]) -> [TextLine] {
        var rows: [[TextLine]] = []
        for line in lines.sorted(by: { $0.box.centerY < $1.box.centerY }) {
            if let anchor = rows.last?.first, abs(line.box.centerY - anchor.box.centerY) <= anchor.box.height / 2 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { $0.sorted { $0.box.left < $1.box.left } }
    }
}
