import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';
import 'add_book_page.dart';

class ScanPage extends StatefulWidget {
  final bool fromArchive;
  final String? archiveBookId;
  final bool tocMode;

  const ScanPage({
    super.key,
    this.fromArchive = false,
    this.archiveBookId,
    this.tocMode = false,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _captured = false;
  bool _memoOpen = false;
  bool _typeOpen = false;
  String _memo = '';
  String _typedText = '';
  File? _galleryImage;
  final _memoCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _memoCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _capture() => setState(() => _captured = true);

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _galleryImage = File(file.path);
        _captured = true;
      });
    }
  }

  void _save() {
    final state = context.read<AppState>();
    if (widget.tocMode) {
      state.setTocSaved(widget.archiveBookId ?? 'b_new');
      Navigator.pop(context);
    } else {
      final bookId = widget.fromArchive ? (widget.archiveBookId ?? 'b1') : 'b1';
      final text = _typedText.isNotEmpty
          ? _typedText
          : '나는 모든 무엇이 누군가의 눈물이 나올 만큼 잊고 있었다.';
      final h = Highlight(
        id: state.nextHighlightId(),
        bookId: bookId,
        text: text,
        page: 23,
        slot: state.activeSlot,
        date: '2026.05.03',
        note: _memo,
        toc: state.tocSavedForBookId == bookId ? '2장 — 잿빛 골짜기' : '',
      );
      state.addHighlight(h);
      if (widget.fromArchive) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddBookPage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isToc = widget.tocMode;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity;
            if (v != null && v > 200) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0E0C0A),
            body: Column(
              children: [
                _buildTopBar(isToc),
                Expanded(child: _buildViewfinder(isToc)),
                _buildShutterRow(state, isToc),
              ],
            ),
          ),
        ),
        if (_memoOpen) _buildMemoSheet(),
        if (_typeOpen) _buildTypeSheet(),
      ],
    );
  }

  Widget _buildTopBar(bool isToc) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('← 뒤로', style: DesignTokens.hahmlet(13, color: const Color(0xD9FFF7EE))),
            ),
            Expanded(
              child: Text(isToc ? '목차 촬영' : '스캔',
                  style: DesignTokens.hahmlet(17, weight: FontWeight.w600, color: const Color(0xFFFFF7EE)),
                  textAlign: TextAlign.center),
            ),
            GestureDetector(
              onTap: _captured
                  ? () => setState(() {
                        _captured = false;
                        _galleryImage = null;
                        _typedText = '';
                      })
                  : _pickFromGallery,
              child: _captured
                  ? Text('다시 촬영',
                      style: DesignTokens.hahmlet(12, color: const Color(0xD9FFF7EE)))
                  : const Icon(Icons.photo_outlined, size: 20, color: Color(0xD9FFF7EE)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder(bool isToc) {
    final sz = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: sz.height * 0.08, left: sz.width * 0.10,
          right: sz.width * 0.10, bottom: sz.height * 0.08,
          child: AnimatedOpacity(
            opacity: _captured ? 0.18 : 0.08,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF0E2C9), Color(0xFFE8D5B0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        if (_captured)
          Positioned(
            top: sz.height * 0.10, left: sz.width * 0.12,
            right: sz.width * 0.12, bottom: sz.height * 0.08,
            child: _galleryImage != null
                ? ClipRRect(
                    child: Image.file(
                      _galleryImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : Container(
                    color: const Color(0xFFF0E2C9),
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('— 23 —',
                              style: DesignTokens.ptSans(9, color: DesignTokens.inkMute)
                                  .copyWith(letterSpacing: 1.2)),
                        ),
                        const SizedBox(height: 14),
                        if (isToc) ...[
                          _tocLine('1장 — 서부에서 동부로 …… 1'),
                          _tocLine('2장 — 잿빛 골짜기 …… 23'),
                          _tocLine('3장 — 첫 파티 …… 47'),
                          _tocLine('4장 — 옥스퍼드의 환영 …… 67'),
                        ] else
                          Text(
                            _typedText.isNotEmpty
                                ? _typedText
                                : '나는 모든 무엇이 누군가의 눈물이 나올 만큼 잊고 있었다.',
                            style: DesignTokens.lora(11, color: DesignTokens.inkSoft),
                          ),
                      ],
                    ),
                  ),
          ),
        const Positioned.fill(child: _CornerBrackets()),
        if (!_captured)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isToc ? '책의 목차 페이지를 화면에 맞춰주세요' : '쪽수가 함께 보이도록 촬영해주세요',
                style: DesignTokens.hahmlet(12, color: const Color(0xB3FFF7EE)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_captured)
          Positioned(
            top: 14, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: DesignTokens.sage.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('✓ 촬영 완료',
                    style: DesignTokens.hahmlet(11, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tocLine(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: DesignTokens.hahmlet(11, color: DesignTokens.inkSoft)),
      );

  Widget _buildShutterRow(AppState state, bool isToc) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_captured)
              _iconBtn(
                onTap: () => setState(() {
                  _typeCtrl.text = _typedText;
                  _typeOpen = true;
                }),
                child: const Icon(Icons.keyboard_outlined, size: 20, color: Color(0xFFFFF7EE)),
              )
            else
              GestureDetector(
                onTap: () => setState(() { _memoOpen = true; _memoCtrl.text = _memo; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  height: 48,
                  decoration: BoxDecoration(
                    color: _memo.isNotEmpty
                        ? DesignTokens.sage.withValues(alpha: 0.18)
                        : const Color(0x0FFFF7EE),
                    border: Border.all(
                      color: _memo.isNotEmpty ? DesignTokens.sage : const Color(0x80FFF7EE),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_note, size: 16, color: Color(0xFFFFF7EE)),
                      const SizedBox(width: 8),
                      Text('메모${_memo.isNotEmpty ? ' ✓' : ''}',
                          style: DesignTokens.hahmlet(13, weight: FontWeight.w600,
                              color: const Color(0xFFFFF7EE))),
                    ],
                  ),
                ),
              ),
            if (!_captured)
              GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: DesignTokens.sage,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xD9FFF7EE), width: 4),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  height: 52,
                  decoration: BoxDecoration(
                    color: DesignTokens.sage,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xD9FFF7EE), width: 2),
                  ),
                  child: Center(
                    child: Text(isToc ? '목차 저장' : '문장 저장',
                        style: DesignTokens.hahmlet(14, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            if (!isToc)
              Row(
                children: ['sage', 'terra', 'amber'].map((s) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => state.setSlot(s),
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: DesignTokens.slotColor(s),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: state.activeSlot == s
                              ? const Color(0xFFFFF7EE)
                              : const Color(0x4DFFF7EE),
                          width: state.activeSlot == s ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: const Color(0x0FFFF7EE),
          border: Border.all(color: const Color(0x59FFF7EE)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildMemoSheet() {
    return GestureDetector(
      onTap: () => setState(() => _memoOpen = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: DesignTokens.bgIvory,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
                ),
                padding: EdgeInsets.fromLTRB(22, 22, 22,
                    MediaQuery.of(context).viewInsets.bottom + 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('메모 추가', style: DesignTokens.hahmlet(15, weight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _memoOpen = false),
                          child: Text('×', style: DesignTokens.ptSans(20, color: DesignTokens.inkMute)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('이 문장이 저장될 때 함께 기록됩니다.',
                        style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _memoCtrl,
                      maxLines: 4,
                      autofocus: true,
                      style: DesignTokens.hahmlet(13),
                      decoration: InputDecoration(
                        hintText: '이 문장이 마음에 든 이유, 떠오른 생각…',
                        hintStyle: DesignTokens.hahmlet(13, color: DesignTokens.inkFaint),
                        filled: true,
                        fillColor: DesignTokens.bgIvoryDeep,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.sage)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() { _memo = _memoCtrl.text; _memoOpen = false; }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.ink,
                          foregroundColor: DesignTokens.bgIvory,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text('저장',
                            style: DesignTokens.hahmlet(14, weight: FontWeight.w600, color: DesignTokens.bgIvory)),
                      ),
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

  Widget _buildTypeSheet() {
    return GestureDetector(
      onTap: () => setState(() => _typeOpen = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: DesignTokens.bgIvory,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
                ),
                padding: EdgeInsets.fromLTRB(22, 22, 22,
                    MediaQuery.of(context).viewInsets.bottom + 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('문장 직접 입력', style: DesignTokens.hahmlet(15, weight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _typeOpen = false),
                          child: Text('×', style: DesignTokens.ptSans(20, color: DesignTokens.inkMute)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('책에서 기억하고 싶은 문장을 직접 입력하세요.',
                        style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _typeCtrl,
                      maxLines: 5,
                      autofocus: true,
                      style: DesignTokens.lora(13),
                      decoration: InputDecoration(
                        hintText: '문장을 여기에 입력하세요…',
                        hintStyle: DesignTokens.hahmlet(13, color: DesignTokens.inkFaint),
                        filled: true,
                        fillColor: DesignTokens.bgIvoryDeep,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.sage)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_typeCtrl.text.trim().isNotEmpty) {
                            setState(() {
                              _typedText = _typeCtrl.text.trim();
                              _captured = true;
                              _typeOpen = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.ink,
                          foregroundColor: DesignTokens.bgIvory,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text('확인',
                            style: DesignTokens.hahmlet(14, weight: FontWeight.w600, color: DesignTokens.bgIvory)),
                      ),
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

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BracketPainter());
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xD9FFF7EE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const l = 30.0;
    final t = size.height * 0.12;
    final b = size.height * 0.86;
    final x0 = size.width * 0.10;
    final x1 = size.width * 0.90;

    canvas.drawLine(Offset(x0, t), Offset(x0 + l, t), paint);
    canvas.drawLine(Offset(x0, t), Offset(x0, t + l), paint);
    canvas.drawLine(Offset(x1, t), Offset(x1 - l, t), paint);
    canvas.drawLine(Offset(x1, t), Offset(x1, t + l), paint);
    canvas.drawLine(Offset(x0, b), Offset(x0 + l, b), paint);
    canvas.drawLine(Offset(x0, b), Offset(x0, b - l), paint);
    canvas.drawLine(Offset(x1, b), Offset(x1 - l, b), paint);
    canvas.drawLine(Offset(x1, b), Offset(x1, b - l), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
