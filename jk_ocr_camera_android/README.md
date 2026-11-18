# jk_ocr_camera_android

Package con của [`jk_ocr_camera`](../jk_ocr_camera/README.md) (cấu trúc federated plugin).
App **không** thêm trực tiếp package này; hãy dùng `jk_ocr_camera`.

- Native: `android/src/main/kotlin/com/jk/ocr/flutter/JkOcrCameraPlugin.kt` mở `IdCardScanActivity`.
- SDK: `android/maven/` là repo Maven cục bộ chứa `com.jk.ocr:ocr-core|ocr-camera|ocr-scanner:1.0.0`,
  sinh bởi `../tool/sync_native.sh` từ SDK native Android. Không sửa tay.
