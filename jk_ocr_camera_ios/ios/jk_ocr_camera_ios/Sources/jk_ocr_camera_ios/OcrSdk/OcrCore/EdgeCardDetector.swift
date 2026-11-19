import Foundation

/// Phát hiện thẻ bằng biên ảnh (thuần Swift). Cùng thuật toán với bản Kotlin
/// (`com.jk.ocr.core.EdgeCardDetector`). Trên iOS dùng làm **dự phòng** khi Vision
/// `VNDetectRectanglesRequest` không thấy thẻ (vd. ngón tay che góc thẻ).
///
/// 1. Ứng viên cạnh: thử các góc nghiêng trong ±`maxSearchAngle`, lấy đỉnh cục bộ của profile gradient
///    (chỉ dải giữa), giữ vài ứng viên mạnh nhất mỗi cạnh.
/// 2. Đo từng ứng viên: sáng phía trong / ngoài, tương phản, độ liền mạch (ngưỡng tự điều chỉnh).
/// 3. Chọn cả bộ 4 cạnh theo tỉ lệ ~1.586, độ mạnh × liền mạch, phía trong đồng nhất, cùng chiều
///    tương phản. Biên của nền rối (cầm tay) hay dòng chữ bên trong không tạo thành thẻ nhất quán.
/// 4. Giao 4 đường → 4 góc → hình bao + độ xô lệch.
public final class EdgeCardDetector {

    public struct Params {
        public var minEdgeStrength: Float = 5
        public var candidateFraction: Float = 0.15
        public var candidatesPerSide = 4
        public var minAspect: Float = 1.35
        public var maxAspect: Float = 1.85
        public var minWidthCoverage: Float = 0.4
        public var minEdgeContinuity: Float = 0.4
        public var minMeanContinuity: Float = 0.55
        public var minSideContrast: Float = 10
        public var maxSearchAngle = 12

        public init() {}
    }

    private let params: Params

    public init(params: Params = Params()) {
        self.params = params
    }

    private enum Side {
        case top, bottom, left, right
        var horizontal: Bool { self == .top || self == .bottom }
        var insideSign: Int { (self == .top || self == .left) ? 1 : -1 }
    }

    /// Cạnh ngang: `y = pos + slope * (x - cx)`. Cạnh dọc: `x = pos + slope * (y - cy)`.
    private struct Edge {
        let side: Side
        let pos: Float
        let slope: Float
        let strength: Float
        let inside: Float
        let contrast: Float
        let threshold: Float
        let bandContinuity: Float
    }

    private struct Combo {
        let edges: [Edge]
        let tl: (Float, Float), tr: (Float, Float), bl: (Float, Float), br: (Float, Float)
        let meanContinuity: Float
        let score: Float
    }

