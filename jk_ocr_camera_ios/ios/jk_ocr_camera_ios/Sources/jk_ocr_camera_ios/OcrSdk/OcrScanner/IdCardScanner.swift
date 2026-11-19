import AVFoundation
import CoreImage
import CoreVideo
#if canImport(OcrCamera)
import OcrCamera
#endif
#if canImport(OcrCore)
import OcrCore
#endif
import UIKit

/// Nối camera của `CardScanViewController` với pipeline offline:
///
/// 1. Mỗi khung: Vision `VNDetectRectanglesRequest` tìm thẻ → `FrameQualityAnalyzer` đo sáng / chói / nét
///    → `ScanDecisionEngine` → cập nhật màu khung.
/// 2. Thẻ đạt → khung xanh. Chế độ `.manual` (mặc định): hiện nút chụp, người dùng bấm thì đọc trên
///    khung **đạt kế tiếp**. Chế độ `.auto`: tự đọc khi thẻ đứng yên.
///    Đọc = Vision `VNRecognizeTextRequest` + `VNDetectBarcodesRequest` → `CardScanResult`.
///    Lỗi (tối / chói / mờ / mất thẻ) hiện ngay theo từng khung và nút chụp ẩn đi.
/// 3. Sau khi trả kết quả, scanner **tạm dừng** đến khi gọi `resume()`.
///
/// ```swift
/// let vc = CardScanViewController()
/// scanner.attach(to: vc) { result in ...; scanner.resume() }   // gọi trước khi present
/// ```
///
/// Kết quả chứa dữ liệu cá nhân: không log.
public final class IdCardScanner {

    public let config: IdCardScannerConfig

    /// Ngôn ngữ Vision đang dùng để đọc chữ (ưu tiên tiếng Việt nếu iOS hỗ trợ).
    public var textRecognitionLanguages: [String] { textReader.languages }

    private let cardDetector = VisionCardDetector()
    /// Dự phòng khi Vision không thấy thẻ (vd. ngón tay che góc): dò biên trên ảnh xám.
    private let edgeDetector = EdgeCardDetector()
    private let tracker = CardTracker()
    /// Số khung liên tiếp mà chỉ detector biên (không phải Vision) thấy thẻ. Đủ `edgeFallbackMinStreak` mới tin.
    private var edgeStreak = 0
    private let edgeFallbackMinStreak = 3
    private let edgeFallbackMinConfidence: Float = 0.65
    private lazy var ciContext = CIContext()
    private let textReader = VisionTextReader()
    private let engine: ScanDecisionEngine

    private weak var viewController: CardScanViewController?
    private var onResult: ((CardScanResult) -> Void)?

    private struct Flags {
        var paused = false
        var resetRequested = false
        var holdUntil: TimeInterval = 0
        /// Người dùng đã bấm nút chụp, chờ khung đạt kế tiếp.
        var captureRequested = false
    }
    private let flags = NSLockedFlags(Flags())
    /// Trạng thái UI gồm màu khung / thông báo và nút chụp. Chỉ truy cập trên main thread.
    private struct UiState: Equatable {
        var scan: CardScanState
        var showCaptureButton: Bool
        var subtitleOverride: String?
    }
    private var lastPosted: UiState?

    /// Chiều rộng ảnh xám dùng để phân tích (≈300 px cho phần ô quét, giống Android):
    /// ngưỡng độ nét hiệu chỉnh theo nó.
    private let analysisWidth = 420

    private static func clamp01(_ r: NormRect) -> NormRect {
        NormRect(left: min(max(r.left, 0), 1), top: min(max(r.top, 0), 1),
                 right: min(max(r.right, 0), 1), bottom: min(max(r.bottom, 0), 1))
    }

    public init(config: IdCardScannerConfig = IdCardScannerConfig()) {
        self.config = config
        engine = ScanDecisionEngine(thresholds: config.thresholds,
                                    stableFramesRequired: config.stableFramesRequired)
    }

