import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';

class HighlightCard extends StatefulWidget {
  final Highlight highlight;
  final String? bookTitle;
  final VoidCallback onTap;
  /// 제공 시 카드 우측에 삭제 아이콘이 표시됩니다.
  final VoidCallback? onDelete;

  const HighlightCard({
    super.key,
    required this.highlight,
    this.bookTitle,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<HighlightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final slotColor = state.slotColor(widget.highlight.slot);
    final memoFont  = state.memoFont;
    final isDark = state.isDark;
    final textStyle = DesignTokens.hahmlet(14, color: isDark ? DesignTokens.inkDark : DesignTokens.ink).copyWith(height: 1.6);

    // 각주 분리
    const footnoteDelimiter = '\n\n(각주)\n';
    final rawText = widget.highlight.text;
    final hasFootnote = rawText.contains(footnoteDelimiter);
    final mainText = hasFootnote ? rawText.split(footnoteDelimiter)[0] : rawText;
    final footnoteText = hasFootnote ? rawText.split(footnoteDelimiter)[1] : null;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: slotColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: slotColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 하이라이트 문장 (아코디언) ──
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final tp = TextPainter(
                          text: TextSpan(text: mainText, style: textStyle),
                          maxLines: 3,
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: constraints.maxWidth);
                        final overflows = tp.didExceedMaxLines;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainText,
                              style: textStyle,
                              maxLines: _expanded ? null : 3,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                            if (overflows || _expanded)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _expanded = !_expanded);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _expanded ? '접기' : '더 보기',
                                    style: DesignTokens.ptSans(10,
                                            color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute,
                                            weight: FontWeight.w700)
                                        .copyWith(letterSpacing: 0.5),
                                  ),
                                ),
                              ),
                            // ── 각주 (기울임꼴, 여백 포함) ──
                            if (footnoteText != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                footnoteText,
                                style: DesignTokens.hahmlet(12,
                                    color: isDark
                                        ? DesignTokens.inkDarkMute
                                        : DesignTokens.inkMute)
                                    .copyWith(
                                      fontStyle: FontStyle.italic,
                                      height: 1.55,
                                    ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    // ── 첨부 이미지 (그래프·표) ──
                    if (widget.highlight.imagePath.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(widget.highlight.imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    // ── 메모 ──
                    if (widget.highlight.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: slotColor.withValues(alpha: 0.07),
                          border: Border(
                            left: BorderSide(color: slotColor, width: 2),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text('"${widget.highlight.note}"',
                            style: DesignTokens.memoStyle(memoFont, 13, // -2px
                                    color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)
                                .copyWith(height: 1.5)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // ── 메타 정보 ──
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (widget.bookTitle != null) widget.bookTitle!,
                              'p. ${widget.highlight.page}',
                              if (widget.highlight.toc.isNotEmpty) widget.highlight.toc,
                            ].join(' · '),
                            style: DesignTokens.ptSans(10, color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                                .copyWith(letterSpacing: 0.8),
                          ),
                        ),
                        Row(
                          children: [
                            Text(widget.highlight.date,
                                style: DesignTokens.ptSans(10, color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)),
                            if (widget.highlight.note.isEmpty) ...[
                              const SizedBox(width: 6),
                              Text('+ 메모',
                                  style: DesignTokens.ptSans(10,
                                      color: DesignTokens.terracotta,
                                      weight: FontWeight.w700)),
                            ],
                            if (widget.onDelete != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: widget.onDelete,
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.red.shade300,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
