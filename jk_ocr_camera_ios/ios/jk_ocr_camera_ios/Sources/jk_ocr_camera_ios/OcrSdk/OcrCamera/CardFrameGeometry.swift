import CoreGraphics

/// Tính vị trí ô quét: tỉ lệ 16:9, căn giữa ngang, tâm hơi lệch lên trên để chừa chỗ cho thông báo.
enum CardFrameGeometry {
    static let aspectRatio: CGFloat = 16.0 / 9.0

    static func compute(
        in bounds: CGRect,
        horizontalMargin: CGFloat = 24,
        maxWidth: CGFloat = 560,
        centerYFraction: CGFloat = 0.45
    ) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let width = min(bounds.width - 2 * horizontalMargin, maxWidth)
        let height = width / aspectRatio
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.minY + bounds.height * centerYFraction - height / 2,
            width: width,
            height: height
        )
    }
}
