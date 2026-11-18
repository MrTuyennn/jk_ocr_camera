import CoreGraphics
import Foundation

/// Kích thước view và vị trí ô quét (point, toạ độ của `CardScanView`).
public struct ScanGeometry: Equatable {
    public var viewSize: CGSize
    public var frame: CGRect

    public init(viewSize: CGSize, frame: CGRect) {
        self.viewSize = viewSize
        self.frame = frame
    }
}

/// Hộp giữ giá trị an toàn khi đọc/ghi từ nhiều luồng.
final class LockedBox<Value> {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func get() -> Value {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Value) {
        lock.lock(); value = newValue; lock.unlock()
    }
}
