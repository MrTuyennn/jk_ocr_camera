import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_ocr_camera_platform_interface/jk_ocr_camera_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelJkOcrCamera();
  const channel = MethodChannel('jk_ocr_camera');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('gửi đúng tham số', () async {
    MethodCall? call;
    messenger.setMockMethodCallHandler(channel, (c) async {
      call = c;
      return null;
    });
    await platform.scanCard(
      side: CardSide.back,
      options: const ScanOptions(captureMode: CaptureMode.auto, minWidthRatio: 0.5),
      localized: const ScanLocalized(title: 'Mặt sau', blur: 'Mờ quá'),
    );
    final args = call!.arguments as Map;
    expect(call!.method, 'scanCard');
    expect(args['side'], 'back');
    expect(args['title'], 'Mặt sau');
    expect(args['captureMode'], 'auto');
    expect((args['placement'] as Map)['minWidthRatio'], 0.5);
    expect(args['messages'], {'ekyc_error_blur': 'Mờ quá'});
  });

  test('huỷ trả null', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await platform.scanCard(), isNull);
  });

  test('parse kết quả', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {
          'side': 'front',
          'imagePath': '/tmp/a.jpg',
          'cardImagePath': '/tmp/b.jpg',
          'qrRaw': '001090012345|||||',
          'cardBounds': {'left': 0.01, 'top': 0.02, 'right': 0.99, 'bottom': 0.98},
          'quality': {'meanLuma': 130.0, 'glareRatio': 0.0, 'sharpness': 200.0},
          'lines': [
            {'text': 'CĂN CƯỚC CÔNG DÂN', 'box': {'left': 0.1, 'top': 0.1, 'right': 0.6, 'bottom': 0.15}, 'confidence': 0.9},
            {'text': 'Số: 001090012345', 'box': {'left': 0.1, 'top': 0.3, 'right': 0.6, 'bottom': 0.35}, 'confidence': null},
          ],
          'cccdQr': {
            'idNumber': '001090012345',
            'oldIdNumber': null,
            'fullName': 'Nguyễn Văn A',
            'dateOfBirth': '01/01/1990',
            'sex': 'Nam',
            'address': 'Hà Nội',
            'issueDate': '15/08/2021',
            'rawFields': ['001090012345', '', 'Nguyễn Văn A'],
          },
        });
    final r = (await platform.scanCard())!;
    expect(r.side, CardSide.front);
    expect(r.cardImagePath, '/tmp/b.jpg');
    expect(r.lines, hasLength(2));
    expect(r.lines[1].confidence, isNull);
    expect(r.fullText, 'CĂN CƯỚC CÔNG DÂN\nSố: 001090012345');
    expect(r.cccdQr!.fullName, 'Nguyễn Văn A');
    expect(r.cardBounds!.width, closeTo(0.98, 1e-9));
    expect(r.cccdQr.toString(), isNot(contains('Nguyễn')));
  });

  test('lỗi native thành JkOcrException', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'permission_denied');
    });
    expect(
      () => platform.scanCard(),
      throwsA(isA<JkOcrException>().having((e) => e.code, 'code', JkOcrErrorCode.permissionDenied)),
    );
  });
}
