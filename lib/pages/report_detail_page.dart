import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/reading_report.dart';
import '../providers/app_state.dart';
import 'archive_page.dart';

/// AI 독서 리포트 상세 페이지
///
/// "독서 데이터실 월간 사보" — 사내 기록물을 펼쳐보는 편집 레이아웃.
class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({super.key, required this.report});

  final ReadingReport report;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final bg = isDark ? DesignTokens.bgDark : const Color(0xFFFAF7F2);

    // 읽음 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!report.isRead) context.read<AppState>().markReportRead(report.id);
    });

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            _TopBar(isDark: isDark),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 마스트헤드 ─────────────────────────────────────────
                      _Masthead(report: report, isDark: isDark),
                      _Rule(isDark: isDark),

                      // ── 이달의 숫자 ───────────────────────────────────────
                      _SectionLabel(text: '이달의 숫자', isDark: isDark),
                      const SizedBox(height: 14),
                      _NumbersRow(report: report, isDark: isDark),
                      const SizedBox(height: 24),
                      _Rule(isDark: isDark),

                      // ── 이달의 책 (있을 때만) ─────────────────────────────
                      if (report.topBookTitle.isNotEmpty) ...[
                        _SectionLabel(text: '이달의 책', isDark: isDark),
                        const SizedBox(height: 12),
                        _FeaturedBook(
                          title: report.topBookTitle,
                          isDark: isDark,
                          bookId: state.books
                              .where((b) => b.title == report.topBookTitle)
                              .map((b) => b.id)
                              .firstOrNull,
                        ),
                        const SizedBox(height: 24),
                        _Rule(isDark: isDark),
                      ],

                      // ── 문장 분포 ─────────────────────────────────────────
                      if (report.quotesBySlot.isNotEmpty) ...[
                        _SectionLabel(text: '문장 분포', isDark: isDark),
                        const SizedBox(height: 12),
                        _SlotChart(
                            quotesBySlot: report.quotesBySlot,
                            state: state,
                            isDark: isDark),
                        const SizedBox(height: 24),
                        _Rule(isDark: isDark),
                      ],

                      // ── Revi's Note ───────────────────────────────────────
                      const SizedBox(height: 20),
                      _ReviNote(comment: report.aiComment, isDark: isDark),
                      const SizedBox(height: 32),

                      // ── 발행 정보 ─────────────────────────────────────────
                      _IssueInfo(report: report, isDark: isDark),
                    ],
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

// ── 상단 바 ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mute = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('← 독서 데이터실',
                  style: DesignTokens.hahmlet(13, color: mute)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 마스트헤드 ────────────────────────────────────────────────────────────────
class _Masthead extends StatelessWidget {
  const _Masthead({required this.report, required this.isDark});
  final ReadingReport report;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? DesignTokens.inkDark : const Color(0xFF1A1209);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 레이블
          Row(
            children: [
              Text(
                'REVI REPORT',
                style: DesignTokens.ptSans(9,
                        weight: FontWeight.w700,
                        color: isDark
                            ? DesignTokens.inkDarkMute
                            : const Color(0xFF3B2015))
                    .copyWith(letterSpacing: 2.5),
              ),
              const Spacer(),
              Text(
                report.labelKo,
                style: DesignTokens.ptSans(9,
                        color: isDark
                            ? DesignTokens.inkDarkMute
                            : const Color(0xFF7A6555))
                    .copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 메인 타이틀
          Text(
            '독서 데이터실\n월간 기록',
            style: DesignTokens.hahmlet(32,
                    weight: FontWeight.w700, color: ink)
                .copyWith(height: 1.15, letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          // 부제
          Text(
            '${report.year}년 ${report.month}월의 독서 여정을 기록합니다.',
            style: DesignTokens.hahmlet(12,
                    color: isDark
                        ? DesignTokens.inkDarkMute
                        : const Color(0xFF7A6555))
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── 섹션 라벨 ─────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 0),
      child: Text(
        text,
        style: DesignTokens.ptSans(9,
                weight: FontWeight.w700,
                color: isDark
                    ? DesignTokens.inkDarkMute
                    : const Color(0xFF3B2015))
            .copyWith(letterSpacing: 2.0),
      ),
    );
  }
}

// ── 수평 구분선 ───────────────────────────────────────────────────────────────
class _Rule extends StatelessWidget {
  const _Rule({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: isDark
          ? const Color(0xFF3B2015).withValues(alpha: 0.25)
          : const Color(0xFF3B2015).withValues(alpha: 0.12),
    );
  }
}

// ── 이달의 숫자 ───────────────────────────────────────────────────────────────
class _NumbersRow extends StatelessWidget {
  const _NumbersRow({required this.report, required this.isDark});
  final ReadingReport report;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink  = isDark ? DesignTokens.inkDark : const Color(0xFF1A1209);
    final mute = isDark ? DesignTokens.inkDarkMute : const Color(0xFF7A6555);

    return Row(
      children: [
        _StatBlock(
            number: '${report.booksAdded}',
            unit: '권',
            label: '읽은 책',
            ink: ink,
            mute: mute),
        _VerticalDivider(isDark: isDark),
        _StatBlock(
            number: '${report.quotesAdded}',
            unit: '개',
            label: '저장한 문장',
            ink: ink,
            mute: mute),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.number,
    required this.unit,
    required this.label,
    required this.ink,
    required this.mute,
  });
  final String number, unit, label;
  final Color ink, mute;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(number,
                  style: DesignTokens.solway(42, color: ink)),
              const SizedBox(width: 3),
              Text(unit,
                  style: DesignTokens.hahmlet(14, color: mute)),
            ],
          ),
          Text(label,
              style: DesignTokens.ptSans(10, color: mute)
                  .copyWith(letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark
          ? const Color(0xFF3B2015).withValues(alpha: 0.3)
          : const Color(0xFF3B2015).withValues(alpha: 0.15),
    );
  }
}

// ── 이달의 책 ─────────────────────────────────────────────────────────────────
class _FeaturedBook extends StatelessWidget {
  const _FeaturedBook({
    required this.title,
    required this.isDark,
    this.bookId,
  });
  final String title;
  final bool isDark;
  final String? bookId;

