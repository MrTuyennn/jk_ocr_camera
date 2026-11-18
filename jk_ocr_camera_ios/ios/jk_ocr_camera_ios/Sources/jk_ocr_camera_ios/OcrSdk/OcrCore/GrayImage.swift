import Foundation

/// Ảnh xám 8-bit, hàng nối tiếp (row-major), không padding.
public struct GrayImage {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0, "Kích thước ảnh phải dương")
        precondition(pixels.count >= width * height, "Thiếu dữ liệu pixel")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    @inline(__always)
    public subscript(x: Int, y: Int) -> Int { Int(pixels[y * width + x]) }
}
