import CoreGraphics
import CoreVideo
#if canImport(OcrCore)
import OcrCore
#endif

/// Lấy mẫu kênh Y (độ sáng) của pixel buffer 420f / 420v / BGRA thành `GrayImage`.
enum PixelBufferSampler {

    /// - Parameters:
    ///   - roi: vùng cần lấy (px, toạ độ buffer, gốc trên-trái).
    ///   - outWidth: chiều rộng ảnh đầu ra; chiều cao theo tỉ lệ `roi`.
    static func gray(from buffer: CVPixelBuffer, roi: CGRect, outWidth: Int) -> GrayImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let format = CVPixelBufferGetPixelFormatType(buffer)
        let isPlanar = CVPixelBufferIsPlanar(buffer)
        let base: UnsafeMutableRawPointer?
        let bytesPerRow: Int
        let width: Int
        let height: Int
        let bytesPerPixel: Int
        let lumaOffset: Int

        if isPlanar {
            base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
            bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            width = CVPixelBufferGetWidthOfPlane(buffer, 0)
            height = CVPixelBufferGetHeightOfPlane(buffer, 0)
            bytesPerPixel = 1
            lumaOffset = 0
        } else if format == kCVPixelFormatType_32BGRA {
            // Ước lượng độ sáng bằng kênh G (đủ cho đánh giá chất lượng / biên).
            base = CVPixelBufferGetBaseAddress(buffer)
            bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            width = CVPixelBufferGetWidth(buffer)
            height = CVPixelBufferGetHeight(buffer)
            bytesPerPixel = 4
            lumaOffset = 1
        } else {
            return nil
        }
        guard let base, roi.width > 0, roi.height > 0, outWidth > 0 else { return nil }

        let src = base.assumingMemoryBound(to: UInt8.self)
        let outW = outWidth
        let outH = max(1, Int((CGFloat(outWidth) * roi.height / roi.width).rounded()))
        let stepX = roi.width / CGFloat(outW)
        let stepY = roi.height / CGFloat(outH)
        var px = [UInt8](repeating: 0, count: outW * outH)

        px.withUnsafeMutableBufferPointer { out in
            for oy in 0..<outH {
                let y = min(max(Int(roi.minY + (CGFloat(oy) + 0.5) * stepY), 0), height - 1)
                let row = src + y * bytesPerRow
                for ox in 0..<outW {
                    let x = min(max(Int(roi.minX + (CGFloat(ox) + 0.5) * stepX), 0), width - 1)
                    out[oy * outW + ox] = row[x * bytesPerPixel + lumaOffset]
                }
            }
        }
        return GrayImage(width: outW, height: outH, pixels: px)
    }
}
