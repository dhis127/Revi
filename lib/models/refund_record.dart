import 'refund_result.dart';

/// 환불 처리 상태
enum RefundStatus {
  /// 환불 요청 접수 (결제 게이트웨이 응답 대기)
  pending,

  /// 환불 완료
  completed,

  /// 환불 실패 (게이트웨이 오류 등)
  failed,
}

/// 환불 이력 레코드
///
/// 정산 및 사용자 환불 내역 추적을 위해 모든 환불(쿨링오프·다운그레이드)을
/// 별도 트랜잭션으로 저장해야 한다.
/// Phase 3: Supabase `refund_records` 테이블로 교체 예정.
class RefundRecord {
  const RefundRecord({
    required this.refundId,
    required this.userId,
    required this.refundType,
    required this.originalPaymentId,
    required this.refundAmount,
    required this.requestedAt,
    this.processedAt,
    required this.status,
    required this.reason,
  });

  /// 환불 고유 ID (UUID)
  final String refundId;

  /// 사용자 ID
  final String userId;

  /// 환불 유형
  final RefundType refundType;

  /// 원결제 ID — 결제 게이트웨이 연동 시 실제 PG 거래 ID로 교체
  final String originalPaymentId;

  /// 환불액 (원, floor 처리)
  final int refundAmount;

  /// 환불 요청 시각
  final DateTime requestedAt;

  /// 환불 처리 완료 시각 (pending 상태이면 null)
  final DateTime? processedAt;

  /// 처리 상태
  final RefundStatus status;

  /// 사용자에게 보여주는 사유 문구
  final String reason;

  /// 상태 업데이트용 복사 생성자
  RefundRecord copyWith({
    RefundStatus? status,
    DateTime? processedAt,
  }) =>
      RefundRecord(
        refundId: refundId,
        userId: userId,
        refundType: refundType,
        originalPaymentId: originalPaymentId,
        refundAmount: refundAmount,
        requestedAt: requestedAt,
        processedAt: processedAt ?? this.processedAt,
        status: status ?? this.status,
        reason: reason,
      );
}
