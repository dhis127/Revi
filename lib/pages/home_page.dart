import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/book.dart';
import '../providers/app_state.dart';
import 'scan_page.dart';
import '../widgets/book_cover_image.dart';
import 'archive_page.dart';
import 'add_book_page.dart';
import 'quotes_page.dart';
import 'settings_page.dart';
import 'search_page.dart';
import 'paywall_page.dart';
import 'subscription_page.dart';
import 'report_detail_page.dart';

// ── spine book seed / size lookup ──────────────────────────────────────────────
int _spineSeed(String id) {
  int h = 0;
  for (final c in id.codeUnits) { h = (h * 31 + c) & 0x7FFFFFFF; }
  return h;
}

// ── 책 질감 오버레이 페인터 ────────────────────────────────────────────────────
class _BookGrainPainter extends CustomPainter {
  final int seed;
  final bool isSpine; // 책등 vs 표지

  const _BookGrainPainter({required this.seed, this.isSpine = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    // ① 왼쪽 엣지 하이라이트 (광택)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * (isSpine ? 0.18 : 0.12), size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.09),
    );

    // ② 수직 결 라인 (나무·직물 질감)
    final grainPaint = Paint()
      ..strokeWidth = 0.7;
    final lineCount = isSpine ? 4 : 7;
    for (int i = 0; i < lineCount; i++) {
      final x = rng.nextDouble() * size.width;
      final jitter = (rng.nextDouble() - 0.5) * (isSpine ? 2.0 : 5.0);
      grainPaint.color = Colors.white.withValues(alpha: rng.nextDouble() * 0.06 + 0.02);
      canvas.drawLine(Offset(x, 0), Offset(x + jitter, size.height), grainPaint);
    }

    // ③ 하단 미세 그림자 (두께감)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.8, size.width, size.height * 0.2),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant _BookGrainPainter old) => old.seed != seed;
}
const _spineWidths  = [22, 28, 18, 32, 24, 20, 30];
const _spineHeights = [180, 168, 196, 156, 188, 172, 162];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // 애니메이션 (하단 바 화살표)
  late AnimationController _leftCtrl;
  late AnimationController _rightCtrl;
  late Animation<double> _leftAnim;
  late Animation<double> _rightAnim;

  // 한도 팝업 (세션당 1회)
  bool _limitShown = false;

  // ── 리포트 인앱 배너 ────────────────────────────────────────────────────────
  OverlayEntry? _reportBanner;
  bool _reportBannerShown = false;

  // 책장 페이지 컨트롤러
  late PageController _pageCtrl;
  int _currentPage = 0;

  // Listener 기반 수직 스와이프 감지
  double _ptrDownY = 0;
  double _ptrDownX = 0;
  DateTime _ptrDownTime = DateTime(0);

  // 페이지 이름 인라인 편집
  bool _editingTitle = false;
  final TextEditingController _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(() {
      final p = _pageCtrl.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });

