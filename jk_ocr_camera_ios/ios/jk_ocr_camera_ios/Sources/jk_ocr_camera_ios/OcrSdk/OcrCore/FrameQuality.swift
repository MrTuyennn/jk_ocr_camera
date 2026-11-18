import Foundation

/// Chỉ số chất lượng vùng ảnh. Cùng định nghĩa với bản Kotlin (`com.jk.ocr.core.FrameQuality`).
public struct FrameQuality: Equatable {
    /// Độ sáng trung bình 0..255.
    public var meanLuma: Float
    /// Tỉ lệ điểm ảnh gần trắng tuyệt đối (≥ `FrameQualityAnalyzer.glareLevel`), 0..1.
    public var glareRatio: Float
    /// Phương sai Laplacian: càng lớn càng nét. Tính trên ảnh đã thu nhỏ về cùng kích thước.
    public var sharpness: Float

    public init(meanLuma: Float, glareRatio: Float, sharpness: Float) {
        self.meanLuma = meanLuma
        self.glareRatio = glareRatio
        self.sharpness = sharpness
    }
}

/// Ngưỡng đánh giá. Mặc định là ước lượng ban đầu, cần tinh chỉnh bằng ảnh thật (PLAN.md mục 9).
public struct QualityThresholds: Equatable {
    public var minMeanLuma: Float = 55
    public var maxMeanLuma: Float = 225
    public var maxGlareRatio: Float = 0.03
    public var minSharpness: Float = 45

    public init() {}
}

public enum FrameQualityAnalyzer {
    public static let glareLevel = 250

    /// Tính chất lượng trên `region` (chuẩn hóa theo ảnh); mặc định cả ảnh.
    public static func analyze(_ image: GrayImage, region: NormRect = .full) -> FrameQuality {
        let x0 = clamp(Int(region.left * Float(image.width)), 0, image.width - 1)
        let y0 = clamp(Int(region.top * Float(image.height)), 0, image.height - 1)
        let x1 = clamp(Int(region.right * Float(image.width)), x0 + 1, image.width)
        let y1 = clamp(Int(region.bottom * Float(image.height)), y0 + 1, image.height)

        var sum = 0
        var glare = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let v = image[x, y]
                sum += v
                if v >= glareLevel { glare += 1 }
            }
        }
        let count = Float((x1 - x0) * (y1 - y0))
        return FrameQuality(
            meanLuma: Float(sum) / count,
            glareRatio: Float(glare) / count,
            sharpness: laplacianVariance(image, x0, y0, x1, y1)
        )
    }

    private static func laplacianVariance(_ img: GrayImage, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Float {
        let sx = max(x0, 1), sy = max(y0, 1)
        let ex = min(x1, img.width - 1), ey = min(y1, img.height - 1)
        guard ex > sx, ey > sy else { return 0 }
        var sum = 0.0, sumSq = 0.0
        var n = 0
        img.pixels.withUnsafeBufferPointer { p in
            let w = img.width
            for y in sy..<ey {
                let row = y * w
                for x in sx..<ex {
                    let lap = Int(p[row + x - 1]) + Int(p[row + x + 1]) + Int(p[row - w + x])
                        + Int(p[row + w + x]) - 4 * Int(p[row + x])
                    let d = Double(lap)
                    sum += d
                    sumSq += d * d
                    n += 1
                }
            }
        }
        let mean = sum / Double(n)
        return Float(sumSq / Double(n) - mean * mean)
    }

    @inline(__always)
    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }
}
