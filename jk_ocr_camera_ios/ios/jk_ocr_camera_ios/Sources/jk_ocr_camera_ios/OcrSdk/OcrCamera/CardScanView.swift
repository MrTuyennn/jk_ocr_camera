import AVFoundation
import UIKit

/// Màn hình quét thẻ: camera toàn màn hình, ô quét 16:9 ở giữa nhìn rõ, xung quanh blur,
/// 4 góc khung và thông báo đổi màu theo `CardScanState`.
///
/// View này chỉ lo phần hiển thị. Camera session do `CardScanViewController` quản lý,
/// hoặc app tự gắn session vào `previewLayer`.
public final class CardScanView: UIView {

    public var previewLayer: AVCaptureVideoPreviewLayer { previewContainer.previewLayer }

    /// Gọi khi bấm nút quay lại.
    public var onBack: (() -> Void)?

    /// Gọi khi bấm nút chụp (chỉ bấm được khi nút đang hiện, xem `setCaptureButtonVisible`).
    public var onCapture: (() -> Void)?

    public var captureButtonTitle: String {
        get { captureButton.title(for: .normal) ?? "" }
        set { captureButton.setTitle(newValue, for: .normal); captureButton.accessibilityLabel = newValue }
    }

    /// Nút chụp có đang hiện (và bấm được) không.
    public var isCaptureButtonVisible: Bool { captureButton.isEnabled && !captureButton.isHidden }

    public var theme = CardScanTheme() {
        didSet { applyTheme(); applyState(state, animated: false) }
    }

    public var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue; setNeedsLayout() }
    }

    /// Dòng hướng dẫn dưới tiêu đề. Mặc định: `ekyc_guide_for_capturing_id_card`.
    public var subtitle: String? {
        didSet { if subtitleOverride == nil { subtitleLabel.text = subtitle; setNeedsLayout() } }
    }

    /// Thay tạm dòng hướng dẫn (vd. "Hãy giữ yên" khi ảnh mờ). `nil` = hiện lại `subtitle`.
    /// Dòng thay thế được in đậm để người dùng chú ý.
    public var subtitleOverride: String? {
        didSet {
            guard subtitleOverride != oldValue else { return }
            subtitleLabel.text = subtitleOverride ?? subtitle
            subtitleLabel.font = subtitleOverride == nil ? .systemFont(ofSize: 14) : .systemFont(ofSize: 14, weight: .bold)
            setNeedsLayout()
        }
    }

    public private(set) var state: CardScanState = .scanning

    /// Vị trí ô quét trong hệ toạ độ của view (để tầng phân tích ảnh crop đúng vùng).
    public private(set) var frameRect: CGRect = .zero

    /// Ảnh chụp nhanh kích thước view + ô quét, cập nhật mỗi lần layout.
    /// **An toàn để đọc từ hàng đợi phân tích ảnh.** nil khi chưa layout.
    public var scanGeometry: ScanGeometry? { geometryBox.get() }
    private let geometryBox = LockedBox<ScanGeometry?>(nil)

    private let previewContainer = PreviewContainerView()
    private let overlay = CardScanOverlayView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusView = StatusToastView()
    private let captureButton = UIButton(type: .custom)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .black

        previewContainer.previewLayer.videoGravity = .resizeAspectFill
        addSubview(previewContainer)
        addSubview(overlay)

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        addSubview(subtitleLabel)

        statusView.alpha = 0
        addSubview(statusView)

        captureButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        captureButton.layer.cornerRadius = 26
        captureButton.setTitle(CameraL10n.string("ekyc_button_capture"), for: .normal)
        captureButton.accessibilityLabel = CameraL10n.string("ekyc_button_capture")
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        captureButton.alpha = 0
        captureButton.isHidden = true
        captureButton.isEnabled = false
        addSubview(captureButton)

        let arrow = UIImage(systemName: "arrow.left",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        backButton.setImage(arrow, for: .normal)
        backButton.tintColor = .white
        backButton.accessibilityLabel = CameraL10n.string("ekyc_content_description_back")
        backButton.layer.cornerRadius = 18
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        addSubview(backButton)

        title = "Căn Cước mặt trước"
        subtitle = CameraL10n.string("ekyc_guide_for_capturing_id_card")
        applyTheme()
        applyState(state, animated: false)
    }

    @objc private func backTapped() { onBack?() }

    @objc private func captureTapped() {
        guard captureButton.isEnabled else { return }
        onCapture?()
    }

    /// Hiện / ẩn nút chụp. Ẩn thì nút ngừng nhận bấm ngay (kể cả khi đang chạy animation),
    /// để không chụp nhầm lúc thẻ vừa lệch khỏi khung.
    public func setCaptureButtonVisible(_ visible: Bool, animated: Bool = true) {
        guard visible != isCaptureButtonVisible else { return }
        captureButton.isEnabled = visible
        if visible {
            captureButton.isHidden = false
            guard animated else { captureButton.alpha = 1; captureButton.transform = .identity; return }
            captureButton.transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState]) {
                self.captureButton.alpha = 1
                self.captureButton.transform = .identity
            }
        } else {
            guard animated else { captureButton.alpha = 0; captureButton.isHidden = true; return }
            UIView.animate(withDuration: 0.14, delay: 0, options: [.beginFromCurrentState], animations: {
                self.captureButton.alpha = 0
            }, completion: { _ in
                if !self.captureButton.isEnabled { self.captureButton.isHidden = true }
            })
        }
    }

    // MARK: State

    public func setState(_ newState: CardScanState, animated: Bool = true) {
        guard newState != state else { return }
        state = newState
        applyState(newState, animated: animated)
    }

    private func applyState(_ s: CardScanState, animated: Bool) {
        switch s {
        case .scanning:
            overlay.setBracketColor(theme.scanningColor, animated: animated)
            hideStatus(animated: animated)
        case .hint(let message):
            overlay.setBracketColor(theme.scanningColor, animated: animated)
            statusView.configure(message: message, symbol: "exclamationmark.circle.fill",
                                 accent: theme.scanningColor, background: theme.hintToastBackground,
                                 textColor: theme.hintTextColor)
            showStatus(animated: animated)
        case .error(let message):
            overlay.setBracketColor(theme.errorColor, animated: animated)
            statusView.configure(message: message, symbol: "xmark.circle.fill",
                                 accent: theme.errorColor, background: theme.errorToastBackground,
                                 textColor: theme.errorTextColor)
            showStatus(animated: animated)
        case .success(let message):
            overlay.setBracketColor(theme.successColor, animated: animated)
            statusView.configure(message: message, symbol: "checkmark.circle.fill",
                                 accent: theme.successColor, background: theme.successToastBackground,
                                 textColor: theme.successTextColor)
            showStatus(animated: animated)
        }
        setNeedsLayout()
    }

    private func showStatus(animated: Bool) {
        let wasHidden = statusView.alpha < 1
        guard animated else {
            statusView.alpha = 1
            statusView.transform = .identity
            return
        }
        if wasHidden { statusView.transform = CGAffineTransform(translationX: 0, y: 6) }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState]) {
            self.statusView.alpha = 1
            self.statusView.transform = .identity
        }
    }

    private func hideStatus(animated: Bool) {
        guard animated else { statusView.alpha = 0; return }
        UIView.animate(withDuration: 0.16, delay: 0, options: [.beginFromCurrentState]) {
            self.statusView.alpha = 0
        }
    }

    private func applyTheme() {
        titleLabel.textColor = theme.textColor
        subtitleLabel.textColor = theme.secondaryTextColor
        overlay.scrimColor = theme.scrimColor
        overlay.blurStyle = theme.blurStyle
        backButton.backgroundColor = theme.backButtonBackground
        captureButton.backgroundColor = theme.captureButtonBackground
        captureButton.setTitleColor(theme.captureButtonTextColor, for: .normal)
    }

    // MARK: Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        frameRect = CardFrameGeometry.compute(in: bounds)
        let geometry = ScanGeometry(viewSize: bounds.size, frame: frameRect)
        if geometryBox.get() != geometry { geometryBox.set(geometry) }

        previewContainer.frame = bounds
        overlay.frame = bounds
        overlay.frameRect = frameRect

        backButton.frame = CGRect(x: 16, y: safeAreaInsets.top + 12, width: 36, height: 36)

        let textWidth = frameRect.width
        let subtitleSize = subtitleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let titleSize = titleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))

        let subtitleBottom = frameRect.minY - 30
        subtitleLabel.frame = CGRect(x: bounds.midX - subtitleSize.width / 2,
                                     y: subtitleBottom - subtitleSize.height,
                                     width: subtitleSize.width, height: subtitleSize.height)
        titleLabel.frame = CGRect(x: bounds.midX - titleSize.width / 2,
                                  y: subtitleLabel.frame.minY - 6 - titleSize.height,
                                  width: titleSize.width, height: titleSize.height)

        let statusSize = statusView.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        statusView.bounds = CGRect(origin: .zero, size: statusSize)
        statusView.center = CGPoint(x: bounds.midX, y: frameRect.maxY + 28 + statusSize.height / 2)

        // Nút chụp ở đáy màn hình (trên home indicator), vị trí cố định để dễ bấm.
        let buttonHeight: CGFloat = 52
        captureButton.bounds = CGRect(x: 0, y: 0, width: frameRect.width, height: buttonHeight)
        captureButton.center = CGPoint(x: bounds.midX,
                                       y: bounds.height - safeAreaInsets.bottom - 32 - buttonHeight / 2)
    }
}

