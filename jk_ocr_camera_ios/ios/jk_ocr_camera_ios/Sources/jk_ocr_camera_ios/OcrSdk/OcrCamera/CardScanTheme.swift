import UIKit

/// Màu sắc của màn hình quét. Mặc định bám theo UI tham khảo (vàng / đỏ / xanh).
public struct CardScanTheme {
    public var scanningColor = UIColor(red: 0xF5 / 255, green: 0xB8 / 255, blue: 0x41 / 255, alpha: 1)
    public var errorColor = UIColor(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255, alpha: 1)
    public var successColor = UIColor(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255, alpha: 1)
    public var errorToastBackground = UIColor(red: 0x45 / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 0.9)
    public var successToastBackground = UIColor(red: 0x14 / 255, green: 0x3D / 255, blue: 0x25 / 255, alpha: 0.9)
    public var textColor = UIColor.white
    public var secondaryTextColor = UIColor.white.withAlphaComponent(0.85)
    /// Lớp tối phủ thêm trên vùng blur ngoài khung.
    public var scrimColor = UIColor.black.withAlphaComponent(0.2)
    public var blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark
    public var backButtonBackground = UIColor.black.withAlphaComponent(0.35)
    /// Màu chữ thông báo thành công (chữ xanh trên nền xanh sẫm).
    public var successTextColor = UIColor(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255, alpha: 1)
    /// Màu chữ thông báo lỗi.
    public var errorTextColor = UIColor.white
    public var hintToastBackground = UIColor(red: 0x40 / 255, green: 0x34 / 255, blue: 0x10 / 255, alpha: 0.9)
    public var hintTextColor = UIColor.white
    public var captureButtonBackground = UIColor(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255, alpha: 1)
    public var captureButtonTextColor = UIColor.white

    public init() {}
}
