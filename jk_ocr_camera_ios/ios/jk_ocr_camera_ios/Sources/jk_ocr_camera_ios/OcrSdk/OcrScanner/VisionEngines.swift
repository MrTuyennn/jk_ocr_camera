import CoreGraphics
import CoreVideo
#if canImport(OcrCore)
import OcrCore
#endif
import Vision

/// Đổi bounding box chuẩn hóa của Vision (gốc dưới-trái) sang px gốc trên-trái.
@inline(__always)
func visionRectToPixels(_ r: CGRect, width: CGFloat, height: CGFloat) -> CGRect {
    CGRect(x: r.minX * width, y: (1 - r.maxY) * height, width: r.width * width, height: r.height * height)
}

/// Phát hiện thẻ bằng `VNDetectRectanglesRequest` (có sẵn trong iOS, offline).
final class VisionCardDetector {

    struct Params {
        /// Tỉ lệ rộng/cao hợp lệ của thẻ (ID-1 ≈ 1.586).
        var minAspect: CGFloat = 1.35
        var maxAspect: CGFloat = 1.85
        /// Bỏ qua ứng viên hẹp hơn bấy nhiêu phần chiều rộng ô (nhỏ hơn nữa coi như không có thẻ).
        /// Thẻ có nằm gọn / đủ lớn không do `CardPlacement` quyết định, không phải detector.
        var minWidthCoverage: CGFloat = 0.4
        /// Bỏ ứng viên có góc sát mép ảnh (px): thẻ đang bị cắt khỏi khung hình camera.
        var borderMargin: CGFloat = 4
    }

    private let params: Params
    private let request: VNDetectRectanglesRequest

    init(params: Params = Params()) {
        self.params = params
        request = VNDetectRectanglesRequest()
        // Vision định nghĩa aspect = cạnh ngắn / cạnh dài. Thẻ ID-1: 54/85.6 ≈ 0.63.
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 0.8
        request.minimumSize = 0.25
        request.quadratureTolerance = 20
        request.minimumConfidence = 0.5
        request.maximumObservations = 4
    }

    /// - Returns: hình bao thẻ theo **px buffer** (gốc trên-trái), độ tin cậy, độ xô lệch (độ), hoặc nil.
    ///   Biên có thể tràn ra ngoài `guide` (thẻ quá gần / lệch): `CardPlacement` sẽ báo.
    func detect(in buffer: CVPixelBuffer, guide: CGRect) -> (rect: CGRect, confidence: Float, skewDegrees: Float)? {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { return nil }

        let w = CGFloat(CVPixelBufferGetWidth(buffer))
        let h = CGFloat(CVPixelBufferGetHeight(buffer))
        let bounds = CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: params.borderMargin, dy: params.borderMargin)

        var best: (rect: CGRect, confidence: Float, skew: Float, score: Float)?
        for obs in request.results ?? [] {
            let rect = visionRectToPixels(obs.boundingBox, width: w, height: h)
            guard rect.height > 0 else { continue }
            let aspect = rect.width / rect.height
            guard aspect >= params.minAspect, aspect <= params.maxAspect,
                  rect.width >= guide.width * params.minWidthCoverage,
                  // Tâm thẻ phải nằm trong ô; góc không được sát mép ảnh.
                  guide.contains(CGPoint(x: rect.midX, y: rect.midY)),
                  bounds.contains(rect) else { continue }
            // Ưu tiên ứng viên có tâm gần tâm ô và độ tin cậy cao.
            let dx = Float((rect.midX - guide.midX) / guide.width)
            let dy = Float((rect.midY - guide.midY) / guide.height)
            let score = obs.confidence * (1 - min(1, (dx * dx + dy * dy).squareRoot()))
            if best == nil || score > best!.score { best = (rect, obs.confidence, Self.skewDegrees(obs, w, h), score) }
        }
        return best.map { ($0.rect, $0.confidence, $0.skew) }
    }

    /// Góc lệch lớn nhất của 4 cạnh so với phương ngang (cạnh trên/dưới) và dọc (cạnh trái/phải), tính
    /// trong không gian pixel. Thẻ xoay làm cả 4 cạnh lệch; chụp nghiêng (phối cảnh) làm cạnh đối
    /// diện lệch ngược chiều nhau.
    static func skewDegrees(_ o: VNRectangleObservation, _ w: CGFloat, _ h: CGFloat) -> Float {
        func p(_ n: CGPoint) -> CGPoint { CGPoint(x: n.x * w, y: (1 - n.y) * h) }
        let tl = p(o.topLeft), tr = p(o.topRight), bl = p(o.bottomLeft), br = p(o.bottomRight)
        func horizontal(_ a: CGPoint, _ b: CGPoint) -> CGFloat { abs(atan2(b.y - a.y, b.x - a.x)) }
        func vertical(_ a: CGPoint, _ b: CGPoint) -> CGFloat { abs(atan2(b.x - a.x, b.y - a.y)) }
        let worst = max(horizontal(tl, tr), horizontal(bl, br), vertical(tl, bl), vertical(tr, br))
        return Float(worst * 180 / .pi)
    }
}

