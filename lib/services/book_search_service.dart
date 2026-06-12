import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// 도서 표지 검색 결과 한 건
class BookCoverResult {
  final String title;
  final String author;
  final String publisher;
  final String year;     // 출간연도 (없으면 '')
  final String coverUrl; // 표지 썸네일 URL (https)
  final String source;   // 'kakao' | 'google'

  const BookCoverResult({
    required this.title,
    required this.author,
    required this.publisher,
    required this.year,
    required this.coverUrl,
    required this.source,
  });
}

/// 도서 표지 검색 — 카카오 책 검색 우선, 결과 없으면 Google Books 폴백.
/// 동일 도서의 여러 판본(개정판·에디션)이 함께 반환되어 유저가 고를 수 있음.
class BookSearchService {
  BookSearchService._();

  static const _timeout = Duration(seconds: 6);

  /// 제목(+저자)으로 표지 후보 검색.
  /// 네트워크 오류 시 [BookSearchException]을 던짐 — UI에서 안내 처리.
  static Future<List<BookCoverResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    List<BookCoverResult> results;
    try {
      results = await _searchKakao(q);
    } catch (_) {
      // 카카오 실패 시 구글로 폴백 시도
      results = [];
    }
    if (results.isNotEmpty) return results;

    try {
      return await _searchGoogle(q);
    } catch (e) {
      throw const BookSearchException('검색에 실패했어요. 네트워크를 확인해주세요.');
    }
  }

  // ── 카카오 책 검색 ─────────────────────────────────────────────────────────
  static Future<List<BookCoverResult>> _searchKakao(String q) async {
    final uri = Uri.https('dapi.kakao.com', '/v3/search/book', {
      'query': q,
      'size': '20',
    });
    final res = await http.get(uri, headers: {
      'Authorization': 'KakaoAK ${AppConfig.kakaoRestApiKey}',
    }).timeout(_timeout);
    if (res.statusCode != 200) {
      throw BookSearchException('카카오 검색 오류 (${res.statusCode})');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final docs = (json['documents'] as List?) ?? [];
    return docs
        .cast<Map<String, dynamic>>()
        .map((d) {
          final thumb = (d['thumbnail'] as String?) ?? '';
          if (thumb.isEmpty) return null;
          final dt = (d['datetime'] as String?) ?? '';
          return BookCoverResult(
            title: (d['title'] as String?) ?? '',
            author: ((d['authors'] as List?) ?? []).join(', '),
            publisher: (d['publisher'] as String?) ?? '',
            year: dt.length >= 4 ? dt.substring(0, 4) : '',
            coverUrl: thumb.replaceFirst('http://', 'https://'),
            source: 'kakao',
          );
        })
        .whereType<BookCoverResult>()
        .toList();
  }

  // ── Google Books (해외·영문 도서 폴백) ─────────────────────────────────────
  static Future<List<BookCoverResult>> _searchGoogle(String q) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': q,
      'maxResults': '20',
      'printType': 'books',
    });
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw BookSearchException('Google Books 오류 (${res.statusCode})');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final items = (json['items'] as List?) ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map((item) {
          final info = (item['volumeInfo'] as Map?) ?? {};
          final links = (info['imageLinks'] as Map?) ?? {};
          var thumb = (links['thumbnail'] as String?) ??
              (links['smallThumbnail'] as String?) ??
              '';
          if (thumb.isEmpty) return null;
          // ATS(https 필수) + 고해상도 요청
          thumb = thumb
              .replaceFirst('http://', 'https://')
              .replaceFirst('zoom=1', 'zoom=2');
          final date = (info['publishedDate'] as String?) ?? '';
          return BookCoverResult(
            title: (info['title'] as String?) ?? '',
            author: ((info['authors'] as List?) ?? []).join(', '),
            publisher: (info['publisher'] as String?) ?? '',
            year: date.length >= 4 ? date.substring(0, 4) : '',
            coverUrl: thumb,
            source: 'google',
          );
        })
        .whereType<BookCoverResult>()
        .toList();
  }

  // ── 표지 이미지 다운로드 ───────────────────────────────────────────────────
  static Future<Uint8List?> downloadCover(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  // ── 표지 비율(3:4) 센터 크롭 ──────────────────────────────────────────────
  /// 갤러리·카메라로 받은 임의 비율 이미지를 책 표지 비율로 정규화.
  /// 이미 3:4에 가깝거나(±8%) 디코딩 실패 시 원본 그대로 반환.
  static Future<Uint8List> cropToCoverRatio(Uint8List src) async {
    try {
      final codec = await ui.instantiateImageCodec(src);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final w = img.width.toDouble();
      final h = img.height.toDouble();

      const target = 3 / 4; // 표지 비율 (가로/세로)
      final ratio = w / h;
      if ((ratio - target).abs() < target * 0.08) {
        img.dispose();
        codec.dispose();
        return src; // 이미 표지 비율
      }

      double cw, ch;
      if (ratio > target) {
        ch = h;
        cw = h * target; // 좌우 잘라냄
      } else {
        cw = w;
        ch = w / target; // 위아래 잘라냄
      }
      final sx = (w - cw) / 2;
      final sy = (h - ch) / 2;

      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        img,
        ui.Rect.fromLTWH(sx, sy, cw, ch),
        ui.Rect.fromLTWH(0, 0, cw, ch),
        ui.Paint(),
      );
      img.dispose();
      codec.dispose();

      final cropped =
          await recorder.endRecording().toImage(cw.round(), ch.round());
      final bytes =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      return bytes?.buffer.asUint8List() ?? src;
    } catch (_) {
      return src;
    }
  }
}

class BookSearchException implements Exception {
  final String message;
  const BookSearchException(this.message);
  @override
  String toString() => message;
}
