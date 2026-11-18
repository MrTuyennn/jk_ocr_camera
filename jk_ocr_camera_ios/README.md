# jk_ocr_camera_ios

Package con của [`jk_ocr_camera`](../jk_ocr_camera/README.md) (cấu trúc federated plugin).
App **không** thêm trực tiếp package này; hãy dùng `jk_ocr_camera`.

- Hỗ trợ cả **Swift Package Manager** (`ios/jk_ocr_camera_ios/Package.swift`) và **CocoaPods**
  (`ios/jk_ocr_camera_ios.podspec`), dùng chung thư mục nguồn.
- Native: `JkOcrCameraPlugin.swift` present `IdCardScanFlowViewController`.
- `Sources/jk_ocr_camera_ios/OcrSdk` và `Resources` là bản sao của SDK native iOS (`ios/Sources`), sinh bởi
  `../tool/sync_native.sh`. Không sửa tay.
