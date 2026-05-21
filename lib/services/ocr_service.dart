import 'package:flutter/services.dart';

/// OCR 인식 결과 한 줄 — 텍스트 + 정규화 좌표 (iOS Vision 기준: 좌하단 원점)
class OcrLine {
  final String text;
  final double x, y, w, h; // 0‥1 normalized, origin = bottom-left of image
  final double confidence;  // Vision 인식 신뢰도 0.0–1.0
  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.confidence = 1.0,
  });
}

class OcrService {
  static const platform = MethodChannel('revi/ocr');

  static Future<List<OcrLine>> recognizeText(String imagePath) async {
    try {
      final result = await platform.invokeMethod<List<dynamic>>(
        'recognizeText',
        {'path': imagePath},
      );
      if (result == null) return [];
      return result.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return OcrLine(
          text: map['text'] as String,
          x: (map['x'] as num).toDouble(),
          y: (map['y'] as num).toDouble(),
          w: (map['w'] as num).toDouble(),
          h: (map['h'] as num).toDouble(),
          confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
