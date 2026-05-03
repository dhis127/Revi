import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/book.dart';
import '../providers/app_state.dart';
import 'scan_page.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _titleCtrl  = TextEditingController();
  final _authorCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final state = context.read<AppState>();
    final title  = _titleCtrl.text.trim();
    final author = _authorCtrl.text.trim();
    if (title.isEmpty || author.isEmpty) return;

    const colors = ['sage', 'terra', 'amber'];
    final color = colors[state.books.length % colors.length];
    final shelf = 1 + (state.books.where((b) => b.shelf > 0).length ~/ 5) % 3;

    state.addBook(Book(
      id: state.nextBookId(),
      title: title,
      author: author,
      color: color,
      shelf: shelf,
    ));
    state.clearTocSaved();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tocSaved = state.tocSavedForBookId != null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity;
        if (v != null && v > 200) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: DesignTokens.bgIvory,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverBox(),
                    const SizedBox(height: 22),
                    _buildField('책 제목', _titleCtrl, '제목을 입력하세요'),
                    const SizedBox(height: 22),
                    _buildField('저자', _authorCtrl, '저자를 입력하세요'),
                    const SizedBox(height: 22),
                    _buildIsbnButton(),
                    const SizedBox(height: 14),
                    _buildTocButton(tocSaved, state),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('← 뒤로', style: DesignTokens.hahmlet(13, color: DesignTokens.inkMute)),
            ),
            Expanded(
              child: Text('책 추가',
                  style: DesignTokens.hahmlet(17, weight: FontWeight.w600), textAlign: TextAlign.center),
            ),
            GestureDetector(
              onTap: _save,
              child: Text('저장', style: DesignTokens.hahmlet(13, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverBox() {
    return Center(
      child: Container(
        width: 96, height: 128,
        decoration: BoxDecoration(
          color: DesignTokens.bgIvoryDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DesignTokens.inkFaint, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 22, color: DesignTokens.inkFaint),
            const SizedBox(height: 8),
            Text('표지 이미지', style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute)),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: DesignTokens.ptSans(10, weight: FontWeight.w700, color: DesignTokens.inkMute)
                .copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          style: DesignTokens.hahmlet(15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DesignTokens.hahmlet(15, color: DesignTokens.inkFaint),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DesignTokens.inkFaint)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DesignTokens.sage)),
            contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildIsbnButton() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.bgIvoryDeep,
        border: Border.all(color: DesignTokens.rule),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _barcodeIcon(),
          const SizedBox(width: 10),
          Expanded(child: Text('ISBN 바코드로 자동 입력', style: DesignTokens.hahmlet(13, color: DesignTokens.inkSoft))),
          Text('›', style: DesignTokens.ptSans(16, color: DesignTokens.inkFaint)),
        ],
      ),
    );
  }

  Widget _buildTocButton(bool tocSaved, AppState state) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScanPage(tocMode: true, archiveBookId: 'b_new')),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tocSaved ? DesignTokens.sage.withValues(alpha: 0.12) : DesignTokens.bgIvoryDeep,
          border: Border.all(color: tocSaved ? DesignTokens.sage : DesignTokens.rule),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.list_alt_outlined, size: 16, color: tocSaved ? DesignTokens.sage : DesignTokens.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tocSaved ? '목차 저장됨 ✓' : '목차 촬영하기',
                      style: DesignTokens.hahmlet(13,
                          color: tocSaved ? DesignTokens.sage : DesignTokens.inkSoft,
                          weight: tocSaved ? FontWeight.w600 : FontWeight.w400)),
                  const SizedBox(height: 2),
                  Text(
                    tocSaved
                        ? '문장을 저장할 때 해당 챕터가 함께 기록돼요.'
                        : '쪽수에 맞는 챕터를 자동으로 연결해요.',
                    style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute),
                  ),
                ],
              ),
            ),
            Text('›', style: DesignTokens.ptSans(16, color: DesignTokens.inkFaint)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.ink,
              foregroundColor: DesignTokens.bgIvory,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: Text('저장하기',
                style: DesignTokens.hahmlet(15, weight: FontWeight.w600, color: DesignTokens.bgIvory)),
          ),
        ),
      ),
    );
  }

  Widget _barcodeIcon() {
    return SizedBox(
      width: 16, height: 16,
      child: CustomPaint(painter: _BarcodePainter()),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = DesignTokens.ink..style = PaintingStyle.fill;
    final bars = [
      [0.00, 0.14], [0.21, 0.07], [0.35, 0.14], [0.56, 0.07], [0.70, 0.14],
    ];
    for (final b in bars) {
      canvas.drawRect(Rect.fromLTWH(size.width * b[0], 0, size.width * b[1], size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
