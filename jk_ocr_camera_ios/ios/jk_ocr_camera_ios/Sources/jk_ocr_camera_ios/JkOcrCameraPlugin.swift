import Flutter
import UIKit

/// Kênh `jk_ocr_camera`, method `scanCard`: present `IdCardScanFlowViewController` với tham số
/// (dictionary), trả dictionary kết quả, `nil` khi huỷ, hoặc `FlutterError` với mã
/// `permission_denied` / `camera_unavailable` / `busy` / `no_activity` (cùng mã với Android).
public final class JkOcrCameraPlugin: NSObject, FlutterPlugin {

    private var busy = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "jk_ocr_camera", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(JkOcrCameraPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scanCard": scanCard(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func scanCard(arguments: [String: Any], result: @escaping FlutterResult) {
        guard !busy else {
            result(FlutterError(code: "busy", message: "Đang có một phiên quét khác", details: nil))
            return
        }
        guard let presenter = Self.topViewController() else {
            result(FlutterError(code: "no_activity", message: "Không tìm thấy view controller để mở màn hình quét", details: nil))
            return
        }

        let options = IdCardScanOptions(dictionary: arguments)
        busy = true
        let vc = IdCardScanFlowViewController(options: options) { [weak self] outcome in
            self?.busy = false
            switch outcome {
            case .completed(let scan):
                result(CardScanResultCoding.dictionary(scan, side: options.side))
            case .cancelled:
                result(nil)
            case .failed(let code):
                result(FlutterError(code: code, message: nil, details: nil))
            }
        }
        presenter.present(vc, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
