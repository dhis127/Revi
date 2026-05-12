import 'dart:math';

import '../constants/subscription_constants.dart';
import '../models/refund_record.dart';
import '../models/refund_result.dart';

/// Revi 구독 환불 서비스 (싱글톤)
///
/// 환불 계산 로직 및 이력 관리를 담당한다.
/// Phase 3: processRefund() 내 TODO 주석 위치에 실제 결제 게이트웨이 연동 추가.
class RefundService {
  RefundService._();
  static final RefundService instance = RefundService._();

  // 환불 이력 — Phase 3에서 Supabase 테이블로 교체
  final List<RefundRecord> _records = [];

  // ── 공개 API ──────────────────────────────────────────────────────────

  /// 쿨링오프 여부 판정
  ///
  /// [purchaseDate] 결제(또는 플랜 변경) 시각,
  /// [requestDate] 환불/해지 요청 시각.
  /// 차이가 72시간 미만이면 true.
  bool isCoolingOff(DateTime purchaseDate, DateTime requestDate) {
    final diff = requestDate.difference(purchaseDate);
    return diff.inHours < SubscriptionConstants.coolingOffHours;
  }

  /// 환불 금액·유형 계산
  ///
  /// - [isCancellation] true이면 해지, false이면 다운그레이드.
  /// - 다운그레이드 시 [targetPlan], [targetBillingType] 필수.
  RefundResult calculateRefund({
    required SubscriptionPlan currentPlan,
    required SubscriptionBillingType currentBillingType,
    required DateTime purchaseDate,
    required DateTime expiresAt,
    required DateTime requestDate,
    SubscriptionPlan? targetPlan,
    SubscriptionBillingType? targetBillingType,
    required bool isCancellation,
  }) {
    // 잔여 일수 (0 이상)
    final remainingDays = expiresAt
        .difference(requestDate)
        .inDays
        .clamp(0, 99999);

    final coolingOff = isCoolingOff(purchaseDate, requestDate);

    // ── 케이스 1: 쿨링오프 — 전액 환불 ────────────────────────────────
    if (coolingOff) {
      final fullAmount = _actualPrice(currentPlan, currentBillingType);
      return RefundResult(
        refundType: RefundType.coolingOff,
        refundAmount: fullAmount,
        remainingDays: remainingDays,
        targetPlan: targetPlan,
        targetBillingType: targetBillingType,
        expiresAt: expiresAt,
        userMessage:
            '결제 후 72시간 이내로, ${_fmt(fullAmount)}이 전액 환불됩니다.',
      );
    }

    // ── 케이스 2: 해지 (쿨링오프 이후) — 환불 없음, expiresAt 유지 ────
    if (isCancellation) {
      return RefundResult(
        refundType: RefundType.noRefund,
        refundAmount: 0,
        remainingDays: remainingDays,
        expiresAt: expiresAt,
        userMessage:
            '${_fmtDate(expiresAt)}까지 현재 플랜을 계속 이용할 수 있습니다.\n'
            '쿨링오프(72시간) 이후 해지는 별도 환불이 제공되지 않습니다.',
      );
    }

    // ── 케이스 3: 다운그레이드 ─────────────────────────────────────────
    assert(
      targetPlan != null && targetBillingType != null,
      'calculateRefund: 다운그레이드 시 targetPlan, targetBillingType 필수',
    );
    final tPlan = targetPlan!;
    final tBilling = targetBillingType!;

    // 케이스 A: 연구독 → 연구독 (일할 차액 환불, 만료일 유지)
    if (currentBillingType == SubscriptionBillingType.annual &&
        tBilling == SubscriptionBillingType.annual) {
      return _caseA(
        currentPlan: currentPlan,
        targetPlan: tPlan,
        remainingDays: remainingDays,
        expiresAt: expiresAt,
      );
    }

    // 케이스 B·C: 연구독 → 월구독 (잔액 환불 후 신규 월구독 결제)
    if (currentBillingType == SubscriptionBillingType.annual &&
        tBilling == SubscriptionBillingType.monthly) {
      return _caseBorC(
        currentPlan: currentPlan,
        targetPlan: tPlan,
        remainingDays: remainingDays,
        requestDate: requestDate,
      );
    }

    // 그 외 (월→연 업그레이드 등 — 본 서비스 범위 외)
    return RefundResult(
      refundType: RefundType.noRefund,
      refundAmount: 0,
      remainingDays: remainingDays,
      targetPlan: tPlan,
      targetBillingType: tBilling,
      expiresAt: expiresAt,
      userMessage: '처리할 수 없는 변경 유형입니다. 고객센터에 문의해 주세요.',
    );
  }

  /// 환불 실행 + RefundRecord 저장
  ///
  /// [userId] 사용자 ID,
  /// [result] calculateRefund() 결과,
  /// [originalPaymentId] 원결제 ID.
  ///
  /// refundAmount == 0 이면 noRefund 처리로 즉시 completed.
  /// refundAmount > 0 이면 pending 상태로 저장 후 반환
  ///   (Phase 3에서 게이트웨이 응답에 따라 updateRefundStatus 호출).
  Future<RefundRecord> processRefund(
    String userId,
    RefundResult result,
    String originalPaymentId,
  ) async {
    final record = RefundRecord(
      refundId: _genId(),
      userId: userId,
      refundType: result.refundType,
      originalPaymentId: originalPaymentId,
      refundAmount: result.refundAmount,
      requestedAt: DateTime.now(),
      status: result.refundAmount > 0
          ? RefundStatus.pending
          : RefundStatus.completed,
      reason: result.userMessage,
    );
    _records.add(record);

    if (result.refundAmount > 0) {
      // TODO(Phase 3): 결제 게이트웨이(RevenueCat / KG이니시스 등) 연동
      //
      // try {
      //   final res = await PaymentGateway.refund(
      //     paymentId: originalPaymentId,
      //     amount: result.refundAmount,
      //   );
      //   await updateRefundStatus(
      //     record.refundId,
      //     res.success ? RefundStatus.completed : RefundStatus.failed,
      //   );
      // } catch (e) {
      //   await updateRefundStatus(record.refundId, RefundStatus.failed);
      //   rethrow;
      // }
      //
      // 케이스 B·C (연→월): 환불 성공 후 월구독 신규 결제 트랜잭션 시작.
      // 반드시 환불이 completed 된 이후에 신규 결제 진행.
    }

    return record;
  }

