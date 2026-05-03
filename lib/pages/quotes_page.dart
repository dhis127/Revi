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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = _filter == 'all'
        ? state.highlights
        : state.highlights.where((h) => h.slot == _filter).toList();

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
                          'QUOTES · ${list.length.toString().padLeft(2, '0')}',
                          style: DesignTokens.ptSans(11, color: DesignTokens.inkMute)
                              .copyWith(letterSpacing: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                  child: Text('모아둔 문장',
                      style: DesignTokens.hahmlet(22, weight: FontWeight.w600)
                          .copyWith(letterSpacing: -0.2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Row(
                    children: [
                      SlotFilterChip(label: '전체', active: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                      const SizedBox(width: 8),
                      SlotFilterChip(dotColor: DesignTokens.sageSoft, active: _filter == 'sage', onTap: () => setState(() => _filter = 'sage')),
                      const SizedBox(width: 8),
                      SlotFilterChip(dotColor: DesignTokens.terracotta, active: _filter == 'terra', onTap: () => setState(() => _filter = 'terra')),
                      const SizedBox(width: 8),
                      SlotFilterChip(dotColor: DesignTokens.amber, active: _filter == 'amber', onTap: () => setState(() => _filter = 'amber')),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text('아직 모아둔 문장이 없어요.',
                              style: DesignTokens.hahmlet(14, color: DesignTokens.inkMute)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final h = list[i];
                            final book = state.books.firstWhere((b) => b.id == h.bookId,
                                orElse: () => state.books.first);
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
