import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../config/design_tokens.dart';
import '../models/subscription_model.dart';
import '../providers/app_state.dart';

/// PaywallPage — 한도 도달 / 80% 경고 시 표시되는 구독 전환 화면
/// Free → Standard 전환 유도 (Standard → Premium 업셀은 subscription_page.dart)
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  SubscriptionTier _selected = SubscriptionTier.standardAnnual;
  bool _loading = false;

  // 혜택 문구는 lib/config/app_config.dart 의 stdFeatures 에서 관리합니다.
  static List<PaywallFeature> get _features => AppConfig.stdFeatures;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final bg     = isDark ? DesignTokens.bgDark     : DesignTokens.bgIvory;
    final ink    = isDark ? DesignTokens.inkDark     : DesignTokens.ink;
    final mute   = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint  = isDark ? DesignTokens.inkDarkFaint: DesignTokens.inkFaint;
    final cardBg = isDark ? DesignTokens.bgDarkDeep  : DesignTokens.bgIvoryDeep;
    final rule   = isDark ? DesignTokens.ruleDark    : DesignTokens.rule;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('← 닫기',
                        style: DesignTokens.hahmlet(13, color: mute)),
                  ),
                  const Spacer(),
                  Text('STANDARD',
                      style: DesignTokens.ptSans(10,
                              weight: FontWeight.w700,
                              color: DesignTokens.terracotta)
                          .copyWith(letterSpacing: 1.5)),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 타이틀 ──
                    Text('구독하고 계속 이어가세요.',
                        style: DesignTokens.hahmlet(26,
                                weight: FontWeight.w600, color: ink)
                            .copyWith(letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text('저장한 책과 문장은 그대로 있어요.',
                        style: DesignTokens.hahmletRegular(14, mute)
                            .copyWith(height: 1.5)),
                    const SizedBox(height: 24),

                    // ── 혜택 카드 ──
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: rule),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: _features.asMap().entries.map((e) {
                          final last = e.key == _features.length - 1;
                          return _FeatureTile(
                            feature: e.value,
                            isDark: isDark,
                            last: last,
                            rule: rule,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── PLAN 선택 ──
                    Text('PLAN',
                        style: DesignTokens.ptSans(10,
                                weight: FontWeight.w700, color: mute)
                            .copyWith(letterSpacing: 1.5)),
                    const SizedBox(height: 10),

                    _PlanTile(
                      tier: SubscriptionTier.standardAnnual,
                      selected: _selected,
                      isDark: isDark,
                      title: '연간 구독',
                      price: AppConfig.stdAnnualLabel,
                      sub: AppConfig.stdAnnualSubtitle,
                      badge: 'BEST',
                      onTap: () => setState(
                          () => _selected = SubscriptionTier.standardAnnual),
                    ),
                    const SizedBox(height: 8),
                    _PlanTile(
                      tier: SubscriptionTier.standardMonthly,
                      selected: _selected,
                      isDark: isDark,
                      title: '월간 구독',
                      price: AppConfig.stdMonthlyLabel,
                      sub: '매월 자동 갱신',
                      onTap: () => setState(
                          () => _selected = SubscriptionTier.standardMonthly),
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: Text('언제든지 취소 가능 · App Store 결제',
                          style: DesignTokens.ptSans(10, color: faint)
                              .copyWith(letterSpacing: 0.1)),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── 하단 CTA ──
            Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                    top: BorderSide(
                        color: isDark
                            ? DesignTokens.ruleDark
                            : DesignTokens.rule)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.terracotta,
                    foregroundColor: DesignTokens.bgIvory,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DesignTokens.bgIvory),
                        )
                      : Text('시작하기',
                          style: DesignTokens.hahmlet(15,
                              weight: FontWeight.w600,
                              color: DesignTokens.bgIvory)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _loading = true);
    // Phase 3: in_app_purchase 결제 플로우로 교체
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.read<AppState>().subscribe(_selected);
    setState(() => _loading = false);
    if (mounted) {
      _showSuccessAndPop();
    }
  }

  void _showSuccessAndPop() {
    final isDark = context.read<AppState>().isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            Text('구독이 시작됐어요!',
                style: DesignTokens.hahmlet(18,
                    weight: FontWeight.w600,
                    color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
            const SizedBox(height: 8),
            Text('이제 문장을 마음껏 저장할 수 있어요.',
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
                  Navigator.pop(context); // sheet
                  Navigator.pop(context); // paywall
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
}

// ─── Feature Tile ─────────────────────────────────────────────────────────────
class _FeatureTile extends StatelessWidget {
  final PaywallFeature feature;
  final bool isDark;
  final bool last;
  final Color rule;
  const _FeatureTile({
    required this.feature,
    required this.isDark,
    required this.last,
    required this.rule,
  });

  @override
  Widget build(BuildContext context) {
    final ink  = isDark ? DesignTokens.inkDark     : DesignTokens.ink;
    final mute = isDark ? DesignTokens.inkDarkMute  : DesignTokens.inkMute;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: rule))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(feature.icon,
                style: DesignTokens.ptSans(14,
                    weight: FontWeight.w700,
                    color: DesignTokens.terracotta)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title,
                    style: DesignTokens.hahmlet(13,
                        weight: FontWeight.w600, color: ink)),
                const SizedBox(height: 2),
                Text(feature.subtitle,
                    style: DesignTokens.ptSans(11, color: mute)
                        .copyWith(height: 1.4)),
              ],
            ),
          ),
          Icon(Icons.check_rounded, size: 17, color: DesignTokens.sage),
        ],
      ),
    );
  }
}