    /// Gắn vào view controller. **Gọi trước khi view hiện lên** (session cấu hình một lần).
    /// `onResult` chạy trên main thread.
    public func attach(to viewController: CardScanViewController,
                       onResult: @escaping (CardScanResult) -> Void) {
        self.viewController = viewController
        self.onResult = onResult
        viewController.frameHandler = { [weak self] sampleBuffer in
            self?.process(sampleBuffer)
        }
        if let title = config.captureButtonTitle { viewController.scanView.captureButtonTitle = title }
        viewController.scanView.onCapture = { [weak self, weak viewController] in
            self?.flags.update { $0.captureRequested = true }
            // Phản hồi ngay: ẩn nút để không bấm nhiều lần.
            viewController?.scanView.setCaptureButtonVisible(false)
        }
    }

    /// Quét tiếp sau khi đã nhận kết quả.
    public func resume() {
        flags.update { $0.paused = false; $0.resetRequested = true; $0.captureRequested = false }
        post(.scanning)
    }

    // MARK: - Phân tích từng khung (hàng đợi video, tuần tự)

    private func process(_ sampleBuffer: CMSampleBuffer) {
        let f = flags.get()
        if f.resetRequested {
            flags.update { $0.resetRequested = false }
            engine.reset()
            tracker.reset()
            edgeStreak = 0
        }
        guard !f.paused, ProcessInfo.processInfo.systemUptime >= f.holdUntil,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let geometry = viewController?.scanView.scanGeometry else { return }

        let bw = CGFloat(CVPixelBufferGetWidth(buffer))
        let bh = CGFloat(CVPixelBufferGetHeight(buffer))
        // Buffer đã được xoay dọc bởi CardScanViewController; nếu chưa thì bỏ qua thay vì tính sai.
        guard bw < bh else { return }

        let guide = Self.guideInBuffer(geometry, bufferWidth: bw, bufferHeight: bh)
        guard guide.width > 0, guide.height > 0 else { return }
        // Vùng phân tích rộng hơn ô quét để đo chất lượng cả phần thẻ tràn ra ngoài ô.
        let margin = guide.width * 0.2
        let roi = guide.insetBy(dx: -margin, dy: -margin).intersection(CGRect(x: 0, y: 0, width: bw, height: bh))
        guard !roi.isNull, roi.width > 0,
              let gray = PixelBufferSampler.gray(from: buffer, roi: roi, outWidth: analysisWidth) else { return }

        let guideInRoi = NormRect(guide, relativeTo: roi)
        // 1) Vision (cần thấy 4 góc). 2) Dự phòng: dò biên (chịu được ngón tay che góc / giữa cạnh).
        let fromVision = cardDetector.detect(in: buffer, guide: guide)
        var freshDetection = fromVision
        if fromVision == nil {
            // Dự phòng lỏng hơn Vision nên cần tin cậy cao và ổn định vài khung liên tiếp (tránh nhận nhầm tờ giấy, điện thoại...).
            if let d = edgeDetector.detect(gray, guide: guideInRoi), d.confidence >= edgeFallbackMinConfidence {
                edgeStreak += 1
                if edgeStreak >= edgeFallbackMinStreak {
                    freshDetection = (rect: CGRect(x: roi.minX + CGFloat(d.bounds.left) * roi.width,
                                                   y: roi.minY + CGFloat(d.bounds.top) * roi.height,
                                                   width: CGFloat(d.bounds.width) * roi.width,
                                                   height: CGFloat(d.bounds.height) * roi.height),
                                      confidence: d.confidence, skewDegrees: d.skewDegrees)
                }
            } else {
                edgeStreak = 0
            }
        } else {
            edgeStreak = 0
        }
        // Bám theo thẻ: trượt 1–3 khung khi cầm tay không làm trạng thái nhảy. Chụp thì cần thẻ thật ở khung này.
        let trackedCard = tracker.update(freshDetection.map {
            CardDetection(bounds: NormRect($0.rect, relativeTo: roi), confidence: $0.confidence, skewDegrees: $0.skewDegrees)
        })
        let fresh = tracker.isFresh
        let detected = trackedCard.map { c in
            (rect: CGRect(x: roi.minX + CGFloat(c.bounds.left) * roi.width,
                          y: roi.minY + CGFloat(c.bounds.top) * roi.height,
                          width: CGFloat(c.bounds.width) * roi.width,
                          height: CGFloat(c.bounds.height) * roi.height),
             confidence: c.confidence, skewDegrees: c.skewDegrees)
        }
        let card = detected.map {
            CardDetection(bounds: NormRect($0.rect, relativeTo: roi), confidence: $0.confidence, skewDegrees: $0.skewDegrees)
        }
        let placement = detected.map {
            CardPlacement.evaluate(NormRect($0.rect, relativeTo: guide), skewDegrees: $0.skewDegrees, rules: config.placement)
        } ?? .ok
        let qualityRegion = card.map { Self.clamp01($0.bounds) } ?? NormRect(guide, relativeTo: roi)
        let quality = FrameQualityAnalyzer.analyze(gray, region: qualityRegion)
        let decision = engine.next(quality: quality, card: card, placement: placement)
        let manual = config.captureMode == .manual

        // Bấm chụp nhưng thẻ đã lệch / lỗi: huỷ yêu cầu, không chụp "trễ" sau này.
        if decision.issue != .none { flags.update { $0.captureRequested = false } }
        let requested = flags.get().captureRequested

        let shouldCapture: Bool
        if manual {
            // Chỉ chụp khung mà chính nó đạt (không dựa vào trạng thái đã chống nhấp nháy).
            shouldCapture = requested && fresh && card != nil
                && engine.classify(quality: quality, card: card, placement: placement) == .none
        } else {
            shouldCapture = decision.readyToCapture && fresh
        }

        if shouldCapture {
            flags.update { $0.captureRequested = false }
            post(.success(config.messages.reading), showButton: false)
            capture(buffer, guide: guide, cardRect: detected?.rect, quality: quality)
        } else if manual && decision.issue == .none && requested {
            // Đã bấm, chờ khung đạt kế tiếp (thường chỉ 1–2 khung).
            post(.success(config.messages.reading), showButton: false)
        } else {
            post(state(for: decision.issue), showButton: manual && decision.issue == .none && fresh,
                 subtitleOverride: decision.issue == .blurry ? config.messages.blurryTitle : nil)
        }
    }

