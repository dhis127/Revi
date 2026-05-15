import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';
import 'add_book_page.dart';
import 'paywall_page.dart';

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
  // ── 촬영 상태 ──────────────────────────────────────────────────────────────
  bool _captured  = false;
  File? _capturedImage;

  // ── 카메라 ─────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  bool _camReady  = false;
  bool _camError  = false;

  // ── 팔레트 (색상 선택) ──────────────────────────────────────────────────────
  bool    _showPalette = false;
  String? _hoverSlot;

  // ── OCR ────────────────────────────────────────────────────────────────────
  List<String> _ocrLines = [];
  bool _ocrRunning = false;

  // ── 시트 ───────────────────────────────────────────────────────────────────
  bool   _memoOpen  = false;
  bool   _typeOpen  = false;
  String _memo      = '';
  String _typedText = '';
  final _memoCtrl  = TextEditingController();
  final _typeCtrl  = TextEditingController();
  final _picker    = ImagePicker();

  // ── 팔레트 레이아웃 상수 ─────────────────────────────────────────────────
  static const double _circleSize = 31.0;
  static const double _circleGap  = 8.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _memoCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  // ── 카메라 초기화 ──────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { if (mounted) setState(() => _camError = true); return; }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camCtrl = CameraController(cam, ResolutionPreset.high, enableAudio: false);
      await _camCtrl!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (_) {
      if (mounted) setState(() => _camError = true);
    }
  }

  // ── 촬영 ──────────────────────────────────────────────────────────────────
  Future<void> _takePicture() async {
    if (_camCtrl == null || !_camReady) return;
    try {
      final file = await _camCtrl!.takePicture();
      if (mounted) {
        setState(() { _capturedImage = File(file.path); _captured = true; });
        _runOcr(file.path);
      }
    } catch (_) {}
  }

  Future<void> _runOcr(String imagePath) async {
    setState(() => _ocrRunning = true);
    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();
      if (!mounted) return;
      final lines = result.blocks
          .expand((b) => b.lines)
          .map((l) => l.text.trim())
          .where((t) => t.length > 3)
          .toList();
      setState(() { _ocrLines = lines; _ocrRunning = false; });
    } catch (_) {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  // ── 갤러리에서 선택 ──────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      setState(() { _capturedImage = File(file.path); _captured = true; });
      _runOcr(file.path);
    }
  }

  // ── 문장 저장 ─────────────────────────────────────────────────────────────
  void _save() {
    final state = context.read<AppState>();
    if (widget.tocMode) {
      state.setTocSaved(widget.archiveBookId ?? 'b_new');
      Navigator.pop(context);
      return;
    }
    if (!state.canSaveHighlight) {
      showLimitBottomSheet(context, isHighlight: true);
      return;
    }
    final now    = DateTime.now();
    final dateStr = '${now.year}.${now.month.toString().padLeft(2,'0')}.${now.day.toString().padLeft(2,'0')}';
    final bookId = widget.fromArchive
        ? (widget.archiveBookId ?? state.books.first.id)
        : state.nextBookId();
    final text = _typedText.isNotEmpty
        ? _typedText
        : '나는 모든 무엇이 누군가의 눈물이 나올 만큼 잊고 있었다.';
    state.addHighlight(Highlight(
      id: state.nextHighlightId(),
      bookId: bookId,
      text: text,
      page: 23,
      slot: state.activeSlot,
      date: dateStr,
      note: _memo,
      toc: state.tocSavedForBookId == bookId ? '2장 — 잿빛 골짜기' : '',
    ));
    if (widget.fromArchive) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddBookPage(fromScan: true)));
    }
  }

  // ── 팔레트: 드래그 위치 → 슬롯 계산 ──────────────────────────────────────
  String? _slotAtGlobal(Offset pos, List<String> slots, double screenWidth) {
    final totalW = slots.length * _circleSize + (slots.length - 1) * _circleGap;
    final startX = (screenWidth - totalW) / 2;
    for (int i = 0; i < slots.length; i++) {
      final cx = startX + i * (_circleSize + _circleGap) + _circleSize / 2;
      if ((pos.dx - cx).abs() <= (_circleSize + _circleGap) / 2) return slots[i];
    }
    return null;
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isToc = widget.tocMode;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(context);
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
        // ── 색상 팔레트 팝업 ──────────────────────────────────────────────
        if (_showPalette) _buildPaletteOverlay(state),
        // ── 시트 ──────────────────────────────────────────────────────────
        if (_memoOpen) _buildMemoSheet(),
        if (_typeOpen) _buildTypeSheet(),
      ],
    );
  }

  // ── 상단 바 ───────────────────────────────────────────────────────────────
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
                  style: DesignTokens.hahmlet(17, weight: FontWeight.w600,
                      color: const Color(0xFFFFF7EE)),
                  textAlign: TextAlign.center),
            ),
            GestureDetector(
              onTap: _captured
                  ? () => setState(() { _captured = false; _capturedImage = null; _typedText = ''; })
                  : _pickFromGallery,
              child: _captured
                  ? Text('다시 촬영', style: DesignTokens.hahmlet(12, color: const Color(0xD9FFF7EE)))
                  : const Icon(Icons.photo_outlined, size: 20, color: Color(0xD9FFF7EE)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 뷰파인더 ──────────────────────────────────────────────────────────────
  Widget _buildViewfinder(bool isToc) {
    final sz = MediaQuery.sizeOf(context);

    Widget cameraLayer;
    if (_captured) {
      // 촬영 후: 찍은 이미지 또는 텍스트 미리보기
      cameraLayer = _capturedImage != null
          ? Image.file(_capturedImage!, fit: BoxFit.cover,
              width: double.infinity, height: double.infinity)
          : Container(
              color: const Color(0xFFF0E2C9),
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(alignment: Alignment.centerRight,
                      child: Text('— 23 —',
                          style: DesignTokens.ptSans(9, color: DesignTokens.inkMute)
                              .copyWith(letterSpacing: 1.2))),
                  const SizedBox(height: 14),
                  if (isToc) ...[
                    _tocLine('1장 — 서부에서 동부로 …… 1'),
                    _tocLine('2장 — 잿빛 골짜기 …… 23'),
                    _tocLine('3장 — 첫 파티 …… 47'),
                    _tocLine('4장 — 옥스퍼드의 환영 …… 67'),
                  ] else
                    Text(_typedText.isNotEmpty ? _typedText : '나는 모든 무엇이 누군가의 눈물이 나올 만큼 잊고 있었다.',
                        style: DesignTokens.lora(11, color: DesignTokens.inkSoft)),
                ],
              ),
            );
    } else if (_camReady && _camCtrl != null) {
      // 카메라 라이브 프리뷰
      cameraLayer = CameraPreview(_camCtrl!);
    } else if (_camError) {
      cameraLayer = const Center(
        child: Text('카메라를 열 수 없습니다.\n설정 > 개인 정보 보호 > 카메라에서\nRevi를 허용해주세요.',
            style: TextStyle(color: Color(0xB3FFF7EE), height: 1.6),
            textAlign: TextAlign.center),
      );
    } else {
      // 로딩 중
      cameraLayer = const Center(
        child: CircularProgressIndicator(color: Color(0x66FFF7EE), strokeWidth: 1.5),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        cameraLayer,
        // 프레임 브라켓
        const _CornerBrackets(),
        // 안내 문구 (촬영 전)
        if (!_captured)
          Positioned(
            bottom: sz.height * 0.06, left: 40, right: 40,
            child: Text(
              isToc ? '책의 목차 페이지를 화면에 맞춰주세요' : '쪽수가 함께 보이도록 촬영해주세요',
              style: DesignTokens.hahmlet(12, color: const Color(0xB3FFF7EE)),
              textAlign: TextAlign.center,
            ),
          ),
        // 촬영 완료 배지
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
                    style: DesignTokens.hahmlet(11, weight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ),
        // OCR 결과 패널
        if (_captured && (_ocrRunning || _ocrLines.isNotEmpty))
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Text('인식된 문장 탭 → 입력',
                            style: DesignTokens.ptSans(10,
                                color: const Color(0x99FFF7EE))),
                        const Spacer(),
                        if (_ocrRunning)
                          const SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(
                                color: Color(0x66FFF7EE), strokeWidth: 1.2)),
                      ],
                    ),
                  ),
                  if (_ocrLines.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _ocrLines.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => setState(() {
                            _typedText = _ocrLines[i];
                            _ocrLines  = [];
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x1AFFF7EE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0x33FFF7EE)),
                            ),
                            child: Text(_ocrLines[i],
                                style: DesignTokens.hahmlet(12,
                                    color: const Color(0xEEFFF7EE))
                                    .copyWith(height: 1.4)),
                          ),
                        ),
                      ),
                    ),
                ],
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

  // ── 셔터 행 ───────────────────────────────────────────────────────────────
  Widget _buildShutterRow(AppState state, bool isToc) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 왼쪽: 키보드 / 메모 버튼 ──
            SizedBox(
              width: 76,
              child: !_captured
                  ? _iconBtn(
                      onTap: () => setState(() {
                        _typeCtrl.text = _typedText;
                        _typeOpen = true;
                      }),
                      child: const Icon(Icons.keyboard_outlined,
                          size: 20, color: Color(0xFFFFF7EE)),
                    )
                  : GestureDetector(
                      onTap: () => setState(() {
                        _memoOpen = true;
                        _memoCtrl.text = _memo;
                      }),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _memo.isNotEmpty
                              ? DesignTokens.sage.withValues(alpha: 0.18)
                              : const Color(0x0FFFF7EE),
                          border: Border.all(
                            color: _memo.isNotEmpty
                                ? DesignTokens.sage
                                : const Color(0x80FFF7EE),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_note, size: 15,
                                color: Color(0xFFFFF7EE)),
                            const SizedBox(width: 5),
                            Text('메모${_memo.isNotEmpty ? ' ✓' : ''}',
                                style: DesignTokens.hahmlet(12,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFFFFF7EE))),
                          ],
                        ),
                      ),
                    ),
            ),

            // ── 가운데: 촬영 / 저장 버튼 ──
            Expanded(
              child: Center(
                child: !_captured
                    ? GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(
                            color: DesignTokens.sage,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xD9FFF7EE), width: 4),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _save,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            color: DesignTokens.sage,
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                                color: const Color(0xD9FFF7EE), width: 2),
                          ),
                          child: Text(
                            isToc ? '목차 저장' : '문장 저장',
                            style: DesignTokens.hahmlet(15,
                                weight: FontWeight.w600, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ),

            // ── 오른쪽: 색상 인디케이터 (길게 탭 → 팔레트) ──
            SizedBox(
              width: 76,
              child: isToc
                  ? const SizedBox()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onLongPressStart: (d) {
                          setState(() {
                            _showPalette = true;
                            _hoverSlot = state.activeSlot;
                          });
                        },
                        onLongPressMoveUpdate: (d) {
                          final sz = MediaQuery.sizeOf(context);
                          final hit = _slotAtGlobal(
                              d.globalPosition, state.highlightSlotOrder, sz.width);
                          if (hit != null && hit != _hoverSlot) {
                            setState(() => _hoverSlot = hit);
                          }
                        },
                        onLongPressEnd: (d) {
                          if (_hoverSlot != null) state.setSlot(_hoverSlot!);
                          setState(() {
                            _showPalette = false;
                            _hoverSlot   = null;
                          });
                        },
                        onLongPressCancel: () =>
                            setState(() { _showPalette = false; _hoverSlot = null; }),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: state.slotColor(state.activeSlot),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xD9FFF7EE), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                  color: state.slotColor(state.activeSlot)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8, spreadRadius: 1),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 색상 팔레트 오버레이 ──────────────────────────────────────────────────
  Widget _buildPaletteOverlay(AppState state) {
    final slots  = state.highlightSlotOrder;
    final totalW = slots.length * _circleSize + (slots.length - 1) * _circleGap;
    final totalH = _circleSize + 10; // hover 확장 여유

    return Positioned(
      bottom: 96 + MediaQuery.of(context).padding.bottom,
      right: 24,
      child: SizedBox(
        width: totalW,
        height: totalH,
        child: Stack(
          clipBehavior: Clip.none,
          children: List.generate(slots.length, (i) {
            final slot    = slots[i];
            final isHover = slot == _hoverSlot;
            final cx = i * (_circleSize + _circleGap);
            return Positioned(
              left: cx,
              top: isHover ? -5 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width:  isHover ? _circleSize + 8 : _circleSize,
                height: isHover ? _circleSize + 8 : _circleSize,
                decoration: BoxDecoration(
                  color: state.slotColor(slot),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHover ? const Color(0xFFFFF7EE) : const Color(0x66FFF7EE),
                    width: isHover ? 2.5 : 1.5,
                  ),
                  boxShadow: isHover
                      ? [BoxShadow(
                          color: state.slotColor(slot).withValues(alpha: 0.7),
                          blurRadius: 10, spreadRadius: 1)]
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── 아이콘 버튼 ───────────────────────────────────────────────────────────
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

  // ── 메모 시트 ─────────────────────────────────────────────────────────────
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
                    Row(children: [
                      Text('메모 추가', style: DesignTokens.hahmlet(15, weight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _memoOpen = false),
                        child: Text('×', style: DesignTokens.ptSans(20, color: DesignTokens.inkMute)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('이 문장이 저장될 때 함께 기록됩니다.',
                        style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _memoCtrl, maxLines: 4, autofocus: true,
                      style: DesignTokens.hahmlet(13),
                      decoration: InputDecoration(
                        hintText: '이 문장이 마음에 든 이유, 떠오른 생각…',
                        hintStyle: DesignTokens.hahmlet(13, color: DesignTokens.inkFaint),
                        filled: true, fillColor: DesignTokens.bgIvoryDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
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
                          backgroundColor: DesignTokens.ink, foregroundColor: DesignTokens.bgIvory,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0,
                        ),
                        child: Text('저장', style: DesignTokens.hahmlet(14,
                            weight: FontWeight.w600, color: DesignTokens.bgIvory)),
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

  // ── 직접 입력 시트 ────────────────────────────────────────────────────────
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
                    Row(children: [
                      Text('문장 직접 입력', style: DesignTokens.hahmlet(15, weight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _typeOpen = false),
                        child: Text('×', style: DesignTokens.ptSans(20, color: DesignTokens.inkMute)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('책에서 기억하고 싶은 문장을 직접 입력하세요.',
                        style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _typeCtrl, maxLines: 5, autofocus: true,
                      style: DesignTokens.lora(13),
                      decoration: InputDecoration(
                        hintText: '문장을 여기에 입력하세요…',
                        hintStyle: DesignTokens.hahmlet(13, color: DesignTokens.inkFaint),
                        filled: true, fillColor: DesignTokens.bgIvoryDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DesignTokens.rule)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
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
                              _captured  = true;
                              _typeOpen  = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.ink, foregroundColor: DesignTokens.bgIvory,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0,
                        ),
                        child: Text('확인', style: DesignTokens.hahmlet(14,
                            weight: FontWeight.w600, color: DesignTokens.bgIvory)),
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

// ── 코너 브라켓 ──────────────────────────────────────────────────────────────
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BracketPainter());
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xD9FFF7EE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const l = 30.0;
    final t  = size.height * 0.12;
    final b  = size.height * 0.86;
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
