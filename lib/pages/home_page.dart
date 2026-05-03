import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/book.dart';
import '../providers/app_state.dart';
import 'scan_page.dart';
import 'archive_page.dart';
import 'quotes_page.dart';
import 'settings_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _leftCtrl;
  late AnimationController _rightCtrl;
  late Animation<double> _leftAnim;
  late Animation<double> _rightAnim;

  @override
  void initState() {
    super.initState();
    _leftCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _rightCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _leftAnim  = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: _leftCtrl,  curve: Curves.easeInOut));
    _rightAnim = Tween<double>(begin: 0, end:  6).animate(CurvedAnimation(parent: _rightCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _LogoutDialog(onConfirm: () {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final books = state.books;
    final covers = books.where((b) => b.shelf == 0).toList();

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -300) {
          // left → Scan
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage()));
        } else if (d.primaryVelocity! > 300) {
          // right → Logout confirm
          _showLogoutConfirm();
        }
      },
      child: Scaffold(
        backgroundColor: DesignTokens.bgIvory,
        body: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildShelves(books, covers)),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchPage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: DesignTokens.bgIvoryDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DesignTokens.rule),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16, color: DesignTokens.inkMute),
                      const SizedBox(width: 8),
                      Text('책 또는 문장을 찾아요', style: DesignTokens.hahmlet(13, color: DesignTokens.inkFaint)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: DesignTokens.bgIvory,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined, size: 20, color: DesignTokens.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelves(List<Book> books, List<Book> covers) {
    return Column(
      children: [
        // Shelf 0 — covers
        Expanded(child: _CoverShelf(books: covers)),
        // Shelves 1–3 — spines
        for (int i = 1; i <= 3; i++)
          Expanded(child: _SpineShelf(books: books.where((b) => b.shelf == i).toList())),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.bgIvory,
        border: Border(top: BorderSide(color: DesignTokens.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ← Log-out
              GestureDetector(
                onTap: _showLogoutConfirm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _leftAnim,
                      builder: (_, child) => Transform.translate(offset: Offset(_leftAnim.value, 0), child: child),
                      child: Text('←', style: DesignTokens.ptSans(14, color: DesignTokens.inkSoft)),
                    ),
                    const SizedBox(width: 6),
                    Text('Log-out', style: DesignTokens.solway(13, color: DesignTokens.inkSoft)),
                  ],
                ),
              ),
              // 모아둔 문장 (중앙)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotesPage())),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_outline, size: 18, color: DesignTokens.inkSoft),
                    const SizedBox(height: 2),
                    Text('문장', style: DesignTokens.ptSans(9, color: DesignTokens.inkMute)
                        .copyWith(letterSpacing: 1.2)),
                  ],
                ),
              ),
              // Scan →
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage())),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Scan', style: DesignTokens.solway(13, color: DesignTokens.inkSoft)),
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: _rightAnim,
                      builder: (_, child) => Transform.translate(offset: Offset(_rightAnim.value, 0), child: child),
                      child: Text('→', style: DesignTokens.ptSans(14, color: DesignTokens.inkSoft)),
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

// ─── Cover Shelf ───────────────────────────────────────────────────────────────
class _CoverShelf extends StatelessWidget {
  final List<Book> books;
  const _CoverShelf({required this.books});

  @override
  Widget build(BuildContext context) {
    return _ShelfWrapper(
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: books.map((b) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: _CoverBook(book: b),
          )).toList(),
        ),
      ),
    );
  }
}

class _CoverBook extends StatelessWidget {
  final Book book;
  const _CoverBook({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivePage(bookId: book.id))),
      child: Container(
        width: 62, height: 96,
        decoration: BoxDecoration(
          gradient: DesignTokens.coverGrad(book.color),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4), bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(1), topLeft: Radius.circular(1),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(2, 4)),
          ],
        ),
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NO.${book.id.replaceAll('b', '').padLeft(2, '0')}',
                style: DesignTokens.ptSans(7, color: const Color(0xBFFFFFFF), weight: FontWeight.w700)),
            const Spacer(),
            Text(book.title,
                style: DesignTokens.hahmlet(10, weight: FontWeight.w600, color: const Color(0xFFFFF7EE)),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(book.author.split(' ').last,
                style: DesignTokens.ptSans(7, color: const Color(0xCCFFF7EE))),
          ],
        ),
      ),
    );
  }
}

