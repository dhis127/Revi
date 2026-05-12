import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import '../models/refund_result.dart';

/// 결제 확인 화면에서 반드시 표시해야 하는 구독 환불 정책 고지 위젯.
///
/// - 플랜별로 안내 문구를 자동 분기한다.
/// - 체크박스 동의 전까지 결제 버튼이 비활성화되도록
///   [onAgreedChanged] 콜백으로 상위 위젯에 상태를 전달한다.
///
/// 사용 예:
/// ```dart
/// SubscriptionPolicyNoticeWidget(
///   plan: SubscriptionPlan.premium,
///   billingType: SubscriptionBillingType.annual,
///   onAgreedChanged: (agreed) => setState(() => _agreed = agreed),
/// )
/// ```
class SubscriptionPolicyNoticeWidget extends StatefulWidget {
  const SubscriptionPolicyNoticeWidget({
    super.key,
    required this.plan,
    required this.billingType,
    required this.onAgreedChanged,
  });

  final SubscriptionPlan plan;
  final SubscriptionBillingType billingType;

  /// 동의 상태가 변경될 때 호출 (true = 동의함)
  final ValueChanged<bool> onAgreedChanged;

  @override
  State<SubscriptionPolicyNoticeWidget> createState() =>
      _SubscriptionPolicyNoticeWidgetState();
}

class _SubscriptionPolicyNoticeWidgetState
    extends State<SubscriptionPolicyNoticeWidget> {
  bool _agreed = false;

  String get _policyText {
    switch (widget.plan) {
      case SubscriptionPlan.standard:
        if (widget.billingType == SubscriptionBillingType.monthly) {
          // 스탠다드 월구독
          return '결제 후 72시간 이내에는 전액 환불이 가능합니다.\n'
              '이후 해지 시에는 남은 이용 기간 동안 서비스를 계속 이용할 수 있으며,\n'
              '별도의 환불은 제공되지 않습니다.';
        } else {
          // 스탠다드 연구독
          return '결제 후 72시간 이내에는 전액 환불이 가능합니다.\n'
              '이후 상위 플랜으로 업그레이드 또는 월구독으로 변경 시\n'
              '남은 기간에 대한 일할 차액을 환불해 드립니다.\n'
              '해지 시에는 남은 이용 기간 동안 서비스를 계속 이용할 수 있으며,\n'
              '별도의 환불은 제공되지 않습니다.';
        }
      case SubscriptionPlan.premium:
        // 프리미엄 연구독 (연구독 전용)
        return '결제 후 72시간 이내에는 전액 환불이 가능합니다.\n'
            '이후 스탠다드 플랜으로 변경 시\n'
            '남은 기간에 대한 일할 차액을 환불해 드립니다.\n'
            '해지 시에는 남은 이용 기간 동안 서비스를 계속 이용할 수 있으며,\n'
            '별도의 환불은 제공되지 않습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.bgIvoryDeep,
        border: Border.all(color: DesignTokens.ruleStrong),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 제목 ──
          Text(
            '환불 정책 안내',
            style: DesignTokens.ptSans(
              10,
              weight: FontWeight.w700,
              color: DesignTokens.inkMute,
            ).copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),

          // ── 정책 본문 ──
          Text(
            _policyText,
            style: DesignTokens.hahmlet(12, color: DesignTokens.inkSoft)
                .copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),

          // ── 구분선 ──
          const Divider(height: 1, color: DesignTokens.rule),
          const SizedBox(height: 10),

          // ── 동의 체크박스 ──
          GestureDetector(
            onTap: () {
              setState(() => _agreed = !_agreed);
              widget.onAgreedChanged(_agreed);
            },
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _agreed
                        ? DesignTokens.sage
                        : Colors.transparent,
                    border: Border.all(
                      color: _agreed
                          ? DesignTokens.sage
                          : DesignTokens.inkFaint,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _agreed
                      ? const Icon(Icons.check,
                          size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '위 내용을 확인했습니다.',
                    style: DesignTokens.hahmlet(
                      13,
                      color: _agreed
                          ? DesignTokens.ink
                          : DesignTokens.inkMute,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
