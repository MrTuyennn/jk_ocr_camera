import AVFoundation
import UIKit

/// View controller quét thẻ: quản lý quyền camera + `AVCaptureSession` và hiển thị `CardScanView`.
///
/// Gắn `frameHandler` để nhận frame camera (chạy trên hàng đợi nền) cho OCR / kiểm tra chất lượng,
/// rồi gọi `setState(_:)` trên main thread.
open class CardScanViewController: UIViewController {

    public let scanView = CardScanView()

    /// Nhận từng frame camera trên hàng đợi nền. `nil` thì không thêm video output.
    /// Phải gán **trước** khi view hiện lên (session chỉ cấu hình một lần).
    ///
    /// Buffer đã được xoay **dọc** (portrait, khớp với màn hình), định dạng 420f (YpCbCr full range).
    public var frameHandler: ((CMSampleBuffer) -> Void)?

    /// Gọi khi không có quyền camera hoặc không mở được camera.
    public var onCameraUnavailable: ((CameraUnavailableReason) -> Void)?

    public enum CameraUnavailableReason {
        case permissionDenied
        case noCamera
        case configurationFailed(Error?)
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "ocr.camera.session")
    private let videoQueue = DispatchQueue(label: "ocr.camera.video")
    private var isConfigured = false
    private lazy var frameDelegate = FrameDelegate { [weak self] buffer in self?.frameHandler?(buffer) }

    open override func loadView() {
        view = scanView
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        scanView.previewLayer.session = session
        if scanView.onBack == nil {
            scanView.onBack = { [weak self] in self?.close() }
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestAccessAndStart()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    public func setState(_ state: CardScanState, animated: Bool = true) {
        scanView.setState(state, animated: animated)
    }

    private func close() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: Camera

    private func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startSession() } else { self?.onCameraUnavailable?(.permissionDenied) }
                }
            }
        default:
            onCameraUnavailable?(.permissionDenied)
        }
    }

    private func startSession() {
        let wantsFrames = frameHandler != nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                if let failure = self.configureSession(wantsFrames: wantsFrames) {
                    DispatchQueue.main.async { self.onCameraUnavailable?(failure) }
                    return
                }
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    /// Trả về lý do lỗi, hoặc `nil` nếu cấu hình thành công. Chạy trên `sessionQueue`.
    private func configureSession(wantsFrames: Bool) -> CameraUnavailableReason? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return .noCamera
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 1920x1080 = 16:9, cùng tỉ lệ với ô quét.
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return .configurationFailed(nil) }
            session.addInput(input)
        } catch {
            return .configurationFailed(error)
        }

        if wantsFrames {
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            output.setSampleBufferDelegate(frameDelegate, queue: videoQueue)
            guard session.canAddOutput(output) else { return .configurationFailed(nil) }
            session.addOutput(output)
            // Xoay buffer về dọc để toạ độ ảnh khớp với màn hình (app chỉ hỗ trợ portrait).
            if let connection = output.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }

        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        }
        return nil
    }
}

private final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let handler: (CMSampleBuffer) -> Void
    init(handler: @escaping (CMSampleBuffer) -> Void) { self.handler = handler }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        handler(sampleBuffer)
    }
}
