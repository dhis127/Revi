import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 표지 이미지에서 대표 색상을 추출해 책장 팔레트(navy/wine/…) 중
/// 가장 가까운 색 이름으로 매핑한다.
///
/// 임의의 추출 색을 그대로 책등에 쓰면 우드톤 서재와 충돌하므로,
/// 큐레이션된 10색 팔레트로 스냅하여 전체 미감을 유지한다.
class CoverPalette {
  // 각 팔레트 이름의 대표(중간) 색 — design_tokens의 spine/cover 중간톤 기준
  static const Map<String, Color> _palette = {
    'navy':   Color(0xFF2E4870),
    'wine':   Color(0xFF8C2F4A),
    'forest': Color(0xFF24503A),
    'terra':  Color(0xFFB05330),
    'cognac': Color(0xFF7E4E2C),
    'slate':  Color(0xFF45586A),
    'amber':  Color(0xFF8A6523),
    'plum':   Color(0xFF5C2E72),
    'sage':   Color(0xFF4A7B5E),
    'ink':    Color(0xFF2A2018),
  };

  /// 표지 바이트 → 가장 가까운 팔레트 이름. 추출 실패 시 null.
  static Future<String?> nameFromImage(Uint8List bytes) async {
    final color = await _dominantColor(bytes);
    if (color == null) return null;
    return nearestName(color);
  }

  /// 임의 색 → 가장 가까운 팔레트 이름 (사람 눈 가중 RGB 거리).
  static String nearestName(Color c) {
    final cr = c.r * 255.0, cg = c.g * 255.0, cb = c.b * 255.0;
    String best = 'sage';
    double bestDist = double.infinity;
    _palette.forEach((name, p) {
      final dr = cr - p.r * 255.0;
      final dg = cg - p.g * 255.0;
      final db = cb - p.b * 255.0;
      final dist = 0.30 * dr * dr + 0.59 * dg * dg + 0.11 * db * db;
      if (dist < bestDist) {
        bestDist = dist;
        best = name;
      }
    });
    return best;
  }

  /// 이미지에서 대표 색 추출.
  /// 48px로 다운샘플 후, 무채색 배경(흰/검) 픽셀을 제외하고
  /// 채도가 높은 픽셀에 가중치를 둔 평균색을 계산한다.
  static Future<Color?> _dominantColor(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 48,
        targetHeight: 48,
      );
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return null;
      final px = data.buffer.asUint8List();

      double rSat = 0, gSat = 0, bSat = 0, wSat = 0; // 채도 가중 평균
      double rAll = 0, gAll = 0, bAll = 0;
      int nAll = 0; // 단순 평균 (폴백)

      for (int i = 0; i + 3 < px.length; i += 4) {
        final r = px[i].toDouble();
        final g = px[i + 1].toDouble();
        final b = px[i + 2].toDouble();
        final a = px[i + 3];
        if (a < 16) continue;

        final lum = (r + g + b) / 3.0;
        rAll += r;
        gAll += g;
        bAll += b;
        nAll++;
        if (lum < 18 || lum > 242) continue; // 거의 검정/흰색 배경 제외

        final maxc = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final minc = r < g ? (r < b ? r : b) : (g < b ? g : b);
        final sat = maxc <= 0 ? 0.0 : (maxc - minc) / maxc;
        final w = sat * sat + 0.04; // 채도 높을수록 강하게 반영
        rSat += r * w;
        gSat += g * w;
        bSat += b * w;
        wSat += w;
      }

      if (wSat > 0.5) {
        return Color.fromARGB(
          255,
          (rSat / wSat).round().clamp(0, 255),
          (gSat / wSat).round().clamp(0, 255),
          (bSat / wSat).round().clamp(0, 255),
        );
      }
      if (nAll > 0) {
        return Color.fromARGB(
          255,
          (rAll / nAll).round().clamp(0, 255),
          (gAll / nAll).round().clamp(0, 255),
          (bAll / nAll).round().clamp(0, 255),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
