// 한도 수치는 lib/config/app_config.dart 에서 관리합니다.
import '../config/app_config.dart';

enum SubscriptionTier {
  free,             // 무료 (책 5권 / 문장 50개 / 책장 1개)
  standardMonthly,  // 스탠다드 월간
  standardAnnual,   // 스탠다드 연간
  premiumAnnual,    // 프리미엄 연간
}

class SubscriptionLimits {
  // 999999 = 사실상 무제한 (Phase 3에서 서버 무제한으로 교체 예정)
  static const Map<SubscriptionTier, int> maxBooks = {
    SubscriptionTier.free:            AppConfig.freeMaxBooks,
    SubscriptionTier.standardMonthly: AppConfig.stdMaxBooks,
    SubscriptionTier.standardAnnual:  AppConfig.stdMaxBooks,
    SubscriptionTier.premiumAnnual:   AppConfig.premMaxBooks,
  };

  static const Map<SubscriptionTier, int> maxHighlights = {
    SubscriptionTier.free:            AppConfig.freeMaxHighlights,
    SubscriptionTier.standardMonthly: AppConfig.stdMaxHighlights,
    SubscriptionTier.standardAnnual:  AppConfig.stdMaxHighlights,
    SubscriptionTier.premiumAnnual:   AppConfig.premMaxHighlights,
  };

  static const Map<SubscriptionTier, int> maxShelves = {
    SubscriptionTier.free:            AppConfig.freeMaxShelves,
    SubscriptionTier.standardMonthly: AppConfig.stdMaxShelves,
    SubscriptionTier.standardAnnual:  AppConfig.stdMaxShelves,
    SubscriptionTier.premiumAnnual:   AppConfig.premMaxShelves,
  };

  static const Map<SubscriptionTier, int> maxFonts = {
    SubscriptionTier.free:            AppConfig.freeMaxFonts,
    SubscriptionTier.standardMonthly: AppConfig.stdMaxFonts,
    SubscriptionTier.standardAnnual:  AppConfig.stdMaxFonts,
    SubscriptionTier.premiumAnnual:   AppConfig.premMaxFonts,
  };

  static const Map<SubscriptionTier, int> maxHighlightSlots = {
    SubscriptionTier.free:            AppConfig.freeMaxSlots,
    SubscriptionTier.standardMonthly: AppConfig.stdMaxSlots,
    SubscriptionTier.standardAnnual:  AppConfig.stdMaxSlots,
    SubscriptionTier.premiumAnnual:   AppConfig.premMaxSlots,
  };
}