  @override
  Widget build(BuildContext context) {
    final canNavigate = bookId != null;
    return GestureDetector(
      onTap: canNavigate
          ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ArchivePage(bookId: bookId!)))
          : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF3B2015).withValues(alpha: isDark ? 0.15 : 0.06),
          border: Border.all(
              color: const Color(0xFF3B2015).withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 책등 느낌 수직 바
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF3B2015).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('가장 많이 담은 책',
                      style: DesignTokens.ptSans(9,
                              color: isDark
                                  ? DesignTokens.inkDarkMute
                                  : const Color(0xFF7A6555))
                          .copyWith(letterSpacing: 1.2)),
                  const SizedBox(height: 5),
                  Text(title,
                      style: DesignTokens.hahmlet(18,
                          weight: FontWeight.w600,
                          color: isDark
                              ? DesignTokens.inkDark
                              : const Color(0xFF1A1209))),
                ],
              ),
            ),
            if (canNavigate) ...[
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios,
                  size: 12,
                  color: const Color(0xFF3B2015).withValues(alpha: 0.4)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 문장 분포 ─────────────────────────────────────────────────────────────────
class _SlotChart extends StatelessWidget {
  const _SlotChart({
    required this.quotesBySlot,
    required this.state,
    required this.isDark,
  });
  final Map<String, int> quotesBySlot;
  final AppState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final total = quotesBySlot.values.fold(0, (a, b) => a + b);
    final mute  = isDark ? DesignTokens.inkDarkMute : const Color(0xFF7A6555);

    return Column(
      children: quotesBySlot.entries.map((e) {
        final ratio = total == 0 ? 0.0 : e.value / total;
        final color = state.slotColor(e.key);
        final pct   = (ratio * 100).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 슬롯 색상 점
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              // 슬롯 이름
              SizedBox(
                width: 52,
                child: Text(e.key,
                    style: DesignTokens.hahmlet(12, color: mute)),
              ),
              // 바
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 2,
                        color: color.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(height: 2, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 퍼센트 + 개수
              SizedBox(
                width: 52,
                child: Text('$pct%  ·  ${e.value}개',
                    style: DesignTokens.ptSans(9, color: mute)
                        .copyWith(letterSpacing: 0.5),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Revi's Note ───────────────────────────────────────────────────────────────
class _ReviNote extends StatelessWidget {
  const _ReviNote({required this.comment, required this.isDark});
  final String comment;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF3B2015),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('R',
                    style: TextStyle(
                      fontFamily: 'Solway',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(width: 8),
            Text("Revi's Note",
                style: DesignTokens.ptSans(10,
                        weight: FontWeight.w700,
                        color: const Color(0xFF3B2015))
                    .copyWith(letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 14),
        // 사서 코멘트 본문
        Text(
          '"$comment"',
          style: DesignTokens.hahmlet(15,
                  color: isDark
                      ? DesignTokens.inkDark
                      : const Color(0xFF2A1A0A))
              .copyWith(
            height: 1.85,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        // 서명
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '— 사서 Revi',
            style: DesignTokens.ptSans(10,
                    color: const Color(0xFF3B2015).withValues(alpha: 0.6))
                .copyWith(letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }
}

// ── 발행 정보 ─────────────────────────────────────────────────────────────────
class _IssueInfo extends StatelessWidget {
  const _IssueInfo({required this.report, required this.isDark});
  final ReadingReport report;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final faint = isDark
        ? DesignTokens.inkDarkFaint
        : const Color(0xFF3B2015).withValues(alpha: 0.3);
    return Column(
      children: [
        Container(height: 1, color: faint),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '독서 데이터실 월간 사보',
              style: DesignTokens.ptSans(8, color: faint)
                  .copyWith(letterSpacing: 1.2),
            ),
            Text(
              '${report.year}.${report.month.toString().padLeft(2, '0')}.01',
              style: DesignTokens.ptSans(8, color: faint)
                  .copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
      ],
    );
  }
}