    _leftCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _rightCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _leftAnim  = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: _leftCtrl,  curve: Curves.easeInOut));
    _rightAnim = Tween<double>(begin: 0, end:  6).animate(CurvedAnimation(parent: _rightCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _reportBanner?.remove();
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  // ── 리포트 배너 표시 ─────────────────────────────────────────────────────────
  void _showReportBanner(BuildContext ctx, AppState state) {
    final report = state.latestUnreadReport;
    if (report == null) return;
    _reportBanner?.remove();
    _reportBanner = OverlayEntry(
      builder: (_) => _ReportBannerOverlay(
        report: report,
        onTap: () {
          _reportBanner?.remove();
          _reportBanner = null;
          if (!state.isSubscribed) {
            _pushPaywall(ctx);
            return;
          }
          // 리포트 책장(마지막 페이지)으로 이동 후 리포트 열기
          final reportPageIdx = state.pageCount; // user pages + report page
          final nav = Navigator.of(ctx);
          _pageCtrl.animateToPage(
            reportPageIdx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ).then((_) {
            if (!mounted) return;
            nav.push(MaterialPageRoute(builder: (_) => ReportDetailPage(report: report)));
          });
        },
        onDismiss: () {
          _reportBanner?.remove();
          _reportBanner = null;
        },
      ),
    );
    Overlay.of(ctx).insert(_reportBanner!);
  }

  // ── 책장 이름 편집 (검색창 아래) ─────────────────────────────────────────────
  void _startEditTitle(AppState state) {
    // 탭 시 텍스트를 비워서 빈칸 + 힌트 표시
    _titleCtrl.clear();
    setState(() => _editingTitle = true);
  }

  void _submitTitle(AppState state) {
    final name = _titleCtrl.text.trim();
    // 비어있으면 '' 저장 → getPageName이 기본값("책장 N") 반환
    state.updatePageName(_currentPage, name);
    setState(() => _editingTitle = false);
    FocusScope.of(context).unfocus();
  }

  // ── Paywall 하단 슬라이드 업 전환 ─────────────────────────────────────────
  void _pushPaywall(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PaywallPage(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _pushSubscriptionPage(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SubscriptionPage(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ── 한도 경고 팝업 (배너 아님, 중앙 다이얼로그) ────────────────────────────────
  void _showLimitDialog(BuildContext context) {
    final state = context.read<AppState>();
    final isDark = state.isDark;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('책장이 거의 가득 찼어요.',
                  style: DesignTokens.hahmlet(16,
                      weight: FontWeight.w600,
                      color: isDark ? DesignTokens.inkDark : DesignTokens.ink),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(state.bookLimitMessage,
                  style: DesignTokens.ptSans(13,
                      color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                  textAlign: TextAlign.center),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pushPaywall(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.terracotta,
                    foregroundColor: const Color(0xFFFFF7EE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: Text('구독하고 계속 저장하기',
                      style: DesignTokens.hahmlet(14,
                          weight: FontWeight.w600,
                          color: const Color(0xFFFFF7EE))),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('나중에',
                    style: DesignTokens.ptSans(13,
                        color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 책장 페이지 추가 ─────────────────────────────────────────────────────────
  void _addShelfPage(BuildContext context, AppState state) {
    if (!state.isSubscribed) {
      _pushPaywall(context);
      return;
    }
    if (!state.canAddShelf) {
      if (state.isPremium) return; // 999999 한도, 사실상 미도달
      // 스탠다드 → 프리미엄 업셀
      _pushSubscriptionPage(context);
      return;
    }
    HapticFeedback.mediumImpact();
    state.addShelfPage();
    // addShelfPage() → notifyListeners() → 다음 프레임에서 PageView rebuild
    // → 그 다음 프레임에서 animateToPage (이중 콜백으로 타이밍 보장)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageCtrl.animateToPage(
          context.read<AppState>().pageCount - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  // ── 책 이동 모달 ────────────────────────────────────────────────────────────
  void _showMoveBookSheet(BuildContext context, AppState state) {
    final booksOnOtherPages = state.books.where((b) {
      final page = b.shelf ~/ 10;
      return page != _currentPage;
    }).toList();

    if (booksOnOtherPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('다른 책장에 이동할 책이 없어요.',
              style: DesignTokens.hahmlet(13, color: const Color(0xFFFFF7EE))),
          backgroundColor: DesignTokens.ink,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: state.isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이 책장으로 가져오기',
                  style: DesignTokens.hahmlet(15,
                      weight: FontWeight.w600,
                      color: state.isDark ? DesignTokens.inkDark : DesignTokens.ink)),
              const SizedBox(height: 4),
              Text('선택한 책이 "${state.getPageName(_currentPage)}"의 첫 번째 칸으로 이동해요.',
                  style: DesignTokens.ptSans(12,
                      color: state.isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
              const SizedBox(height: 16),
              ...booksOnOtherPages.map((book) {
                final fromPage = book.shelf ~/ 10;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(book.title,
                      style: DesignTokens.hahmlet(13,
                          color: state.isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                  subtitle: Text('${state.getPageName(fromPage)}에서',
                      style: DesignTokens.ptSans(11,
                          color: state.isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14,
                      color: state.isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                  onTap: () {
                    state.moveBookToPage(book.id, _currentPage);
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _LogoutDialog(onConfirm: () {
        context.read<AppState>().logout();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;

    // 한도 80% 도달 시 중앙 팝업 (세션당 1회, 구독 중 제외)
    if (state.isNearBookLimit && !state.isSubscribed && !_limitShown) {
      _limitShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLimitDialog(context);
      });
    }
    if (!state.isNearBookLimit) _limitShown = false; // 구독 후 초기화

    // 새 리포트 배너 (세션당 1회)
    if (state.hasUnreadReport && !_reportBannerShown) {
      _reportBannerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showReportBanner(context, state);
      });
    }

    return GestureDetector(
      // ← 스캔, → 로그아웃 (모든 책장 페이지에 동일 적용)
      onHorizontalDragEnd: (d) {
        if (_editingTitle) return;
        final vx = d.velocity.pixelsPerSecond.dx;
        final vy = d.velocity.pixelsPerSecond.dy;
        // 수직 성분이 수평 성분의 절반 이상이면 대각선 → 무시
        if (vy.abs() > vx.abs() * 0.5) return;
        if (vx < -600) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage()));
        } else if (vx > 600) {
          _showLogoutConfirm();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
        body: Column(
          children: [
            _buildTopBar(context, isDark, state),
            // ── Listener: 수직 스와이프로 책장 페이지 이동 ──────────────────────
            // PageView는 NeverScrollableScrollPhysics로 렌더링만 담당.
            // Listener는 게스처 아레나를 우회하여 raw pointer를 직접 처리하므로
            // 내부의 SingleChildScrollView(horizontal)와 충돌 없음.
            // 푸터(_buildPageFooter)도 Listener 안에 포함해야 하단 텍스트에서
            // 시작한 스와이프도 onPointerDown이 잡힌다.
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  _ptrDownY    = e.position.dy;
                  _ptrDownX    = e.position.dx;
                  _ptrDownTime = DateTime.now();
                },
                onPointerUp: (e) {
                  // 롱프레스/드래그(> 500ms) 제외
                  if (DateTime.now().difference(_ptrDownTime).inMilliseconds > 500) return;
                  final dy = e.position.dy - _ptrDownY;
                  final dx = e.position.dx - _ptrDownX;
                  // 수직 이동이 50px 이상이고, 수평보다 1.2배 이상 커야 함
                  if (dy.abs() < 50 || dy.abs() < dx.abs() * 1.2) return;
                  final s = context.read<AppState>();
                  if (dy < 0) {
                    if (_currentPage < s.pageCount - 1) {
                      // 다음 유저 책장으로 이동
                      HapticFeedback.lightImpact();
                      _pageCtrl.animateToPage(_currentPage + 1,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic);
                    } else if (_currentPage == s.pageCount - 1) {
                      // 마지막 유저 책장에서 위로 → 책장 추가 (무료면 paywall)
                      _addShelfPage(context, s);
                    }
                    // 리포트 책장(_currentPage == s.pageCount)에서 위로 → 무시
                  } else if (dy > 0 && _currentPage > 0) {
                    // 이전 책장으로 이동
                    HapticFeedback.lightImpact();
                    _pageCtrl.animateToPage(_currentPage - 1,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic);
                  }
                },
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageCtrl,
                        scrollDirection: Axis.vertical,
                        // 제스처는 Listener가 담당. PageView는 렌더링만.
                        physics: const NeverScrollableScrollPhysics(),
                        // 유저 책장 수 + 리포트 책장 1개
                        itemCount: state.pageCount + 1,
                        itemBuilder: (context, pageIdx) {
                          // 마지막 페이지 = 리포트 책장 (고정)
                          if (pageIdx == state.pageCount) {
                            return _ReportShelfContent(
                              reports: state.reports,
                              isDark: isDark,
                            );
                          }
                          return _ShelfContent(
                            pageIndex: pageIdx,
                            books: state.books,
                            isDark: isDark,
                            onAddBook: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddBookPage(targetPageIndex: pageIdx),
                              ),
                            ),
                            onMoveBook: () => _showMoveBookSheet(context, state),
                          );
                        },
                      ),
                    ),
                    // ── 하단 푸터: 마지막 페이지 → 추가 안내 / 중간 → 도트 ────────────
                    // Listener 안에 있어야 하단 텍스트 위치에서 시작한 스와이프도 감지됨
                    _buildPageFooter(context, isDark, state),
                  ],
                ),
              ),
            ),
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  // ── 상단 바: 고정 "내 책장" + 설정 / 검색창 / 책장이름 편집 ─────────────────
  Widget _buildTopBar(BuildContext context, bool isDark, AppState state) {
    final inkColor    = isDark ? DesignTokens.inkDark      : DesignTokens.ink;
    final mutedColor  = isDark ? DesignTokens.inkDarkMute  : DesignTokens.inkMute;
    final faintColor  = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    // 리포트 책장 여부
    final isReportPage = _currentPage == state.pageCount;
    // 현재 페이지의 기본 이름 (편집 전 힌트용)
    final defaultName = isReportPage
        ? '${state.displayName}의 독서 데이터실'
        : state.getPageName(_currentPage);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1행: "내 책장" 고정 레이블 + 설정 버튼 ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '내 책장',
                    style: DesignTokens.hahmlet(15,
                        weight: FontWeight.w600, color: inkColor),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage())),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.settings_outlined, size: 19, color: inkColor),
                  ),
                ),
              ],
            ),
          ),
          // ── 2행: 검색창 ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: mutedColor),
                    const SizedBox(width: 8),
                    Text('책 또는 문장을 찾아요',
                        style: DesignTokens.hahmlet(13, color: faintColor)),
                  ],
                ),
              ),
            ),
          ),
          // ── 3행: 책장 이름 (표시 시 제목 스타일 / 탭 시 편집 모드) ──────────────
          // 평소: 진하고 큰 폰트로 제목처럼 표시 (inkColor)
          // 편집 중: 빈칸 + defaultName 힌트 텍스트
          // 빈칸 확인 → getPageName이 기본값("책장 N")으로 복원
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _editingTitle
                ? TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: DesignTokens.hahmlet(15,
                        weight: FontWeight.w600, color: inkColor),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: defaultName,
                      hintStyle: DesignTokens.hahmlet(15,
                          weight: FontWeight.w600, color: faintColor),
                    ),
                    onSubmitted: (_) => _submitTitle(state),
                    onTapOutside: (_) => _submitTitle(state),
                  )
                : isReportPage
                    // 리포트 책장: 수정 불가 고정 제목
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(Icons.auto_stories_outlined,
                              size: 13, color: Color(0xFF3B2015)),
                          const SizedBox(width: 5),
                          Text(
                            defaultName,
                            style: DesignTokens.hahmlet(15,
                                weight: FontWeight.w600,
                                color: const Color(0xFF3B2015)),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () => _startEditTitle(state),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              defaultName,
                              style: DesignTokens.hahmlet(15,
                                  weight: FontWeight.w600, color: inkColor),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Icon(Icons.edit_outlined, size: 8, color: faintColor),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── 하단 푸터 ────────────────────────────────────────────────────────────────
  Widget _buildPageFooter(BuildContext context, bool isDark, AppState state) {
    final totalWithReport = state.pageCount + 1;
    final isReportShelf   = _currentPage == state.pageCount;
    final isLastUserShelf = _currentPage == state.pageCount - 1;

    if (isReportShelf) {
      // 리포트 책장에서는 레이블만 표시
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 11,
                color: Color(0xFF3B2015)),
            const SizedBox(width: 5),
            Text('AI 독서 리포트',
                style: DesignTokens.ptSans(11, color: const Color(0xFF3B2015))
                    .copyWith(letterSpacing: 1.1)),
          ],
        ),
      );
    }
    if (isLastUserShelf) {
      return _AddShelfButton(
        isDark: isDark,
        onTap: () => _addShelfPage(context, state),
      );
    }
    return _PageDots(
      currentPage: _currentPage,
      totalPages: totalWithReport,
      isDark: isDark,
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
        border: Border(top: BorderSide(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _showLogoutConfirm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _leftAnim,
                      builder: (_, child) => Transform.translate(
                          offset: Offset(_leftAnim.value, 0), child: child),
                      child: Text('←', style: DesignTokens.ptSans(14,
                          color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)),
                    ),
                    const SizedBox(width: 6),
                    Text('Log-out', style: DesignTokens.solway(13,
                        color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const QuotesPage())),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_outline, size: 18,
                        color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft),
                    const SizedBox(height: 2),
                    Text('문장', style: DesignTokens.ptSans(9,
                        color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                        .copyWith(letterSpacing: 1.2)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ScanPage())),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Scan', style: DesignTokens.solway(13,
                        color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)),
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: _rightAnim,
                      builder: (_, child) => Transform.translate(
                          offset: Offset(_rightAnim.value, 0), child: child),
                      child: Text('→', style: DesignTokens.ptSans(14,
                          color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _ShelfContent — PageView 내 각 책장 페이지의 콘텐츠
// ═══════════════════════════════════════════════════════════════════════════════
class _ShelfContent extends StatelessWidget {
  final int pageIndex;
  final List<Book> books;
  final bool isDark;
  final VoidCallback onAddBook;
  final VoidCallback onMoveBook;

  const _ShelfContent({
    required this.pageIndex,
    required this.books,
    required this.isDark,
    required this.onAddBook,
    required this.onMoveBook,
  });

  int get _base => pageIndex * 10; // 이 페이지의 shelf 기준값

  @override
  Widget build(BuildContext context) {
    final covers     = books.where((b) => b.shelf == _base).toList();
    final hasContent = books.any((b) => b.shelf >= _base && b.shelf <= _base + 3);

    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: _CoverShelf(
              books: covers,
              shelfIndex: _base,
              emptyHint: _EmptyCoverHint(
                isDark: isDark,
                onAddBook: onAddBook,
                onMoveBook: pageIndex > 0 ? onMoveBook : null,
              ),
            )),
            for (int i = 1; i <= 3; i++)
              Expanded(child: _SpineShelf(
                books: books.where((b) => b.shelf == _base + i).toList(),
                shelfIndex: _base + i,
              )),
          ],
        ),
        // 책이 있는 페이지(0 제외)에는 우상단에 "책 가져오기" 버튼
        if (pageIndex > 0 && hasContent)
          Positioned(
            top: 8, right: 12,
            child: GestureDetector(
              onTap: onMoveBook,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep)
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 13,
                        color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                    const SizedBox(width: 4),
                    Text('책 가져오기',
                        style: DesignTokens.hahmlet(11,
                            color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// 빈 커버 칸 힌트
class _EmptyCoverHint extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAddBook;
  final VoidCallback? onMoveBook;

  const _EmptyCoverHint({
    required this.isDark,
    required this.onAddBook,
    this.onMoveBook,
  });

  @override
  Widget build(BuildContext context) {
    final color = (isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
        .withValues(alpha: 0.38);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 26, color: color),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onAddBook,
            child: Text('+ 새 책 추가하기',
                style: DesignTokens.hahmlet(12, color: color)),
          ),
          if (onMoveBook != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onMoveBook,
              child: Text('다른 책장에서 가져오기',
                  style: DesignTokens.hahmlet(11,
                      color: color.withValues(alpha: 0.6))),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 책장 추가 안내 (마지막 페이지 하단 플로팅 텍스트) ────────────────────────────
class _AddShelfButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _AddShelfButton({required this.isDark, required this.onTap});

  @override
  State<_AddShelfButton> createState() => _AddShelfButtonState();
}

class _AddShelfButtonState extends State<_AddShelfButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -4, end: 4)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = (widget.isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)
        .withValues(alpha: 0.55);
    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: AnimatedBuilder(
          animation: _float,
          builder: (_, child) =>
              Transform.translate(offset: Offset(0, _float.value), child: child),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('↑ ',
                  style: DesignTokens.ptSans(13,
                      weight: FontWeight.w700, color: color)),
              Text('책장 추가하기',
                  style: DesignTokens.hahmlet(13,
                      weight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 페이지 도트 인디케이터 ────────────────────────────────────────────────────────
class _PageDots extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isDark;

  const _PageDots({
    required this.currentPage,
    required this.totalPages,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor   = (isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft).withValues(alpha: 0.75);
    final inactiveColor = (isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute).withValues(alpha: 0.28);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (i) {
          final active = i == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: active ? 16 : 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: active ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Cover Shelf ──────────────────────────────────────────────────────────────
class _CoverShelf extends StatelessWidget {
  final List<Book> books;
  final int shelfIndex;
  final Widget? emptyHint;

  const _CoverShelf({
    required this.books,
    required this.shelfIndex,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = books.length >= 3;
    return DragTarget<Book>(
      onWillAcceptWithDetails: (d) =>
          d.data.shelf != shelfIndex && !isFull,
      onAcceptWithDetails: (d) {
        HapticFeedback.mediumImpact();
        context.read<AppState>().moveBookToShelf(d.data.id, shelfIndex);
      },
      builder: (context, candidateItems, rejectedItems) {
        final isRejecting = isFull && rejectedItems.isNotEmpty;
        return _ShelfWrapper(
          isHovering: candidateItems.isNotEmpty,
          isRejecting: isRejecting,
          child: books.isEmpty
              ? (emptyHint ?? const SizedBox.shrink())
              : Align(
                  alignment: const Alignment(0, 0.75),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: books
                        .map((b) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 13),
                              child: _DraggableCoverBook(book: b),
                            ))
                        .toList(),
                  ),
                ),
        );
      },
    );
  }
}

class _DraggableCoverBook extends StatefulWidget {
  final Book book;
  const _DraggableCoverBook({required this.book});
  @override
  State<_DraggableCoverBook> createState() => _DraggableCoverBookState();
}

class _DraggableCoverBookState extends State<_DraggableCoverBook>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  OverlayEntry? _overlay;
  bool _isSnapping = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _overlay?.remove();
    _ctrl.dispose();
    super.dispose();
  }

  void _snapBack(Velocity velocity, Offset cancelOffset) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero);
    final size   = box.size;
    final anim   = Tween<Offset>(begin: cancelOffset, end: origin)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
    _overlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Positioned(
          left: anim.value.dx, top: anim.value.dy,
          width: size.width, height: size.height,
          child: Material(color: Colors.transparent,
              child: Opacity(opacity: 0.92, child: _CoverBook(book: widget.book))),
        ),
      ),
    );
    setState(() => _isSnapping = true);
    Overlay.of(context).insert(_overlay!);
    _ctrl.forward(from: 0).then((_) {
      _overlay?.remove(); _overlay = null;
      if (mounted) setState(() => _isSnapping = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = _CoverBook(book: widget.book);
    return LongPressDraggable<Book>(
      data: widget.book,
      hapticFeedbackOnStart: true,
      delay: const Duration(milliseconds: 350),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.06,
            child: Opacity(opacity: 0.92, child: _CoverBook(book: widget.book))),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      onDraggableCanceled: _snapBack,
      child: _isSnapping ? Opacity(opacity: 0, child: child) : child,
    );
  }
}

class _CoverBook extends StatelessWidget {
  final Book book;
  const _CoverBook({required this.book});

  static const _r = BorderRadius.only(
    topRight: Radius.circular(4), bottomRight: Radius.circular(4),
    bottomLeft: Radius.circular(1), topLeft: Radius.circular(1),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ArchivePage(bookId: book.id))),
      child: Container(
        width: 88, height: 132,
        decoration: const BoxDecoration(
          borderRadius: _r,
          boxShadow: [BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(2, 4))],
        ),
        child: ClipRRect(
          borderRadius: _r,
          child: BookCoverImage(
            book: book,
            width: 88, height: 132,
            placeholder: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? DesignTokens.coverGradDark(book.color)
                            : DesignTokens.coverGrad(book.color),
                      ),
                    ),
                    // 질감 오버레이
                    CustomPaint(
                      painter: _BookGrainPainter(
                          seed: _spineSeed(book.id), isSpine: false),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NO.${book.id.replaceAll('b', '').padLeft(2, '0')}',
                              style: DesignTokens.ptSans(7,
                                  color: const Color(0xBFFFFFFF), weight: FontWeight.w700)),
                          const Spacer(),
                          Text(book.title,
                              style: DesignTokens.hahmlet(10,
                                  weight: FontWeight.w600, color: const Color(0xFFFFF7EE)),
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(book.author.split(' ').last,
                              style: DesignTokens.ptSans(7, color: const Color(0xCCFFF7EE))),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

// ─── Spine Shelf ──────────────────────────────────────────────────────────────
class _SpineShelf extends StatefulWidget {
  final List<Book> books;
  final int shelfIndex;
  const _SpineShelf({required this.books, required this.shelfIndex});
  @override
  State<_SpineShelf> createState() => _SpineShelfState();
}

class _SpineShelfState extends State<_SpineShelf> {
  final _labelCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() { _labelCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final isDark = state.isDark;
    if (!_initialized) {
      _labelCtrl.text = state.getShelfLabel(widget.shelfIndex);
      _initialized = true;
    }
    return DragTarget<Book>(
      onWillAcceptWithDetails: (d) => d.data.shelf != widget.shelfIndex,
      onAcceptWithDetails: (d) {
        HapticFeedback.mediumImpact();
        context.read<AppState>().moveBookToShelf(d.data.id, widget.shelfIndex);
      },
      builder: (context, candidateItems, rejectedItems) => _ShelfWrapper(
        isHovering: candidateItems.isNotEmpty,
        isRejecting: rejectedItems.isNotEmpty,
        curationWidget: _buildLabel(isDark, state),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 14),
              ...widget.books.asMap().entries.map((e) {
                final s = _spineSeed(e.value.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _DraggableSpineBook(
                    book: e.value,
                    width:  _spineWidths [s % _spineWidths.length ].toDouble(),
                    height: _spineHeights[s % _spineHeights.length].toDouble(),
                    index: e.key, totalBooks: widget.books.length,
                  ),
                );
              }),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(bool isDark, AppState state) {
    final hintColor = (isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute).withValues(alpha: 0.45);
    final textColor = isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft;
    // 메인 책장(0~3)은 기본 힌트, 추가 책장은 빈 힌트
    final hints = {1: '읽기 전', 2: '읽는 중', 3: '다 읽은 책'};
    final hint  = hints[widget.shelfIndex] ?? '나만의 큐레이션';
    return SizedBox(
      width: 110,
      child: TextField(
        controller: _labelCtrl,
        textAlign: TextAlign.right,
        maxLines: 2,
        style: DesignTokens.hahmlet(11, color: textColor),
        decoration: InputDecoration(
          hintText: '$hint\n(탭 하여 수정)',
          hintStyle: DesignTokens.hahmlet(11, color: hintColor),
          border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (val) => context.read<AppState>().updateShelfLabel(widget.shelfIndex, val.trim()),
        onTapOutside: (_) {
          context.read<AppState>().updateShelfLabel(widget.shelfIndex, _labelCtrl.text.trim());
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

class _DraggableSpineBook extends StatefulWidget {
  final Book book;
  final double width, height;
  final int index, totalBooks;
  const _DraggableSpineBook({
    required this.book, required this.width, required this.height,
    required this.index, required this.totalBooks,
  });
  @override
  State<_DraggableSpineBook> createState() => _DraggableSpineBookState();
}

class _DraggableSpineBookState extends State<_DraggableSpineBook>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  OverlayEntry? _overlay;
  bool _isSnapping = false;

  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000)); }
  @override
  void dispose() { _overlay?.remove(); _ctrl.dispose(); super.dispose(); }

  void _snapBack(Velocity velocity, Offset cancelOffset) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final origin = box.localToGlobal(Offset.zero);
    final size   = box.size;
    final anim   = Tween<Offset>(begin: cancelOffset, end: origin)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));
    final snap = _SpineBook(book: widget.book, width: widget.width, height: widget.height, index: 1, totalBooks: 3);
    _overlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Positioned(
          left: anim.value.dx, top: anim.value.dy,
          width: size.width, height: size.height,
          child: Material(color: Colors.transparent,
              child: Opacity(opacity: 0.92, child: snap)),
        ),
      ),
    );
    setState(() => _isSnapping = true);
    Overlay.of(context).insert(_overlay!);
    _ctrl.forward(from: 0).then((_) {
      _overlay?.remove(); _overlay = null;
      if (mounted) setState(() => _isSnapping = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final child    = _SpineBook(book: widget.book, width: widget.width, height: widget.height, index: widget.index, totalBooks: widget.totalBooks);
    final feedback = _SpineBook(book: widget.book, width: widget.width, height: widget.height, index: 1, totalBooks: 3);
    return LongPressDraggable<Book>(
      data: widget.book,
      hapticFeedbackOnStart: true,
      delay: const Duration(milliseconds: 350),
      feedback: Material(color: Colors.transparent,
          child: Transform.scale(scale: 1.08, child: Opacity(opacity: 0.92, child: feedback))),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      onDraggableCanceled: _snapBack,
      child: _isSnapping ? Opacity(opacity: 0, child: child) : child,
    );
  }
}

class _SpineBook extends StatelessWidget {
  final Book book;
  final double width, height;
  final int index, totalBooks;
  const _SpineBook({
    required this.book, required this.width, required this.height,
    required this.index, required this.totalBooks,
  });

  double _tiltAngle() {
    final s   = _spineSeed(book.id);
    final raw = ((s % 200) / 100.0) - 1.0;
    double deg = raw * 3.5;
    if (index == 0 && deg < 0) deg = deg.abs();
    if (index == totalBooks - 1 && deg > 0) deg = -deg.abs();
    return deg * math.pi / 180.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = context.watch<AppState>().isDark;
    final authorParts = book.author.length > 8 ? book.author.split(' ') : [book.author];
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ArchivePage(bookId: book.id))),
      child: Transform.rotate(
        angle: _tiltAngle(),
        alignment: Alignment.bottomCenter,
        child: Container(
          width: width, height: height,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: isDark ? DesignTokens.spineGradDark(book.color) : DesignTokens.spineGrad(book.color),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(1), topRight: Radius.circular(1),
              bottomLeft: Radius.circular(2), bottomRight: Radius.circular(2),
            ),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(1, 2))],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 질감 오버레이
              CustomPaint(
                painter: _BookGrainPainter(seed: _spineSeed(book.id), isSpine: true),
              ),
              // 텍스트
              Column(
                children: [
                  Expanded(child: Center(child: RotatedBox(quarterTurns: 1,
                    child: Text(book.title,
                        style: DesignTokens.hahmlet(width >= 24 ? 10 : 9,
                            weight: FontWeight.w600, color: const Color(0xF5FFF7EE)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)))),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(children: authorParts.map((p) =>
                        Text(p, style: DesignTokens.ptSans(6,
                            weight: FontWeight.w700, color: const Color(0xC8FFF7EE)),
                            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)
                    ).toList()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shelf Wrapper ────────────────────────────────────────────────────────────
class _ShelfWrapper extends StatelessWidget {
  final Widget child;
  final bool isHovering, isRejecting;
  final Widget? curationWidget;

  const _ShelfWrapper({
    required this.child,
    this.isHovering = false,
    this.isRejecting = false,
    this.curationWidget,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isRejecting
        ? DesignTokens.terracotta.withValues(alpha: 0.12)
        : isHovering
            ? DesignTokens.sage.withValues(alpha: 0.10)
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: bgColor,
      child: Stack(
        children: [
          Positioned.fill(bottom: 8, child: child),
          if (curationWidget != null) Positioned(top: 8, right: 10, child: curationWidget!),
          if (isRejecting)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DesignTokens.terracotta.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('최상단 책장에 도서는 최대 3권까지 놓을 수 있어요.',
                    style: DesignTokens.hahmlet(10, color: const Color(0xFFFFF7EE))),
              )),
            ),
          Positioned(
            left: 0, right: 0, bottom: 0, height: 8,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [DesignTokens.shelfWood, DesignTokens.shelfWoodDark],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _ReportShelfContent — 리포트 전용 책장 (PageView 마지막 페이지)
// ═══════════════════════════════════════════════════════════════════════════════
class _ReportShelfContent extends StatelessWidget {
  const _ReportShelfContent({required this.reports, required this.isDark});

  final List reports;   // List<ReadingReport>
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isSubscribed = context.watch<AppState>().isSubscribed;

    // 무료 유저: 리포트 책장을 미리보기로 표시하되 열람은 막음
    if (!isSubscribed) {
      return _ShelfWrapper(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined, size: 26,
                  color: const Color(0xFF3B2015).withValues(alpha: 0.35)),
              const SizedBox(height: 10),
              Text('스탠다드 구독 후\nAI 독서 리포트를 받아보세요.',
                  style: DesignTokens.hahmlet(12,
                      color: const Color(0xFF3B2015).withValues(alpha: 0.45))
                      .copyWith(height: 1.65),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (reports.isEmpty) {
      return _ShelfWrapper(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined, size: 26,
                  color: const Color(0xFF3B2015).withValues(alpha: 0.35)),
              const SizedBox(height: 10),
              Text('매월 1일, AI 독서 리포트가\n이곳에 꽂혀요.',
                  style: DesignTokens.hahmlet(12,
                      color: const Color(0xFF3B2015).withValues(alpha: 0.45))
                      .copyWith(height: 1.65),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // 리포트를 4개 슬롯(커버 1 + 책등 3)에 나눠서 표시
    // 커버 칸: 최신 리포트 최대 3권 (표지 크기)
    // 책등 칸: 나머지 리포트들 시간순
    final covers = reports.length <= 3
        ? reports.toList()
        : reports.sublist(reports.length - 3);
    final spines = reports.length > 3
        ? reports.sublist(0, reports.length - 3)
        : [];

    return Stack(
      children: [
        Column(
          children: [
            // 커버 칸
            Expanded(
              child: _ShelfWrapper(
                child: Align(
                  alignment: const Alignment(0, 0.75),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: covers
                        .map<Widget>((r) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 13),
                              child: _ReportBookCover(report: r),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            // 책등 칸 1~3: 순차 배분
            for (int row = 0; row < 3; row++)
              Expanded(
                child: _ShelfWrapper(
                  child: spines.isEmpty
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: 14),
                              ...spines
                                  .asMap()
                                  .entries
                                  .where((e) => e.key % 3 == row)
                                  .map<Widget>((e) => Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: _ReportBookSpine(report: e.value),
                                      )),
                              const SizedBox(width: 14),
                            ],
                          ),
                        ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── 리포트 책 — 표지 (커버 칸) ────────────────────────────────────────────────
class _ReportBookCover extends StatelessWidget {
  const _ReportBookCover({required this.report});
  final dynamic report; // ReadingReport

  static const _r = BorderRadius.only(
    topRight: Radius.circular(4), bottomRight: Radius.circular(4),
    bottomLeft: Radius.circular(1), topLeft: Radius.circular(1),
  );

  @override
  Widget build(BuildContext context) {
    final isUnread = !(report.isRead as bool);
    return GestureDetector(
      onTap: () {
        final state = context.read<AppState>();
        // 리포트 열람은 스탠다드 이상 혜택 (PaywallPage는 하단 슬라이드 전환)
        if (!state.isSubscribed) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const PaywallPage(),
              transitionsBuilder: (_, animation, __, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 350),
            ),
          );
          return;
        }
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReportDetailPage(report: report)));
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 75, height: 117,
            decoration: const BoxDecoration(
              borderRadius: _r,
              boxShadow: [BoxShadow(
                  color: Color(0x40000000), blurRadius: 10, offset: Offset(2, 4))],
            ),
            child: ClipRRect(
              borderRadius: _r,
              child: _ReportCoverPainter(yearMonthCode: report.yearMonthCode as String),
            ),
          ),
          // 읽지 않은 리포트 — 우상단 빨간 점
          if (isUnread)
            Positioned(
              top: -3, right: -3,
              child: Container(
                width: 9, height: 9,
                decoration: const BoxDecoration(
                  color: DesignTokens.terracotta,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 표지 그래픽 — 로그인 페이지 톤앤매너 (다크브라운 + sage + terracotta)
class _ReportCoverPainter extends StatelessWidget {
  const _ReportCoverPainter({required this.yearMonthCode});
  final String yearMonthCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 75, height: 117,
      color: const Color(0xFF3B2015),
      child: Stack(
        children: [
          // 좌측 광택 라인
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 5,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          // 상단 sage 수평선
          Positioned(
            top: 22, left: 10, right: 10,
            child: Container(height: 1.5, color: DesignTokens.sage.withValues(alpha: 0.65)),
          ),
          // 연월 코드 (대형)
          Positioned(
            top: 30, left: 0, right: 0,
            child: Center(
              child: Text(
                yearMonthCode,
                style: DesignTokens.solway(28,
                    color: Colors.white.withValues(alpha: 0.92)),
              ),
            ),
          ),
          // 하단 "Revi" 브랜딩
          Positioned(
            bottom: 22, left: 0, right: 0,
            child: Center(
              child: Text(
                'Revi',
                style: DesignTokens.solway(9,
                    color: DesignTokens.sage.withValues(alpha: 0.75)),
              ),
            ),
          ),
          // 하단 terracotta 언더라인 (로그인 페이지 참조)
          Positioned(
            bottom: 18, left: 20, right: 20,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: DesignTokens.terracotta.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 리포트 책 — 책등 ──────────────────────────────────────────────────────────
class _ReportBookSpine extends StatelessWidget {
  const _ReportBookSpine({required this.report});
  final dynamic report;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final state = context.read<AppState>();
        if (!state.isSubscribed) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const PaywallPage(),
              transitionsBuilder: (_, animation, __, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 350),
            ),
          );
          return;
        }
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReportDetailPage(report: report)));
      },
      child: Container(
        width: 24, height: 168,
        decoration: const BoxDecoration(
          color: Color(0xFF3B2015),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(1), topRight: Radius.circular(1),
            bottomLeft: Radius.circular(2), bottomRight: Radius.circular(2),
          ),
          boxShadow: [BoxShadow(
              color: Color(0x40000000), blurRadius: 4, offset: Offset(1, 2))],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 좌측 광택
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                  width: 4,
                  color: Colors.white.withValues(alpha: 0.07)),
            ),
            // 연월 코드 (세로)
            Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  report.yearMonthCode as String,
                  style: DesignTokens.solway(10,
                      color: Colors.white.withValues(alpha: 0.85)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 하단 sage 점
            Positioned(
              bottom: 7, left: 0, right: 0,
              child: Center(
                child: Container(
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color: DesignTokens.sage.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _ReportBannerOverlay — iOS 스타일 인앱 배너 알림
// ═══════════════════════════════════════════════════════════════════════════════
class _ReportBannerOverlay extends StatefulWidget {
  const _ReportBannerOverlay({
    required this.report,
    required this.onTap,
    required this.onDismiss,
  });
  final dynamic report;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_ReportBannerOverlay> createState() => _ReportBannerOverlayState();
}

class _ReportBannerOverlayState extends State<_ReportBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    // 5초 후 자동 닫힘
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 10,
      left: 16, right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -100) _dismiss();
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B2015),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x50000000), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  // 미니 표지 썸네일
                  Container(
                    width: 36, height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A3520),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        widget.report.yearMonthCode as String,
                        style: DesignTokens.solway(11, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${widget.report.labelKo} 독서 리포트 완성',
                            style: DesignTokens.hahmlet(13,
                                weight: FontWeight.w600,
                                color: Colors.white)),
                        const SizedBox(height: 3),
                        Text('이달의 독서 기록이 책장에 꽂혔어요.',
                            style: DesignTokens.hahmlet(11,
                                color: Colors.white.withValues(alpha: 0.65))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(Icons.close, size: 16,
                        color: Colors.white.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logout Confirm Dialog ────────────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _LogoutDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return Dialog(
      backgroundColor: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('정말 로그아웃 하시겠어요?',
                style: DesignTokens.hahmlet(16, weight: FontWeight.w600,
                    color: isDark ? DesignTokens.inkDark : DesignTokens.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('다시 돌아오실 때까지, 모아둔 문장은 그 자리에 있을게요.',
                style: DesignTokens.hahmlet(13,
                    color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('취소', style: DesignTokens.hahmlet(13,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); onConfirm(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? DesignTokens.inkDark : DesignTokens.ink,
                      foregroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text('로그아웃', style: DesignTokens.hahmlet(13,
                        weight: FontWeight.w600,
                        color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