    /// - Parameters:
    ///   - image: vùng ảnh quanh ô hướng dẫn (đã thẳng đứng).
    ///   - guide: vị trí ô hướng dẫn, chuẩn hóa theo `image`.
    public func detect(_ image: GrayImage, guide: NormRect) -> CardDetection? {
        let w = image.width, h = image.height
        let gl = guide.left * Float(w), gr = guide.right * Float(w)
        let gt = guide.top * Float(h), gb = guide.bottom * Float(h)
        let gw = gr - gl, gh = gb - gt
        guard gw >= 8, gh >= 8, w >= 16, h >= 16 else { return nil }

        var gradY = [Int32](repeating: 0, count: w * h)
        var gradX = [Int32](repeating: 0, count: w * h)
        image.pixels.withUnsafeBufferPointer { p in
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let i = y * w + x
                    gradY[i] = Int32(abs(Int(p[i + w]) - Int(p[i - w])))
                    gradX[i] = Int32(abs(Int(p[i + 1]) - Int(p[i - 1])))
                }
            }
        }

        let bandX0 = clamp(Int(gl + gw * 0.2), 1, w - 2)
        let bandX1 = clamp(Int(gr - gw * 0.2), bandX0 + 1, w - 1)
        let bandY0 = clamp(Int(gt + gh * 0.2), 1, h - 2)
        let bandY1 = clamp(Int(gb - gh * 0.2), bandY0 + 1, h - 1)
        let cx = Float(bandX0 + bandX1) / 2
        let cy = Float(bandY0 + bandY1) / 2

        let tops = candidates(image, gradY, .top, 1, Int(gt + gh * 0.45), bandX0, bandX1, cx)
        let bottoms = candidates(image, gradY, .bottom, Int(gb - gh * 0.45), h - 2, bandX0, bandX1, cx)
        let lefts = candidates(image, gradX, .left, 1, Int(gl + gw * 0.35), bandY0, bandY1, cy)
        let rights = candidates(image, gradX, .right, Int(gr - gw * 0.35), w - 2, bandY0, bandY1, cy)
        guard !tops.isEmpty, !bottoms.isEmpty, !lefts.isEmpty, !rights.isEmpty else { return nil }

        var best: Combo?
        for t in tops { for b in bottoms { for l in lefts { for r in rights {
            guard let combo = evaluate(image, t, b, l, r, cx, cy, gw) else { continue }
            if best == nil || combo.score > best!.score { best = combo }
        } } } }
        guard let c = best else { return nil }

        let xs = [c.tl.0, c.tr.0, c.bl.0, c.br.0]
        let ys = [c.tl.1, c.tr.1, c.bl.1, c.br.1]
        let skew = c.edges.map { abs(atan($0.slope) * 180 / .pi) }.max() ?? 0
        return CardDetection(
            bounds: NormRect(left: xs.min()! / Float(w), top: ys.min()! / Float(h),
                             right: xs.max()! / Float(w), bottom: ys.max()! / Float(h)),
            confidence: min(max(c.meanContinuity, 0), 1),
            skewDegrees: skew
        )
    }

    private func evaluate(_ img: GrayImage, _ t: Edge, _ b: Edge, _ l: Edge, _ r: Edge,
                          _ cx: Float, _ cy: Float, _ guideWidth: Float) -> Combo? {
        let edges = [t, b, l, r]
        if edges.contains(where: { abs($0.contrast) < params.minSideContrast }) { return nil }

        let tl = intersect(t, l, cx, cy), tr = intersect(t, r, cx, cy)
        let bl = intersect(b, l, cx, cy), br = intersect(b, r, cx, cy)
        let cardW = ((tr.0 - tl.0) + (br.0 - bl.0)) / 2
        let cardH = ((bl.1 - tl.1) + (br.1 - tr.1)) / 2
        guard cardW > 0, cardH > 0 else { return nil }
        let aspect = cardW / cardH
        guard aspect >= params.minAspect, aspect <= params.maxAspect,
              cardW >= guideWidth * params.minWidthCoverage else { return nil }

        let conts = [
            continuity(img, t, tl.0, tr.0, cx),
            continuity(img, b, bl.0, br.0, cx),
            continuity(img, l, tl.1, bl.1, cy),
            continuity(img, r, tr.1, br.1, cy),
        ]
        if conts.contains(where: { $0 < params.minEdgeContinuity }) { return nil }
        let meanContinuity = conts.reduce(0, +) / 4
        guard meanContinuity >= params.minMeanContinuity else { return nil }

        let insides = edges.map(\.inside)
        let spread = insides.max()! - insides.min()!
        let consistency = min(max(1 - spread / 80, 0.05), 1)
        let positive = edges.filter { $0.contrast > 0 }.count
        let signFactor: Float = (positive == 0 || positive == 4) ? 1 : (positive == 1 || positive == 3 ? 0.3 : 0.1)
        let aspectScore = min(max(1 - abs(aspect - 1.586) / 0.35, 0.2), 1)
        var evidence: Float = 0
        for i in 0..<4 { evidence += edges[i].strength * conts[i] }

        return Combo(edges: edges, tl: tl, tr: tr, bl: bl, br: br, meanContinuity: meanContinuity,
                     score: evidence * consistency * signFactor * aspectScore)
    }

    private func candidates(_ img: GrayImage, _ grad: [Int32], _ side: Side, _ from: Int, _ to: Int,
                            _ band0: Int, _ band1: Int, _ center: Float) -> [Edge] {
        let w = img.width
        let length = side.horizontal ? img.height : img.width
        let a = clamp(from, 3, length - 4)
        let b = clamp(to, 3, length - 4)
        guard b > a else { return [] }

        var raws: [(pos: Int, slope: Float, strength: Float)] = []
        var profile = [Float](repeating: 0, count: length)
        grad.withUnsafeBufferPointer { g in
            for deg in -params.maxSearchAngle...params.maxSearchAngle {
                let slope = Float(tan(Double(deg) * .pi / 180))
                for p in a...b {
                    var sum = 0, n = 0
                    for q in band0..<band1 {
                        let shifted = Int((Float(p) + slope * (Float(q) - center)).rounded())
                        if shifted < 1 || shifted > length - 2 { continue }
                        sum += Int(side.horizontal ? g[shifted * w + q] : g[q * w + shifted])
                        n += 1
                    }
                    profile[p] = n == 0 ? 0 : Float(sum) / Float(n)
                }
                let sm = smooth(profile, a, b)
                var maxV: Float = 0
                for i in a...b { maxV = max(maxV, sm[i]) }
                let threshold = max(params.minEdgeStrength, maxV * params.candidateFraction)
                for i in a...b {
                    let v = sm[i]
                    if v >= threshold && v >= sm[max(i - 1, a)] && v >= sm[min(i + 1, b)] {
                        raws.append((i, slope, v))
                    }
                }
            }
        }

        raws.sort { $0.strength > $1.strength }
        var kept: [(pos: Int, slope: Float, strength: Float)] = []
        for r in raws {
            if !kept.contains(where: { abs($0.pos - r.pos) <= 3 }) { kept.append(r) }
            if kept.count >= params.candidatesPerSide * 4 { break }
        }
        return kept
            .map { measure(img, side, Float($0.pos), $0.slope, $0.strength, band0, band1, center) }
            .sorted { $0.strength * $0.bandContinuity > $1.strength * $1.bandContinuity }
            .prefix(params.candidatesPerSide)
            .map { $0 }
    }

    private func measure(_ img: GrayImage, _ side: Side, _ pos: Float, _ slope: Float, _ strength: Float,
                         _ band0: Int, _ band1: Int, _ center: Float) -> Edge {
        let limit = side.horizontal ? img.height : img.width
        func at(_ q: Int, _ p: Int) -> Int {
            let pp = clamp(p, 0, limit - 1)
            return side.horizontal ? img[q, pp] : img[pp, q]
        }
        var plusSum = 0, minusSum = 0, n = 0
        for q in band0..<band1 {
            let line = Int((pos + slope * (Float(q) - center)).rounded())
            for d in 4...7 {
                plusSum += at(q, line + d)
                minusSum += at(q, line - d)
            }
            n += 4
        }
        let plus = Float(plusSum) / Float(n), minus = Float(minusSum) / Float(n)
        let inside = side.insideSign > 0 ? plus : minus
        let outside = side.insideSign > 0 ? minus : plus
        let contrast = inside - outside
        let thr = min(max(abs(contrast) * 0.5, 10), 20)

        var hit = 0, total = 0
        for q in band0..<band1 {
            let line = Int((pos + slope * (Float(q) - center)).rounded())
            var best = 0
            for p in (line - 1)...(line + 1) { best = max(best, abs(at(q, p + 2) - at(q, p - 2))) }
            if Float(best) >= thr { hit += 1 }
            total += 1
        }
        return Edge(side: side, pos: pos, slope: slope, strength: strength, inside: inside, contrast: contrast,
                    threshold: thr, bandContinuity: total == 0 ? 0 : Float(hit) / Float(total))
    }

    private func continuity(_ img: GrayImage, _ e: Edge, _ start: Float, _ end: Float, _ center: Float) -> Float {
        let horizontal = e.side.horizontal
        let alongLimit = horizontal ? img.width : img.height
        let acrossLimit = horizontal ? img.height : img.width
        let inset = (end - start) / 10
        let a = clamp(Int(start + inset), 0, alongLimit - 1)
        let b = clamp(Int(end - inset), a + 1, alongLimit)
        var hit = 0
        for q in a..<b {
            let line = Int((e.pos + e.slope * (Float(q) - center)).rounded())
            var best = 0
            for p in (line - 1)...(line + 1) {
                if p - 2 < 0 || p + 2 >= acrossLimit { continue }
                let d = horizontal ? abs(img[q, p + 2] - img[q, p - 2]) : abs(img[p + 2, q] - img[p - 2, q])
                best = max(best, d)
            }
            if Float(best) >= e.threshold { hit += 1 }
        }
        return Float(hit) / Float(b - a)
    }

    private func intersect(_ hz: Edge, _ vt: Edge, _ cx: Float, _ cy: Float) -> (Float, Float) {
        let t = hz.slope, s = vt.slope
        let x = (vt.pos + s * (hz.pos - t * cx - cy)) / (1 - s * t)
        return (x, hz.pos + t * (x - cx))
    }

    private func smooth(_ p: [Float], _ a: Int, _ b: Int) -> [Float] {
        var out = p
        for i in a...b { out[i] = (p[max(i - 1, a)] + 2 * p[i] + p[min(i + 1, b)]) / 4 }
        return out
    }

    @inline(__always)
    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }
}

/// Bám theo thẻ giữa các khung hình (cùng logic với bản Kotlin). Giữ kết quả gần nhất thêm tối đa
/// `maxMissedFrames` khung khi detector trượt (rung tay, ngón tay che). Kết quả giữ lại chỉ dùng cho
/// hiển thị; chụp phải dựa trên khung có thẻ thật (`isFresh`).
public final class CardTracker {
    private let maxMissedFrames: Int
    private var last: CardDetection?
    private var missed = 0

    /// `true` nếu lần `update` gần nhất có thẻ thật ở khung hiện tại.
    public private(set) var isFresh = false

    public init(maxMissedFrames: Int = 3) {
        self.maxMissedFrames = maxMissedFrames
    }

    public func update(_ detection: CardDetection?) -> CardDetection? {
        if let detection {
            last = detection
            missed = 0
            isFresh = true
            return detection
        }
        isFresh = false
        if let held = last, missed < maxMissedFrames {
            missed += 1
            return held
        }
        last = nil
        return nil
    }

    public func reset() {
        last = nil
        missed = 0
        isFresh = false
    }
}
