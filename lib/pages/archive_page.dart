import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
            backgroundColor: DesignTokens.bgIvory,
            body: Column(
              children: [
                _buildTopBar(book.title, book.author),
                _buildFilterRow(list.length),
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
              backgroundColor: DesignTokens.sage,
              elevation: 6,
              child: const Icon(Icons.add, color: Colors.white, size: 22),
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

  Widget _buildTopBar(String title, String author) {
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
                  child: Text('← 서재', style: DesignTokens.hahmlet(13, color: DesignTokens.inkMute)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const QuotesPage())),
                  child: Text('모아둔 문장 →',
                      style: DesignTokens.hahmlet(12, color: DesignTokens.inkMute)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: DesignTokens.hahmlet(22, weight: FontWeight.w600)
                        .copyWith(letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(author, style: DesignTokens.hahmlet(12, color: DesignTokens.inkMute)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(int count) {
    return Padding(
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
          const Spacer(),
          Text('$count 문장',
              style: DesignTokens.ptSans(10, color: DesignTokens.inkMute).copyWith(letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text('아직 모아둔 문장이 없어요.\n첫 문장을 남겨주세요.',
          style: DesignTokens.hahmlet(14, color: DesignTokens.inkMute).copyWith(height: 1.7),
          textAlign: TextAlign.center),
    );
  }
}

