// swift-tools-version: 5.9
import PackageDescription

// Swift Package Manager cho Flutter plugin (Flutter 3.24+). CocoaPods dùng chung thư mục nguồn
// qua ../jk_ocr_camera_ios.podspec.
//
// Sources/jk_ocr_camera_ios/OcrSdk và Resources là BẢN SAO của SDK native iOS (ios/Sources),
// sinh bởi tool/sync_native.sh ở gốc repo. Sửa ở repo native rồi chạy lại script.
let package = Package(
    name: "jk_ocr_camera_ios",
    defaultLocalization: "vi",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "jk-ocr-camera-ios", targets: ["jk_ocr_camera_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "jk_ocr_camera_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            exclude: ["OcrSdk/README.md"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
