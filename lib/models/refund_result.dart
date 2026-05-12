/// Revi 구독 플랜 종류
enum SubscriptionPlan {
  standard, // 스탠다드
  premium,  // 프리미엄
}

/// 구독 결제 주기
enum SubscriptionBillingType {
  monthly, // 월구독
  annual,  // 연구독
}

/// 환불 유형
enum RefundType {
  /// 결제 후 72시간 이내 — 전액 환불
  coolingOff,

  /// 연구독 → 연구독 — 일할 차액 환불 (케이스 A)
  proratedDiff,

  /// 연구독 → 월구독 — 일할 잔액 환불 후 신규 결제 (케이스 B·C)
  proratedFull,

  /// 쿨링오프 이후 해지 또는 최소 환불액 미달 — 환불 없음
  noRefund,
}

/// 환불 계산 결과 (불변)
///
/// [refundAmount] 는 floor() 처리된 원(KRW) 정수.
/// 해지(noRefund)일 때도 [expiresAt] 은 반드시 원래 만료일을 유지해야 한다.
class RefundResult {
  const RefundResult({
    required this.refundType,
    required this.refundAmount,
    required this.remainingDays,
    this.targetPlan,
    this.targetBillingType,
    required this.expiresAt,
    required this.userMessage,
  });

  /// 환불 유형
  final RefundType refundType;

  /// 환불액 (원). 환불 없음이면 0.
  final int refundAmount;

  /// 계산 시점의 잔여 일수 (clamp(0, ∞))
  final int remainingDays;

  /// 다운그레이드 목표 플랜 (해지이면 null)
  final SubscriptionPlan? targetPlan;

  /// 다운그레이드 목표 결제 주기 (해지이면 null)
  final SubscriptionBillingType? targetBillingType;

  /// 만료일
  /// - 해지·다운그레이드(연→연): 기존 expiresAt 유지
  /// - 연→월 전환: 신규 월구독 시작일 + 30일
  final DateTime expiresAt;

  /// 사용자에게 표시하는 한국어 안내 문구
  final String userMessage;
}