    /// Ô quét trong buffer (px). Preview dùng `.resizeAspectFill` nên phần bị cắt được tính vào.
    static func guideInBuffer(_ g: ScanGeometry, bufferWidth bw: CGFloat, bufferHeight bh: CGFloat) -> CGRect {
        guard g.viewSize.width > 0, g.viewSize.height > 0 else { return .zero }
        let scale = max(g.viewSize.width / bw, g.viewSize.height / bh)
        let offX = (bw - g.viewSize.width / scale) / 2
        let offY = (bh - g.viewSize.height / scale) / 2
        return CGRect(x: offX + g.frame.minX / scale, y: offY + g.frame.minY / scale,
                      width: g.frame.width / scale, height: g.frame.height / scale)
    }

    private func state(for issue: ScanIssue) -> CardScanState {
        let m = config.messages
        switch issue {
        case .none: return .success(config.captureMode == .manual ? m.ready : m.holdStill)
        case .noCard: return .hint(m.noCard)
        case .tooDark: return .error(m.tooDark)
        case .tooBright: return .error(m.tooBright)
        case .glare: return .error(m.glare)
        case .blurry: return .error(m.blurry)
        case .tooClose: return .error(m.tooClose)
        case .tooFar: return .error(m.tooFar)
        case .offsetTop: return .error(m.offsetTop)
        case .offsetBottom: return .error(m.offsetBottom)
        case .offsetLeft: return .error(m.offsetLeft)
        case .offsetRight: return .error(m.offsetRight)
        case .skewed: return .error(m.skewed)
        }
    }

    // MARK: - OCR + QR

