import UIKit

/// Lớp phủ quanh ô quét: blur + scrim (có lỗ bo góc ở giữa) và 4 góc khung đổi màu theo trạng thái.
final class CardScanOverlayView: UIView {

    let cutoutRadius: CGFloat = 12
    private let bracketGap: CGFloat = 8
    private let bracketArm: CGFloat = 34
    private let bracketWidth: CGFloat = 4

    private let blurView = UIVisualEffectView(effect: nil)
    private let blurMask = HoleMaskView()
    private let scrimLayer = CAShapeLayer()
    private let bracketLayer = CAShapeLayer()

    var frameRect: CGRect = .zero {
        didSet { if frameRect != oldValue { setNeedsLayout() } }
    }

    var blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark {
        didSet { blurView.effect = UIBlurEffect(style: blurStyle) }
    }

    var scrimColor: UIColor = UIColor.black.withAlphaComponent(0.2) {
        didSet { scrimLayer.fillColor = scrimColor.cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        blurView.effect = UIBlurEffect(style: blurStyle)
        // UIVisualEffectView phải mask bằng `mask` (view), không dùng layer.mask.
        blurView.mask = blurMask
        addSubview(blurView)

        scrimLayer.fillRule = .evenOdd
        scrimLayer.fillColor = scrimColor.cgColor
        layer.addSublayer(scrimLayer)

        bracketLayer.fillColor = nil
        bracketLayer.lineWidth = bracketWidth
        bracketLayer.lineCap = .round
        bracketLayer.lineJoin = .round
        layer.addSublayer(bracketLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setBracketColor(_ color: UIColor, animated: Bool) {
        let newColor = color.cgColor
        if animated, let current = bracketLayer.presentation()?.strokeColor ?? bracketLayer.strokeColor {
            let anim = CABasicAnimation(keyPath: "strokeColor")
            anim.fromValue = current
            anim.toValue = newColor
            anim.duration = 0.22
            bracketLayer.add(anim, forKey: "strokeColor")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bracketLayer.strokeColor = newColor
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        blurView.frame = bounds
        blurMask.frame = blurView.bounds
        blurMask.hole = frameRect
        blurMask.holeRadius = cutoutRadius

        let scrim = UIBezierPath(rect: bounds)
        if !frameRect.isEmpty {
            scrim.append(UIBezierPath(roundedRect: frameRect, cornerRadius: cutoutRadius))
        }
        scrimLayer.frame = bounds
        scrimLayer.path = scrim.cgPath

        bracketLayer.frame = bounds
        bracketLayer.path = frameRect.isEmpty ? nil : bracketPath().cgPath

        CATransaction.commit()
    }

    private func bracketPath() -> UIBezierPath {
        let r = frameRect.insetBy(dx: -bracketGap, dy: -bracketGap)
        let radius = cutoutRadius + bracketGap
        let arm = max(bracketArm, radius + 4)
        let p = UIBezierPath()
        // Trên-trái
        p.move(to: CGPoint(x: r.minX, y: r.minY + arm))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addArc(withCenter: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius,
                 startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))
        // Trên-phải
        p.move(to: CGPoint(x: r.maxX - arm, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addArc(withCenter: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius,
                 startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + arm))
        // Dưới-phải
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - arm))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addArc(withCenter: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius,
                 startAngle: 0, endAngle: .pi * 0.5, clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX - arm, y: r.maxY))
        // Dưới-trái
        p.move(to: CGPoint(x: r.minX + arm, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addArc(withCenter: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius,
                 startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - arm))
        return p
    }
}

/// Mask cho blur: đặc toàn màn hình, trong suốt trong vùng lỗ.
private final class HoleMaskView: UIView {
    var hole: CGRect = .zero { didSet { if hole != oldValue { setNeedsDisplay() } } }
    var holeRadius: CGFloat = 12 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath(rect: bounds)
        if !hole.isEmpty {
            path.append(UIBezierPath(roundedRect: hole, cornerRadius: holeRadius))
        }
        path.usesEvenOddFillRule = true
        UIColor.black.setFill()
        path.fill()
    }
}
