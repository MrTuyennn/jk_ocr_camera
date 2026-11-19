import CoreGraphics
import Foundation
#if canImport(OcrCore)
import OcrCore
#endif

/// Mặt giấy tờ đang chụp.
public enum CardSide: String {
    case front
    case back
}

/// Tuỳ chọn mở `IdCardScanFlowViewController`. Cùng schema với Android `IdCardScanOptions` (JSON)
/// và Flutter `ScanOptions`:
///
/// ```
/// side: "front" | "back", title, subtitle, captureButtonText, captureMode: "manual" | "auto",
/// readQr, saveImages, jpegQuality (1..100), maxImageBytes (byte, 0 = không giới hạn),
/// placement: { edgeTolerance, minWidthRatio, maxSkewDegrees }, messages: { "ekyc_error_blur": "...", ... }
/// ```
public struct IdCardScanOptions {
    public var side: CardSide = .front
    public var title: String?
    public var subtitle: String?
    public var captureButtonText: String?
    public var captureMode: CaptureMode = .manual
    public var readQr = true
    public var saveImages = true
    /// 1..100 (giống Android).
    public var jpegQuality = 95
    /// Dung lượng tối đa mỗi ảnh (byte); 0 = không giới hạn.
    public var maxImageBytes = 5 * 1024 * 1024
    public var placement = PlacementRules()
    public var messageOverrides: [String: String] = [:]

    public init() {}

    /// Đọc từ dictionary (vd. tham số MethodChannel). Trường thiếu / sai kiểu thì dùng mặc định.
    public init(dictionary d: [String: Any]) {
        if let v = d["side"] as? String, let side = CardSide(rawValue: v) { self.side = side }
        title = Self.nonEmpty(d["title"])
        subtitle = Self.nonEmpty(d["subtitle"])
        captureButtonText = Self.nonEmpty(d["captureButtonText"])
        if (d["captureMode"] as? String) == "auto" { captureMode = .auto }
        if let v = d["readQr"] as? Bool { readQr = v }
        if let v = d["saveImages"] as? Bool { saveImages = v }
        if let v = d["jpegQuality"] as? NSNumber { jpegQuality = v.intValue }
        if let v = d["maxImageBytes"] as? NSNumber { maxImageBytes = max(0, v.intValue) }
        if let p = d["placement"] as? [String: Any] {
            if let v = p["edgeTolerance"] as? NSNumber { placement.edgeTolerance = v.floatValue }
            if let v = p["minWidthRatio"] as? NSNumber { placement.minWidthRatio = v.floatValue }
            if let v = p["maxSkewDegrees"] as? NSNumber { placement.maxSkewDegrees = v.floatValue }
        }
        if let m = d["messages"] as? [String: Any] {
            messageOverrides = m.compactMapValues { $0 as? String }
        }
    }

    /// Cấu hình scanner tương ứng.
    public var scannerConfig: IdCardScannerConfig {
        var c = IdCardScannerConfig()
        c.captureMode = captureMode
        c.captureButtonTitle = captureButtonText
        c.readQr = readQr
        c.saveImages = saveImages
        c.jpegQuality = CGFloat(min(max(jpegQuality, 1), 100)) / 100
        c.maxImageBytes = maxImageBytes
        c.placement = placement
        c.messages = IdCardScannerMessages().withOverrides(messageOverrides)
        return c
    }

    private static func nonEmpty(_ v: Any?) -> String? {
        guard let s = v as? String, !s.isEmpty else { return nil }
        return s
    }
}

/// Chuyển `CardScanResult` sang dictionary (cùng schema với Android JSON / Flutter `ScanResult`).
/// Giá trị thiếu là `NSNull`. Chứa dữ liệu cá nhân: không log.
public enum CardScanResultCoding {

    public static func dictionary(_ r: CardScanResult, side: CardSide) -> [String: Any] {
        func rect(_ n: NormRect) -> [String: Any] {
            ["left": n.left, "top": n.top, "right": n.right, "bottom": n.bottom]
        }
        func orNull(_ v: Any?) -> Any { v ?? NSNull() }

        return [
            "side": side.rawValue,
            "imagePath": orNull(r.imagePath),
            "cardImagePath": orNull(r.cardImagePath),
            "qrRaw": orNull(r.qrRaw),
            "cardBounds": orNull(r.cardBounds.map(rect)),
            "quality": [
                "meanLuma": r.quality.meanLuma,
                "glareRatio": r.quality.glareRatio,
                "sharpness": r.quality.sharpness,
            ],
            "lines": r.lines.map { line -> [String: Any] in
                ["text": line.text, "box": rect(line.box), "confidence": orNull(line.confidence)]
            },
            "cccdQr": orNull(r.cccdQr.map { q -> [String: Any] in
                [
                    "idNumber": q.idNumber,
                    "oldIdNumber": orNull(q.oldIdNumber),
                    "fullName": orNull(q.fullName),
                    "dateOfBirth": orNull(q.dateOfBirth),
                    "sex": orNull(q.sex),
                    "address": orNull(q.address),
                    "issueDate": orNull(q.issueDate),
                    "rawFields": q.rawFields,
                ]
            }),
        ]
    }
}
