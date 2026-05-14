class Highlight {
  final String id;
  final String bookId;
  final String text;
  final int page;
  final String slot; // 'sage' | 'terra' | 'amber'
  final String date;
  final String note;
  final String toc;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.text,
    required this.page,
    required this.slot,
    required this.date,
    this.note = '',
    this.toc = '',
  });

  Highlight copyWith({String? bookId, String? note, String? toc}) => Highlight(
    id: id,
    bookId: bookId ?? this.bookId,
    text: text,
    page: page,
    slot: slot,
    date: date,
    note: note ?? this.note,
    toc: toc ?? this.toc,
  );
}

const List<Highlight> seedHighlights = [
  Highlight(id: 'h1', bookId: 'b1', text: '나는 모든 무엇이 누군가의 눈물이 나올 만큼 잊고 있었다.', page: 23, slot: 'sage',  date: '2026.04.30', toc: '2장 — 잿빛 골짜기'),
  Highlight(id: 'h2', bookId: 'b1', text: '그녀는 고기를 먹지 않았다고 했다. 이유는 눈물이었다.',     page: 47, slot: 'terra', date: '2026.04.28', toc: '3장 — 첫 파티'),
  Highlight(id: 'h3', bookId: 'b1', text: '붉어 오는 김보배가 주위를 새로 알아보지 못했다.',          page: 67, slot: 'amber', date: '2026.04.25', note: 'p.67 — 시점 전환의 첫 조짐.', toc: '4장 — 옥스퍼드의 환영'),
  // 아코디언 테스트용 긴 문단
  Highlight(id: 'h1t', bookId: 'b1', text: '개츠비가 믿었던 녹색 불빛, 연년이 우리 앞에서 멀어져 가는 황홀한 미래에 대한 믿음이여. 그것은 우리에게서 달아났지만 그것은 문제가 되지 않는다 — 내일 우리는 더 빨리 달릴 것이고 팔을 더 멀리 뻗을 것이다. 그리하여 아름다운 어느 아침에 — 우리는 여전히 조류에 맞서 배를 젓고, 끊임없이 과거 속으로 떠밀려 가고 있다.', page: 189, slot: 'sage', date: '2026.04.29', toc: '9장 — 마지막 밤'),
  Highlight(id: 'h4', bookId: 'b2', text: '새는 알에서 나오려고 투쟁한다. 알은 세계다.',             page: 118, slot: 'sage',  date: '2026.04.27', toc: '7장 — 베아트리체'),
  Highlight(id: 'h5', bookId: 'b3', text: '가장 중요한 것은 눈에 보이지 않아.',                    page: 82,  slot: 'amber', date: '2026.04.18', note: '여우와의 작별 장면.', toc: '21장 — 여우의 비밀'),
];