    /// Chạy đồng bộ trên hàng đợi video: trong lúc OCR, khung mới bị bỏ (alwaysDiscardsLateVideoFrames).
    private func capture(_ buffer: CVPixelBuffer, guide: CGRect, cardRect: CGRect?, quality: FrameQuality) {
        let (imagePath, cardImagePath) = saveImages(buffer, crop: cardRect ?? guide)
        let output = textReader.read(buffer, readQr: config.readQr)

        let lines: [TextLine] = output.lines.compactMap { line in
            let box = NormRect(line.rect, relativeTo: guide)
            guard (-0.05...1.05).contains(box.centerX), (-0.05...1.05).contains(box.centerY) else { return nil }
            return TextLine(text: line.text, box: box, confidence: line.confidence)
        }

        if lines.count < config.minTextLines && output.qrPayload == nil {
            for path in [imagePath, cardImagePath].compactMap({ $0 }) { try? FileManager.default.removeItem(atPath: path) }
            let hold = config.readFailedHold
            flags.update {
                $0.holdUntil = ProcessInfo.processInfo.systemUptime + hold
                $0.resetRequested = true
            }
            post(.error(config.messages.readFailed))
            return
        }

        flags.update { $0.paused = true }
        let result = CardScanResult(
            lines: CardScanResult.sortReadingOrder(lines),
            qrRaw: output.qrPayload,
            cccdQr: CccdQrParser.parse(output.qrPayload),
            quality: quality,
            cardBounds: cardRect.map { NormRect($0, relativeTo: guide) },
            imagePath: imagePath,
            cardImagePath: cardImagePath
        )
        DispatchQueue.main.async { [weak self] in
            self?.onResult?(result)
        }
    }

    /// Lưu ảnh khung hình và ảnh cắt theo `crop` (px buffer, gốc trên-trái, nới 3%) vào `Caches/jk_ocr/`.
    /// Lỗi thì trả (nil, nil), không chặn việc đọc chữ.
    private func saveImages(_ buffer: CVPixelBuffer, crop: CGRect) -> (String?, String?) {
        guard config.saveImages,
              let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return (nil, nil) }
        let dir = caches.appendingPathComponent("jk_ocr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let image = CIImage(cvPixelBuffer: buffer)
        let h = image.extent.height
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        func encode(_ img: CIImage, quality: CGFloat) -> Data? {
            let opts: [CIImageRepresentationOption: Any] = [
                CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality,
            ]
            return ciContext.jpegRepresentation(of: img, colorSpace: space, options: opts)
        }

        /// Nén theo `jpegQuality`; vượt `maxImageBytes` thì hạ chất lượng dần (>= 0.5), vẫn lớn thì thu nhỏ kích thước.
        func encodeLimited(_ source: CIImage) -> Data? {
            var img = source
            let limit = config.maxImageBytes
            var q = min(max(config.jpegQuality, 0.01), 1)
            var data = encode(img, quality: q)
            guard limit > 0 else { return data }
            var scaleSteps = 0
            while let d = data, d.count > limit, scaleSteps < 6 {
                if q > 0.5 {
                    q = max(0.5, q - 0.05)
                } else {
                    img = img.transformed(by: CGAffineTransform(scaleX: 0.85, y: 0.85))
                    scaleSteps += 1
                }
                data = encode(img, quality: q)
            }
            return data
        }

        func write(_ img: CIImage, _ name: String) -> String? {
            guard let data = encodeLimited(img) else { return nil }
            let url = dir.appendingPathComponent(name)
            return (try? data.write(to: url)) != nil ? url.path : nil
        }

        let full = write(image, "scan_\(stamp)_full.jpg")
        let padded = crop.insetBy(dx: -crop.width * 0.03, dy: -crop.height * 0.03)
        // CoreImage gốc dưới-trái.
        let ciRect = CGRect(x: padded.minX, y: h - padded.maxY, width: padded.width, height: padded.height)
            .intersection(image.extent)
        let card = ciRect.isNull || ciRect.isEmpty ? nil : write(image.cropped(to: ciRect), "scan_\(stamp)_card.jpg")
        return (full, card)
    }

    private func post(_ state: CardScanState, showButton: Bool = false, subtitleOverride: String? = nil) {
        let ui = UiState(scan: state, showCaptureButton: showButton, subtitleOverride: subtitleOverride)
        DispatchQueue.main.async { [weak self] in
            guard let self, ui != self.lastPosted else { return }
            self.lastPosted = ui
            self.viewController?.setState(state)
            self.viewController?.scanView.setCaptureButtonVisible(showButton)
            self.viewController?.scanView.subtitleOverride = subtitleOverride
        }
    }
}

/// Giá trị có khoá, đọc/ghi từ nhiều luồng.
final class NSLockedFlags<Value> {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func get() -> Value {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func update(_ body: (inout Value) -> Void) {
        lock.lock(); body(&value); lock.unlock()
    }
}
