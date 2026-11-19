import Foundation

/// Vị trí thẻ so với ô quét. Cùng logic với bản Kotlin.
public enum PlacementIssue: Equatable {
    case ok
    /// Thẻ tràn ra ngoài ô ở **hai phía đối diện** (to hơn ô): cần đưa ra xa hơn.
    case tooClose
    /// Thẻ quá nhỏ trong ô quét: chữ có thể quá bé để đọc, cần đưa lại gần hơn.
    case tooFar
    /// Thẻ tràn ra ngoài ô ở một cạnh.
    case offsetTop, offsetBottom, offsetLeft, offsetRight
    /// Thẻ xoay / chụp nghiêng: cạnh thẻ không song song với khung.
    case skewed
}

/// - `edgeTolerance`: cho phép thẻ lấn ra ngoài ô tối đa bấy nhiêu (tỉ lệ kích thước ô), bù sai số dò biên.
/// - `minWidthRatio`: thẻ phải rộng ít nhất bấy nhiêu phần chiều rộng ô.
/// - `maxSkewDegrees`: cạnh thẻ lệch quá bấy nhiêu độ so với khung → `.skewed`.
public struct PlacementRules: Equatable {
    public var edgeTolerance: Float
    public var minWidthRatio: Float
    public var maxSkewDegrees: Float

    public init(edgeTolerance: Float = 0.04, minWidthRatio: Float = 0.6, maxSkewDegrees: Float = 8) {
        self.edgeTolerance = edgeTolerance
        self.minWidthRatio = minWidthRatio
        self.maxSkewDegrees = maxSkewDegrees
    }
}

public enum CardPlacement {

    /// Thứ tự ưu tiên: tràn khung (lệch một phía / quá gần) → xô lệch → quá xa.
    /// - Parameter cardInGuide: biên thẻ chuẩn hóa theo ô quét (0..1 = nằm trong ô).
    public static func evaluate(_ cardInGuide: NormRect, skewDegrees: Float = 0,
                                rules: PlacementRules = PlacementRules()) -> PlacementIssue {
        let t = rules.edgeTolerance
        let overTop = -cardInGuide.top - t
        let overBottom = cardInGuide.bottom - 1 - t
        let overLeft = -cardInGuide.left - t
        let overRight = cardInGuide.right - 1 - t

        if (overTop > 0 && overBottom > 0) || (overLeft > 0 && overRight > 0) { return .tooClose }

        let worst: (PlacementIssue, Float) = [
            (.offsetTop, overTop), (.offsetBottom, overBottom), (.offsetLeft, overLeft), (.offsetRight, overRight),
        ].max { $0.1 < $1.1 }!
        if worst.1 > 0 { return worst.0 }

        if abs(skewDegrees) > rules.maxSkewDegrees { return .skewed }
        if cardInGuide.width < rules.minWidthRatio { return .tooFar }
        return .ok
    }

    /// Đổi biên chuẩn hóa theo ảnh sang chuẩn hóa theo ô quét `guide` (cũng chuẩn hóa theo ảnh).
    public static func toGuide(_ b: NormRect, guide g: NormRect) -> NormRect {
        NormRect(left: (b.left - g.left) / g.width, top: (b.top - g.top) / g.height,
                 right: (b.right - g.left) / g.width, bottom: (b.bottom - g.top) / g.height)
    }
}
