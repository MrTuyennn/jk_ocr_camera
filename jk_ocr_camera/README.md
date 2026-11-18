# jk_ocr_camera

Flutter plugin quét giấy tờ tùy thân Việt Nam và OCR **chạy offline hoàn toàn**: không gọi backend, không tải model,
không cần mạng.

|             | Android | iOS |
|-------------|---------|-----|
| **Hỗ trợ**  | API 24+ | 15.0+ |
| Đọc chữ     | Google ML Kit Text Recognition (bản bundled) | Apple Vision (`vi-VT` nếu iOS hỗ trợ) |
| Đọc QR      | ML Kit Barcode Scanning (bản bundled) | Apple Vision |
| Phát hiện giấy tờ | Dò biên ảnh (thuần Kotlin) | Apple Vision `VNDetectRectanglesRequest` |

**Màn hình quét:** camera toàn màn hình, khung 16:9 ở giữa, xung quanh blur. Lỗi (tối, chói, mờ, lệch, xô lệch, không
có giấy tờ…) hiện **realtime**. Khi giấy tờ đúng khung thì khung chuyển xanh và hiện nút **"Chụp ảnh"**.

> **Lưu ý quan trọng:** kết quả là **dữ liệu OCR thô** (dòng chữ + vị trí) và **QR CCCD đã tách trường**. Plugin
> **không** xác minh giấy tờ thật / giả. OCR thành công ≠ thông tin hợp lệ ≠ giấy tờ thật.

---

## Cấu trúc (federated plugin)

| Package | Vai trò |
|---|---|
| `jk_ocr_camera` | Package app dùng: class `JkOcrCamera` |
| `jk_ocr_camera_platform_interface` | Lớp abstract chung, model, MethodChannel |
| `jk_ocr_camera_android` | Hiện thực Android (mở `IdCardScanActivity` của SDK `com.jk.ocr:ocr-scanner`) |
| `jk_ocr_camera_ios` | Hiện thực iOS (present `IdCardScanFlowViewController`), hỗ trợ SPM + CocoaPods |

App **chỉ** cần thêm `jk_ocr_camera`; hai package nền tảng được chọn tự động.

---

## Cài đặt

Package phân phối qua **git**, không qua pub.dev. Cả 4 package nằm chung một repo:

```
jk_ocr_camera/                           ← gốc repo https://github.com/MrTuyennn/jk_ocr_camera
├── jk_ocr_camera/                       ← package app dùng (+ example/)
├── jk_ocr_camera_platform_interface/
├── jk_ocr_camera_android/
├── jk_ocr_camera_ios/
└── tool/sync_native.sh
```

### Bước 1: thêm dependency vào `pubspec.yaml` của app

```yaml
dependencies:
  jk_ocr_camera:
    git:
      url: https://github.com/MrTuyennn/jk_ocr_camera.git
      ref: v0.1.0                  # nên ghim theo tag; hoặc tên nhánh, vd. main
      path: jk_ocr_camera
```

> `jk_ocr_camera` tham chiếu 3 package còn lại bằng đường dẫn tương đối (`../jk_ocr_camera_android`...). Pub tải
> **nguyên repo** khi cài từ git nên các đường dẫn này vẫn đúng. Đừng chỉ copy riêng thư mục `jk_ocr_camera`.

> Nếu repo để **private**: máy build (và CI) phải có quyền đọc repo, vì pub dùng `git` để tải. Dùng SSH thì đổi
> `url` thành `git@github.com:MrTuyennn/jk_ocr_camera.git` và cấu hình SSH key cho máy / CI.

Hoặc khi phát triển cùng máy:

```yaml
dependencies:
  jk_ocr_camera:
    path: /đường/dẫn/tới/repo-clone/jk_ocr_camera
```

### Bước 2: chạy

```sh
flutter pub get
```

---

## Cấu hình

<details>
<summary><b>Android</b></summary>

1. `minSdk` của app phải **≥ 24** (`android/app/build.gradle(.kts)`):

   ```kotlin
   android {
       defaultConfig {
           minSdk = 24
       }
   }
   ```

2. Quyền camera đã được khai báo sẵn trong plugin (`android.permission.CAMERA`), app **không** cần thêm. Màn hình quét
   tự xin quyền lúc mở.

3. `android/build.gradle(.kts)` của app phải khai báo repository theo kiểu `allprojects { repositories { ... } }`
   (mặc định của template Flutter). Plugin thêm repo Maven cục bộ chứa SDK native vào đó. Nếu app đặt
   `repositoriesMode = FAIL_ON_PROJECT_REPOS` trong `settings.gradle`, hãy đổi sang `PREFER_SETTINGS` hoặc thêm
   repo này vào `dependencyResolutionManagement`:

   ```kotlin
   maven { url = uri("<đường dẫn pub cache>/jk_ocr_camera_android/android/maven") }
   ```

