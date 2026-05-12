import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../models/refund_record.dart';
import '../models/refund_result.dart';
import '../providers/app_state.dart';
import '../services/refund_service.dart';

/// 환불/해지/다운그레이드 미리보기 다이얼로그
///
/// [result] 를 기반으로 예상 환불 금액과 안내 문구를 보여주고,
/// 확인 버튼 탭 시 [RefundService.processRefund] 를 호출한다.
///
/// 사용 예:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => RefundPreviewDialog(
///     result: refundResult,
///     originalPaymentId: 'payment_xyz',
///     userId: 'user_123',
///   ),
/// );
/// ```
class RefundPreviewDialog extends StatefulWidget {
  const RefundPreviewDialog({
    super.key,
    required this.result,
    required this.originalPaymentId,
    required this.userId,
  });

  final RefundResult result;
  final String originalPaymentId;
  final String userId;

  @override
  State<RefundPreviewDialog> createState() => _RefundPreviewDialogState();
}

class _RefundPreviewDialogState extends State<RefundPreviewDialog> {
  bool _processing = false;

  // ── 아이콘·색상 ──────────────────────────────────────────────────────
  IconData get _icon {
    switch (widget.result.refundType) {
      case RefundType.coolingOff:
        return Icons.verified_outlined;
      case RefundType.proratedDiff:
      case RefundType.proratedFull:
        return Icons.swap_horiz_rounded;
      case RefundType.noRefund:
        return Icons.event_available_outlined;
    }
  }

  Color get _accentColor {
    switch (widget.result.refundType) {
      case RefundType.coolingOff:
        return DesignTokens.sage;
      case RefundType.proratedDiff:
      case RefundType.proratedFull:
        return DesignTokens.amber;
      case RefundType.noRefund:
        return DesignTokens.inkMute;
    }
  }

  String get _title {
    switch (widget.result.refundType) {
      case RefundType.coolingOff:
        return '전액 환불 안내';
      case RefundType.proratedDiff:
        return '플랜 변경 환불 안내';
      case RefundType.proratedFull:
        return '월구독 전환 환불 안내';
      case RefundType.noRefund:
        return widget.result.targetPlan == null ? '구독 해지 안내' : '플랜 변경 안내';
    }
  }

  // ── 환불 요약 카드 ────────────────────────────────────────────────────
  Widget _buildSummaryCard(bool isDark) {
    final r = widget.result;
    final bg   = isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge;
    final rule = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: rule),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // 환불액
          if (r.refundAmount > 0) ...[
            _SummaryRow(
              label: '환불 예정 금액',
              value: _fmtAmount(r.refundAmount),
              valueColor: DesignTokens.sage,
              isDark: isDark,
            ),
            _divider(rule),
          ],

          // 잔여 일수
          _SummaryRow(
            label: '잔여 이용일',
            value: '${r.remainingDays}일',
            isDark: isDark,
          ),
          _divider(rule),

          // 만료일
          _SummaryRow(
            label: r.refundType == RefundType.proratedFull
                ? '신규 월구독 만료일'
                : '이용 만료일',
            value: _fmtDate(r.expiresAt),
            isDark: isDark,
          ),

          // 변경 후 플랜
          if (r.targetPlan != null) ...[
            _divider(rule),
            _SummaryRow(
              label: '변경 후 플랜',
              value: _planName(r.targetPlan!, r.targetBillingType!),
              isDark: isDark,
            ),
          ],

          // noRefund 인 경우 환불 없음 표시
          if (r.refundAmount == 0 &&
              r.refundType == RefundType.noRefund) ...[
            _divider(rule),
            _SummaryRow(
              label: '환불 금액',
              value: '없음',
              valueColor: DesignTokens.inkMute,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider(Color color) =>
      Divider(height: 16, thickness: 1, color: color);

  // ── 처리 결과 스낵바 ──────────────────────────────────────────────────
  void _showResult(BuildContext ctx, RefundRecord record) {
    final success = record.status == RefundStatus.completed ||
        record.status == RefundStatus.pending;
    final msg = success
        ? (record.refundAmount > 0
            ? '${_fmtAmount(record.refundAmount)} 환불이 요청되었습니다. 영업일 3~5일 내 처리됩니다.'
            : '플랜이 변경되었습니다.')
        : '환불 처리 중 오류가 발생했습니다. 고객센터(support@revi.app)로 문의해 주세요.';

    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg,
          style: DesignTokens.hahmlet(12, color: DesignTokens.bgIvory)),
      backgroundColor:
          success ? DesignTokens.sage : DesignTokens.terracotta,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _onConfirm(BuildContext ctx) async {
    setState(() => _processing = true);
    try {
      final record = await RefundService.instance.processRefund(
        widget.userId,
        widget.result,
        widget.originalPaymentId,
      );

      // 해지인 경우 구독 상태 취소 처리
      if (widget.result.targetPlan == null &&
          widget.result.refundType == RefundType.noRefund) {
        if (ctx.mounted) ctx.read<AppState>().cancelSubscription();
      }

      if (ctx.mounted) {
        Navigator.pop(ctx);
        _showResult(ctx, record);
      }
    } catch (e) {
      setState(() => _processing = false);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('오류: $e',
              style: DesignTokens.hahmlet(12, color: DesignTokens.bgIvory)),
          backgroundColor: DesignTokens.terracotta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = context.watch<AppState>().isDark;
    final ink     = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute    = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final bgColor = isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 18, color: _accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _title,
                    style: DesignTokens.hahmlet(16,
                        weight: FontWeight.w600, color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 요약 카드 ──
            _buildSummaryCard(isDark),
            const SizedBox(height: 14),

            // ── 안내 문구 ──
            Text(
              widget.result.userMessage,
              style: DesignTokens.hahmlet(12, color: mute)
                  .copyWith(height: 1.65),
            ),
            const SizedBox(height: 20),

            // ── 버튼 ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _processing ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: isDark
                              ? DesignTokens.ruleDarkStrong
                              : DesignTokens.ruleStrong),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('취소',
                        style: DesignTokens.hahmlet(13, color: ink)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processing ? null : () => _onConfirm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.ink,
                      foregroundColor: DesignTokens.bgIvory,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.result.refundAmount > 0
                                ? '환불 확인'
                                : '확인',
                            style: DesignTokens.hahmlet(13,
                                weight: FontWeight.w600,
                                color: DesignTokens.bgIvory),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────
  String _fmtAmount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$buf원';
  }

  String _fmtDate(DateTime dt) => '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  String _planName(SubscriptionPlan plan, SubscriptionBillingType billing) {
    final p = plan == SubscriptionPlan.premium ? '프리미엄' : '스탠다드';
    final b = billing == SubscriptionBillingType.annual ? '연구독' : '월구독';
    return '$p $b';
  }
}

// ── 요약 행 위젯 ──────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink  = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: DesignTokens.hahmlet(12, color: mute)),
        Text(value,
            style: DesignTokens.hahmlet(13,
                weight: FontWeight.w600,
                color: valueColor ?? ink)),
      ],
    );
  }
}
