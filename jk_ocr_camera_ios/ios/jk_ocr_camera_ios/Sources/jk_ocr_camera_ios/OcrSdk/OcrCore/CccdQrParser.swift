import Foundation

/// Dữ liệu QR trên CCCD gắn chip. Chuỗi gốc phân tách bằng `|`, thứ tự quan sát được:
/// `số CCCD | số CMND cũ | họ tên | ngày sinh ddMMyyyy | giới tính | địa chỉ | ngày cấp ddMMyyyy`.
///
/// ⚠️ Thứ tự / số trường có thể khác giữa các mẫu thẻ (PLAN.md 6.1). Chứa dữ liệu cá nhân: không log.
public struct CccdQrData: Equatable, CustomStringConvertible {
    public var idNumber: String
    public var oldIdNumber: String?
    public var fullName: String?
    /// dd/MM/yyyy
    public var dateOfBirth: String?
    public var sex: String?
    public var address: String?
    /// dd/MM/yyyy
    public var issueDate: String?
    public var rawFields: [String]

    public var description: String { "CccdQrData(<redacted>, fields=\(rawFields.count))" }
}

public enum CccdQrParser {

    public static func parse(_ raw: String?) -> CccdQrData? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let fields = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count >= 6, isDigits(fields[0], count: [12]) else { return nil }

        func at(_ i: Int) -> String? { i < fields.count && !fields[i].isEmpty ? fields[i] : nil }

        return CccdQrData(
            idNumber: fields[0],
            oldIdNumber: at(1).flatMap { isDigits($0, count: [9, 12]) ? $0 : nil },
            fullName: at(2),
            dateOfBirth: at(3).flatMap(formatDate),
            sex: at(4),
            address: at(5),
            issueDate: at(6).flatMap(formatDate),
            rawFields: fields
        )
    }

    /// `ddMMyyyy` → `dd/MM/yyyy`; ngày không hợp lệ → nil.
    public static func formatDate(_ s: String) -> String? {
        guard isDigits(s, count: [8]) else { return nil }
        let c = Array(s)
        guard let d = Int(String(c[0...1])), let m = Int(String(c[2...3])), let y = Int(String(c[4...7])),
              (1...12).contains(m), (1900...2100).contains(y) else { return nil }
        let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard (1...days[m - 1]).contains(d) else { return nil }
        return "\(String(c[0...1]))/\(String(c[2...3]))/\(String(c[4...7]))"
    }

    private static func isDigits(_ s: String, count: Set<Int>) -> Bool {
        count.contains(s.count) && s.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