4. **Về mạng:** thư viện ML Kit tự thêm quyền `INTERNET` và `ACCESS_NETWORK_STATE` vào app để gửi log thống kê sử
   dụng của Google. Nhận diện **không** cần mạng. Nếu app không cần mạng và muốn gỡ, thêm vào
   `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android"
       xmlns:tools="http://schemas.android.com/tools">
       <uses-permission android:name="android.permission.INTERNET" tools:node="remove" />
       <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" tools:node="remove" />
   ```

   (App Flutter ở chế độ debug cần `INTERNET` để hot reload; chỉ gỡ ở bản release.)

5. Dung lượng: model OCR + QR khoảng 15–17 MB mỗi ABI. Nên phát hành bằng App Bundle (`flutter build appbundle`)
   để mỗi máy chỉ tải ABI của nó.

</details>

<details>
<summary><b>iOS</b></summary>

1. Deployment target của app **≥ 15.0**:
   - Xcode → Runner → General → Minimum Deployments: `15.0`.
   - Nếu app dùng CocoaPods: dòng `platform :ios, '15.0'` trong `ios/Podfile`.

2. Thêm mô tả quyền camera vào `ios/Runner/Info.plist`:

   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Ứng dụng cần camera để chụp giấy tờ tùy thân.</string>
   ```

3. Plugin hỗ trợ cả **Swift Package Manager** (mặc định từ Flutter 3.24+ khi bật) và **CocoaPods**. Không cần cấu hình
   thêm.

</details>

---

## Sử dụng

### Chụp một mặt giấy tờ

```dart
import 'package:jk_ocr_camera/jk_ocr_camera.dart';

final camera = JkOcrCamera();

