# jk_ocr_camera

Flutter plugin quét giấy tờ tùy thân Việt Nam và OCR **offline**, dạng federated plugin gồm 4 package.

[![pub package](https://img.shields.io/pub/v/jk_ocr_camera.svg)](https://pub.dev/packages/jk_ocr_camera)

- pub.dev: <https://pub.dev/packages/jk_ocr_camera>
- Repo: <https://github.com/MrTuyennn/jk_ocr_camera>

**Hướng dẫn cài đặt và sử dụng: [jk_ocr_camera/README.md](jk_ocr_camera/README.md).**

| Thư mục | Package | Vai trò |
|---|---|---|
| [`jk_ocr_camera/`](jk_ocr_camera) | `jk_ocr_camera` | Package app dùng (`JkOcrCamera().scanCard(...)`) + `example/` |
| [`jk_ocr_camera_platform_interface/`](jk_ocr_camera_platform_interface) | `jk_ocr_camera_platform_interface` | Lớp abstract chung, model, MethodChannel |
| [`jk_ocr_camera_android/`](jk_ocr_camera_android) | `jk_ocr_camera_android` | Hiện thực Android + SDK native đóng gói (`android/maven/`) |
| [`jk_ocr_camera_ios/`](jk_ocr_camera_ios) | `jk_ocr_camera_ios` | Hiện thực iOS (SPM + CocoaPods) + SDK native đóng gói (`OcrSdk/`) |
| [`tool/`](tool) | | `sync_native.sh`: đóng gói lại SDK native vào plugin |

## Cài vào app

```sh
flutter pub add jk_ocr_camera
```

## Phát triển trong repo

Repo dùng **pub workspace** (`pubspec.yaml` ở gốc, Dart 3.6+). Các package phụ thuộc nhau theo version
(`jk_ocr_camera_platform_interface: ^1.0.1`), nhưng trong workspace pub lấy luôn bản trong repo, không tải từ pub.dev.

### Lần đầu sau khi clone

```sh
git clone https://github.com/MrTuyennn/jk_ocr_camera.git
cd jk_ocr_camera
flutter pub get
```

### Chạy app ví dụ

```sh
cd jk_ocr_camera/example
flutter run
```

### Kiểm tra

```sh
flutter analyze                                   # từ gốc repo, phân tích cả 4 package
(cd jk_ocr_camera_platform_interface && flutter test)
```

### Cập nhật SDK native

Mã native thật (Kotlin `android/`, Swift `ios/`) nằm ở repo SDK native riêng. Sau khi sửa SDK:

```sh
./tool/sync_native.sh /đường/dẫn/tới/repo-native
git add jk_ocr_camera_android/android/maven jk_ocr_camera_ios/ios
```

**Không** ignore và **không** sửa tay hai thư mục sinh ra:
- `jk_ocr_camera_android/android/maven/`
- `jk_ocr_camera_ios/ios/jk_ocr_camera_ios/Sources/jk_ocr_camera_ios/OcrSdk/` và `Resources/`
