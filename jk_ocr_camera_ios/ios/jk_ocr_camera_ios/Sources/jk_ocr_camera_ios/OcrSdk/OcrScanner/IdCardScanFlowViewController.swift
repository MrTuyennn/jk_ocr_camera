import UIKit
#if canImport(OcrCamera)
import OcrCamera
#endif
#if canImport(OcrCore)
import OcrCore
#endif

/// Màn hình quét giấy tờ hoàn chỉnh: xin quyền camera, quét, trả kết quả rồi tự đóng.
/// Dùng cho Flutter plugin `jk_ocr_camera` hoặc app iOS thuần:
///
/// ```swift
/// var options = IdCardScanOptions(); options.side = .front
/// let vc = IdCardScanFlowViewController(options: options) { outcome in ... }
/// vc.modalPresentationStyle = .fullScreen
/// present(vc, animated: true)
/// ```
///
/// `completion` chạy trên main thread **sau khi** màn hình đã đóng, đúng một lần.
public final class IdCardScanFlowViewController: CardScanViewController {

    public enum Outcome {
        case completed(CardScanResult)
        /// Người dùng bấm quay lại.
        case cancelled
        /// `permission_denied` | `camera_unavailable` (cùng mã với Android).
        case failed(code: String)
    }

    public let options: IdCardScanOptions
    private let scanner: IdCardScanner
    private let completion: (Outcome) -> Void
    private var finished = false

    public init(options: IdCardScanOptions = IdCardScanOptions(), completion: @escaping (Outcome) -> Void) {
        self.options = options
        self.scanner = IdCardScanner(config: options.scannerConfig)
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        scanView.title = options.title ?? ScannerL10n.string(options.side == .back ? "ekyc_title_back_side" : "ekyc_title_front_side")
        if let subtitle = options.subtitle { scanView.subtitle = subtitle }
        scanView.onBack = { [weak self] in self?.finish(.cancelled) }
        onCameraUnavailable = { [weak self] reason in
            switch reason {
            case .permissionDenied: self?.finish(.failed(code: "permission_denied"))
            case .noCamera, .configurationFailed: self?.finish(.failed(code: "camera_unavailable"))
            }
        }
        // Gắn trước viewWillAppear để session có video output.
        scanner.attach(to: self) { [weak self] result in self?.finish(.completed(result)) }
    }

    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        finished = true
        let done = completion
        if presentingViewController != nil {
            dismiss(animated: true) { done(outcome) }
        } else {
            done(outcome)
        }
    }
}