Future<void> scanFront() async {
  try {
    final result = await camera.scanCard(side: CardSide.front);
    if (result == null) {
      // Người dùng bấm quay lại.
      return;
    }
    print(result.cardImagePath);      // ảnh cắt theo giấy tờ
    print(result.cccdQr?.idNumber);   // nếu đọc được QR CCCD
    print(result.fullText);           // toàn bộ chữ OCR
  } on JkOcrException catch (e) {
    if (e.code == JkOcrErrorCode.permissionDenied) {
      // Hướng dẫn người dùng mở Cài đặt để cấp quyền camera.
    }
  }
}
```

### Chụp mặt trước rồi mặt sau

```dart
final front = await camera.scanCard(side: CardSide.front);
if (front == null) return;
final back = await camera.scanCard(side: CardSide.back);
```

### Tham số `scanCard`

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `side` | `CardSide` | `front` | Mặt giấy tờ. Dùng làm tiêu đề mặc định ("Mặt trước giấy tờ" / "Mặt sau giấy tờ"). |
| `options` | [`ScanOptions`](#scanoptions) | | Cách chụp và các ngưỡng. |
| `localized` | [`ScanLocalized`](#scanlocalized) | | Đổi chữ hiển thị. |

### `ScanOptions`

| Thuộc tính | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `captureMode` | `CaptureMode` | `manual` | `manual`: hiện nút "Chụp ảnh" khi giấy tờ đúng khung. `auto`: tự chụp khi giấy tờ đúng khung và đứng yên. |
| `readQr` | `bool` | `true` | Đọc QR (CCCD gắn chip có QR ở mặt trước). |
| `saveImages` | `bool` | `true` | Lưu ảnh JPEG vào thư mục cache của app. |
| `jpegQuality` | `int` | `90` | Chất lượng JPEG 1..100. |
| `edgeTolerance` | `double` | `0.04` | Cho phép giấy tờ lấn ra ngoài khung tối đa 4% (bù sai số). Lấn nhiều hơn → báo lệch trên/dưới/trái/phải. |
| `minWidthRatio` | `double` | `0.6` | Giấy tờ phải rộng ít nhất 60% khung. Nhỏ hơn → báo "quá xa" (chữ nhỏ dễ đọc sai). |
| `maxSkewDegrees` | `double` | `5` | Cạnh giấy tờ lệch quá 5° so với khung → báo "xô lệch". |

### `ScanLocalized`

Trường nào để `null` thì dùng chữ mặc định tiếng Việt của SDK.

| Thuộc tính | Khoá native | Mặc định |
|---|---|---|
| `title` | | Mặt trước giấy tờ / Mặt sau giấy tờ |
| `subtitle` | `ekyc_guide_for_capturing_id_card` | Đặt giấy tờ nằm vừa khung hình chữ nhật, chụp đủ ánh sáng và rõ nét |
| `captureButton` | `ekyc_button_capture` | Chụp ảnh |
| `noCard` | `ekyc_error_no_card` | Vui lòng đưa giấy tờ vào trong khung hình |
| `blur` | `ekyc_error_blur` | Giấy tờ mờ nhòe. Vui lòng đặt giấy tờ trên mặt phẳng và giữ yên giấy tờ khi chụp |
| `blurTitle` | `ekyc_title_card_blur` | Hãy giữ yên |
| `cardTop` / `cardBottom` / `cardLeft` / `cardRight` | `ekyc_error_card_top` / `_bottom` / `_left` / `_right` | Giấy tờ bị lệch trên/dưới/trái/phải. Vui lòng đặt giấy tờ thẳng góc với khung chụp |
| `wobbly` | `ekyc_title_wobbly` | Vui lòng đặt Giấy tờ thẳng góc, không bị xô lệch khi chụp |
| `dark` | `ekyc_error_dark` | Không quét được thông tin, vui lòng đặt giấy tờ ở nơi có ánh sáng phù hợp |
| `bright` | `ekyc_error_bright` | Ảnh quá sáng, vui lòng tránh nguồn sáng chiếu trực tiếp vào giấy tờ |
| `glare` | `ekyc_error_glare` | Giấy tờ bị lóa sáng, vui lòng nghiêng nhẹ giấy tờ để tránh phản chiếu |
| `tooClose` | `ekyc_error_too_close` | Giấy tờ bị cắt góc. Vui lòng đưa giấy tờ ra xa hơn một chút |
| `tooFar` | `ekyc_error_too_far` | Giấy tờ ở quá xa. Vui lòng đưa giấy tờ lại gần hơn |
| `ready` | `ekyc_title_card_ready` | Giấy tờ đã nằm đúng khung, nhấn Chụp ảnh |
| `holdStill` | `ekyc_title_hold_still` | Giữ yên giấy tờ trong giây lát... (chế độ `auto`) |
| `reading` | `ekyc_title_reading` | Đang đọc thông tin, giữ yên giấy tờ... |
| `readFailed` | `ekyc_error_read_failed` | Không đọc được thông tin trên giấy tờ, vui lòng thử lại |

```dart
await camera.scanCard(
  side: CardSide.front,
  localized: const ScanLocalized(
    title: 'Căn Cước mặt trước',
    blur: 'Ảnh bị mờ, giữ chắc tay nhé',
  ),
);
```

### `ScanResult`

| Thuộc tính | Kiểu | Mô tả |
|---|---|---|
| `side` | `CardSide` | Mặt đã chụp. |
| `cardImagePath` | `String?` | Ảnh JPEG cắt theo giấy tờ. |
| `imagePath` | `String?` | Ảnh JPEG khung hình đầy đủ. |
| `lines` | `List<TextLine>` | Dòng chữ OCR trong khung, từ trên xuống, trái sang phải. `TextLine.box` là vị trí theo khung (0..1). |
| `fullText` | `String` | Toàn bộ chữ, mỗi dòng một hàng. |
| `qrRaw` | `String?` | Chuỗi QR gốc. |
| `cccdQr` | `CccdQrData?` | QR CCCD đã tách: `idNumber`, `oldIdNumber`, `fullName`, `dateOfBirth`, `sex`, `address`, `issueDate`. |
| `cardBounds` | `NormRect?` | Biên giấy tờ theo khung. |
| `quality` | `FrameQuality` | Độ sáng, tỉ lệ lóa, độ nét lúc chụp. |

> Ảnh được lưu ở thư mục cache của app (`cacheDir/jk_ocr/` trên Android, `Caches/jk_ocr/` trên iOS). App **tự xoá**
> khi dùng xong. Kết quả chứa dữ liệu cá nhân: **không log** ra console / dịch vụ ngoài.

### Lỗi

`scanCard` trả `null` khi người dùng bấm quay lại. Các trường hợp còn lại ném `JkOcrException`:

| `code` | Khi nào |
|---|---|
| `permissionDenied` | Người dùng từ chối quyền camera. |
| `cameraUnavailable` | Thiết bị không có camera / không mở được camera. |
| `busy` | Gọi `scanCard` khi màn hình quét đang mở. |
| `noActivity` | Không tìm thấy Activity / ViewController để mở màn hình. |

---

## App ví dụ

```sh
cd example
flutter run
```

---

## Cập nhật SDK native

Mã native thật (Kotlin / Swift) nằm ở **repo SDK native riêng** (thư mục chứa `android/` và `ios/`). Repo này chỉ chứa
**bản đóng gói** của chúng:

- Android: repo Maven cục bộ `jk_ocr_camera_android/android/maven/`.
- iOS: bản sao nguồn trong `jk_ocr_camera_ios/ios/jk_ocr_camera_ios/Sources/jk_ocr_camera_ios/OcrSdk` và `Resources`.

Sau khi sửa SDK native, từ gốc repo này chạy lại rồi commit các thư mục được sinh ra:

```sh
./tool/sync_native.sh /đường/dẫn/tới/repo-native
```
