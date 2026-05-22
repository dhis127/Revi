import 'dart:math' show min, sqrt;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/highlight.dart';
import '../providers/app_state.dart';
import '../services/ocr_service.dart';
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
  Uint8List? _capturedBytes;
  Size? _imageSize; // 촬영 이미지 실제 픽셀 크기 (좌표 매핑용)

  // ── 카메라 ──────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  bool _camReady  = false;
  bool _camError  = false;

  // ── 팔레트 (색상 선택) ──────────────────────────────────────────────────────
  bool    _showPalette = false;
  String? _hoverSlot;

  // ── OCR ────────────────────────────────────────────────────────────────────
  List<OcrLine> _ocrLines = [];
  bool _ocrRunning = false;

  // ── 형광펜 ─────────────────────────────────────────────────────────────────
  // 여러 줄을 그을 수 있도록 List<List<Offset>> 구조 사용
  List<List<Offset>> _strokes = [];
  // LayoutBuilder에서 캐시 (gesture callback에서 사용, setState 불필요)
  double _layoutOx = 0, _layoutOy = 0, _layoutDw = 0, _layoutDh = 0;

  // ── 시트 ───────────────────────────────────────────────────────────────────
  bool   _memoOpen  = false;
  bool   _typeOpen  = false;
  bool   _editOpen  = false;   // OCR 결과 확인·수정 시트
  String _memo      = '';
  String _typedText = '';
  final _memoCtrl  = TextEditingController();
  final _typeCtrl  = TextEditingController();
  final _editCtrl  = TextEditingController();
  final _picker    = ImagePicker();

  // ── 팔레트 레이아웃 상수 ─────────────────────────────────────────────────
  static const double _circleSize = 22.0; // 31 × 0.8 × 0.9 ≈ 22

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
    _editCtrl.dispose();
    super.dispose();
  }

  // ── 카메라 초기화 ────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _camError = true);
        return;
      }
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

  // ── 촬영 ─────────────────────────────────────────────────────────────────
  Future<void> _takePicture() async {
    if (_camCtrl == null || !_camReady) return;
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라 권한이 필요합니다. 설정에서 허용해 주세요.')),
        );
      }
      return;
    }
    try {
      final file = await _camCtrl!.takePicture();
      if (!mounted) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imgSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _capturedBytes = bytes;
        _imageSize = imgSize;
        _captured = true;
      });
      _runOcr(file.path);
    } catch (_) {}
  }

  // ── OCR (Apple Vision 기반) ──────────────────────────────────────────────
  Future<void> _runOcr(String imagePath) async {
    setState(() => _ocrRunning = true);
    try {
      final lines = await OcrService.recognizeText(imagePath);
      if (!mounted) return;
      setState(() {
        _ocrLines = lines;
        _strokes = [];
        _ocrRunning = false;
      });
    } catch (_) {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  // ── 형광펜 영역 → OCR 텍스트 추출 → 수정 시트 표시 ──────────────────────
  void _confirmOcrSelection() {
    if (_strokes.isEmpty) return;

    // 모든 스트로크가 지나간 단어 박스 검출
    final found = <int>{};
    for (final stroke in _strokes) {
      for (int i = 0; i < _ocrLines.length; i++) {
        final expanded = _ocrLineRect(i)
            .inflate(_ocrLines[i].h * _layoutDh * 0.25);
        if (stroke.any(expanded.contains)) found.add(i);
      }
    }

    final sorted = found.toList()..sort();
    setState(() {
      _editCtrl.text = _buildOcrText(sorted);
      _editOpen = true;
    });
  }

  // ── OCR 결과 포맷 ────────────────────────────────────────────────────────
  // 본문 크기 단어 + 신뢰도 80% 이상 소형 텍스트(한자·주석 등)를 조합.
  // 신뢰도 낮은 소형 텍스트는 오인식 가능성이 높아 생략.
  String _buildOcrText(List<int> indices) {
    if (indices.isEmpty) return '';
    final words = indices.map((i) => _ocrLines[i]).toList();
    if (words.length == 1) return words.first.text;

    final hs = words.map((w) => w.h).toList()..sort();
    final medH = hs[hs.length ~/ 2];

    final main  = words.where((w) => w.h >= medH * 0.60).toList();
    // 소형 텍스트: 인식 신뢰도 80% 이상인 것만 괄호 병기
    final small = words
        .where((w) => w.h < medH * 0.60 && w.confidence >= 0.80)
        .toList();
    if (main.isEmpty) return words.map((w) => w.text).join(' ');

    // 읽기 순 정렬: Vision y좌표 기준 (y 클수록 이미지 상단)
    main.sort((a, b) {
      final dy = b.y - a.y;
      if (dy.abs() > medH * 0.5) return dy > 0 ? 1 : -1;
      return a.x.compareTo(b.x);
    });

    if (small.isEmpty) return main.map((w) => w.text).join(' ');

    // 소형 텍스트를 공간적으로 가장 가까운 본문 단어 뒤에 괄호로 삽입
    final used   = <OcrLine>{};
    final tokens = <String>[];
    for (final mw in main) {
      final annots = small.where((aw) {
        if (used.contains(aw)) return false;
        final dY = (aw.y - mw.y).abs();
        final dX = aw.x - (mw.x + mw.w);
        return dY < medH && dX >= -mw.w * 0.3 && dX < mw.w * 3.0;
      }).toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      used.addAll(annots);
      tokens.add(annots.isNotEmpty
          ? '${mw.text}(${annots.map((a) => a.text).join(' ')})'
          : mw.text);
    }
    return tokens.join(' ');
  }

  // ── 획 직선 보정 ──────────────────────────────────────────────────────────
  // 수직 편차가 획 길이의 20% 미만이면 시작·끝 두 점으로 대체 → 직선화
  void _straightenLastStroke() {
    if (_strokes.isEmpty) return;
    final pts = _strokes.last;
    if (pts.length < 3) return;

    final start = pts.first;
    final end   = pts.last;
    final dx    = end.dx - start.dx;
    final dy    = end.dy - start.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq < 1) return;

    double maxDev = 0;
    for (final p in pts) {
      final t    = ((p.dx - start.dx) * dx + (p.dy - start.dy) * dy) / lenSq;
      final projX = start.dx + t * dx;
      final projY = start.dy + t * dy;
      final dev  = (p.dx - projX) * (p.dx - projX) + (p.dy - projY) * (p.dy - projY);
      if (dev > maxDev) maxDev = dev;
    }

    if (sqrt(maxDev) < sqrt(lenSq) * 0.20) {
      _strokes[_strokes.length - 1] = [start, end];
    }
  }

  // ── 갤러리에서 선택 ──────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imgSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _capturedBytes = bytes;
        _imageSize = imgSize;
        _captured = true;
      });
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
  // Row 방식: 셀 = maxSize(39), 셀 간격 = 4, right:24 정렬
  String? _slotAtGlobal(Offset pos, List<String> slots, double screenWidth) {
    const maxSize  = _circleSize + 8.0; // 33 (25 + hover 8)
    const gap      = 2.0;
    const cellStep = maxSize + gap;     // 35
    final totalW   = slots.length * maxSize + (slots.length - 1) * gap;
    final leftEdge = screenWidth - 24 - totalW;
    for (int i = 0; i < slots.length; i++) {
      final cx = leftEdge + i * cellStep + maxSize / 2;
      if ((pos.dx - cx).abs() <= cellStep / 2) return slots[i];
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
          // 캡처 후엔 형광펜 pan과의 arena 충돌을 막기 위해 swipe-back 비활성
          onHorizontalDragEnd: _captured
              ? null
              : (d) {
                  if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(context);
                },
          child: Scaffold(
            backgroundColor: const Color(0xFF0E0C0A),
            body: Column(
              children: [
                _buildTopBar(isToc),
                Expanded(child: _buildViewfinder(isToc, state.slotColor(state.activeSlot))),
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
        if (_editOpen) _buildTextEditSheet(),
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
                  ? () => setState(() {
                      _captured = false;
                      _capturedBytes = null;
                      _imageSize = null;
                      _ocrLines = [];
                      _strokes = [];
                      _typedText = '';
                      _typeCtrl.clear();
                      _memo = '';
                      _memoCtrl.clear();
                    })
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

  // ── 좌표 변환 헬퍼 ───────────────────────────────────────────────────────
  Rect _ocrLineRect(int i) {
    final ln = _ocrLines[i];
    return Rect.fromLTWH(
      ln.x * _layoutDw + _layoutOx,
      (1.0 - ln.y - ln.h) * _layoutDh + _layoutOy,
      ln.w * _layoutDw,
      ln.h * _layoutDh,
    );
  }

  // ── 뷰파인더 ──────────────────────────────────────────────────────────────
  Widget _buildViewfinder(bool isToc, Color slotColor) {
    final sz = MediaQuery.sizeOf(context);

    // 촬영 후 — 이미지 + 형광펜 오버레이
    if (_captured && _capturedBytes != null && _imageSize != null) {
      return LayoutBuilder(builder: (ctx, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        final scale = min(cw / _imageSize!.width, ch / _imageSize!.height);
        final dw = _imageSize!.width * scale;
        final dh = _imageSize!.height * scale;
        final ox = (cw - dw) / 2;
        final oy = (ch - dh) / 2;
        // gesture callback에서 사용할 레이아웃 캐시
        _layoutOx = ox; _layoutOy = oy; _layoutDw = dw; _layoutDh = dh;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 촬영 이미지
            Image.memory(_capturedBytes!, fit: BoxFit.contain),
            // 형광펜 스트로크 오버레이
            CustomPaint(
              painter: _OcrOverlayPainter(
                strokes: _strokes,
                slotColor: slotColor,
              ),
            ),
            // 터치 핸들러 — 새 획을 _strokes에 추가, 기존 획 유지
            if (!_ocrRunning)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(() {
                  _strokes.add([d.localPosition]);
                }),
                onPanUpdate: (d) => setState(() {
                  _strokes.last.add(d.localPosition);
                }),
                onPanEnd: (_) => setState(_straightenLastStroke),
                child: const SizedBox.expand(),
              ),
            // OCR 분석 중 스피너
            if (_ocrRunning)
              const Positioned(
                top: 10, right: 10,
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Color(0xCCFFF7EE), strokeWidth: 1.5),
                ),
              ),
            // 안내 문구
            if (!_ocrRunning && _strokes.isEmpty)
              Positioned(
                top: 12, left: 0, right: 0,
                child: Text('형광펜으로 원하는 문장 위에 선을 그어주세요',
                    style: DesignTokens.hahmlet(12,
                        color: const Color(0xCCFFF7EE)),
                    textAlign: TextAlign.center),
              ),
          ],
        );
      });
    }

    // 카메라 라이브 프리뷰 / 에러 / 로딩
    Widget cameraLayer;
    if (_camReady && _camCtrl != null) {
      cameraLayer = ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: sz.width,
              height: sz.width * _camCtrl!.value.aspectRatio,
              child: CameraPreview(_camCtrl!),
            ),
          ),
        ),
      );
    } else if (_camError) {
      cameraLayer = const Center(
        child: Text(
          '카메라를 열 수 없습니다.\n설정 > Revi > 카메라를 허용해주세요.',
          style: TextStyle(color: Color(0xB3FFF7EE), height: 1.6),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      cameraLayer = const Center(
        child: CircularProgressIndicator(color: Color(0x66FFF7EE), strokeWidth: 1.5),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        cameraLayer,
        const _CornerBrackets(),
        Positioned(
          bottom: sz.height * 0.06, left: 40, right: 40,
          child: Text(
            isToc ? '책의 목차 페이지를 화면에 맞춰주세요' : '쪽수가 함께 보이도록 촬영해주세요',
            style: DesignTokens.hahmlet(12, color: const Color(0xB3FFF7EE)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

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
                      onTap: () => setState(() => _typeOpen = true),
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

            // ── 가운데: 촬영 / 선택 완료 / 저장 버튼 ──
            Expanded(
              child: Center(
                child: !_captured
                    // 촬영 전 — 셔터
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
                    : _strokes.isNotEmpty
                        // 형광펜 그은 상태 — 선택 완료
                        ? GestureDetector(
                            onTap: _confirmOcrSelection,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 16),
                              decoration: BoxDecoration(
                                color: DesignTokens.sage,
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(
                                    color: const Color(0xD9FFF7EE), width: 2),
                              ),
                              child: Text(
                                '선택 완료',
                                style: DesignTokens.hahmlet(15,
                                    weight: FontWeight.w600, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        // 형광펜 미사용 — 문장 저장
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
  // Row 기반: 슬롯마다 고정 셀 크기(maxSize)를 주고 원을 Center로 배치
  // → hover 시 원이 커져도 인접 원 위치가 흔들리지 않고 항상 균등 정렬됨
  Widget _buildPaletteOverlay(AppState state) {
    final slots   = state.highlightSlotOrder;
    const maxSize = _circleSize + 8.0; // 39 — hover 최대 크기

    return Positioned(
      bottom: 96 + MediaQuery.of(context).padding.bottom,
      right: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < slots.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),   // 간격 50% 축소
            SizedBox(
              width: maxSize,
              height: maxSize,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 60),
                  width:  slots[i] == _hoverSlot ? maxSize : _circleSize,
                  height: slots[i] == _hoverSlot ? maxSize : _circleSize,
                  decoration: BoxDecoration(
                    color: state.slotColor(slots[i]),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: slots[i] == _hoverSlot
                          ? const Color(0xFFFFF7EE)
                          : const Color(0x66FFF7EE),
                      width: slots[i] == _hoverSlot ? 2.5 : 1.5,
                    ),
                    boxShadow: slots[i] == _hoverSlot
                        ? [BoxShadow(
                            color: state.slotColor(slots[i]).withValues(alpha: 0.7),
                            blurRadius: 10, spreadRadius: 1)]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ],
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

  // ── OCR 결과 확인·수정 시트 ──────────────────────────────────────────────
  Widget _buildTextEditSheet() {
    return GestureDetector(
      onTap: () => setState(() => _editOpen = false),
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
                  boxShadow: [BoxShadow(
                      color: Colors.black26, blurRadius: 20,
                      offset: Offset(0, -4))],
                ),
                padding: EdgeInsets.fromLTRB(22, 22, 22,
                    MediaQuery.of(context).viewInsets.bottom + 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('문장 확인 및 수정',
                          style: DesignTokens.hahmlet(15,
                              weight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _editOpen = false),
                        child: Text('×',
                            style: DesignTokens.ptSans(20,
                                color: DesignTokens.inkMute)),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Text('OCR로 인식된 문장이에요. 저장 전에 직접 수정할 수 있어요.',
                        style: DesignTokens.hahmlet(11,
                            color: DesignTokens.inkMute)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _editCtrl,
                      maxLines: 5,
                      autofocus: true,
                      style: DesignTokens.lora(13),
                      decoration: InputDecoration(
                        hintText: '형광펜 영역의 문장이 여기에 표시됩니다…',
                        hintStyle: DesignTokens.hahmlet(13,
                            color: DesignTokens.inkFaint),
                        filled: true,
                        fillColor: DesignTokens.bgIvoryDeep,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: DesignTokens.rule)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: DesignTokens.rule)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: DesignTokens.sage)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final edited = _editCtrl.text.trim();
                          if (edited.isEmpty) return;
                          setState(() {
                            _typedText = edited;
                            _strokes   = [];
                            _ocrLines  = [];
                            _editOpen  = false;
                          });
                          _save(); // 수정 완료 → 즉시 문장 저장 화면으로
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.ink,
                          foregroundColor: DesignTokens.bgIvory,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text('확인',
                            style: DesignTokens.hahmlet(14,
                                weight: FontWeight.w600,
                                color: DesignTokens.bgIvory)),
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

// ── 형광펜 스트로크 오버레이 페인터 ─────────────────────────────────────────
// 여러 획(strokes)을 모두 그림 — iPhone 마크업 스타일

class _OcrOverlayPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color slotColor;

  const _OcrOverlayPainter({
    required this.strokes,
    required this.slotColor,
  });

  static const double _strokeW = 15.0; // 28 × 0.6 × 0.9 ≈ 15

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final paint = Paint()
      ..color = slotColor.withValues(alpha: 0.40)
      ..strokeWidth = _strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final pts in strokes) {
      if (pts.isEmpty) continue;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, _strokeW / 2,
            Paint()..color = slotColor.withValues(alpha: 0.40));
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OcrOverlayPainter old) =>
      old.strokes != strokes || old.slotColor != slotColor;
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
