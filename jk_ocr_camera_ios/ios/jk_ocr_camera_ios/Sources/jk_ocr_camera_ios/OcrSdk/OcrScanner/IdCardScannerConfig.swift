import CoreGraphics
import Foundation
#if canImport(OcrCore)
import OcrCore
#endif

/// Thông báo hiển thị. Mặc định đọc từ `Resources/vi.lproj/Localizable.strings` của OcrScanner
/// (khoá `ekyc_*`, cùng tên với string resource Android). Đổi từng chuỗi qua thuộc tính.
public struct IdCardScannerMessages {
    /// Không có giấy tờ trong khung (`ekyc_error_no_card`), hiện dạng nhắc nhở (khung vàng).
    public var noCard = ScannerL10n.string("ekyc_error_no_card")
    public var tooDark = ScannerL10n.string("ekyc_error_dark")
    public var tooBright = ScannerL10n.string("ekyc_error_bright")
    public var glare = ScannerL10n.string("ekyc_error_glare")
    /// Ảnh mờ (`ekyc_error_blur`).
    public var blurry = ScannerL10n.string("ekyc_error_blur")
    /// Thay dòng hướng dẫn khi ảnh mờ (`ekyc_title_card_blur`).
    public var blurryTitle = ScannerL10n.string("ekyc_title_card_blur")
    public var offsetTop = ScannerL10n.string("ekyc_error_card_top")
    public var offsetBottom = ScannerL10n.string("ekyc_error_card_bottom")
    public var offsetLeft = ScannerL10n.string("ekyc_error_card_left")
    public var offsetRight = ScannerL10n.string("ekyc_error_card_right")
    /// Thẻ xoay / nghiêng (`ekyc_title_wobbly`).
    public var skewed = ScannerL10n.string("ekyc_title_wobbly")
    public var tooClose = ScannerL10n.string("ekyc_error_too_close")
    public var tooFar = ScannerL10n.string("ekyc_error_too_far")
    /// Chế độ `.auto`: thẻ đạt, đang chờ đứng yên để tự chụp.
    public var holdStill = ScannerL10n.string("ekyc_title_hold_still")
    /// Chế độ `.manual`: thẻ đạt, hiện nút chụp.
    public var ready = ScannerL10n.string("ekyc_title_card_ready")
    /// Đang đọc chữ / QR sau khi chụp.
    public var reading = ScannerL10n.string("ekyc_title_reading")
    public var readFailed = ScannerL10n.string("ekyc_error_read_failed")

    public init() {}

    /// Ghi đè theo khoá (`ekyc_error_blur`, `ekyc_title_card_ready`...), cùng khoá với Android.
    /// Khoá lạ bị bỏ qua. Dùng khi cấu hình từ Flutter / dictionary.
    public func withOverrides(_ o: [String: String]) -> IdCardScannerMessages {
        var m = self
        if let v = o["ekyc_error_no_card"] { m.noCard = v }
        if let v = o["ekyc_error_dark"] { m.tooDark = v }
        if let v = o["ekyc_error_bright"] { m.tooBright = v }
        if let v = o["ekyc_error_glare"] { m.glare = v }
        if let v = o["ekyc_error_blur"] { m.blurry = v }
        if let v = o["ekyc_title_card_blur"] { m.blurryTitle = v }
        if let v = o["ekyc_error_card_top"] { m.offsetTop = v }
        if let v = o["ekyc_error_card_bottom"] { m.offsetBottom = v }
        if let v = o["ekyc_error_card_left"] { m.offsetLeft = v }
        if let v = o["ekyc_error_card_right"] { m.offsetRight = v }
        if let v = o["ekyc_title_wobbly"] { m.skewed = v }
        if let v = o["ekyc_error_too_close"] { m.tooClose = v }
        if let v = o["ekyc_error_too_far"] { m.tooFar = v }
        if let v = o["ekyc_title_hold_still"] { m.holdStill = v }
        if let v = o["ekyc_title_card_ready"] { m.ready = v }
        if let v = o["ekyc_title_reading"] { m.reading = v }
        if let v = o["ekyc_error_read_failed"] { m.readFailed = v }
        return m
    }
}

public enum CaptureMode {
    /// Thẻ đạt → khung xanh + nút chụp; người dùng bấm mới đọc. (Mặc định)
    case manual
    /// Thẻ đạt và đứng yên `stableFramesRequired` khung → tự đọc.
    case auto
}

public struct IdCardScannerConfig {
    public var captureMode: CaptureMode = .manual
    /// Chữ trên nút chụp; nil = `ekyc_button_capture`.
    public var captureButtonTitle: String?
    public var thresholds = QualityThresholds()
    /// Thẻ phải nằm gọn trong khung, thẳng góc và đủ lớn.
    public var placement = PlacementRules()
    public var messages = IdCardScannerMessages()
    /// Chế độ `.auto`: số khung liên tiếp thẻ phải đứng yên trước khi tự đọc (~30 fps).
    public var stableFramesRequired = 8
    /// Có đọc QR không (CCCD gắn chip có QR ở mặt trước).
    public var readQr = true
    /// Ít hơn số dòng này trong khung (và không có QR) thì coi là đọc thất bại.
    public var minTextLines = 3
    /// Thời gian giữ thông báo lỗi đọc thất bại trước khi quét lại.
    public var readFailedHold: TimeInterval = 1.5
    /// Lưu ảnh khung hình + ảnh cắt theo thẻ vào `Caches/jk_ocr/` khi chụp.
    public var saveImages = true
    /// Chất lượng JPEG 0..1.
    public var jpegQuality: CGFloat = 0.9

    public init() {}
}

/// Chuỗi của OcrScanner, bảng `OcrScanner.strings`.
enum ScannerL10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: "OcrScanner", bundle: ScannerResourceBundle.bundle, comment: "")
    }
}

/// Xem `OcrResourceBundle` (OcrCamera). Khi gộp một pod, hai enum trỏ cùng resource bundle.
enum ScannerResourceBundle {
    static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let host = Bundle(for: BundleToken.self)
        if let url = host.url(forResource: "JkOcrResources", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return host
        #endif
    }()

    private final class BundleToken {}
}
