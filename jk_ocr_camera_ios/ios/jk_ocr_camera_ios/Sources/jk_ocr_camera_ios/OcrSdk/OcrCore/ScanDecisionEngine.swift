import Foundation

/// Vấn đề hiện tại của khung hình, theo thứ tự ưu tiên khi kiểm tra.
public enum ScanIssue: Equatable {
    /// Đạt: có thẻ, đủ sáng, không chói, nét.
    case none
    case tooDark
    case tooBright
    /// Không thấy thẻ trong khung.
    case noCard
    /// Thẻ to hơn khung, tràn ở hai phía đối diện.
    case tooClose
    /// Thẻ quá nhỏ trong khung.
    case tooFar
    /// Thẻ tràn ra ngoài khung ở một cạnh.
    case offsetTop, offsetBottom, offsetLeft, offsetRight
    /// Thẻ xoay / chụp nghiêng.
    case skewed
    case glare
    case blurry
}

public struct ScanDecision: Equatable {
    /// Vấn đề đang hiển thị (đã chống nhấp nháy).
    public var issue: ScanIssue
    /// Thẻ đạt chất lượng và đứng yên đủ lâu: có thể chạy OCR.
    public var readyToCapture: Bool
    /// Tiến độ đứng yên 0..1.
    public var stableProgress: Float
}

/// Biến (chất lượng, thẻ) của từng khung thành quyết định cho UI. Cùng logic với bản Kotlin.
///
/// - Chống nhấp nháy: vấn đề mới phải lặp lại `debounceFrames` khung liên tiếp.
/// - Đứng yên: thẻ giữ vị trí (IoU ≥ `stableIou`) trong `stableFramesRequired` khung.
///
/// Không thread-safe: gọi tuần tự từ hàng đợi phân tích ảnh.
public final class ScanDecisionEngine {
    private let thresholds: QualityThresholds
    private let debounceFrames: Int
    private let stableFramesRequired: Int
    private let stableIou: Float

    private var current: ScanIssue = .noCard
    private var pending: ScanIssue = .noCard
    private var pendingCount = 0
    private var stableCount = 0
    private var lastBounds: NormRect?

    public init(thresholds: QualityThresholds = QualityThresholds(),
                debounceFrames: Int = 3,
                stableFramesRequired: Int = 8,
                stableIou: Float = 0.85) {
        self.thresholds = thresholds
        self.debounceFrames = debounceFrames
        self.stableFramesRequired = stableFramesRequired
        self.stableIou = stableIou
    }

    public func reset() {
        current = .noCard
        pending = .noCard
        pendingCount = 0
        stableCount = 0
        lastBounds = nil
    }

    /// - Parameter placement: vị trí thẻ so với ô quét (xem `CardPlacement`); bỏ qua nếu `card` nil.
    public func next(quality: FrameQuality, card: CardDetection?, placement: PlacementIssue = .ok) -> ScanDecision {
        let candidate = classify(quality: quality, card: card, placement: placement)

        if candidate == pending { pendingCount += 1 } else { pending = candidate; pendingCount = 1 }
        if candidate == current || pendingCount >= debounceFrames { current = candidate }

        if candidate == .none, let card {
            if let prev = lastBounds, prev.iou(card.bounds) >= stableIou {
                stableCount += 1
            } else {
                stableCount = 1
            }
            lastBounds = card.bounds
        } else {
            stableCount = 0
            lastBounds = nil
        }

        return ScanDecision(
            issue: current,
            readyToCapture: current == .none && stableCount >= stableFramesRequired,
            stableProgress: min(1, Float(stableCount) / Float(stableFramesRequired))
        )
    }

    /// Thứ tự: sáng/tối trước, rồi có thẻ, vị trí thẻ, rồi chói, rồi mờ.
    public func classify(quality: FrameQuality, card: CardDetection?, placement: PlacementIssue = .ok) -> ScanIssue {
        if quality.meanLuma < thresholds.minMeanLuma { return .tooDark }
        if quality.meanLuma > thresholds.maxMeanLuma { return .tooBright }
        if card == nil { return .noCard }
        switch placement {
        case .ok: break
        case .tooClose: return .tooClose
        case .tooFar: return .tooFar
        case .offsetTop: return .offsetTop
        case .offsetBottom: return .offsetBottom
        case .offsetLeft: return .offsetLeft
        case .offsetRight: return .offsetRight
        case .skewed: return .skewed
        }
        if quality.glareRatio > thresholds.maxGlareRatio { return .glare }
        if quality.sharpness < thresholds.minSharpness { return .blurry }
        return .none
    }
}