// ─── Plan Tile ────────────────────────────────────────────────────────────────
class _PlanTile extends StatelessWidget {
  final SubscriptionTier tier;
  final SubscriptionTier selected;
  final bool isDark;
  final String title;
  final String price;
  final String sub;
  final String? badge;
  final VoidCallback onTap;

  const _PlanTile({
    required this.tier,
    required this.selected,
    required this.isDark,
    required this.title,
    required this.price,
    required this.sub,
    required this.onTap,
    this.badge,
  });

  bool get _isSelected => tier == selected;

  @override
  Widget build(BuildContext context) {
    final ink     = isDark ? DesignTokens.inkDark    : DesignTokens.ink;
    final mute    = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final cardBg  = isDark ? DesignTokens.bgDarkDeep  : DesignTokens.bgIvoryDeep;
    final edgeBg  = isDark ? DesignTokens.bgDarkEdge  : DesignTokens.bgIvoryEdge;
    final ruleDef = isDark ? DesignTokens.ruleDark    : DesignTokens.rule;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isSelected ? edgeBg : cardBg,
          border: Border.all(
            color: _isSelected ? DesignTokens.terracotta : ruleDef,
            width: _isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isSelected
                      ? DesignTokens.terracotta
                      : (isDark
                          ? DesignTokens.inkDarkMute
                          : DesignTokens.inkFaint),
                  width: _isSelected ? 5 : 1.5,
                ),
                color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: DesignTokens.hahmlet(13,
                              weight: FontWeight.w600, color: ink)),
                      if (badge != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DesignTokens.terracotta,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge!,
                              style: DesignTokens.ptSans(7,
                                      weight: FontWeight.w700,
                                      color: DesignTokens.bgIvory)
                                  .copyWith(letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: DesignTokens.ptSans(10, color: mute)
                          .copyWith(letterSpacing: 0.1)),
                ],
              ),
            ),
            Text(price,
                style: DesignTokens.hahmlet(14,
                    weight: FontWeight.w600,
                    color:
                        _isSelected ? DesignTokens.terracotta : ink)),
          ],
        ),
      ),
    );
  }
}

// ─── 한도 도달 BottomSheet ─────────────────────────────────────────────────────
/// 문장/책 저장 시도 시 호출
/// Phase 2에서 add_book_page.dart, scan_page.dart에 연결
void showLimitBottomSheet(BuildContext context, {required bool isHighlight}) {
  final state  = context.read<AppState>();
  final isDark = state.isDark;
  final count  = isHighlight
      ? state.effectiveHighlightCount
      : state.effectiveBookCount;
  final unit   = isHighlight ? '개' : '권';
  final noun   = isHighlight ? '문장' : '책';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _LimitSheet(
      isDark: isDark,
      title: '${noun}이 가득 찼어요.',
      body: '$count$unit의 $noun이 쌓였어요.\n이 기억들은 그대로 있어요.\n더 저장하려면 구독이 필요해요.',
    ),
  );
}

class _LimitSheet extends StatelessWidget {
  final bool isDark;
  final String title;
  final String body;
  const _LimitSheet(
      {required this.isDark, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final bg   = isDark ? DesignTokens.bgDarkDeep  : DesignTokens.bgIvoryDeep;
    final ink  = isDark ? DesignTokens.inkDark      : DesignTokens.ink;
    final mute = isDark ? DesignTokens.inkDarkMute  : DesignTokens.inkMute;
    final rule = isDark ? DesignTokens.ruleDark     : DesignTokens.rule;
    final edgeBg = isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: rule),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? DesignTokens.ruleDarkStrong
                    : DesignTokens.ruleStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          Text(title,
              style: DesignTokens.hahmlet(18,
                  weight: FontWeight.w600, color: ink)),
          const SizedBox(height: 10),
          Text(body,
              style: DesignTokens.hahmlet(13, color: mute)
                  .copyWith(height: 1.65)),
          const SizedBox(height: 22),

          // 연간 플랜 (강조)
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaywallPage()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: edgeBg,
                border:
                    Border.all(color: DesignTokens.sage, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('연간  ',
                                style: DesignTokens.hahmlet(13,
                                    weight: FontWeight.w600, color: ink)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DesignTokens.terracotta,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('BEST',
                                  style: DesignTokens.ptSans(7,
                                          weight: FontWeight.w700,
                                          color: DesignTokens.bgIvory)
                                      .copyWith(letterSpacing: 0.8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(AppConfig.stdAnnualSubtitle,
                            style: DesignTokens.ptSans(10, color: mute)),
                      ],
                    ),
                  ),
                  Text(AppConfig.stdAnnualLabel,
                      style: DesignTokens.hahmlet(14,
                          weight: FontWeight.w600,
                          color: DesignTokens.terracotta)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 월간 플랜
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaywallPage()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: rule),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('월간',
                            style: DesignTokens.hahmlet(13,
                                weight: FontWeight.w600, color: ink)),
                        const SizedBox(height: 2),
                        Text('매월 자동 갱신',
                            style: DesignTokens.ptSans(10, color: mute)),
                      ],
                    ),
                  ),
                  Text(AppConfig.stdMonthlyLabel,
                      style: DesignTokens.hahmlet(14,
                          weight: FontWeight.w600, color: ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 나중에 할게요
          Center(
            child: GestureDetector(
              onTap: () {
                // Phase 3: 7일 후 푸시 알림 예약 (local_notifications 패키지)
                Navigator.pop(context);
              },
              child: Text('나중에 할게요',
                  style: DesignTokens.ptSans(12, color: mute)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }
}
