import Foundation

/// Trạng thái hiển thị của màn hình quét thẻ. Quyết định màu khung và thông báo bên dưới khung.
///
/// Đây chỉ là trạng thái **UI**. Nó không nói gì về kết quả OCR hay validation:
/// tầng phân tích ảnh tự quyết định khi nào chuyển trạng thái.
public enum CardScanState: Equatable {
    /// Đang chờ / đang quét: khung vàng, không có thông báo.
    case scanning
    /// Nhắc nhở (vd. chưa có giấy tờ trong khung): khung vàng + thông báo dạng nhắc.
    case hint(String)
    /// Không quét được (thiếu sáng, chói, mờ...): khung đỏ + thông báo lỗi.
    case error(String)
    /// Đã bắt được thẻ, yêu cầu giữ yên: khung xanh + thông báo thành công.
    case success(String)
}