// ─── Spine Shelf ──────────────────────────────────────────────────────────────
class _SpineShelf extends StatelessWidget {
  final List<Book> books;
  const _SpineShelf({required this.books});

  static int _seed(String id) {
    int h = 0;
    for (final c in id.codeUnits) { h = (h * 31 + c) & 0x7FFFFFFF; }
    return h;
  }

  static const _spineWidths  = [22, 28, 18, 32, 24, 20, 30];
  static const _spineHeights = [180, 168, 196, 156, 188, 172, 162];

  @override
  Widget build(BuildContext context) {
    return _ShelfWrapper(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 14),
            ...books.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              final s = _seed(b.id);
              final w = _spineWidths[s % _spineWidths.length].toDouble();
              final h = _spineHeights[s % _spineHeights.length].toDouble();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _SpineBook(
                  book: b, width: w, height: h,
                  index: i, totalBooks: books.length,
                ),
              );
            }),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _SpineBook extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final int index;
  final int totalBooks;
  const _SpineBook({
    required this.book,
    required this.width,
    required this.height,
    required this.index,
    required this.totalBooks,
  });

  double _tiltAngle() {
    final s = _SpineShelf._seed(book.id);
    // -1.0 ~ 1.0 사이 값
    final raw = ((s % 200) / 100.0) - 1.0;
    // 최대 3.5도
    double deg = raw * 3.5;

    // 맨 왼쪽 책: 상단이 왼쪽(여백) 방향으로 기울면 안 됨 → 양수(오른쪽 기울기)만 허용
    if (index == 0 && deg < 0) deg = deg.abs();
    // 맨 오른쪽 책: 상단이 오른쪽(여백) 방향으로 기울면 안 됨 → 음수(왼쪽 기울기)만 허용
    if (index == totalBooks - 1 && deg > 0) deg = -deg.abs();

    return deg * math.pi / 180.0;
  }

  @override
  Widget build(BuildContext context) {
    final authorParts = book.author.length > 8 ? book.author.split(' ') : [book.author];
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivePage(bookId: book.id))),
      child: Transform.rotate(
        angle: _tiltAngle(),
        alignment: Alignment.bottomCenter,
        child: Container(
        width: width, height: height,
        decoration: BoxDecoration(
          gradient: DesignTokens.spineGrad(book.color),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(1), topRight: Radius.circular(1),
            bottomLeft: Radius.circular(2), bottomRight: Radius.circular(2),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(1, 2)),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3, // bottom-to-top reading
                  child: Text(
                    book.title,
                    style: DesignTokens.hahmlet(width >= 24 ? 10 : 9,
                        weight: FontWeight.w600, color: const Color(0xF5FFF7EE)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                children: authorParts.map((p) => Text(
                  p,
                  style: DesignTokens.ptSans(6, weight: FontWeight.w700, color: const Color(0xC8FFF7EE)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )).toList(),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Shelf Wrapper (with plank) ────────────────────────────────────────────────
class _ShelfWrapper extends StatelessWidget {
  final Widget child;
  const _ShelfWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(bottom: 8, child: child),
        Positioned(
          left: 0, right: 0, bottom: 0, height: 8,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [DesignTokens.shelfWood, DesignTokens.shelfWoodDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Logout Confirm Dialog ──────────────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _LogoutDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DesignTokens.bgIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('정말 로그아웃 하시겠어요?', style: DesignTokens.hahmlet(16, weight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('다시 돌아오실 때까지, 모아둔 문장은 그 자리에 있을게요.',
                style: DesignTokens.hahmlet(13, color: DesignTokens.inkMute), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: DesignTokens.ruleStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('취소', style: DesignTokens.hahmlet(13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.ink,
                      foregroundColor: DesignTokens.bgIvory,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text('로그아웃', style: DesignTokens.hahmlet(13, weight: FontWeight.w600, color: DesignTokens.bgIvory)),
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
