import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../providers/app_state.dart';
import '../services/book_search_service.dart';

/// 표지 입력 바텀시트 — 한 시트에서 세 가지 방법 제공:
///  ① 제목 검색 (카카오 → Google Books 폴백, 판본별 표지 그리드)
///  ② 갤러리 선택   ③ 카메라 촬영
/// 선택이 끝나면 표지 비율로 정규화된 PNG 바이트를 반환. 취소 시 null.
Future<Uint8List?> showCoverPickerSheet(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoverPickerSheet(initialQuery: initialQuery),
  );
}

class _CoverPickerSheet extends StatefulWidget {
  final String initialQuery;
  const _CoverPickerSheet({required this.initialQuery});

  @override
  State<_CoverPickerSheet> createState() => _CoverPickerSheetState();
}

enum _SearchState { idle, loading, results, empty, error }

class _CoverPickerSheetState extends State<_CoverPickerSheet> {
  final _queryCtrl = TextEditingController();
  final _picker = ImagePicker();

  _SearchState _state = _SearchState.idle;
  List<BookCoverResult> _results = [];
  String _errorMsg = '';
  bool _downloading = false; // 표지 다운로드/크롭 중 오버레이

  @override
  void initState() {
    super.initState();
    _queryCtrl.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      // 시트가 뜨자마자 제목으로 자동 검색
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _state = _SearchState.loading);
    try {
      final results = await BookSearchService.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _state = results.isEmpty ? _SearchState.empty : _SearchState.results;
      });
    } on BookSearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _state = _SearchState.error;
      });
    }
  }

  Future<void> _selectResult(BookCoverResult r) async {
    setState(() => _downloading = true);
    final bytes = await BookSearchService.downloadCover(r.coverUrl);
    if (!mounted) return;
    setState(() => _downloading = false);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('표지를 불러오지 못했어요. 다른 표지를 선택해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pop(context, bytes);
  }

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null || !mounted) return;
      setState(() => _downloading = true);
      final raw = await file.readAsBytes();
      // 임의 비율 사진 → 표지 비율(3:4) 센터 크롭
      final cropped = await BookSearchService.cropToCoverRatio(raw);
      if (!mounted) return;
      Navigator.pop(context, cropped);
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera
              ? '카메라를 사용할 수 없어요. 권한을 확인해주세요.'
              : '이미지를 불러오지 못했어요.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    final bg    = isDark ? DesignTokens.bgDark : DesignTokens.bgIvory;
    final ink   = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute  = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    final deep  = isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep;
    final rule  = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                // 핸들
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? DesignTokens.ruleDarkStrong
                        : DesignTokens.ruleStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('표지 가져오기',
                      style: DesignTokens.hahmlet(16,
                          weight: FontWeight.w600, color: ink)),
                ),
                const SizedBox(height: 12),

                // ── 검색창 ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: deep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rule),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 16, color: mute),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _queryCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          style: DesignTokens.hahmlet(13, color: ink),
                          decoration: InputDecoration(
                            hintText: '책 제목으로 표지를 찾아요',
                            hintStyle:
                                DesignTokens.hahmlet(13, color: faint),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _search,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                          child: Text('검색',
                              style: DesignTokens.hahmlet(12,
                                  weight: FontWeight.w600,
                                  color: DesignTokens.sage)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── 갤러리 / 카메라 ──
                Row(
                  children: [
                    Expanded(
                      child: _MethodButton(
                        icon: Icons.photo_outlined,
                        label: '갤러리',
                        isDark: isDark,
                        onTap: () => _pickFrom(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MethodButton(
                        icon: Icons.camera_alt_outlined,
                        label: '카메라 촬영',
                        isDark: isDark,
                        onTap: () => _pickFrom(ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 검색 결과 영역 ──
                Expanded(child: _buildBody(scrollCtrl, ink, mute, faint)),
              ],
            ),
          ),

          // 다운로드/처리 중 오버레이
          if (_downloading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 26, height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(
      ScrollController scrollCtrl, Color ink, Color mute, Color faint) {
    switch (_state) {
      case _SearchState.idle:
        return Center(
          child: Text('제목을 검색하거나\n갤러리·카메라로 표지를 추가하세요.',
              textAlign: TextAlign.center,
              style: DesignTokens.hahmlet(12, color: faint)
                  .copyWith(height: 1.6)),
        );

      case _SearchState.loading:
        return const Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: DesignTokens.sage),
          ),
        );

      case _SearchState.empty:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 30, color: faint),
              const SizedBox(height: 10),
              Text('"${_queryCtrl.text.trim()}" 표지를 찾지 못했어요.',
                  style: DesignTokens.hahmlet(13, color: mute)),
              const SizedBox(height: 4),
              Text('갤러리나 카메라로 직접 추가할 수 있어요.',
                  style: DesignTokens.hahmlet(11, color: faint)),
            ],
          ),
        );

      case _SearchState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 30, color: faint),
              const SizedBox(height: 10),
              Text(_errorMsg, style: DesignTokens.hahmlet(13, color: mute)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _search,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DesignTokens.sage),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('다시 시도',
                    style: DesignTokens.hahmlet(12,
                        color: DesignTokens.sage)),
              ),
            ],
          ),
        );

      case _SearchState.results:
        // 같은 책의 여러 판본이 그리드로 나열 → 원하는 표지를 한 번에 선택
        return GridView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.only(top: 2, bottom: 30),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.52,
          ),
          itemCount: _results.length,
          itemBuilder: (_, i) => _CoverGridItem(
            result: _results[i],
            ink: ink,
            mute: mute,
            onTap: () => _selectResult(_results[i]),
          ),
        );
    }
  }
}

// ── 갤러리/카메라 버튼 ────────────────────────────────────────────────────────
class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _MethodButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
          border: Border.all(
              color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 6),
            Text(label, style: DesignTokens.hahmlet(12, color: ink)),
          ],
        ),
      ),
    );
  }
}

// ── 검색 결과 그리드 아이템 ───────────────────────────────────────────────────
class _CoverGridItem extends StatelessWidget {
  final BookCoverResult result;
  final Color ink;
  final Color mute;
  final VoidCallback onTap;

  const _CoverGridItem({
    required this.result,
    required this.ink,
    required this.mute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (result.publisher.isNotEmpty) result.publisher,
      if (result.year.isNotEmpty) result.year,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 6,
                      offset: Offset(1, 2)),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                result.coverUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.black12,
                        child: const Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined,
                      size: 20, color: mute),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DesignTokens.hahmlet(10.5,
                  weight: FontWeight.w600, color: ink)),
          const SizedBox(height: 2),
          Text(meta.isEmpty ? result.author : meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DesignTokens.ptSans(9, color: mute)),
        ],
      ),
    );
  }
}