/// Đọc chữ (`VNRecognizeTextRequest`) và QR (`VNDetectBarcodesRequest`) trong một lần.
final class VisionTextReader {

    struct Output {
        /// Dòng chữ, toạ độ px buffer (gốc trên-trái).
        var lines: [(text: String, rect: CGRect, confidence: Float)]
        var qrPayload: String?
    }

    /// Ngôn ngữ đang dùng. Ưu tiên tiếng Việt nếu phiên bản iOS hỗ trợ, kèm en-US.
    let languages: [String]

    init() {
        let probe = VNRecognizeTextRequest()
        probe.recognitionLevel = .accurate
        let supported = (try? probe.supportedRecognitionLanguages()) ?? []
        let vietnamese = supported.filter { $0.lowercased().hasPrefix("vi") }
        languages = vietnamese + ["en-US"]
    }

    var supportsVietnamese: Bool { languages.count > 1 }

    func read(_ buffer: CVPixelBuffer, readQr: Bool) -> Output {
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        // Không dùng sửa lỗi theo từ điển: dễ "sửa" sai số giấy tờ, tên riêng.
        text.usesLanguageCorrection = false
        text.recognitionLanguages = languages
        Self.preferCpuOnSimulator(text)

        let qr = VNDetectBarcodesRequest()
        Self.preferCpuOnSimulator(qr)
        #if targetEnvironment(simulator)
        // Revision 3+ (model ML) chạy CPU trên simulator trả rỗng không báo lỗi; revision 2 đọc được.
        qr.revision = VNDetectBarcodesRequestRevision2
        #endif
        qr.symbologies = [.qr]

        // Chạy riêng từng request: một cái lỗi không làm mất kết quả cái kia.
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        let textOk = (try? handler.perform([text])) != nil
        let qrOk = readQr && (try? handler.perform([qr])) != nil

        let w = CGFloat(CVPixelBufferGetWidth(buffer))
        let h = CGFloat(CVPixelBufferGetHeight(buffer))
        let lines: [(text: String, rect: CGRect, confidence: Float)] = textOk
            ? (text.results ?? []).compactMap { obs in
                guard let top = obs.topCandidates(1).first else { return nil }
                return (top.string, visionRectToPixels(obs.boundingBox, width: w, height: h), top.confidence)
            }
            : []
        let payload = qrOk ? qr.results?.compactMap(\.payloadStringValue).first : nil
        return Output(lines: lines, qrPayload: payload)
    }

    /// Simulator (Apple Silicon) không tạo được inference context trên GPU/ANE cho
    /// text/barcode (lỗi Vision code 9 "Could not create inference context"): ép chạy CPU.
    /// Thiết bị thật không ảnh hưởng.
    static func preferCpuOnSimulator(_ request: VNRequest) {
        #if targetEnvironment(simulator)
        request.usesCPUOnly = true
        #endif
    }
}

extension NormRect {
    /// Chuẩn hóa rect px theo kích thước ảnh.
    init(_ r: CGRect, width: CGFloat, height: CGFloat) {
        self.init(left: Float(r.minX / width), top: Float(r.minY / height),
                  right: Float(r.maxX / width), bottom: Float(r.maxY / height))
    }

    /// Chuẩn hóa rect px theo một khung tham chiếu (px).
    init(_ r: CGRect, relativeTo ref: CGRect) {
        self.init(left: Float((r.minX - ref.minX) / ref.width), top: Float((r.minY - ref.minY) / ref.height),
                  right: Float((r.maxX - ref.minX) / ref.width), bottom: Float((r.maxY - ref.minY) / ref.height))
    }
}
