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
  String _filter = 'all';
  Highlight? _memoTarget;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final filtered = state.highlights.where((h) {
      final slotMatch = _filter == 'all' || h.slot == _filter;
      final queryMatch = _query.isEmpty ||
          h.text.toLowerCase().contains(_query.toLowerCase());
      return slotMatch && queryMatch;
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        if (_memoTarget != null) return;
        final v = d.primaryVelocity;
        if (v != null && v > 200) {
          Navigator.pop(context);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: DesignTokens.bgIvory,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text('← 서재', style: DesignTokens.hahmlet(13, color: DesignTokens.inkMute)),
                        ),
                        const Spacer(),
                        Text(
                          'QUOTES · ${filtered.length.toString().padLeft(2, '0')}',
                          style: DesignTokens.ptSans(11, color: DesignTokens.inkMute)
                              .copyWith(letterSpacing: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text('모아둔 문장',
                      style: DesignTokens.hahmlet(22, weight: FontWeight.w600)
                          .copyWith(letterSpacing: -0.2)),
                ),

                // ── 검색바 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignTokens.bgIvoryDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _query.isNotEmpty ? DesignTokens.sage : DesignTokens.rule,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: DesignTokens.inkMute),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: DesignTokens.hahmlet(13),
                            decoration: InputDecoration(
                              hintText: '문장을 검색해요',
                              hintStyle: DesignTokens.hahmlet(13, color: DesignTokens.inkFaint),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: const Icon(Icons.close, size: 16, color: DesignTokens.inkMute),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── 슬롯 필터 (동적 슬롯) ──
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
                            onTap: () => setState(() => _filter = slot),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _query.isNotEmpty
                                ? '"$_query"에 대한 문장이 없어요'
                                : '아직 모아둔 문장이 없어요.',
                            style: DesignTokens.hahmlet(14, color: DesignTokens.inkMute),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final h = filtered[i];
                            final book = state.books.firstWhere(
                              (b) => b.id == h.bookId,
                              orElse: () => state.books.first,
                            );
                            return HighlightCard(
                              highlight: h,
                              bookTitle: book.title,
                              onTap: () => setState(() => _memoTarget = h),
                            );
                          },
                        ),
                ),
              ],
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
}