// MARK: - Subviews

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// Thông báo bo góc dưới khung: icon tròn + nội dung.
private final class StatusToastView: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()
    private let padding = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 14)
    private let iconSize: CGFloat = 18
    private let spacing: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10
        layer.borderWidth = 1
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: String, symbol: String, accent: UIColor, background: UIColor, textColor: UIColor) {
        label.text = message
        label.textColor = textColor
        let config = UIImage.SymbolConfiguration(pointSize: iconSize)
            .applying(UIImage.SymbolConfiguration(paletteColors: [.white, accent]))
        iconView.image = UIImage(systemName: symbol, withConfiguration: config)
        backgroundColor = background
        layer.borderColor = accent.withAlphaComponent(0.6).cgColor
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let maxLabelWidth = max(0, size.width - padding.left - padding.right - iconSize - spacing)
        let labelSize = label.sizeThatFits(CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude))
        let contentHeight = max(iconSize, labelSize.height)
        return CGSize(width: padding.left + iconSize + spacing + min(labelSize.width, maxLabelWidth) + padding.right,
                      height: padding.top + contentHeight + padding.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let contentHeight = bounds.height - padding.top - padding.bottom
        iconView.frame = CGRect(x: padding.left, y: padding.top + (contentHeight - iconSize) / 2,
                                width: iconSize, height: iconSize)
        let labelX = iconView.frame.maxX + spacing
        label.frame = CGRect(x: labelX, y: padding.top,
                             width: bounds.width - labelX - padding.right, height: contentHeight)
    }
}
