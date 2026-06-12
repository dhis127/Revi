import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/book.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';
import 'archive_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _query = _ctrl.text.trim()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final q = _query.toLowerCase();

    final matchedBooks = q.isEmpty
        ? <Book>[]
        : state.books
            .where((b) =>
                b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q))
            .toList();

    final matchedHighlights = q.isEmpty
        ? <Highlight>[]
        : state.highlights
            .where((h) => h.text.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
      body: Column(
        children: [
          _buildSearchBar(context, isDark),
          Expanded(
            child: q.isEmpty
                ? _buildEmpty(isDark)
                : (matchedBooks.isEmpty && matchedHighlights.isEmpty)
                    ? _buildNoResult(isDark)
                    : _buildResults(state, matchedBooks, matchedHighlights, q, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DesignTokens.sage),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16,
                        color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: DesignTokens.hahmlet(13,
                            color: isDark ? DesignTokens.inkDark : DesignTokens.ink),
                        decoration: InputDecoration(
                          hintText: '책 또는 문장을 찾아요',
                          hintStyle: DesignTokens.hahmlet(13,
                              color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () => _ctrl.clear(),
                        child: Icon(Icons.close, size: 16,
                            color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('취소', style: DesignTokens.hahmlet(13,
                  color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 40,
              color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
          const SizedBox(height: 12),
          Text('책 제목, 저자, 문장으로 찾아요',
              style: DesignTokens.hahmlet(13,
                  color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
        ],
      ),
    );
  }

  Widget _buildNoResult(bool isDark) {
    return Center(
      child: Text('"$_query"에 대한 결과가 없어요',
          style: DesignTokens.hahmlet(13,
              color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
    );
  }

  Widget _buildResults(
    AppState state,
    List<Book> books,
    List<Highlight> highlights,
    String q,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (books.isNotEmpty) ...[
          _sectionHeader('책 · ${books.length}', isDark),
          ...books.map((b) => _bookTile(b, q, isDark)),
          const SizedBox(height: 8),
        ],
        if (highlights.isNotEmpty) ...[
          _sectionHeader('문장 · ${highlights.length}', isDark),
          ...highlights.map((h) {
            // 책 미지정·삭제된 책 폴백 (잘못된 책 제목 표시 방지)
            final book =
                state.books.where((b) => b.id == h.bookId).firstOrNull;
            return _highlightTile(h, book, q, isDark);
          }),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Text(
        label.toUpperCase(),
        style: DesignTokens.ptSans(10, weight: FontWeight.w700,
            color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
            .copyWith(letterSpacing: 1.5),
      ),
    );
  }

  Widget _bookTile(Book book, String q, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ArchivePage(bookId: book.id)));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 36,
              decoration: BoxDecoration(
                // bookAccent: 10색 팔레트 전부 구분 (slotColor는 3색만 매핑)
                color: DesignTokens.bookAccent(book.color),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlightText(book.title, q, 14, FontWeight.w600,
                      baseColor: isDark ? DesignTokens.inkDark : DesignTokens.ink),
                  const SizedBox(height: 2),
                  _highlightText(book.author, q, 11, FontWeight.w400,
                      baseColor: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                ],
              ),
            ),
            Text('${context.read<AppState>().highlightsForBook(book.id).length}',
                style: DesignTokens.ptSans(10,
                    color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
                    .copyWith(letterSpacing: 0.5)),
            const SizedBox(width: 4),
            Icon(Icons.bookmark_outline, size: 12,
                color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
          ],
        ),
      ),
    );
  }

  Widget _highlightTile(Highlight h, Book? book, String q, bool isDark) {
    return GestureDetector(
      onTap: book == null
          ? null // 책 미지정 문장은 아카이브로 이동 불가
          : () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ArchivePage(bookId: h.bookId)));
            },
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _highlightText(h.text, q, 13, FontWeight.w400,
                baseColor: isDark ? DesignTokens.inkDark : DesignTokens.ink),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: context.read<AppState>().slotColor(h.slot),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(book?.title ?? '책 미지정',
                    style: DesignTokens.ptSans(10,
                        color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                        .copyWith(letterSpacing: 0.5)),
                const Spacer(),
                Text('p.${h.page}',
                    style: DesignTokens.ptSans(10,
                        color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 검색어 일치 부분을 굵게 강조
  Widget _highlightText(
    String text,
    String q,
    double size,
    FontWeight weight, {
    Color? baseColor,
  }) {
    final base = baseColor ?? DesignTokens.ink;
    final lower = text.toLowerCase();
    final idx = lower.indexOf(q);

    if (idx < 0) {
      return Text(text,
          style: DesignTokens.hahmlet(size, weight: weight, color: base));
    }

    return RichText(
      text: TextSpan(
        style: DesignTokens.hahmlet(size, weight: weight, color: base),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: TextStyle(
              color: DesignTokens.terracotta,
              fontWeight: FontWeight.w700,
              backgroundColor: DesignTokens.terracotta.withValues(alpha: 0.1),
            ),
          ),
          if (idx + q.length < text.length)
            TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
    );
  }
}
