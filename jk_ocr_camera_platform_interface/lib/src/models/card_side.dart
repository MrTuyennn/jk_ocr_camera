/// Mặt giấy tờ cần chụp.
enum CardSide {
  front('front'),
  back('back');

  const CardSide(this.wire);

  /// Giá trị gửi qua kênh native.
  final String wire;

  static CardSide fromWire(Object? v) =>
      CardSide.values.firstWhere((s) => s.wire == v, orElse: () => CardSide.front);
}
