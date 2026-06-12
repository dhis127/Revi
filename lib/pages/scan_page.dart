import 'dart:async' show Timer;
import 'dart:io';
import 'dart:math' show max, min;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  // ── 촬영 상태 ──────────────────────────────────────────────────────────────
  bool _captured  = false;
  Uint8List? _capturedBytes;
  Size? _imageSize; // 촬영 이미지 실제 픽셀 크기 (좌표 매핑용)

  // ── 카메라 ──────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  bool _camReady            = false;
  bool _camError            = false; // 권한 OK지만 하드웨어/초기화 실패
  bool _camPermissionDenied = false; // 권한 거부 상태

  // ── 팔레트 (색상 선택) ──────────────────────────────────────────────────────
  bool    _showPalette = false;
  String? _hoverSlot;

  // ── OCR ────────────────────────────────────────────────────────────────────
  List<OcrLine> _ocrLines = [];
  bool _ocrRunning = false;

  // ── 형광펜 ─────────────────────────────────────────────────────────────────
  List<List<Offset>> _strokes = [];
  // LayoutBuilder에서 캐시
  double _layoutOx = 0, _layoutOy = 0, _layoutDw = 0, _layoutDh = 0;

  // 직선화 Timer (iOS 미세진동 오작동 방지 — 3px 이상 이동 시만 리셋)
  Timer?  _straightenTimer;
  bool    _willStraighten    = false; // true일 때 시각 피드백 표시
  Offset? _lastSigPanPos;             // 마지막 유의미 이동 위치

  // ── 이미지 영역 선택 (그래프·표 캡처) ──────────────────────────────────────
  bool    _imgSelectMode  = false;   // 이미지 영역 선택 모드 ON/OFF
  Offset? _imgCropStart;             // 드래그 시작점 (화면 좌표)
  Offset? _imgCropCurrent;           // 드래그 현재 끝점
  String  _savedImagePath = '';      // 크롭 완료 후 저장된 파일 경로

  Rect? get _imgCropRect {
    if (_imgCropStart == null || _imgCropCurrent == null) return null;
    return Rect.fromPoints(_imgCropStart!, _imgCropCurrent!);
  }

  // ── 시트 ───────────────────────────────────────────────────────────────────
  bool   _memoOpen  = false;
  bool   _typeOpen  = false;
  bool   _editOpen  = false;   // OCR 결과 확인·수정 시트
  bool   _tocReviewOpen = false; // 목차 인식 결과 확인 시트
  String? _continuationBuffer; // 두 페이지에 걸친 문장 누적 (#2)
  String _memo      = '';
  String _typedText = '';
  final _memoCtrl  = TextEditingController();
  final _typeCtrl  = TextEditingController();
  final _editCtrl  = TextEditingController();
  final _tocReviewCtrl = TextEditingController();
  final _picker    = ImagePicker();

  // ── 페이지 번호 ────────────────────────────────────────────────────────────
  int _pageNumber = 0;
  final _pageCtrl = TextEditingController();

  // ── 팔레트 레이아웃 상수 ─────────────────────────────────────────────────
  static const double _circleSize = 22.0; // 31 × 0.8 × 0.9 ≈ 22

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermissionAndInit();
  }

  // ── 앱 포그라운드 복귀 시 카메라 권한 재확인 ──────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _camPermissionDenied &&
        !_camReady) {
      _requestCameraPermissionAndInit();
    }
  }

  // ── 카메라 권한 요청 후 초기화 ─────────────────────────────────────────────
  // permission_handler 없이 카메라 직접 초기화 시도.
  // iOS는 카메라 접근 시 자체적으로 권한 다이얼로그를 처리함.
  // 권한 오류는 _initCamera 내 CameraException 코드로만 판별.
  Future<void> _requestCameraPermissionAndInit() async {
    if (!mounted) return;
    setState(() { _camError = false; _camPermissionDenied = false; });
    _initCamera();
  }

  @override
  void dispose() {
    _straightenTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _camCtrl?.dispose();
    _memoCtrl.dispose();
    _typeCtrl.dispose();
    _editCtrl.dispose();
    _tocReviewCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── 카메라 초기화 ────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _camError = true);
        return;
      }
      // 기존 컨트롤러가 있으면 먼저 해제
      await _camCtrl?.dispose();
      _camCtrl = null;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camCtrl = CameraController(
        cam,
        ResolutionPreset.veryHigh, // 문자 인식용 고해상도
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camCtrl!.initialize();
      // 자동 초점 + 자동 노출 활성화
      await _camCtrl!.setFocusMode(FocusMode.auto);
      await _camCtrl!.setExposureMode(ExposureMode.auto);
      if (mounted) setState(() => _camReady = true);
    } on CameraException catch (e) {
      if (!mounted) return;
      // iOS camera 플러그인의 정확한 권한 거부 코드만 권한 오류로 처리
      // (substring 매칭 오탐 방지)
      const permCodes = {
        'CameraAccessDenied',
        'CameraAccessDeniedWithoutPrompt',
        'cameraPermission',
      };
      setState(() {
        if (permCodes.contains(e.code)) {
          _camPermissionDenied = true;
        } else {
          _camError = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _camError = true);
    }
  }

  // ── 촬영 ─────────────────────────────────────────────────────────────────
  Future<void> _takePicture() async {
    if (_camCtrl == null || !_camReady) return;
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
    } catch (_) {
      // 촬영 실패 시 무반응 방지 — 사용자에게 알림
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('촬영에 실패했어요. 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── OCR (Apple Vision 기반: 전체 페이지 박스/검토 UI용) ────────────────────
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
      // 목차 모드: 전체 페이지 인식이 끝나면 곧바로 확인 시트를 띄움
      if (widget.tocMode && lines.isNotEmpty) {
        _tocReviewCtrl.text = _assembleAllLinesText();
        setState(() => _tocReviewOpen = true);
      }
    } catch (_) {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }


  // ── 형광펜 영역 → 크롭 기반 OCR → 텍스트 시트 ─────────────────────────────
  // 획 그룹 Y 범위로 1차 위치를 잡되, 전체 페이지 OCR bbox로 크롭 높이를 보정한다.
  // 이렇게 해야 크롭 경계에 걸린 글자가 잘려 Vision이 엉뚱한 글자로 읽는 일을 줄일 수 있다.
  //
  // 핵심 개선:
  //  • 획 Y 범위 자체가 크롭 경계 → 페이지 곡면·bbox 오차와 무관
  //  • 각 그룹 크롭 안에만 OCR 실행 → 그룹 사이 줄은 자동 제외
  //  • 두 그룹 사이 → '...' 삽입
  Future<void> _confirmOcrSelection() async {
    if (_strokes.isEmpty || _capturedBytes == null || _imageSize == null) return;
    if (_ocrRunning) return;

    setState(() => _ocrRunning = true);
    try {
      // 추정 줄 높이(화면 px) — 크롭 패딩 계산용
      double estLineH = 30.0;
      if (_ocrLines.isNotEmpty && _layoutDh > 0) {
        final hs = List.generate(_ocrLines.length, (i) => _ocrLineRect(i).height);
        estLineH = hs.reduce((a, b) => a + b) / hs.length;
      } else if (_layoutDh > 0) {
        estLineH = _layoutDh / 28.0;
      }

      // ── 1. 획 Y 범위 계산 ──────────────────────────────────────────────────
      final sBounds = <(double, double)>[];
      for (final s in _strokes) {
        double lo = s.first.dy, hi = s.first.dy;
        for (final p in s) {
          if (p.dy < lo) lo = p.dy;
          if (p.dy > hi) hi = p.dy;
        }
        sBounds.add((lo, hi));
      }

      // ── 2. 획을 Y 기준 정렬 후 그룹화 ────────────────────────────────────────
      // 인접 획 Y 간격 > estLineH × 2.5 이면 새 그룹 (줄 2개 이상 건너뜀)
      final idx = List.generate(_strokes.length, (i) => i)
        ..sort((a, b) => sBounds[a].$1.compareTo(sBounds[b].$1));

      final groups = <(double, double)>[];
      var gMin = sBounds[idx.first].$1;
      var gMax = sBounds[idx.first].$2;
      for (int k = 1; k < idx.length; k++) {
        final (lo, hi) = sBounds[idx[k]];
        if (lo - gMax > estLineH * 2.5) {
          groups.add((gMin, gMax));
          gMin = lo; gMax = hi;
        } else {
          if (lo < gMin) gMin = lo;
          if (hi > gMax) gMax = hi;
        }
      }
      groups.add((gMin, gMax));

      // ── 3. 그룹별: 크롭 → OCR → 텍스트 수집 ────────────────────────────────
      // 크롭은 넉넉히 잡고, OCR 후 원래 획 band와 다시 맞는 줄만 채택한다.
      final scaleY = _imageSize!.height / _layoutDh;
      final pad    = (estLineH * 0.45).clamp(12.0, 48.0);

      // 각 그룹의 (imgY1 비율, OCR 텍스트) 저장
      final groupData = <(double imgY1Ratio, String text)>[];

      for (final (groupMin, groupMax) in groups) {
        final cropRect = _cropRectForStrokeGroup(
          groupMin: groupMin,
          groupMax: groupMax,
          estLineH: estLineH,
          pad: pad,
          scaleY: scaleY,
        );
        final imgY1 = cropRect.top;
        final imgY2 = cropRect.bottom;
        if (imgY2 - imgY1 < 10) continue;

        final tmpPath = await _cropToTempFile(cropRect);
        if (tmpPath == null) continue;

        final lines = await OcrService.recognizeText(tmpPath, enhanced: true);
        try { await File(tmpPath).delete(); } catch (_) {}
        if (lines.isEmpty) continue;

        final used = _selectLinesForStrokeBand(
          lines: lines,
          cropRect: cropRect,
          groupMin: groupMin,
          groupMax: groupMax,
          estLineH: estLineH,
          scaleY: scaleY,
        );
        if (used.isEmpty) continue;
        final text = used.map((l) => l.text.trim()).join(' ').trim();
        if (text.isNotEmpty) {
          groupData.add((imgY1 / _imageSize!.height, text));
        }
      }

      if (!mounted) return;
      if (groupData.isEmpty) {
        setState(() => _ocrRunning = false);
        return;
      }

      _autoDetectPageNumber();

      // ── 4. 본문 그룹 vs 각주 그룹 분리 → 조합 ─────────────────────────────
      // 각주 그룹 조건: 이미지 하단 40% 에 위치 + 그룹이 2개 이상일 때 마지막 그룹
      String? fnText;
      final bodyGroups = <String>[];

      if (groupData.length >= 2 && groupData.last.$1 > 0.55) {
        // 마지막 그룹이 페이지 하단 → 각주로 분류
        fnText = groupData.last.$2;
        for (int i = 0; i < groupData.length - 1; i++) {
          bodyGroups.add(groupData[i].$2);
        }
      } else {
        for (final (_, t) in groupData) {
          bodyGroups.add(t);
        }
      }

      // 본문: 그룹 사이에 ' ... ' 인라인 삽입
      final mainText = bodyGroups.join(' ... ');

      // 각주: 본문 끝 마커 추출 → '*3: 각주전문' 형식
      String fullText;
      if (fnText != null && fnText.isNotEmpty) {
        final marker = _extractMarkerFromText(mainText);
        final prefix = marker != null ? '$marker: ' : '';
        fullText = '$mainText$footnoteDelimiter$prefix$fnText';
      } else {
        fullText = mainText;
      }

      // 두 페이지 이어찍기(#2): 이전 페이지 문장이 있으면 앞에 이어붙임
      if (_continuationBuffer != null && _continuationBuffer!.isNotEmpty) {
        fullText = '${_continuationBuffer!} $fullText';
      }

      setState(() {
        _editCtrl.text = fullText;
        _ocrRunning    = false;
        _editOpen      = true;
      });
    } catch (_) {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  // ── 본문 텍스트 끝에서 각주 마커 추출 (*3, †, "3 등) ────────────────────────
  String? _extractMarkerFromText(String text) {
    if (text.isEmpty) return null;
    // _lineHasFootnoteMarker와 동일한 역방향 스캔
    int i = text.length - 1;
    while (i >= 0 && text[i] == ' ') { i--; }
    int digits = 0;
    while (i >= 0 && digits < 3 &&
           text.codeUnitAt(i) >= 0x30 && text.codeUnitAt(i) <= 0x39) {
      i--; digits++;
    }
    while (i >= 0 && text[i] == ' ') { i--; }
    if (i < 0) return null;
    const markerCp = {
      0x2A, 0x2020, 0x2021, 0x203B, 0x2022, 0xFF0A,
      0x22, 0x27, 0x2018, 0x2019, 0x201C, 0x201D,
    };
    if (markerCp.contains(text.codeUnitAt(i))) {
      return text.substring(i).trim();
    }
    return null;
  }

  Rect _cropRectForStrokeGroup({
    required double groupMin,
    required double groupMax,
    required double estLineH,
    required double pad,
    required double scaleY,
  }) {
    double top = groupMin - pad;
    double bottom = groupMax + pad;

    if (_ocrLines.isNotEmpty && _layoutDh > 0) {
      final bandTop = groupMin - estLineH * 0.65;
      final bandBottom = groupMax + estLineH * 0.65;
      final matchedRects = <Rect>[];

      for (int i = 0; i < _ocrLines.length; i++) {
        final rect = _ocrLineRect(i);
        final overlap = min(rect.bottom, bandBottom) - max(rect.top, bandTop);
        final centerInside = rect.center.dy >= bandTop && rect.center.dy <= bandBottom;
        final enoughOverlap = overlap > min(rect.height * 0.45, estLineH * 0.35);
        if (centerInside || enoughOverlap) {
          matchedRects.add(rect);
        }
      }

      if (matchedRects.isNotEmpty) {
        top = matchedRects.map((r) => r.top).reduce(min);
        bottom = matchedRects.map((r) => r.bottom).reduce(max);
        final linePad = max(6.0, estLineH * 0.38);
        top -= linePad;
        bottom += linePad;
      }
    }

    final imgY1 = ((top - _layoutOy) * scaleY).clamp(0.0, _imageSize!.height);
    final imgY2 = ((bottom - _layoutOy) * scaleY).clamp(imgY1, _imageSize!.height);
    return Rect.fromLTRB(0, imgY1, _imageSize!.width.toDouble(), imgY2);
  }

  List<OcrLine> _selectLinesForStrokeBand({
    required List<OcrLine> lines,
    required Rect cropRect,
    required double groupMin,
    required double groupMax,
    required double estLineH,
    required double scaleY,
  }) {
    if (lines.isEmpty || cropRect.height <= 0) return [];

    final cropH = cropRect.height;
    final strokeTopPx = (((groupMin - _layoutOy) * scaleY) - cropRect.top)
        .clamp(0.0, cropH);
    final strokeBottomPx = (((groupMax - _layoutOy) * scaleY) - cropRect.top)
        .clamp(0.0, cropH);
    final strokeMin = min(strokeTopPx, strokeBottomPx);
    final strokeMax = max(strokeTopPx, strokeBottomPx);
    final bandPad = max(estLineH * scaleY * 0.55, cropH * 0.06);
    final bandTop = (strokeMin - bandPad).clamp(0.0, cropH);
    final bandBottom = (strokeMax + bandPad).clamp(0.0, cropH);
    final bandHeight = max(1.0, bandBottom - bandTop);
    final bandCenter = (bandTop + bandBottom) / 2.0;

    Rect lineRect(OcrLine line) {
      final top = (1.0 - line.y - line.h) * cropH;
      final bottom = (1.0 - line.y) * cropH;
      return Rect.fromLTRB(
        line.x * cropRect.width,
        top,
        (line.x + line.w) * cropRect.width,
        bottom,
      );
    }

    final matched = <OcrLine>[];
    for (final line in lines) {
      if (line.text.trim().isEmpty || line.h < 0.006) continue;
      final rect = lineRect(line);
      final overlap = min(rect.bottom, bandBottom) - max(rect.top, bandTop);
      final centerInside = rect.center.dy >= bandTop && rect.center.dy <= bandBottom;
      final enoughOverlap = overlap > min(rect.height * 0.35, bandHeight * 0.35);
      if (centerInside || enoughOverlap) {
        matched.add(line);
      }
    }

    if (matched.isNotEmpty) {
      return matched..sort((a, b) => b.y.compareTo(a.y));
    }

    final sortedByDistance = lines
        .where((line) => line.text.trim().isNotEmpty && line.h >= 0.006)
        .toList()
      ..sort((a, b) {
        final da = (lineRect(a).center.dy - bandCenter).abs();
        final db = (lineRect(b).center.dy - bandCenter).abs();
        return da.compareTo(db);
      });
    if (sortedByDistance.isEmpty) return [];

    final closest = sortedByDistance.first;
    final distance = (lineRect(closest).center.dy - bandCenter).abs();
    final maxDistance = max(estLineH * scaleY * 1.35, cropH * 0.35);
    return distance <= maxDistance ? [closest] : [];
  }

  // ── 크롭 헬퍼: 이미지 픽셀 좌표 → 임시 PNG 파일 ────────────────────────────
  Future<String?> _cropToTempFile(Rect srcRect) async {
    if (_capturedBytes == null) return null;
    try {
      final codec  = await ui.instantiateImageCodec(_capturedBytes!);
      final frame  = await codec.getNextFrame();
      final dstW   = srcRect.width.toInt();
      final dstH   = srcRect.height.toInt();
      if (dstW < 4 || dstH < 4) {
        frame.image.dispose(); codec.dispose(); return null;
      }
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        frame.image, srcRect,
        Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
        Paint(),
      );
      frame.image.dispose(); codec.dispose();
      final picture  = recorder.endRecording();
      final cropped  = await picture.toImage(dstW, dstH);
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (byteData == null) return null;
      final dir  = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/tmp_ocr_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(byteData.buffer.asUint8List());
      return path;
    } catch (_) { return null; }
  }

  // ── 쪽수 자동 감지 ───────────────────────────────────────────────────────
  // 이미지 상단/하단에 있는 숫자 전용 텍스트를 쪽수로 인식
  void _autoDetectPageNumber() {
    if (_pageCtrl.text.isNotEmpty || _ocrLines.isEmpty) return;

    // 본문 폰트 높이 중앙값
    final hs = _ocrLines.map((l) => l.h).toList()..sort();
    final medH = hs[hs.length ~/ 2];

    for (final line in _ocrLines) {
      final trimmed = line.text.trim();
      final num = int.tryParse(trimmed);
      if (num == null || num <= 0 || num > 2000) continue;
      final isSmall  = line.h < medH * 0.85;
      final isBottom = line.y < 0.18;              // Vision: y=0 → 이미지 하단 (여유 증가)
      final isTop    = (line.y + line.h) > 0.82;   // Vision: y=1 → 이미지 상단 (여유 증가)
      if (isSmall && (isBottom || isTop)) {
        setState(() {
          _pageNumber = num;
          _pageCtrl.text = trimmed;
        });
        return;
      }
    }
  }

  // ── 각주 구분자 (저장 포맷: 본문 + delimiter + '*N: 각주 전문') ─────────────
  static const String footnoteDelimiter = '\n\n(각주)\n';

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

  // ── 이미지 영역 크롭 및 저장 ────────────────────────────────────────────────
  Future<void> _cropAndSaveImage() async {
    final rect = _imgCropRect;
    if (rect == null || _capturedBytes == null || _imageSize == null) return;

    // 화면 좌표 → 이미지 픽셀 좌표 변환
    final scaleX = _imageSize!.width  / _layoutDw;
    final scaleY = _imageSize!.height / _layoutDh;
    final left   = ((rect.left   - _layoutOx) * scaleX).clamp(0.0, _imageSize!.width  - 1);
    final top    = ((rect.top    - _layoutOy) * scaleY).clamp(0.0, _imageSize!.height - 1);
    final right  = ((rect.right  - _layoutOx) * scaleX).clamp(left + 1, _imageSize!.width);
    final bottom = ((rect.bottom - _layoutOy) * scaleY).clamp(top  + 1, _imageSize!.height);
    final srcRect = Rect.fromLTRB(left, top, right, bottom);
    final dstW = srcRect.width.toInt();
    final dstH = srcRect.height.toInt();
    if (dstW < 4 || dstH < 4) return;

    // 이미지 디코딩 → 크롭
    final codec = await ui.instantiateImageCodec(_capturedBytes!);
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      frame.image,
      srcRect,
      Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      Paint(),
    );
    frame.image.dispose();
    codec.dispose();
    final picture  = recorder.endRecording();
    final cropped  = await picture.toImage(dstW, dstH);
    final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (byteData == null || !mounted) return;

    // 파일 저장
    final dir      = await getApplicationDocumentsDirectory();
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
    final file     = File('${dir.path}/$fileName');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    if (!mounted) return;
    setState(() {
      _savedImagePath = file.path;
      _imgSelectMode  = false;
      _imgCropStart   = null;
      _imgCropCurrent = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('이미지 영역이 캡처됐어요. 저장 시 하이라이트에 첨부됩니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── 목차: 전체 페이지 줄을 읽기 순서대로 결합 ───────────────────────────────
  String _assembleAllLinesText() {
    // _ocrLines는 플러그인에서 이미 읽기 순서(위→아래)로 정렬됨.
    // 목차는 줄 구조가 의미를 가지므로 줄바꿈으로 결합.
    return _ocrLines
        .map((l) => l.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n')
        .trim();
  }

  // ── 문장 저장 ─────────────────────────────────────────────────────────────
  void _save() {
    final state = context.read<AppState>();
    if (widget.tocMode) {
      // 전체 페이지 OCR 텍스트를 확인 시트로 — 수정·추가·재촬영 가능
      if (!_captured || _ocrRunning) return;
      _tocReviewCtrl.text = _assembleAllLinesText();
      setState(() => _tocReviewOpen = true);
      return;
    }
    // 저장 가능 조건: 문장 / 첨부 이미지 / 메모 중 하나라도 있으면 됨.
    // (그래프·표를 이미지로만 저장하고 싶은 경우 텍스트 없이도 허용)
    final hasText  = _typedText.trim().isNotEmpty;
    final hasImage = _savedImagePath.isNotEmpty;
    final hasMemo  = _memo.trim().isNotEmpty;
    if (!hasText && !hasImage && !hasMemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문장을 선택하거나, 이미지 영역을 캡처하거나, 메모를 입력해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!state.canSaveHighlight) {
      showLimitBottomSheet(context, isHighlight: true);
      return;
    }
    final now     = DateTime.now();
    final dateStr = '${now.year}.${now.month.toString().padLeft(2,'0')}.${now.day.toString().padLeft(2,'0')}';
    // 아카이브 진입: 해당 책에 바로 귀속 + 목차 챕터 자동 연결.
    // 새 스캔: 책이 아직 없으므로 미지정('')으로 저장 후
    //          AddBookPage에서 새 책/기존 책에 연결 (가짜 ID 선점 금지 — 고아 방지)
    final fromArchive = widget.fromArchive && widget.archiveBookId != null;
    final bookId = fromArchive ? widget.archiveBookId! : '';
    final highlightId = state.nextHighlightId();
    state.addHighlight(Highlight(
      id: highlightId,
      bookId: bookId,
      text: _typedText.trim(),
      page: _pageNumber,
      slot: state.activeSlot,
      date: dateStr,
      note: _memo,
      toc: fromArchive ? state.chapterForPage(bookId, _pageNumber) : '',
      imagePath: _savedImagePath,
    ));
    if (widget.fromArchive) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddBookPage(
            fromScan: true,
            pendingHighlightId: highlightId,
          ),
        ),
      );
    }
  }

  // ── 목차: 이 페이지 추가 후 완료 → add_book 복귀 ──────────────────────────
  void _tocAddAndFinish() {
    final state = context.read<AppState>();
    state.appendPendingToc(_tocReviewCtrl.text, widget.archiveBookId ?? 'b_new');
    Navigator.pop(context);
  }

  // ── 목차: 이 페이지 추가 후 한 장 더 촬영 (다중 페이지 목차 #7) ────────────
  void _tocAddAndScanMore() {
    final state = context.read<AppState>();
    state.appendPendingToc(_tocReviewCtrl.text, widget.archiveBookId ?? 'b_new');
    setState(() {
      _tocReviewOpen = false;
      _captured      = false;
      _capturedBytes = null;
      _imageSize     = null;
      _ocrLines      = [];
      _strokes       = [];
    });
  }

  // ── 두 페이지 문장 이어찍기 (#2) ──────────────────────────────────────────
  // 현재까지 조합된 문장을 버퍼에 저장하고 카메라로 돌아가 다음 페이지를 촬영.
  // 다음 페이지 선택이 끝나면 버퍼 뒤에 이어붙여 하나의 하이라이트로 저장됨.
  void _continueToNextPage() {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _continuationBuffer = text;
      _editOpen      = false;
      _captured      = false;
      _capturedBytes = null;
      _imageSize     = null;
      _ocrLines      = [];
      _strokes       = [];
    });
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
          // 캡처 후 또는 시트/오버레이가 열린 상태에선 pan 비활성
          // → 시트 닫기·버튼 탭과의 제스처 arena 충돌 방지
          onHorizontalDragEnd: (_captured ||
                  _memoOpen ||
                  _typeOpen ||
                  _editOpen ||
                  _camPermissionDenied)
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
        if (_tocReviewOpen) _buildTocReviewSheet(),
        // 이어찍기 활성 배너 (#2) — 카메라로 돌아왔을 때 상태 표시
        if (_continuationBuffer != null &&
            !_editOpen && !_tocReviewOpen && !_memoOpen && !_typeOpen)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 52),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: DesignTokens.sage,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('이어찍기 — 다음 페이지를 촬영하세요',
                        style: DesignTokens.hahmlet(12, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
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
                      _pageNumber = 0;
                      _pageCtrl.clear();
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
            // 형광펜 스트로크 오버레이 (텍스트 모드)
            if (!_imgSelectMode)
              CustomPaint(
                painter: _OcrOverlayPainter(
                  strokes: _strokes,
                  slotColor: slotColor,
                  willStraighten: _willStraighten,
                ),
              ),
            // 이미지 크롭 rect 오버레이
            if (_imgSelectMode)
              CustomPaint(
                painter: _CropOverlayPainter(cropRect: _imgCropRect),
              ),
            // 터치 핸들러 — 형광펜(pan) / 이미지 크롭(pan)
            // 목차 모드(isToc)에서는 형광펜/크롭이 필요 없으므로 제스처 비활성
            if (!_ocrRunning && !isToc)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  if (_imgSelectMode) {
                    setState(() {
                      _imgCropStart   = d.localPosition;
                      _imgCropCurrent = d.localPosition;
                    });
                  } else {
                    // 직선화 타이머 초기화
                    _straightenTimer?.cancel();
                    _willStraighten = false;
                    _lastSigPanPos  = d.localPosition;
                    setState(() => _strokes.add([d.localPosition]));
                  }
                },
                onPanUpdate: (d) {
                  if (_imgSelectMode) {
                    setState(() => _imgCropCurrent = d.localPosition);
                  } else {
                    setState(() => _strokes.last.add(d.localPosition));

                    // iOS 미세진동 무시: 3px 이상 이동 시에만 타이머 리셋
                    final prev = _lastSigPanPos;
                    if (prev == null ||
                        (d.localPosition - prev).distance > 3.0) {
                      _lastSigPanPos = d.localPosition;
                      _straightenTimer?.cancel();
                      if (_willStraighten) setState(() => _willStraighten = false);
                      _straightenTimer = Timer(
                        const Duration(milliseconds: 350),
                        () {
                          if (mounted) setState(() => _willStraighten = true);
                        },
                      );
                    }
                  }
                },
                onPanEnd: (_) {
                  _straightenTimer?.cancel();
                  if (!_imgSelectMode) {
                    if (_willStraighten && _strokes.isNotEmpty &&
                        _strokes.last.length >= 2) {
                      // 0.35초 정지 후 떼기 → 시작~끝 강제 직선화
                      final pts = _strokes.last;
                      setState(() {
                        _strokes[_strokes.length - 1] = [pts.first, pts.last];
                        _willStraighten = false;
                      });
                    } else {
                      if (_willStraighten) setState(() => _willStraighten = false);
                      // 일반 떼기 → 그린 그대로 유지
                    }
                  }
                },
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
            // 안내 문구 (텍스트 모드, 획 없을 때)
            if (!_ocrRunning && _strokes.isEmpty && !_imgSelectMode)
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
      cameraLayer = GestureDetector(
        // 탭투포커스: 탭 위치를 카메라 좌표로 변환해 초점 설정
        onTapUp: (d) async {
          if (_camCtrl == null || !_camReady) return;
          final size = MediaQuery.sizeOf(context);
          final x = (d.localPosition.dx / size.width).clamp(0.0, 1.0);
          final y = (d.localPosition.dy / size.height).clamp(0.0, 1.0);
          try {
            await _camCtrl!.setFocusPoint(Offset(x, y));
            await _camCtrl!.setExposurePoint(Offset(x, y));
          } catch (_) {}
        },
        child: ClipRect(
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
        ),
      );
    } else if (_camPermissionDenied) {
      // ── 권한 거부 상태: 인앱 허용 유도 UI ──
      // GestureDetector opaque → 아래 pan GD와 이벤트 충돌 방지
      cameraLayer = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // 배경 탭 흡수
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 52, color: Color(0x80FFF7EE)),
                const SizedBox(height: 18),
                const Text(
                  '카메라 접근 권한이 필요해요',
                  style: TextStyle(
                    color: Color(0xFFFFF7EE),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '책 페이지를 스캔하려면\n카메라 허용이 필요합니다.',
                  style: TextStyle(
                      color: Color(0xB3FFF7EE), fontSize: 13, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // 설정 열기 (영구 거부 대응)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openAppSettings(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(
                      color: DesignTokens.sage,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '설정에서 허용하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 재시도 (이미 허용했는데 오류 시)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _requestCameraPermissionAndInit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(
                      '다시 시도',
                      style: TextStyle(
                        color: Color(0xB3FFF7EE),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xB3FFF7EE),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_camError) {
      // ── 권한은 있지만 하드웨어/초기화 실패 ──
      cameraLayer = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '카메라를 열 수 없습니다.',
                style: TextStyle(
                    color: Color(0xB3FFF7EE),
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() { _camError = false; _camReady = false; });
                  _initCamera();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x80FFF7EE)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('다시 시도',
                      style: TextStyle(
                          color: Color(0xFFFFF7EE), fontSize: 13)),
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 촬영 후: 텍스트 / 이미지 모드 탭 ──────────────────────────
            if (_captured && !isToc) ...[
              _buildModeToggle(),
              const SizedBox(height: 10),
            ],
            Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 왼쪽: 상황별 버튼 ──────────────────────────────────────────
            SizedBox(
              width: 76,
              child: !_captured
                  // 촬영 전 — 키보드 직접 입력
                  ? _iconBtn(
                      onTap: () => setState(() => _typeOpen = true),
                      child: const Icon(Icons.keyboard_outlined,
                          size: 20, color: Color(0xFFFFF7EE)),
                    )
                  : _imgSelectMode
                  // 이미지 모드 — 취소
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _imgSelectMode  = false;
                        _imgCropStart   = null;
                        _imgCropCurrent = null;
                      }),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0x0FFFF7EE),
                          border: Border.all(color: const Color(0x80FFF7EE)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('✕ 취소',
                              style: TextStyle(fontSize: 13, color: Color(0xD9FFF7EE))),
                        ),
                      ),
                    )
                  : _strokes.isNotEmpty
                  // 텍스트 모드 + 획 있음 — ↩ 실행취소
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _strokes.removeLast()),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0x0FFFF7EE),
                          border: Border.all(color: const Color(0x80FFF7EE)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.undo_rounded, size: 22,
                              color: Color(0xD9FFF7EE)),
                        ),
                      ),
                    )
                  // 텍스트 모드 + 획 없음 — 메모
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
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

            // ── 가운데: 촬영 / 선택 완료 / 이미지 확인 / 저장 버튼 ──
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
                    : _imgSelectMode
                        // 이미지 모드 — 영역 확인
                        ? GestureDetector(
                            onTap: _imgCropRect != null
                                ? _cropAndSaveImage
                                : null,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 16),
                              decoration: BoxDecoration(
                                color: _imgCropRect != null
                                    ? DesignTokens.terracotta
                                    : const Color(0x33FFF7EE),
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(
                                    color: const Color(0xD9FFF7EE), width: 2),
                              ),
                              child: Text(
                                _imgCropRect != null ? '영역 저장' : '영역 선택 중…',
                                style: DesignTokens.hahmlet(15,
                                    weight: FontWeight.w600, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                    : _strokes.isNotEmpty
                        // 형광펜 그은 상태 — 선택 완료
                        ? GestureDetector(
                            onTap: () => _confirmOcrSelection(),
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
                                isToc
                                    ? '목차 저장'
                                    : (_savedImagePath.isNotEmpty && _typedText.trim().isEmpty
                                        ? '이미지 저장'
                                        : '문장 저장'),
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
        ), // Row
          ], // Column children
        ), // Column
      ),
    );
  }

  // ── 텍스트 / 이미지 모드 토글 탭 ─────────────────────────────────────────
  Widget _buildModeToggle() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0x1AFFF7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeTab(
            label: '텍스트',
            icon: Icons.text_fields_rounded,
            active: !_imgSelectMode,
            onTap: () => setState(() {
              _imgSelectMode  = false;
              _imgCropStart   = null;
              _imgCropCurrent = null;
            }),
          ),
          _modeTab(
            label: '이미지',
            icon: Icons.crop_outlined,
            active: _imgSelectMode,
            onTap: () => setState(() {
              _imgSelectMode = true;
              _strokes = [];
            }),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? DesignTokens.sage : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: active ? Colors.white : const Color(0xB3FFF7EE)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? Colors.white : const Color(0xB3FFF7EE),
                )),
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
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _editOpen = false),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                          child: Text('×',
                              style: DesignTokens.ptSans(22,
                                  color: DesignTokens.inkMute)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Text(
                        _continuationBuffer != null
                            ? '이전 페이지 문장에 이어졌어요. 한 문장으로 저장됩니다.'
                            : 'OCR로 인식된 문장이에요. 저장 전에 직접 수정할 수 있어요.',
                        style: DesignTokens.hahmlet(11,
                            color: _continuationBuffer != null
                                ? DesignTokens.sage
                                : DesignTokens.inkMute)),
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
                    // ── 페이지 번호 입력 ──
                    Row(
                      children: [
                        Text('p.',
                            style: DesignTokens.ptSans(12,
                                color: DesignTokens.inkMute)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _pageCtrl,
                            keyboardType: TextInputType.number,
                            style: DesignTokens.ptSans(13),
                            decoration: InputDecoration(
                              hintText: '쪽수',
                              hintStyle: DesignTokens.ptSans(13,
                                  color: DesignTokens.inkFaint),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              filled: true,
                              fillColor: DesignTokens.bgIvoryDeep,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: DesignTokens.rule)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: DesignTokens.rule)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: DesignTokens.sage)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // 두 페이지에 걸친 문장 — 다음 페이지 이어 찍기 (#2)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (_editCtrl.text.trim().isEmpty) return;
                              _continueToNextPage();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: DesignTokens.sage),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('다음 페이지 잇기',
                                style: DesignTokens.hahmlet(13,
                                    color: DesignTokens.sage)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final edited = _editCtrl.text.trim();
                              if (edited.isEmpty) return;
                              setState(() {
                                _typedText  = edited;
                                _pageNumber = int.tryParse(_pageCtrl.text.trim()) ?? 0;
                                _strokes    = [];
                                _ocrLines   = [];
                                _editOpen   = false;
                                _continuationBuffer = null; // 이어찍기 버퍼 소진
                              });
                              _save(); // 수정 완료 → 즉시 문장 저장
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.ink,
                              foregroundColor: DesignTokens.bgIvory,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text('저장',
                                style: DesignTokens.hahmlet(14,
                                    weight: FontWeight.w600,
                                    color: DesignTokens.bgIvory)),
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

  // ── 목차 인식 결과 확인 시트 ────────────────────────────────────────────────
  // 전체 페이지 OCR 텍스트를 보여주고 수정·재촬영·다중 페이지 추가를 지원.
  Widget _buildTocReviewSheet() {
    final pending = context.read<AppState>().pendingTocText;
    return GestureDetector(
      onTap: () => setState(() => _tocReviewOpen = false),
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
                    MediaQuery.of(context).viewInsets.bottom + 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('목차 인식 결과',
                          style: DesignTokens.hahmlet(15, weight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _tocReviewOpen = false),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                          child: Text('×', style: DesignTokens.ptSans(22, color: DesignTokens.inkMute)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      pending.isEmpty
                          ? '인식된 목차예요. 잘못 인식된 부분은 직접 고칠 수 있어요.'
                          : '이전에 추가한 목차에 이어집니다. 잘못된 부분은 직접 고칠 수 있어요.',
                      style: DesignTokens.hahmlet(11, color: DesignTokens.inkMute),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tocReviewCtrl,
                      maxLines: 9,
                      minLines: 5,
                      style: DesignTokens.lora(12).copyWith(height: 1.5),
                      decoration: InputDecoration(
                        hintText: '목차 텍스트가 여기에 표시됩니다…',
                        hintStyle: DesignTokens.hahmlet(12, color: DesignTokens.inkFaint),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _tocReviewCtrl.text.trim().isEmpty ? null : _tocAddAndScanMore,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: DesignTokens.sage),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text('한 장 더 촬영',
                                style: DesignTokens.hahmlet(13, color: DesignTokens.sage)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _tocReviewCtrl.text.trim().isEmpty ? null : _tocAddAndFinish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.ink,
                              foregroundColor: DesignTokens.bgIvory,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                            child: Text('목차 저장',
                                style: DesignTokens.hahmlet(13,
                                    weight: FontWeight.w600, color: DesignTokens.bgIvory)),
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
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _memoOpen = false),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                          child: Text('×', style: DesignTokens.ptSans(22, color: DesignTokens.inkMute)),
                        ),
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
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _typeOpen = false),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                          child: Text('×', style: DesignTokens.ptSans(22, color: DesignTokens.inkMute)),
                        ),
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
                    // ── 페이지 번호 입력 ──
                    Row(
                      children: [
                        Text('p.',
                            style: DesignTokens.ptSans(12,
                                color: DesignTokens.inkMute)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _pageCtrl,
                            keyboardType: TextInputType.number,
                            style: DesignTokens.ptSans(13),
                            decoration: InputDecoration(
                              hintText: '쪽수',
                              hintStyle: DesignTokens.ptSans(13,
                                  color: DesignTokens.inkFaint),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              filled: true,
                              fillColor: DesignTokens.bgIvoryDeep,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: DesignTokens.rule)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: DesignTokens.rule)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: DesignTokens.sage)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_typeCtrl.text.trim().isNotEmpty) {
                            setState(() {
                              _typedText  = _typeCtrl.text.trim();
                              _pageNumber = int.tryParse(_pageCtrl.text.trim()) ?? 0;
                              _captured   = true;
                              _typeOpen   = false;
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
  final bool willStraighten;

  const _OcrOverlayPainter({
    required this.strokes,
    required this.slotColor,
    this.willStraighten = false,
  });

  static const double _strokeW = 15.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final normalPaint = Paint()
      ..color = slotColor.withValues(alpha: 0.40)
      ..strokeWidth = _strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int si = 0; si < strokes.length; si++) {
      final pts = strokes[si];
      if (pts.isEmpty) continue;

      // 마지막 획이고 willStraighten이면: 직선 미리보기 표시
      final isLastAndWillStraighten =
          willStraighten && si == strokes.length - 1;

      if (isLastAndWillStraighten) {
        // 직선 미리보기 (흰색 점선 위에 슬롯 색 실선)
        final previewPaint = Paint()
          ..color = slotColor.withValues(alpha: 0.85)
          ..strokeWidth = _strokeW * 0.7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(pts.first, pts.last, previewPaint);

        // "직선화 됨" 텍스트 힌트 (작은 아이콘 대신 투명 원)
        canvas.drawCircle(
          pts.first,
          _strokeW * 0.55,
          Paint()..color = Colors.white.withValues(alpha: 0.80),
        );
        canvas.drawCircle(
          pts.last,
          _strokeW * 0.55,
          Paint()..color = Colors.white.withValues(alpha: 0.80),
        );
      } else {
        if (pts.length == 1) {
          canvas.drawCircle(pts.first, _strokeW / 2,
              Paint()..color = slotColor.withValues(alpha: 0.40));
          continue;
        }
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(path, normalPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OcrOverlayPainter old) =>
      old.strokes != strokes ||
      old.slotColor != slotColor ||
      old.willStraighten != willStraighten;
}

// ── 이미지 크롭 영역 오버레이 ──────────────────────────────────────────────────
class _CropOverlayPainter extends CustomPainter {
  final Rect? cropRect;
  const _CropOverlayPainter({this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 반투명 어둡게
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0x55000000),
    );

    final rect = cropRect;
    if (rect == null) return;

    // 선택 영역을 밝게 (지우개 효과)
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);

    // 실선 테두리
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFFFF7EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 코너 핸들
    const cLen = 12.0;
    const cW   = 3.0;
    final corners = <(Offset, Offset, Offset)>[
      (rect.topLeft,     const Offset(cLen, 0),  const Offset(0, cLen)),
      (rect.topRight,    const Offset(-cLen, 0), const Offset(0, cLen)),
      (rect.bottomLeft,  const Offset(cLen, 0),  const Offset(0, -cLen)),
      (rect.bottomRight, const Offset(-cLen, 0), const Offset(0, -cLen)),
    ];
    final cornerPaint = Paint()
      ..color = const Color(0xFFFFF7EE)
      ..strokeWidth = cW
      ..strokeCap = StrokeCap.round;
    for (final (origin, d1, d2) in corners) {
      canvas.drawLine(origin, origin + d1, cornerPaint);
      canvas.drawLine(origin, origin + d2, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.cropRect != cropRect;
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
