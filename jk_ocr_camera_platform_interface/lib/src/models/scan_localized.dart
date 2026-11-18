/// Chữ hiển thị trên màn hình quét. Trường nào `null` thì dùng mặc định tiếng Việt của SDK
/// (string resource `ekyc_*` trên Android, `OcrScanner.strings` trên iOS).
class ScanLocalized {
  const ScanLocalized({
    this.title,
    this.subtitle,
    this.captureButton,
    this.noCard,
    this.blur,
    this.blurTitle,
    this.cardTop,
    this.cardBottom,
    this.cardLeft,
    this.cardRight,
    this.wobbly,
    this.dark,
    this.bright,
    this.glare,
    this.tooClose,
    this.tooFar,
    this.ready,
    this.holdStill,
    this.reading,
    this.readFailed,
  });

  /// Tiêu đề. Mặc định: "Mặt trước giấy tờ" / "Mặt sau giấy tờ" theo `side`.
  final String? title;

  /// Dòng hướng dẫn dưới tiêu đề (`ekyc_guide_for_capturing_id_card`).
  final String? subtitle;

  /// Chữ trên nút chụp (`ekyc_button_capture`).
  final String? captureButton;

  /// `ekyc_error_no_card`
  final String? noCard;

  /// `ekyc_error_blur`
  final String? blur;

  /// Thay dòng hướng dẫn khi ảnh mờ (`ekyc_title_card_blur`).
  final String? blurTitle;

  /// `ekyc_error_card_top`
  final String? cardTop;

  /// `ekyc_error_card_bottom`
  final String? cardBottom;

  /// `ekyc_error_card_left`
  final String? cardLeft;

  /// `ekyc_error_card_right`
  final String? cardRight;

  /// `ekyc_title_wobbly`
  final String? wobbly;

  /// `ekyc_error_dark`
  final String? dark;

  /// `ekyc_error_bright`
  final String? bright;

  /// `ekyc_error_glare`
  final String? glare;

  /// `ekyc_error_too_close`
  final String? tooClose;

  /// `ekyc_error_too_far`
  final String? tooFar;

  /// `ekyc_title_card_ready`
  final String? ready;

  /// `ekyc_title_hold_still` (chế độ tự chụp)
  final String? holdStill;

  /// `ekyc_title_reading`
  final String? reading;

  /// `ekyc_error_read_failed`
  final String? readFailed;

  /// Map khoá `ekyc_*` → chữ, chỉ gồm trường đã đặt.
  Map<String, String> messagesToMap() {
    final m = <String, String?>{
      'ekyc_error_no_card': noCard,
      'ekyc_error_blur': blur,
      'ekyc_title_card_blur': blurTitle,
      'ekyc_error_card_top': cardTop,
      'ekyc_error_card_bottom': cardBottom,
      'ekyc_error_card_left': cardLeft,
      'ekyc_error_card_right': cardRight,
      'ekyc_title_wobbly': wobbly,
      'ekyc_error_dark': dark,
      'ekyc_error_bright': bright,
      'ekyc_error_glare': glare,
      'ekyc_error_too_close': tooClose,
      'ekyc_error_too_far': tooFar,
      'ekyc_title_card_ready': ready,
      'ekyc_title_hold_still': holdStill,
      'ekyc_title_reading': reading,
      'ekyc_error_read_failed': readFailed,
    };
    return {
      for (final e in m.entries)
        if (e.value != null) e.key: e.value!,
    };
  }
}
