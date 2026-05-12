// 휴면 계정 처리 정책 (Phase 3 Supabase 연결 시 구현)
//
// 6개월 미접속:  재방문 유도 이메일 발송
// 11개월 미접속: 휴면 예고 이메일 발송 (구독 재유도 기회)
// 12개월 미접속: 계정 휴면 전환 (cold storage 이동)
// 24개월 미접속: 계정 자동 삭제 및 데이터 완전 파기
//
// 법적 근거: 한국 개인정보보호법 (1년 이상 미접속 계정 처리 의무)
// 비용: Supabase cold storage $0.021/GB/월 (사실상 무시 가능)

import '../models/subscription_model.dart';

class SubscriptionService {
  static const SubscriptionService instance = SubscriptionService._();
  const SubscriptionService._();

  // ── 저장 가능 여부 ──────────────────────────────────────────────────────────

  bool canSaveBook(int currentBookCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxBooks[tier]!;
    return currentBookCount < limit;
  }

  bool canSaveHighlight(int currentHighlightCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxHighlights[tier]!;
    return currentHighlightCount < limit;
  }

  bool canAddShelf(int currentShelfCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxShelves[tier]!;
    return currentShelfCount < limit;
  }

  bool canAddHighlightSlot(int currentSlotCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxHighlightSlots[tier]!;
    return currentSlotCount < limit;
  }

  // ── 남은 개수 ───────────────────────────────────────────────────────────────

  int getBooksRemaining(int currentBookCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxBooks[tier]!;
    return (limit - currentBookCount).clamp(0, limit);
  }

  int getHighlightsRemaining(int currentHighlightCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxHighlights[tier]!;
    return (limit - currentHighlightCount).clamp(0, limit);
  }

  // ── 80% 임박 경고 ──────────────────────────────────────────────────────────

  bool isNearBookLimit(int currentBookCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxBooks[tier]!;
    if (limit >= 999999) return false; // 무제한 티어는 경고 없음
    return currentBookCount / limit >= 0.8;
  }

  bool isNearHighlightLimit(int currentHighlightCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxHighlights[tier]!;
    if (limit >= 999999) return false;
    return currentHighlightCount / limit >= 0.8;
  }

  // 스탠다드 → 프리미엄 업셀: 책장 8/10 이상
  bool isNearShelfLimitForUpsell(int currentShelfCount, SubscriptionTier tier) {
    if (tier != SubscriptionTier.standardMonthly &&
        tier != SubscriptionTier.standardAnnual) return false;
    return currentShelfCount >= 8;
  }

  // ── 한도 도달 여부 ─────────────────────────────────────────────────────────

  bool isAtBookLimit(int currentBookCount, SubscriptionTier tier) {
    return !canSaveBook(currentBookCount, tier);
  }

  bool isAtHighlightLimit(int currentHighlightCount, SubscriptionTier tier) {
    return !canSaveHighlight(currentHighlightCount, tier);
  }

  bool isAtAnyLimit(
      int currentBookCount, int currentHighlightCount, SubscriptionTier tier) {
    return isAtBookLimit(currentBookCount, tier) ||
        isAtHighlightLimit(currentHighlightCount, tier);
  }

  // ── 한도 텍스트 ────────────────────────────────────────────────────────────

  String bookLimitMessage(int currentBookCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxBooks[tier]!;
    final remaining = getBooksRemaining(currentBookCount, tier);
    return '${limit}권 중 ${currentBookCount}권을 저장했어요. ${remaining}권 남았어요.';
  }

  String highlightLimitMessage(
      int currentHighlightCount, SubscriptionTier tier) {
    final limit = SubscriptionLimits.maxHighlights[tier]!;
    final remaining = getHighlightsRemaining(currentHighlightCount, tier);
    return '${limit}개 중 ${currentHighlightCount}개를 저장했어요. ${remaining}개 남았어요.';
  }
}
