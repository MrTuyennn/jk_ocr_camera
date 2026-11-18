import Foundation

/// Chuỗi hiển thị của OcrCamera, bảng `OcrCamera.strings`.
/// App tích hợp đổi chữ qua thuộc tính public (`subtitle`, `captureButtonTitle`...).
enum CameraL10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: "OcrCamera", bundle: OcrResourceBundle.bundle, comment: "")
    }
}

/// Bundle chứa file `.strings`:
/// - Swift Package: `Bundle.module` của target.
/// - CocoaPods (Flutter plugin gộp mọi nguồn vào một pod): resource bundle `JkOcrResources`.
enum OcrResourceBundle {
    static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let host = Bundle(for: BundleToken.self)
        if let url = host.url(forResource: "JkOcrResources", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return host
        #endif
    }()

    private final class BundleToken {}
}
