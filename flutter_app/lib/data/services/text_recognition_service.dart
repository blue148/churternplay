import 'package:flutter/services.dart';

/// One line of text recognised in an image.
///
/// Coordinates are normalised to 0–1 with a top-left origin, so callers don't
/// need to know the source image size or orientation.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory OcrLine.fromMap(Map<Object?, Object?> map) => OcrLine(
        text: map['text'] as String? ?? '',
        left: (map['left'] as num?)?.toDouble() ?? 0,
        top: (map['top'] as num?)?.toDouble() ?? 0,
        width: (map['width'] as num?)?.toDouble() ?? 0,
        height: (map['height'] as num?)?.toDouble() ?? 0,
      );

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

/// On-device OCR over a native method channel: Apple Vision on iOS
/// (ios/Runner/TextRecognizer.swift), ML Kit on Android (MainActivity.kt).
/// Images never leave the device.
abstract class TextRecognitionService {
  static const _channel = MethodChannel('churternplay/text_recognition');

  static Future<List<OcrLine>> recognize(String imagePath) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'recognize',
      {'path': imagePath},
    );
    final lines = result?['lines'] as List<Object?>? ?? const [];
    return lines
        .whereType<Map<Object?, Object?>>()
        .map(OcrLine.fromMap)
        .where((l) => l.text.trim().isNotEmpty)
        .toList();
  }
}
