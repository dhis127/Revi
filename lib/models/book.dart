import 'dart:convert';
import 'dart:typed_data';

class Book {
  final String id;
  final String title;
  final String author;
  final String color; // 'sage' | 'terra' | 'amber' | 'ink'
  final int shelf;    // 0 = covers, 1-3 = spines
  final int highlightCount;
  final String lastDate;
  final String? coverImagePath;
  final Uint8List? coverImageBytes;
  final String? comment;
  /// 목차 OCR 텍스트 (여러 페이지 누적 가능). 없으면 빈 문자열.
  final String tocText;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.color,
    required this.shelf,
    this.highlightCount = 0,
    this.lastDate = '',
    this.coverImagePath,
    this.coverImageBytes,
    this.comment,
    this.tocText = '',
  });

  Book copyWith({String? color, int? shelf, int? highlightCount, String? coverImagePath, Uint8List? coverImageBytes, String? comment, String? tocText}) => Book(
    id: id,
    title: title,
    author: author,
    color: color ?? this.color,
    shelf: shelf ?? this.shelf,
    highlightCount: highlightCount ?? this.highlightCount,
    lastDate: lastDate,
    coverImagePath: coverImagePath ?? this.coverImagePath,
    coverImageBytes: coverImageBytes ?? this.coverImageBytes,
    comment: comment ?? this.comment,
    tocText: tocText ?? this.tocText,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'color': color,
    'shelf': shelf,
    'highlightCount': highlightCount,
    'lastDate': lastDate,
    'coverImagePath': coverImagePath,
    'coverImageBytes': coverImageBytes != null ? base64Encode(coverImageBytes!) : null,
    'comment': comment,
    'tocText': tocText,
  };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
    id: j['id'] as String,
    title: j['title'] as String,
    author: j['author'] as String,
    color: j['color'] as String,
    shelf: j['shelf'] as int,
    highlightCount: (j['highlightCount'] as int?) ?? 0,
    lastDate: (j['lastDate'] as String?) ?? '',
    coverImagePath: j['coverImagePath'] as String?,
    coverImageBytes: j['coverImageBytes'] != null
        ? base64Decode(j['coverImageBytes'] as String)
        : null,
    comment: j['comment'] as String?,
    tocText: (j['tocText'] as String?) ?? '',
  );
}

