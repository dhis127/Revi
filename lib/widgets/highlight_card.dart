import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';

class HighlightCard extends StatelessWidget {
  final Highlight highlight;
  final String? bookTitle;
  final VoidCallback onTap;

  const HighlightCard({
    super.key,
    required this.highlight,
    this.bookTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: DesignTokens.bgIvoryRow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: DesignTokens.slotColor(highlight.slot),
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
                    Text(highlight.text,
                        style: DesignTokens.hahmlet(14).copyWith(height: 1.6)),
                    if (highlight.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: const Color(0xB3FFF7EE),
                          border: Border(
                            left: BorderSide(
                              color: DesignTokens.slotColor(highlight.slot),
                              width: 2,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text('"${highlight.note}"',
                            style: DesignTokens.lora(12, color: DesignTokens.inkSoft)
                                .copyWith(height: 1.55)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (bookTitle != null) bookTitle!,
                              'p. ${highlight.page}',
                              if (highlight.toc.isNotEmpty) highlight.toc,
                            ].join(' · '),
                            style: DesignTokens.ptSans(10, color: DesignTokens.inkMute)
                                .copyWith(letterSpacing: 0.8),
                          ),
                        ),
                        Row(
                          children: [
                            Text(highlight.date,
                                style: DesignTokens.ptSans(10, color: DesignTokens.inkFaint)),
                            if (highlight.note.isEmpty) ...[
                              const SizedBox(width: 6),
                              Text('+ 메모',
                                  style: DesignTokens.ptSans(10, color: DesignTokens.terracotta,
                                      weight: FontWeight.w700)),
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
