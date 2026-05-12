// 가격·환불 상수는 모두 AppConfig에서 관리합니다.
// 값을 변경할 때는 lib/config/app_config.dart 를 수정하세요.
import '../config/app_config.dart';

class SubscriptionConstants {
  SubscriptionConstants._();

  static const int standardMonthlyPrice = AppConfig.stdMonthlyKrw;
  static const int standardAnnualPrice  = AppConfig.stdAnnualKrw;
  static const int premiumAnnualPrice   = AppConfig.premAnnualKrw;

  static const int coolingOffHours  = AppConfig.coolingOffHours;
  static const int annualDays       = AppConfig.annualDays;
  static const int minRefundAmount  = AppConfig.minRefundAmount;
}
