import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jk_ocr_camera/jk_ocr_camera.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'jk_ocr_camera',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const ScanPage(),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _camera = JkOcrCamera();
  final Map<CardSide, ScanResult> _results = {};
  CaptureMode _mode = CaptureMode.manual;
  String? _message;

  Future<void> _scan(CardSide side) async {
    setState(() => _message = null);
    try {
      final result = await _camera.scanCard(
        side: side,
        options: ScanOptions(captureMode: _mode),
        // Ví dụ đổi chữ; bỏ trống thì dùng mặc định tiếng Việt của SDK.
        localized: ScanLocalized(
          title: side == CardSide.front ? 'Căn Cước mặt trước' : 'Căn Cước mặt sau',
        ),
      );
      if (!mounted) return;
      setState(() {
        if (result == null) {
          _message = 'Đã huỷ';
        } else {
          _results[side] = result;
        }
      });
    } on JkOcrException catch (e) {
      if (!mounted) return;
      setState(() => _message = switch (e.code) {
            JkOcrErrorCode.permissionDenied => 'Chưa cấp quyền camera',
            JkOcrErrorCode.cameraUnavailable => 'Không mở được camera',
            _ => 'Lỗi: ${e.code.wire}',
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('jk_ocr_camera')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<CaptureMode>(
            segments: const [
              ButtonSegment(value: CaptureMode.manual, label: Text('Bấm nút chụp')),
              ButtonSegment(value: CaptureMode.auto, label: Text('Tự chụp')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _scan(CardSide.front),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Mặt trước'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _scan(CardSide.back),
                  icon: const Icon(Icons.flip),
                  label: const Text('Mặt sau'),
                ),
              ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          for (final side in CardSide.values)
            if (_results[side] != null) _ResultCard(result: _results[side]!),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final qr = result.cccdQr;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.side == CardSide.front ? 'Mặt trước' : 'Mặt sau', style: text.titleMedium),
            if (result.cardImagePath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(result.cardImagePath!)),
              ),
            ],
            if (qr != null) ...[
              const SizedBox(height: 12),
              Text('QR CCCD', style: text.labelLarge),
              Text('Số: ${qr.idNumber}'),
              if (qr.fullName != null) Text('Họ tên: ${qr.fullName}'),
              if (qr.dateOfBirth != null) Text('Ngày sinh: ${qr.dateOfBirth}'),
              if (qr.sex != null) Text('Giới tính: ${qr.sex}'),
              if (qr.address != null) Text('Địa chỉ: ${qr.address}'),
              if (qr.issueDate != null) Text('Ngày cấp: ${qr.issueDate}'),
            ],
            const SizedBox(height: 12),
            Text('OCR (${result.lines.length} dòng)', style: text.labelLarge),
            SelectableText(result.fullText),
          ],
        ),
      ),
    );
  }
}
