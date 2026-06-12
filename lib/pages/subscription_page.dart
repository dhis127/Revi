import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../config/design_tokens.dart';
import '../models/subscription_model.dart';
import '../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionPage — Phase 1 (UI-only, 로컬 상태)
// Phase 3에서 in_app_purchase + Supabase 연결 예정
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  late SubscriptionTier _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final plan = context.read<AppState>().subscriptionTier;
    // 현재 구독 중이면 그대로, 미구독이면 연간 기본 선택
    _selected = plan == SubscriptionTier.free
        ? SubscriptionTier.standardAnnual
        : plan;
  }

  // 차액 업그레이드 금액 계산 (Phase 1: 183일 남은 것으로 mock)
  String _proratedNote(AppState state) {
    if (_selected != SubscriptionTier.premiumAnnual) return '';
    if (state.subscriptionTier == SubscriptionTier.standardAnnual) {
      const remaining = 183; // Phase 3에서 실제 남은 일수로 교체
      const diff = (AppConfig.premAnnualKrw / AppConfig.annualDays
                  - AppConfig.stdAnnualKrw / AppConfig.annualDays) * remaining;
      return '남은 기간 차액 약 ₩${AppConfig.krwFormat(diff.round())}만 추가 결제';
    }
    if (state.subscriptionTier == SubscriptionTier.standardMonthly) {
      return '연간 구독 ₩${AppConfig.krwFormat(AppConfig.premAnnualKrw)} 결제 (월간 해지 후 전환)';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final isCurrentPlan = _selected == state.subscriptionTier;

    // CTA 문구 결정
    late final String ctaLabel;
    late final bool ctaEnabled;

    if (isCurrentPlan) {
      ctaLabel = '현재 구독 중';
      ctaEnabled = false;
    } else if (_selected == SubscriptionTier.premiumAnnual && state.isStandard) {
      ctaLabel = '프리미엄으로 업그레이드';
      ctaEnabled = true;
    } else if (state.isSubscribed) {
      ctaLabel = '플랜 변경하기';
      ctaEnabled = true;
    } else {
      ctaLabel = '시작하기';
      ctaEnabled = true;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
        body: SafeArea(
          child: Column(
            children: [
              // ── 헤더 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        // 설정 외 여러 경로(홈·페이월 등)에서 진입하므로 중립 표기
                        child: Text('← 뒤로',
                            style: DesignTokens.hahmlet(13,
                                color: isDark
                                    ? DesignTokens.inkDarkMute
                                    : DesignTokens.inkMute)),
                      ),
                    ),
                    const Spacer(),
                    Text('PLAN',
                        style: DesignTokens.ptSans(10,
                                weight: FontWeight.w700,
                                color: isDark
                                    ? DesignTokens.inkDarkMute
                                    : DesignTokens.inkMute)
                            .copyWith(letterSpacing: 1.5)),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              // ── 본문 ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 타이틀
                      Text('구독 플랜',
                          style: DesignTokens.hahmlet(26,
                                  weight: FontWeight.w600,
                                  color: isDark
                                      ? DesignTokens.inkDark
                                      : DesignTokens.ink)
                              .copyWith(letterSpacing: -0.3)),
                      const SizedBox(height: 5),
                      Text('언제든 해지 가능 · App Store 결제',
                          style: DesignTokens.ptSans(12,
                                  color: isDark
                                      ? DesignTokens.inkDarkMute
                                      : DesignTokens.inkMute)
                              .copyWith(letterSpacing: 0.2)),
                      const SizedBox(height: 22),

                      // ── 플랜 카드 ──
                      _sectionLabel('PLAN 선택', isDark),
                      const SizedBox(height: 10),

                      _PlanCard(
                        plan: SubscriptionTier.standardMonthly,
                        selected: _selected,
                        currentPlan: state.subscriptionTier,
                        isDark: isDark,
                        locked: false,
                        title: 'STANDARD MONTHLY',
                        price: AppConfig.stdMonthlyLabel,
                        priceSub: '/ 월',
                        highlight: '매월 자동 갱신',
                        badges: const [],
                        onTap: () =>
                            setState(() => _selected = SubscriptionTier.standardMonthly),
                      ),
                      const SizedBox(height: 8),

                      _PlanCard(
                        plan: SubscriptionTier.standardAnnual,
                        selected: _selected,
                        currentPlan: state.subscriptionTier,
                        isDark: isDark,
                        locked: false,
                        title: 'STANDARD ANNUAL',
                        price: AppConfig.stdAnnualLabel,
                        priceSub: '/ 년',
                        highlight: AppConfig.stdAnnualSubtitle,
                        badges: const ['BEST'],
                        onTap: () =>
                            setState(() => _selected = SubscriptionTier.standardAnnual),
                      ),
                      const SizedBox(height: 8),

                      _PlanCard(
                        plan: SubscriptionTier.premiumAnnual,
                        selected: _selected,
                        currentPlan: state.subscriptionTier,
                        isDark: isDark,
                        locked: false,
                        title: 'PREMIUM ANNUAL',
                        price: AppConfig.premAnnualLabel,
                        priceSub: '/ 년',
                        highlight: AppConfig.premAnnualSubtitle,
                        badges: const ['PREMIUM'],
                        onTap: () => setState(
                            () => _selected = SubscriptionTier.premiumAnnual),
                      ),

                      const SizedBox(height: 26),

                      // ── 기능 비교 ──
                      _sectionLabel('PLAN 비교', isDark),
                      const SizedBox(height: 12),

                      _FeatureTable(
                        isDark: isDark,
                        rows: [
                          _FRow('가격',          free: '무료',    std: '${AppConfig.stdMonthlyLabel}~', prem: AppConfig.premAnnualLabel),
                          const _FRow('책 저장',        free: '${AppConfig.freeMaxBooks}권',  std: '${AppConfig.stdMaxBooks}권',  prem: '무제한'),
                          const _FRow('문장 저장',      free: '${AppConfig.freeMaxHighlights}개', std: '무제한', prem: '무제한'),
                          const _FRow('책장 슬롯',      free: '${AppConfig.freeMaxShelves}개', std: '${AppConfig.stdMaxShelves}개', prem: '무제한'),
                          const _FRow('OCR 스캔',       free: '가능',    std: '무제한',    prem: '무제한'),
                          const _FRow('하이라이트 색상',  free: '${AppConfig.freeMaxSlots}가지', std: '${AppConfig.stdMaxSlots}가지', prem: '${AppConfig.premMaxSlots}슬롯·컬러피커'),
                          const _FRow('문장 아카이빙',   free: '텍스트형', std: '텍스트형',  prem: '텍스트형·카드형'),
                          const _FRow('AI 독서 리포트',  free: '—',      std: '기본',      prem: '심층'),
                          const _FRow('데이터 내보내기', free: '—',       std: 'CSV',      prem: 'CSV·PDF·MD'),
                          const _FRow('화면 모드',       free: '1종',    std: '3종',       prem: '4종·강도 조절'),
                          const _FRow('메모 폰트',       free: '${AppConfig.freeMaxFonts}종', std: '${AppConfig.stdMaxFonts}종', prem: '${AppConfig.premMaxFonts}종'),
                          const _FRow('위치·날씨 태깅',  free: '—',      std: '—',         prem: '✓'),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Cq. 북바 할인 안내
                      _CqMemberBanner(isDark: isDark),

                      const SizedBox(height: 12),

                      // 약관 안내
                      Center(
                        child: Text(
                          'App Store 결제 · 언제든 취소 가능\n구독 기간 만료 24시간 전 자동 갱신',
                          textAlign: TextAlign.center,
                          style: DesignTokens.ptSans(10,
                                  color: isDark
                                      ? DesignTokens.inkDarkFaint
                                      : DesignTokens.inkFaint)
                              .copyWith(height: 1.6, letterSpacing: 0.1),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // ── 하단 고정 CTA ──
              _CtaSection(
                ctaLabel: ctaLabel,
                ctaEnabled: ctaEnabled,
                loading: _loading,
                isDark: isDark,
                proratedNote: _proratedNote(state),
                isCurrentPlan: isCurrentPlan,
                showCancel: state.isSubscribed && !isCurrentPlan,
                onSubscribe: _handleSubscribe,
                onCancel: _handleCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) => Text(
        label,
        style: DesignTokens.ptSans(10,
                weight: FontWeight.w700,
                color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
            .copyWith(letterSpacing: 1.5),
      );

  Future<void> _handleSubscribe() async {
    setState(() => _loading = true);
    // Phase 3에서 in_app_purchase 결제 플로우로 교체
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.read<AppState>().subscribe(_selected);
    setState(() => _loading = false);
    if (mounted) _showSuccessSheet(context, _selected);
  }

  Future<void> _handleCancel() async {
    final confirmed = await _showCancelDialog(context);
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    context.read<AppState>().cancelSubscription();
    setState(() => _loading = false);
    if (mounted) Navigator.pop(context);
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final SubscriptionTier plan;
  final SubscriptionTier selected;
  final SubscriptionTier currentPlan;
  final bool isDark;
  final bool locked;
  final String title;
  final String price;
  final String priceSub;
  final String highlight;
  final List<String> badges;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.currentPlan,
    required this.isDark,
    required this.locked,
    required this.title,
    required this.price,
    required this.priceSub,
    required this.highlight,
    required this.badges,
    required this.onTap,
  });

  bool get _isSelected => plan == selected && !locked;
  bool get _isCurrent => plan == currentPlan;
  bool get _isPrem => plan == SubscriptionTier.premiumAnnual;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep;
    final selectedBg = isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge;

    // 프리미엄 카드 색상 — 앰버/월넛 톤
    final premBg = isDark
        ? const Color(0xFF3D2C18)
        : const Color(0xFFF5E8D0);
    final premSelectedBg = isDark
        ? const Color(0xFF4F3820)
        : const Color(0xFFEDD9B0);
    final premBorder = isDark
        ? const Color(0xFF7A5A30)
        : const Color(0xFFC8A060);

    final borderColor = _isPrem
        ? (_isSelected ? premBorder : (isDark ? const Color(0xFF5A4228) : const Color(0xFFDEC098)))
        : (_isSelected
            ? DesignTokens.terracotta
            : (isDark ? DesignTokens.ruleDark : DesignTokens.rule));

    final bgColor = locked
        ? (isDark ? DesignTokens.bgDark : DesignTokens.bgIvory)
        : (_isPrem
            ? (_isSelected ? premSelectedBg : premBg)
            : (_isSelected ? selectedBg : cardBg));

    final inkColor = locked
        ? (isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
        : (isDark ? DesignTokens.inkDark : DesignTokens.ink);
    final muteColor = locked
        ? (isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
        : (isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor,
            width: _isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Opacity(
          opacity: locked ? 0.55 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 라디오 버튼
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: locked
                          ? (isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
                          : (_isSelected
                              ? (_isPrem ? DesignTokens.amber : DesignTokens.terracotta)
                              : (isDark ? DesignTokens.inkDarkMute : DesignTokens.inkFaint)),
                      width: _isSelected ? 5 : 1.5,
                    ),
                    color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 플랜명 + 뱃지
                    Row(
                      children: [
                        Text(title,
                            style: DesignTokens.ptSans(10,
                                    weight: FontWeight.w700, color: inkColor)
                                .copyWith(letterSpacing: 0.8)),
                        ...badges.map((b) => _Badge(label: b, isPrem: _isPrem)),
                        if (_isCurrent)
                          const _Badge(label: '현재', isPrem: false, isActive: true),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // 가격
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(price,
                            style: DesignTokens.hahmlet(18,
                                weight: FontWeight.w600, color: inkColor)),
                        const SizedBox(width: 2),
                        Text(priceSub,
                            style: DesignTokens.ptSans(11, color: muteColor)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // 하이라이트
                    Text(highlight,
                        style: DesignTokens.ptSans(11, color: muteColor)
                            .copyWith(height: 1.4)),
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

class _Badge extends StatelessWidget {
  final String label;
  final bool isPrem;
  final bool isActive;
  const _Badge({required this.label, required this.isPrem, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? DesignTokens.sage
        : (isPrem ? DesignTokens.amber : DesignTokens.terracotta);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: DesignTokens.ptSans(7,
                  weight: FontWeight.w700, color: DesignTokens.bgIvory)
              .copyWith(letterSpacing: 0.7)),
    );
  }
}

// ─── Feature Comparison (3-column: Free / Standard / Premium) ────────────────

class _FRow {
  final String name;
  final String free;
  final String std;
  final String prem;
  const _FRow(this.name,
      {required this.free, required this.std, required this.prem});
}

class _FeatureTable extends StatelessWidget {
  final bool isDark;
  final List<_FRow> rows;
  const _FeatureTable({required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? DesignTokens.bgDarkDeep  : DesignTokens.bgIvoryDeep;
    final border = isDark ? DesignTokens.ruleDark    : DesignTokens.rule;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── 컬럼 헤더 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border))),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                _headerCell('FREE',     color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
                _headerCell('STD',      color: DesignTokens.terracotta),
                _headerCell('PREMIUM',  color: DesignTokens.amber),
              ],
            ),
          ),
          // ── 데이터 행 ──
          ...rows.asMap().entries.map((e) => _TableRow(
                row: e.value,
                isDark: isDark,
                last: e.key == rows.length - 1,
                border: border,
              )),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required Color color}) => SizedBox(
        width: 62,
        child: Text(label,
            textAlign: TextAlign.center,
            style: DesignTokens.ptSans(8, weight: FontWeight.w700, color: color)
                .copyWith(letterSpacing: 0.8)),
      );
}

class _TableRow extends StatelessWidget {
  final _FRow row;
  final bool isDark;
  final bool last;
  final Color border;
  const _TableRow(
      {required this.row,
      required this.isDark,
      required this.last,
      required this.border});

  Color _valueColor(String val, Color accent) {
    if (val == '—') return isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    if (val == '무제한' || val == '✓') return accent;
    return isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
  }

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? DesignTokens.inkDark : DesignTokens.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: border))),
      child: Row(
        children: [
          Expanded(
              child: Text(row.name,
                  style: DesignTokens.hahmlet(12, color: ink))),
          SizedBox(
            width: 62,
            child: Text(row.free,
                textAlign: TextAlign.center,
                style: DesignTokens.ptSans(10,
                        color: _valueColor(row.free,
                            isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute))
                    .copyWith(letterSpacing: 0.1)),
          ),
          SizedBox(
            width: 62,
            child: Text(row.std,
                textAlign: TextAlign.center,
                style: DesignTokens.ptSans(10,
                        weight: FontWeight.w600,
                        color: _valueColor(row.std, DesignTokens.terracotta))
                    .copyWith(letterSpacing: 0.1)),
          ),
          SizedBox(
            width: 62,
            child: Text(row.prem,
                textAlign: TextAlign.center,
                style: DesignTokens.ptSans(10,
                        weight: FontWeight.w700,
                        color: _valueColor(row.prem, DesignTokens.amber))
                    .copyWith(letterSpacing: 0.1)),
          ),
        ],
      ),
    );
  }
}

// ─── Cq. 북바 멤버 할인 배너 ──────────────────────────────────────────────────
class _CqMemberBanner extends StatelessWidget {
  final bool isDark;
  const _CqMemberBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep;
    final border = isDark ? DesignTokens.ruleDark : DesignTokens.rule;
    final ink = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cq. 북바 멤버 할인',
                  style: DesignTokens.ptSans(10,
                          weight: FontWeight.w700, color: ink)
                      .copyWith(letterSpacing: 0.8)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: DesignTokens.walnut,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('쿠폰 코드',
                    style: DesignTokens.ptSans(7,
                            weight: FontWeight.w700,
                            color: DesignTokens.bgIvory)
                        .copyWith(letterSpacing: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _cqRow('Traveler 멤버',     AppConfig.cqTravelerRow,    mute),
          const SizedBox(height: 4),
          _cqRow('Bookdrunker 멤버', AppConfig.cqBookdrunkerRow, mute),
        ],
      ),
    );
  }

  Widget _cqRow(String tier, String desc, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ',
              style: DesignTokens.ptSans(11, color: color)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DesignTokens.ptSans(11, color: color)
                    .copyWith(height: 1.5),
                children: [
                  TextSpan(
                      text: '$tier  ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      );
}

// ─── CTA 섹션 ─────────────────────────────────────────────────────────────────
class _CtaSection extends StatelessWidget {
  final String ctaLabel;
  final bool ctaEnabled;
  final bool loading;
  final bool isDark;
  final String proratedNote;
  final bool isCurrentPlan;
  final bool showCancel;
  final VoidCallback onSubscribe;
  final VoidCallback onCancel;

  const _CtaSection({
    required this.ctaLabel,
    required this.ctaEnabled,
    required this.loading,
    required this.isDark,
    required this.proratedNote,
    required this.isCurrentPlan,
    required this.showCancel,
    required this.onSubscribe,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? DesignTokens.bgDark : DesignTokens.bgIvory;
    final border = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 차액 안내 (스탠다드 연간 → 프리미엄 업그레이드)
          if (proratedNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(proratedNote,
                  textAlign: TextAlign.center,
                  style: DesignTokens.ptSans(11,
                          color: isDark
                              ? DesignTokens.inkDarkMute
                              : DesignTokens.inkMute)
                      .copyWith(letterSpacing: 0.1)),
            ),

          // 메인 CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (loading || !ctaEnabled) ? null : onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.terracotta,
                foregroundColor: DesignTokens.bgIvory,
                disabledBackgroundColor:
                    isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DesignTokens.bgIvory),
                    )
                  : Text(ctaLabel,
                      style: DesignTokens.hahmlet(15,
                          weight: FontWeight.w600,
                          color: ctaEnabled
                              ? DesignTokens.bgIvory
                              : (isDark
                                  ? DesignTokens.inkDarkMute
                                  : DesignTokens.inkMute))),
            ),
          ),

          // 구독 취소 링크
          if (showCancel)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: onCancel,
                child: Text('구독 해지',
                    style: DesignTokens.ptSans(12,
                        color: isDark
                            ? DesignTokens.inkDarkFaint
                            : DesignTokens.inkFaint)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 구독 취소 확인 다이얼로그 ───────────────────────────────────────────────
Future<bool> _showCancelDialog(BuildContext context) async {
  final isDark = context.read<AppState>().isDark;
  return await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor:
              isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('구독을 해지하시겠습니까?',
                    style: DesignTokens.hahmlet(16,
                        weight: FontWeight.w600,
                        color: isDark
                            ? DesignTokens.inkDark
                            : DesignTokens.ink)),
                const SizedBox(height: 8),
                Text(
                  '기간 만료 전까지는 계속 이용 가능합니다.\nApp Store에서 최종 확인이 필요합니다.',
                  textAlign: TextAlign.center,
                  style: DesignTokens.ptSans(12,
                          color: isDark
                              ? DesignTokens.inkDarkMute
                              : DesignTokens.inkMute)
                      .copyWith(height: 1.5),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: isDark
                                  ? DesignTokens.ruleDarkStrong
                                  : DesignTokens.ruleStrong),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text('유지',
                            style: DesignTokens.hahmlet(13,
                                color: isDark
                                    ? DesignTokens.inkDark
                                    : DesignTokens.ink)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.terracotta,
                          foregroundColor: DesignTokens.bgIvory,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        child: Text('해지',
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
      ) ??
      false;
}

// ─── 구독 성공 시트 ───────────────────────────────────────────────────────────
void _showSuccessSheet(BuildContext context, SubscriptionTier plan) {
  final isDark = context.read<AppState>().isDark;

  final (title, sub) = switch (plan) {
    SubscriptionTier.standardMonthly => ('스탠다드 시작!',      '이제 문장을 마음껏 저장할 수 있어요.\n매월 ${AppConfig.stdMonthlyLabel}이 청구됩니다.'),
    SubscriptionTier.standardAnnual  => ('스탠다드 연간 시작!', '이제 문장을 마음껏 저장할 수 있어요.\n${AppConfig.stdAnnualLabel} / 년으로 자동 갱신됩니다.'),
    SubscriptionTier.premiumAnnual   => ('Revi Premium 시작!', 'AI 심층 분석, 카드형 아카이빙 등\n모든 프리미엄 기능을 이용할 수 있습니다.'),
    _                                => ('완료', ''),
  };

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
            color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: DesignTokens.sage.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: DesignTokens.sage, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: DesignTokens.hahmlet(18,
                  weight: FontWeight.w600,
                  color:
                      isDark ? DesignTokens.inkDark : DesignTokens.ink)),
          const SizedBox(height: 8),
          Text(sub,
              textAlign: TextAlign.center,
              style: DesignTokens.hahmlet(13,
                      color: isDark
                          ? DesignTokens.inkDarkMute
                          : DesignTokens.inkMute)
                  .copyWith(height: 1.6)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 시트 닫기
                Navigator.pop(context); // 설정으로 복귀
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? DesignTokens.bgDarkEdge : DesignTokens.ink,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 15),
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
  );
}