  /// 환불 상태 업데이트 (게이트웨이 응답 수신 후 호출)
  Future<void> updateRefundStatus(
    String refundId,
    RefundStatus status,
  ) async {
    final idx = _records.indexWhere((r) => r.refundId == refundId);
    if (idx == -1) return;
    _records[idx] = _records[idx].copyWith(
      status: status,
      processedAt: DateTime.now(),
    );
  }

  /// 사용자 환불 이력 조회 (최신순)
  Future<List<RefundRecord>> getRefundHistory(String userId) async {
    return _records
        .where((r) => r.userId == userId)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  // ── 케이스별 계산 ─────────────────────────────────────────────────────

  /// 케이스 A: 연구독 → 연구독
  /// 일일 차액 × 잔여 일수, 만료일 유지
  RefundResult _caseA({
    required SubscriptionPlan currentPlan,
    required SubscriptionPlan targetPlan,
    required int remainingDays,
    required DateTime expiresAt,
  }) {
    final currentPrice =
        _actualPrice(currentPlan, SubscriptionBillingType.annual);
    final targetPrice =
        _actualPrice(targetPlan, SubscriptionBillingType.annual);
    final dailyDiff =
        (currentPrice - targetPrice) / SubscriptionConstants.annualDays;
    final raw = (dailyDiff * remainingDays).floor();
    final refund = raw < SubscriptionConstants.minRefundAmount ? 0 : raw;

    final tName = _planName(targetPlan, SubscriptionBillingType.annual);
    return RefundResult(
      refundType:
          refund > 0 ? RefundType.proratedDiff : RefundType.noRefund,
      refundAmount: refund,
      remainingDays: remainingDays,
      targetPlan: targetPlan,
      targetBillingType: SubscriptionBillingType.annual,
      expiresAt: expiresAt, // 만료일 유지
      userMessage: refund > 0
          ? '${_fmt(refund)} 환불 후 즉시 $tName으로 전환됩니다.\n기존 만료일은 유지됩니다.'
          : '잔여 환불액이 최소 기준(100원) 미만이어서 환불 없이 $tName으로 전환됩니다.',
    );
  }

  /// 케이스 B·C: 연구독 → 월구독
  /// 잔여 일할 잔액 환불 후 신규 월구독 결제
  RefundResult _caseBorC({
    required SubscriptionPlan currentPlan,
    required SubscriptionPlan targetPlan,
    required int remainingDays,
    required DateTime requestDate,
  }) {
    final currentPrice =
        _actualPrice(currentPlan, SubscriptionBillingType.annual);
    final dailyRate = currentPrice / SubscriptionConstants.annualDays;
    final raw = (dailyRate * remainingDays).floor();
    final refund = raw < SubscriptionConstants.minRefundAmount ? 0 : raw;

    // 월구독 신규 만료일: 요청일 + 30일
    final newExpires = requestDate.add(const Duration(days: 30));
    const monthlyPrice = SubscriptionConstants.standardMonthlyPrice;

    return RefundResult(
      refundType:
          refund > 0 ? RefundType.proratedFull : RefundType.noRefund,
      refundAmount: refund,
      remainingDays: remainingDays,
      targetPlan: targetPlan,
      targetBillingType: SubscriptionBillingType.monthly,
      expiresAt: newExpires,
      userMessage: refund > 0
          ? '${_fmt(refund)} 환불 후 스탠다드 월구독(${_fmt(monthlyPrice)}/월)이 새로 시작됩니다.\n'
              '환불과 신규 결제는 순차 처리되며, 환불 실패 시 신규 결제는 진행되지 않습니다.'
          : '잔여 환불액이 최소 기준(100원) 미만이어서 환불 없이 월구독으로 전환됩니다.',
    );
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────

  /// 플랜·주기별 실제 결제 금액
  int _actualPrice(SubscriptionPlan plan, SubscriptionBillingType billing) {
    if (plan == SubscriptionPlan.premium) {
      return SubscriptionConstants.premiumAnnualPrice;
    }
    return billing == SubscriptionBillingType.annual
        ? SubscriptionConstants.standardAnnualPrice
        : SubscriptionConstants.standardMonthlyPrice;
  }

  String _planName(SubscriptionPlan plan, SubscriptionBillingType billing) {
    final p = plan == SubscriptionPlan.premium ? '프리미엄' : '스탠다드';
    final b = billing == SubscriptionBillingType.annual ? '연구독' : '월구독';
    return '$p $b';
  }

  /// 금액 포맷: "16,438원"
  String _fmt(int amount) => '${_comma(amount)}원';

  String _comma(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// 날짜 포맷: "2026년 12월 31일"
  String _fmtDate(DateTime dt) => '${dt.year}년 ${dt.month}월 ${dt.day}일';

  /// 16자 랜덤 ID
  String _genId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
