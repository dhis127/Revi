/// AI 독서 리포트 — 매월 1일 생성
class ReadingReport {
  const ReadingReport({
    required this.id,
    required this.year,
    required this.month,
    required this.generatedAt,
    required this.booksAdded,
    required this.quotesAdded,
    required this.topBookTitle,
    required this.quotesBySlot,
    required this.aiComment,
    this.isRead = false,
  });

  final String id;
  final int year;
  final int month;
  final DateTime generatedAt;

  /// 해당 월에 추가된 책 수
  final int booksAdded;

  /// 해당 월에 추가된 문장 수
  final int quotesAdded;

  /// 해당 월에 가장 많이 하이라이트된 책 제목 (없으면 빈 문자열)
  final String topBookTitle;

  /// 슬롯별 문장 수 { 'sage': 12, 'terra': 5, ... }
  final Map<String, int> quotesBySlot;

  /// AI 한 줄 코멘트
  final String aiComment;

  /// 앱 내 알림 읽음 여부
  final bool isRead;

  /// 책 표지 연월 코드 — "2026년 5월" → "2605"
  String get yearMonthCode =>
      '${year.toString().substring(2)}${month.toString().padLeft(2, '0')}';

  /// 표시용 한국어 연월 — "2026년 5월"
  String get labelKo => '$year년 $month월';

  ReadingReport copyWith({bool? isRead}) => ReadingReport(
        id: id,
        year: year,
        month: month,
        generatedAt: generatedAt,
        booksAdded: booksAdded,
        quotesAdded: quotesAdded,
        topBookTitle: topBookTitle,
        quotesBySlot: quotesBySlot,
        aiComment: aiComment,
        isRead: isRead ?? this.isRead,
      );
}
