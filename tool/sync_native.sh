#!/usr/bin/env bash
# Đóng gói SDK native vào các package Flutter. Chạy lại mỗi khi sửa SDK native, rồi commit kết quả.
#
#   - Android: xuất AAR + POM (com.jk.ocr:ocr-core|ocr-camera|ocr-scanner) vào
#     jk_ocr_camera_android/android/maven (repo Maven cục bộ, phải commit).
#   - iOS: chép nguồn Swift + .strings vào
#     jk_ocr_camera_ios/ios/jk_ocr_camera_ios/Sources/jk_ocr_camera_ios/{OcrSdk,Resources} (phải commit).
#
# Cách dùng:
#   ./tool/sync_native.sh /đường/dẫn/tới/repo-native     # thư mục chứa android/ và ios/
#   JK_OCR_NATIVE_DIR=/đường/dẫn ./tool/sync_native.sh
#   ./tool/sync_native.sh                                # mặc định: thư mục cha của repo này
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE_DIR="${1:-${JK_OCR_NATIVE_DIR:-$PLUGIN_DIR/..}}"

if [ ! -x "$NATIVE_DIR/android/gradlew" ] || [ ! -d "$NATIVE_DIR/ios/Sources/OcrScanner" ]; then
  echo "Không tìm thấy SDK native ở: $NATIVE_DIR" >&2
  echo "Cần thư mục chứa android/gradlew và ios/Sources/OcrScanner." >&2
  echo "Dùng: ./tool/sync_native.sh /đường/dẫn/tới/repo-native" >&2
  exit 1
fi
NATIVE_DIR="$(cd "$NATIVE_DIR" && pwd)"
echo "==> SDK native: $NATIVE_DIR"

echo "==> Android: publish com.jk.ocr:* vào jk_ocr_camera_android/android/maven"
MAVEN_DIR="$PLUGIN_DIR/jk_ocr_camera_android/android/maven"
rm -rf "$MAVEN_DIR"
mkdir -p "$MAVEN_DIR"
(cd "$NATIVE_DIR/android" && ./gradlew -q publishReleasePublicationToJkOcrRepository -PjkOcrRepo="$MAVEN_DIR")

echo "==> iOS: chép nguồn Swift + .strings vào jk_ocr_camera_ios (dùng chung cho SPM và CocoaPods)"
TARGET="$PLUGIN_DIR/jk_ocr_camera_ios/ios/jk_ocr_camera_ios/Sources/jk_ocr_camera_ios"
rm -rf "$TARGET/OcrSdk" "$TARGET/Resources"
mkdir -p "$TARGET/OcrSdk" "$TARGET/Resources/vi.lproj"
for module in OcrCore OcrCamera OcrScanner; do
  mkdir -p "$TARGET/OcrSdk/$module"
  find "$NATIVE_DIR/ios/Sources/$module" -maxdepth 1 -name '*.swift' -exec cp {} "$TARGET/OcrSdk/$module/" \;
  if [ -d "$NATIVE_DIR/ios/Sources/$module/Resources/vi.lproj" ]; then
    cp "$NATIVE_DIR/ios/Sources/$module/Resources/vi.lproj/"*.strings "$TARGET/Resources/vi.lproj/"
  fi
done
cat > "$TARGET/OcrSdk/README.md" <<'TXT'
Bản sao tự động của SDK native iOS (ios/Sources), sinh bởi tool/sync_native.sh.
KHÔNG sửa ở đây: sửa ở repo native rồi chạy lại script.
TXT

echo "==> Xong. Nhớ commit jk_ocr_camera_android/android/maven và jk_ocr_camera_ios/ios/.../OcrSdk, Resources."
