import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';

class MemoEditor extends StatefulWidget {
  final Highlight highlight;
  final void Function(String memo) onSave;
  final VoidCallback onClose;

  const MemoEditor({
    super.key,
    required this.highlight,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends State<MemoEditor> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.highlight.note);
  }

  @override
  void didUpdateWidget(MemoEditor old) {
    super.didUpdateWidget(old);
    if (old.highlight.id != widget.highlight.id) {
      _ctrl.text = widget.highlight.note;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: const Color(0x73000000),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
                ),
                padding: EdgeInsets.fromLTRB(22, 18, 22,
                    MediaQuery.of(context).viewInsets.bottom + 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '메모 ${widget.highlight.note.isNotEmpty ? '편집' : '추가'}',
                          style: DesignTokens.hahmlet(15, weight: FontWeight.w600, color: isDark ? DesignTokens.inkDark : DesignTokens.ink),
                        ),
                        const Spacer(),
                        if (widget.highlight.note.isNotEmpty)
                          GestureDetector(
                            onTap: () => widget.onSave(''),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: DesignTokens.terracotta
                                    .withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('삭제',
                                  style: DesignTokens.ptSans(11,
                                      color: DesignTokens.terracotta)),
                            ),
                          ),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Text('×', style: DesignTokens.ptSans(20, color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
                        border: Border(
                          left: BorderSide(
                            color: DesignTokens.slotColor(widget.highlight.slot),
                            width: 3,
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6), bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.highlight.text,
                              style: DesignTokens.hahmlet(12, color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)
                                  .copyWith(height: 1.5)),
                          const SizedBox(height: 4),
                          Text(
                            'p.${widget.highlight.page}${widget.highlight.toc.isNotEmpty ? ' · ${widget.highlight.toc}' : ''}',
                            style: DesignTokens.ptSans(9, color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                                .copyWith(letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ctrl,
                      maxLines: 5,
                      autofocus: true,
                      style: DesignTokens.memoStyle(
                          context.watch<AppState>().memoFont, 16, color: isDark ? DesignTokens.inkDark : DesignTokens.ink), // -2px
                      decoration: InputDecoration(
                        hintText: '이 문장에 대한 생각을 적어주세요…',
                        hintStyle: DesignTokens.memoStyle(
                            context.watch<AppState>().memoFont, 16, // -2px
                            color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
                        filled: true,
                        fillColor: isDark ? DesignTokens.bgDarkEdge : Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.sage)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: widget.onClose,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          ),
                          child: Text('취소', style: DesignTokens.hahmlet(13, color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => widget.onSave(_ctrl.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? DesignTokens.inkDark : DesignTokens.ink,
                              foregroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                            child: Text('저장',
                                style: DesignTokens.hahmlet(14, weight: FontWeight.w600,
                                    color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
