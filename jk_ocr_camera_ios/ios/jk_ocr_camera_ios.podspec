Pod::Spec.new do |s|
  s.name             = 'jk_ocr_camera_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of jk_ocr_camera: offline ID card scanning + OCR (Apple Vision).'
  s.description      = 'Quét giấy tờ tùy thân Việt Nam và OCR offline bằng Apple Vision, AVFoundation.'
  s.homepage         = 'https://github.com/MrTuyennn/jk_ocr_camera'
  s.license          = { :type => 'Proprietary', :text => 'Internal use.' }
  s.author           = 'MrTuyennn'
  s.source           = { :path => '.' }

  # Dùng chung nguồn với Swift Package (jk_ocr_camera_ios/Package.swift).
  # OcrSdk/** và Resources/** là bản sao của SDK native iOS (ios/Sources), sinh bởi tool/sync_native.sh.
  s.source_files     = 'jk_ocr_camera_ios/Sources/jk_ocr_camera_ios/**/*.swift'
  s.resource_bundles = { 'JkOcrResources' => ['jk_ocr_camera_ios/Sources/jk_ocr_camera_ios/Resources/**/*.strings'] }

  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'AVFoundation', 'Vision', 'CoreImage', 'CoreVideo', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
