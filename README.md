# jk_ocr_camera

Flutter plugin quét giấy tờ tùy thân Việt Nam và OCR **offline**, dạng federated plugin gồm 4 package.

- Repo: <https://github.com/MrTuyennn/jk_ocr_camera>
- Clone: `git clone https://github.com/MrTuyennn/jk_ocr_camera.git`

**Hướng dẫn cài đặt và sử dụng: [jk_ocr_camera/README.md](jk_ocr_camera/README.md).**

| Thư mục | Package | Vai trò |
|---|---|---|
| [`jk_ocr_camera/`](jk_ocr_camera) | `jk_ocr_camera` | Package app dùng (`JkOcrCamera().scanCard(...)`) + `example/` |
| [`jk_ocr_camera_platform_interface/`](jk_ocr_camera_platform_interface) | `jk_ocr_camera_platform_interface` | Lớp abstract chung, model, MethodChannel |
| [`jk_ocr_camera_android/`](jk_ocr_camera_android) | `jk_ocr_camera_android` | Hiện thực Android + SDK native đóng gói (`android/maven/`) |
| [`jk_ocr_camera_ios/`](jk_ocr_camera_ios) | `jk_ocr_camera_ios` | Hiện thực iOS (SPM + CocoaPods) + SDK native đóng gói (`OcrSdk/`) |
| [`tool/`](tool) | | `sync_native.sh`: đóng gói lại SDK native vào plugin |

## Cài vào app

```yaml
dependencies:
  jk_ocr_camera:
    git:
      url: https://github.com/MrTuyennn/jk_ocr_camera.git
      ref: v0.1.0
      path: jk_ocr_camera
```

## Phát triển trong repo

### Lần đầu sau khi clone

Mỗi package có `pubspec.yaml` riêng, nên chạy `pub get` cho từng package (nếu không, IDE sẽ báo không tìm thấy
`package:flutter_lints/flutter.yaml`):

```sh
for p in jk_ocr_camera_platform_interface jk_ocr_camera_android jk_ocr_camera_ios jk_ocr_camera jk_ocr_camera/example; do
  (cd "$p" && flutter pub get)
done
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

### Phát hành phiên bản mới

1. Tăng `version` trong `pubspec.yaml` của các package đã đổi, và ghi `CHANGELOG.md`.
2. Nếu sửa SDK native: chạy `tool/sync_native.sh` (bước trên).
3. `flutter analyze` sạch, chạy thử `example` trên Android và iOS.
4. Commit, tạo tag rồi push:

   ```sh
   git tag v0.1.0
   git push origin main --tags
   ```

App dùng plugin ghim `ref: v0.1.0` để không bị đổi bất ngờ khi nhánh `main` thay đổi.
