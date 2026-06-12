class Highlight {
  final String id;
  final String bookId;
  final String text;
  final int page;
  final String slot; // 'sage' | 'terra' | 'amber'
  final String date;
  final String note;
  final String toc;
  /// 첨부 이미지(그래프·표 등) 파일 경로. 없으면 빈 문자열.
  final String imagePath;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.text,
    required this.page,
    required this.slot,
    required this.date,
    this.note = '',
    this.toc = '',
    this.imagePath = '',
  });

  Highlight copyWith({String? bookId, String? note, String? toc, String? imagePath}) => Highlight(
    id: id,
    bookId: bookId ?? this.bookId,
    text: text,
    page: page,
    slot: slot,
    date: date,
    note: note ?? this.note,
    toc: toc ?? this.toc,
    imagePath: imagePath ?? this.imagePath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'text': text,
    'page': page,
    'slot': slot,
    'date': date,
    'note': note,
    'toc': toc,
    'imagePath': imagePath,
  };

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
    id: j['id'] as String,
    bookId: j['bookId'] as String,
    text: j['text'] as String,
    page: j['page'] as int,
    slot: j['slot'] as String,
    date: j['date'] as String,
    note: (j['note'] as String?) ?? '',
    toc: (j['toc'] as String?) ?? '',
    imagePath: (j['imagePath'] as String?) ?? '',
  );
}

