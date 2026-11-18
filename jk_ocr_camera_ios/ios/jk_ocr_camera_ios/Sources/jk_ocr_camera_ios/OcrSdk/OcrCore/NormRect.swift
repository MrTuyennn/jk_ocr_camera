import Foundation

/// Hình chữ nhật chuẩn hóa (0..1), gốc trên-trái, theo hệ toạ độ do ngữ cảnh quy định.
public struct NormRect: Equatable {
    public var left: Float
    public var top: Float
    public var right: Float
    public var bottom: Float

    public init(left: Float, top: Float, right: Float, bottom: Float) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    public static let full = NormRect(left: 0, top: 0, right: 1, bottom: 1)

    public var width: Float { right - left }
    public var height: Float { bottom - top }
    public var centerX: Float { (left + right) / 2 }
    public var centerY: Float { (top + bottom) / 2 }
    public var isEmpty: Bool { width <= 0 || height <= 0 }

    /// Intersection over Union, 0..1.
    public func iou(_ other: NormRect) -> Float {
        let l = max(left, other.left), t = max(top, other.top)
        let r = min(right, other.right), b = min(bottom, other.bottom)
        guard r > l, b > t else { return 0 }
        let inter = (r - l) * (b - t)
        let union = width * height + other.width * other.height - inter
        return union <= 0 ? 0 : inter / union
    }
}

/// Thẻ phát hiện được. `bounds` chuẩn hóa theo ảnh phân tích.
public struct CardDetection: Equatable {
    public var bounds: NormRect
    public var confidence: Float
    /// Độ xô lệch lớn nhất của 4 cạnh so với phương ngang / dọc (độ, ≥ 0).
    public var skewDegrees: Float

    public init(bounds: NormRect, confidence: Float, skewDegrees: Float = 0) {
        self.bounds = bounds
        self.confidence = confidence
        self.skewDegrees = skewDegrees
    }
}
