import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/book.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';
import '../widgets/highlight_card.dart';
import '../widgets/memo_editor.dart';
import '../widgets/filter_chip_row.dart';
import 'scan_page.dart';
import 'quotes_page.dart';

class ArchivePage extends StatefulWidget {
  final String bookId;
  const ArchivePage({super.key, required this.bookId});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  String _filter = 'all';
  Highlight? _memoTarget;
  final _picker = ImagePicker();
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  bool _commentInitialized = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _saveComment(String bookId) {
    context.read<AppState>().updateBookComment(bookId, _commentCtrl.text.trim());
    _commentFocus.unfocus();
  }

  Future<void> _pickCover(Book book) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      context.read<AppState>().updateBookCover(book.id, file.path);
    }
  }

  void _showMoveSheet(Book book, bool isDark) {
    final state = context.read<AppState>();
    final pageCount = state.pageCount;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('책장 이동',
                    style: DesignTokens.hahmlet(16, weight: FontWeight.w600,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                const SizedBox(height: 4),
                Text('이 책을 옮길 책장을 선택하세요.',
                    style: DesignTokens.hahmlet(12,
                        color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                const SizedBox(height: 16),
                // 앞표지 칸 (shelf = pageIndex * 10)
                ...List.generate(pageCount, (pageIndex) {
                  final coverShelf = pageIndex * 10;
                  final spine1 = pageIndex * 10 + 1;
                  final pageName = state.getPageName(pageIndex);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pageName,
                          style: DesignTokens.ptSans(11,
                              color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _ShelfOption(
                            label: '앞표지 칸',
                            isActive: book.shelf == coverShelf,
                            isDark: isDark,
                            onTap: () {
                              state.moveBookToShelf(book.id, coverShelf);
                              Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(width: 8),
                          _ShelfOption(
                            label: '책등 칸',
                            isActive: book.shelf == spine1,
                            isDark: isDark,
                            onTap: () {
                              state.moveBookToShelf(book.id, spine1);
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final book = state.books.firstWhere((b) => b.id == widget.bookId, orElse: () => state.books.first);
    final all = state.highlightsForBook(widget.bookId);
    final list = _filter == 'all' ? all : all.where((h) => h.slot == _filter).toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        if (_memoTarget != null) return;
        final v = d.primaryVelocity;
        if (v == null) return;
        if (v > 200) {
          Navigator.pop(context); // → Home
        } else if (v < -200) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ScanPage(fromArchive: true, archiveBookId: widget.bookId),
          ));
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
            body: Column(
              children: [
                _buildTopBar(book, isDark),
                _buildFilterRow(list.length, isDark),
                Expanded(
                  child: list.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                          itemCount: list.length,
                          itemBuilder: (_, i) => HighlightCard(
                            highlight: list[i],
                            onTap: () => setState(() => _memoTarget = list[i]),
                          ),
                        ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ScanPage(fromArchive: true, archiveBookId: widget.bookId))),
              backgroundColor: isDark ? DesignTokens.sageDark : DesignTokens.sage,
              elevation: isDark ? 2 : 6,
              child: Icon(Icons.add,
                  color: isDark ? DesignTokens.inkDarkSoft : Colors.white, size: 22),
            ),
          ),
          if (_memoTarget != null)
            Positioned.fill(
              child: MemoEditor(
                highlight: _memoTarget!,
                onClose: () => setState(() => _memoTarget = null),
                onSave: (memo) {
                  context.read<AppState>().updateHighlightNote(_memoTarget!.id, memo);
                  setState(() => _memoTarget = null);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Book book, bool isDark) {
    // 최초 1회 comment 초기화
    if (!_commentInitialized) {
      _commentCtrl.text = book.comment ?? '';
      _commentInitialized = true;
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('← 서재', style: DesignTokens.hahmlet(13,
                      color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showMoveSheet(book, isDark),
                  child: Text('책장 이동',
                      style: DesignTokens.hahmlet(12,
                          color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const QuotesPage())),
                  child: Text('모아둔 문장 →',
                      style: DesignTokens.hahmlet(12,
                          color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 20, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(book.title,
                          style: DesignTokens.hahmlet(22, weight: FontWeight.w600,
                              color: isDark ? DesignTokens.inkDark : DesignTokens.ink)
                              .copyWith(letterSpacing: -0.2)),
                      const SizedBox(height: 3),
                      Text(book.author,
                          style: DesignTokens.hahmlet(12,
                              color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: book.coverImagePath == null ? () => _pickCover(book) : null,
                  child: Container(
                    width: 78, height: 108,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: book.coverImagePath != null
                          ? Image.file(File(book.coverImagePath!), fit: BoxFit.cover)
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: isDark
                                        ? DesignTokens.coverGradDark(book.color)
                                        : DesignTokens.coverGrad(book.color),
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? DesignTokens.inkDarkFaint.withOpacity(0.35)
                                        : Colors.white.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                    border: isDark
                                        ? Border.all(
                                            color: DesignTokens.inkDarkMute.withOpacity(0.4),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: isDark
                                        ? DesignTokens.inkDarkSoft
                                        : Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── 한 줄 코멘트 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 18),
            child: TextField(
              controller: _commentCtrl,
              focusNode: _commentFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveComment(book.id),
              // 저장된 입력 텍스트: 선택된 메모 폰트
              style: DesignTokens.memoStyle(
                  context.watch<AppState>().memoFont, 15,
                  color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft),
              decoration: InputDecoration(
                hintText: 'Comment',
                hintStyle: DesignTokens.hahmlet(12,
                    color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chat_bubble_outline,
                      size: 13,
                      color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: isDark ? DesignTokens.ruleDark : DesignTokens.rule, width: 1),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(int count, bool isDark) {
    final s = context.watch<AppState>(); // read→watch로 변경 (슬롯 추가 시 리빌드)
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SlotFilterChip(label: '전체', active: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  ...s.highlightSlotOrder.map((slot) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SlotFilterChip(
                      dotColor: s.slotColor(slot),
                      active: _filter == slot,
                      onTap: () => setState(() => _filter = slot),
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count 문장',
              style: DesignTokens.ptSans(10,
                  color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                  .copyWith(letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = context.watch<AppState>().isDark;
    return Center(
      child: Text('아직 모아둔 문장이 없어요.\n첫 문장을 남겨주세요.',
          style: DesignTokens.hahmlet(14,
              color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
              .copyWith(height: 1.7),
          textAlign: TextAlign.center),
    );
  }
}

class _ShelfOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ShelfOption({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? DesignTokens.sageDark.withValues(alpha: 0.2) : DesignTokens.sage.withValues(alpha: 0.12))
              : (isDark ? DesignTokens.bgDarkEdge : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? DesignTokens.sage : (isDark ? DesignTokens.ruleDark : DesignTokens.rule),
          ),
        ),
        child: Text(
          label,
          style: DesignTokens.hahmlet(13,
              color: isActive ? DesignTokens.sage : (isDark ? DesignTokens.inkDark : DesignTokens.ink)),
        ),
      ),
    );
  }
}

