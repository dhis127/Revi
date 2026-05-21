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
  });

  Book copyWith({int? shelf, int? highlightCount, String? coverImagePath, Uint8List? coverImageBytes, String? comment}) => Book(
    id: id,
    title: title,
    author: author,
    color: color,
    shelf: shelf ?? this.shelf,
    highlightCount: highlightCount ?? this.highlightCount,
    lastDate: lastDate,
    coverImagePath: coverImagePath ?? this.coverImagePath,
    coverImageBytes: coverImageBytes ?? this.coverImageBytes,
    comment: comment ?? this.comment,
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
  );
}

const List<Book> seedBooks = [
  // shelf 0 — covers (3, centered)
  Book(id: 'b1', title: '위대한 개츠비',     author: 'F. 스콧 피츠제럴드',   color: 'sage',  shelf: 0, highlightCount: 4, lastDate: '2026.04.30'),
  Book(id: 'b2', title: '데미안',           author: '헤르만 헤세',           color: 'terra', shelf: 0, highlightCount: 7, lastDate: '2026.04.27'),
  Book(id: 'b3', title: '어린 왕자',        author: '앙투안 드 생텍쥐페리',   color: 'amber', shelf: 0, highlightCount: 3, lastDate: '2026.04.18'),
  // shelf 1 — spines
  Book(id: 'b4', title: '작별하지 않는다',   author: '한 강',                 color: 'sage',  shelf: 1, highlightCount: 5, lastDate: '2026.04.10'),
  Book(id: 'b5', title: 'Plainwater',      author: 'Anne Carson',           color: 'terra', shelf: 1, highlightCount: 2, lastDate: '2026.04.03'),
  Book(id: 'b6', title: 'Austerlitz',      author: 'W. G. Sebald',          color: 'amber', shelf: 1, highlightCount: 3, lastDate: '2026.03.28'),
  Book(id: 'b7', title: '일곱 해의 마지막', author: '김 연수',               color: 'ink',   shelf: 1, highlightCount: 1, lastDate: '2026.03.20'),
  Book(id: 'b8', title: 'Just Kids',       author: 'Patti Smith',           color: 'terra', shelf: 1, highlightCount: 4, lastDate: '2026.03.18'),
  // shelf 2
  Book(id: 'b9',  title: '몰락이라는 영원',  author: '배 수아',              color: 'amber', shelf: 2, highlightCount: 2, lastDate: '2026.03.12'),
  Book(id: 'b10', title: 'On Photography',  author: 'Susan Sontag',         color: 'sage',  shelf: 2, highlightCount: 6, lastDate: '2026.03.10'),
  Book(id: 'b11', title: 'The White Book',  author: 'Han Kang',             color: 'terra', shelf: 2, highlightCount: 3, lastDate: '2026.03.05'),
  Book(id: 'b12', title: '기억의 풍경',     author: '정 지돈',              color: 'ink',   shelf: 2, highlightCount: 1, lastDate: '2026.02.28'),
  Book(id: 'b13', title: '우리들의 한국어', author: '안 상순',              color: 'amber', shelf: 2, highlightCount: 2, lastDate: '2026.02.22'),
  // shelf 3
  Book(id: 'b14', title: "A Lover's Discourse", author: 'Roland Barthes',   color: 'terra', shelf: 3, highlightCount: 5, lastDate: '2026.02.18'),
  Book(id: 'b15', title: 'Ways of Seeing',  author: 'John Berger',          color: 'sage',  shelf: 3, highlightCount: 4, lastDate: '2026.02.10'),
  Book(id: 'b16', title: '유년의 정원',     author: '박 형준',              color: 'amber', shelf: 3, highlightCount: 2, lastDate: '2026.02.05'),
  Book(id: 'b17', title: '세 명의 친구',    author: '안 보윤',              color: 'terra', shelf: 3, highlightCount: 1, lastDate: '2026.01.28'),
];
