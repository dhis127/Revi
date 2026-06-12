import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';
import '../widgets/highlight_card.dart';
import '../widgets/memo_editor.dart';
import '../widgets/filter_chip_row.dart';

class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  String    _filter    = 'all';
  Highlight? _memoTarget;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── 드래그 상태 ──────────────────────────────────────────────────────────
  Highlight? _dragging;
  bool       _overTrash  = false;
  String?    _dragOverId; // 드래그 중 호버된 카드 ID (순서 변경 미리보기)

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final ink   = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute  = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;

    // ── 필터링 ───────────────────────────────────────────────────────────
    final filtered = state.highlights.where((h) {
      final slotMatch  = _filter == 'all' || h.slot == _filter;
      final queryMatch = _query.isEmpty ||
          h.text.toLowerCase().contains(_query.toLowerCase());
      return slotMatch && queryMatch;
    }).toList();

    // 목차 고정 여부: filtered 중 toc 문자열이 있는 것이 하나라도 있으면 고정
    final hasTocOrder = filtered.any((h) => h.toc.isNotEmpty);
    if (hasTocOrder) {
      // 목차 고정 → page 번호 오름차순
      filtered.sort((a, b) => a.page.compareTo(b.page));
    }

    return Stack(
        children: [
          Scaffold(
            backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 상단 바 ──
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('← 서재',
                                style: DesignTokens.hahmlet(13, color: mute)),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'QUOTES · ${filtered.length.toString().padLeft(2, '0')}',
                          style: DesignTokens.ptSans(11, color: mute)
                              .copyWith(letterSpacing: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text('모아둔 문장',
                      style: DesignTokens.hahmlet(22,
                              weight: FontWeight.w600, color: ink)
                          .copyWith(letterSpacing: -0.2)),
                ),

                // ── 검색바 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DesignTokens.bgDarkDeep
                          : DesignTokens.bgIvoryDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _query.isNotEmpty
                            ? DesignTokens.sage
                            : (isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 16, color: mute),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: DesignTokens.hahmlet(13, color: ink),
                            decoration: InputDecoration(
                              hintText: '문장을 검색해요',
                              hintStyle:
                                  DesignTokens.hahmlet(13, color: faint),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: Icon(Icons.close, size: 16, color: mute),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── 슬롯 필터 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SlotFilterChip(
                          label: '전체',
                          active: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        ...state.highlightSlotOrder.map((slot) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: SlotFilterChip(
                                dotColor: state.slotColor(slot),
                                active: _filter == slot,
                                onTap: () =>
                                    setState(() => _filter = slot),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),

                // ── 문장 목록 ──
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _query.isNotEmpty
                                ? '"$_query"에 대한 문장이 없어요'
                                : '아직 모아둔 문장이 없어요.',
                            style: DesignTokens.hahmlet(14, color: mute),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final h = filtered[i];
                            // 책 미지정(스캔 후 책 선택 전 이탈)·삭제된 책 폴백
                            final book = state.books
                                .where((b) => b.id == h.bookId)
                                .firstOrNull;
                            final bookTitle = book?.title ?? '책 미지정';
                            return _buildDraggableCard(
                                h, bookTitle, hasTocOrder, state);
                          },
                        ),
                ),
              ],
            ),
          ),

          // ── 드래그 중: 하단 중앙 휴지통 ─────────────────────────────────
          if (_dragging != null)
            Positioned(
              bottom: 36 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: DragTarget<Highlight>(
                  onWillAcceptWithDetails: (_) {
                    setState(() => _overTrash = true);
                    return true;
                  },
                  onLeave: (_) => setState(() => _overTrash = false),
                  onAcceptWithDetails: (d) {
                    context.read<AppState>().removeHighlight(d.data.id);
                    setState(() {
                      _dragging  = null;
                      _overTrash = false;
                    });
                  },
                  builder: (ctx, candidate, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width:  _overTrash ? 68 : 58,
                        height: _overTrash ? 68 : 58,
                        decoration: BoxDecoration(
                          color: _overTrash
                              ? DesignTokens.terracotta
                              : DesignTokens.terracotta.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: DesignTokens.terracotta, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: DesignTokens.terracotta
                                  .withValues(alpha: _overTrash ? 0.40 : 0.20),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: _overTrash ? Colors.white : DesignTokens.terracotta,
                          size: _overTrash ? 32 : 26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('삭제',
                          style: DesignTokens.ptSans(11,
                              color: DesignTokens.terracotta,
                              weight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          // ── 메모 에디터 ──────────────────────────────────────────────────
          if (_memoTarget != null)
            Positioned.fill(
              child: MemoEditor(
                highlight: _memoTarget!,
                onClose: () => setState(() => _memoTarget = null),
                onSave: (memo) {
                  context.read<AppState>().updateHighlightNote(
                      _memoTarget!.id, memo);
                  setState(() => _memoTarget = null);
                },
              ),
            ),
        ],
    );
  }

  // ── 삭제 확인 다이얼로그 ─────────────────────────────────────────────────
  Future<void> _confirmDelete(Highlight h, AppState state) async {
    final isDark = state.isDark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('문장 삭제',
            style: DesignTokens.hahmlet(16,
                weight: FontWeight.w600,
                color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
        content: Text('이 문장을 삭제할까요?',
            style: DesignTokens.hahmlet(13,
                color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소',
                style: DesignTokens.hahmlet(13,
                    color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제',
                style: DesignTokens.hahmlet(13,
                    weight: FontWeight.w600, color: DesignTokens.terracotta)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      state.removeHighlight(h.id);
    }
  }

  // ── 드래그 가능한 카드 빌드 ───────────────────────────────────────────────
  Widget _buildDraggableCard(
    Highlight h,
    String bookTitle,
    bool hasTocOrder,
    AppState state,
  ) {
    final isBeingDragged = _dragging?.id == h.id;
    final isHoverTarget  = _dragOverId == h.id && !hasTocOrder;

    final card = HighlightCard(
      highlight: h,
      bookTitle: bookTitle,
      onTap: () => setState(() => _memoTarget = h),
      onDelete: () => _confirmDelete(h, state),
    );

    // 목차 없을 때만 드롭 타겟으로 작동 (순서 변경)
    Widget child = hasTocOrder
        ? card
        : DragTarget<Highlight>(
            onWillAcceptWithDetails: (d) {
              if (d.data.id == h.id) return false;
              setState(() => _dragOverId = h.id);
              return true;
            },
            onLeave: (_) {
              if (_dragOverId == h.id) setState(() => _dragOverId = null);
            },
            onAcceptWithDetails: (d) {
              state.reorderHighlights(d.data.id, h.id);
              setState(() { _dragOverId = null; _dragging = null; });
            },
            builder: (ctx, candidate, _) => AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHoverTarget)
                    Container(
                      height: 52,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: DesignTokens.sage.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: DesignTokens.sage.withValues(alpha: 0.40),
                          width: 1.5,
                        ),
                      ),
                    ),
                  card,
                ],
              ),
            ),
          );

    return Padding(
      key: ValueKey(h.id),
      padding: const EdgeInsets.only(bottom: 2),
      child: LongPressDraggable<Highlight>(
        data: h,
        delay: const Duration(milliseconds: 350),
        onDragStarted:  () => setState(() { _dragging = h; _overTrash = false; }),
        onDragEnd:      (_) => setState(() { _dragging = null; _overTrash = false; _dragOverId = null; }),
        onDraggableCanceled: (_, __) => setState(() {
          _dragging = null; _overTrash = false; _dragOverId = null;
        }),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 40,
              child: HighlightCard(
                  highlight: h, bookTitle: bookTitle, onTap: () {}),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: card),
        child: isBeingDragged ? Opacity(opacity: 0.25, child: child) : child,
      ),
    );
  }
}
