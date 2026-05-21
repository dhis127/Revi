// ════════════════════════════════════════════════════════════════════════════
//  Revi — AppConfig
//  비개발자 유지보수 가이드: 이 파일의 값을 바꾸면 앱 전체에 반영됩니다.
//  변경 후 개발자에게 빌드/배포를 요청하세요.
// ════════════════════════════════════════════════════════════════════════════

class AppConfig {
  AppConfig._();

  // ──────────────────────────────────────────────────────────────────────────
  // 1. 구독 가격 (원 단위 정수)
  //
  // ⚠️ 가격 변경 시 Apple 개발자 콘솔(App Store Connect)에서도 반드시 변경하세요.
  //    앱 코드만 바꾸면 실제 결제 금액은 바뀌지 않습니다.
  // ──────────────────────────────────────────────────────────────────────────
  static const int stdMonthlyKrw = 4900;   // 스탠다드 월구독
  static const int stdAnnualKrw  = 39900;  // 스탠다드 연구독
  static const int premAnnualKrw = 69900;  // 프리미엄 연구독

  // CQ(책계일주) 멤버 할인 금액
  static const int cqTravelerDiscount    = 10000; // Traveler 멤버 스탠다드 연간 할인
  static const int cqBookdrunkerDiscount = 20000; // Bookdrunker 멤버 프리미엄 연간 할인

  // ── 자동 계산 (직접 수정 불필요) ──────────────────────────────────────────
  static int    get stdAnnualMonthlyRate  => (stdAnnualKrw / 12).round();
  static int    get premAnnualMonthlyRate => (premAnnualKrw / 12).round();
  static int    get stdFreeMonths         => ((stdMonthlyKrw * 12 - stdAnnualKrw) / stdMonthlyKrw).round();
  static int    get cqStdAnnualFinal      => stdAnnualKrw - cqTravelerDiscount;
  static int    get cqPremAnnualFinal     => premAnnualKrw - cqBookdrunkerDiscount;
  static String get cqTravelerRow         => '스탠다드 연간 ₩${_krw(cqTravelerDiscount)} 할인 → ₩${_krw(cqStdAnnualFinal)}/년';
  static String get cqBookdrunkerRow      => '프리미엄 연간 ₩${_krw(cqBookdrunkerDiscount)} 할인 → ₩${_krw(cqPremAnnualFinal)}/년';

  // ── 화면에 표시되는 가격 문자열 (자동 생성) ──────────────────────────────
  static String get stdMonthlyLabel       => '₩${_krw(stdMonthlyKrw)}';
  static String get stdAnnualLabel        => '₩${_krw(stdAnnualKrw)}';
  static String get premAnnualLabel       => '₩${_krw(premAnnualKrw)}';
  static String get stdAnnualSubtitle     => '월 ₩${_krw(stdAnnualMonthlyRate)} · $stdFreeMonths개월 공짜';
  static String get premAnnualSubtitle    => '월 ₩${_krw(premAnnualMonthlyRate)} · AI 심층 리포트 포함';

  // ──────────────────────────────────────────────────────────────────────────
  // 2. 플랜별 저장 한도
  //
  // 숫자만 바꾸면 앱 전체 한도가 변경됩니다.
  // 999999 = 사실상 무제한 (Phase 3에서 서버 무제한으로 교체 예정)
  // ──────────────────────────────────────────────────────────────────────────
  static const int freeMaxBooks      = 5;
  static const int freeMaxHighlights = 50;
  static const int freeMaxShelves    = 1;
  static const int freeMaxSlots      = 3;
  static const int freeMaxFonts      = 3;

  static const int stdMaxBooks       = 100;
  static const int stdMaxHighlights  = 999999;
  static const int stdMaxShelves     = 10;
  static const int stdMaxSlots       = 3;
  static const int stdMaxFonts       = 10;

  static const int premMaxBooks      = 999999;
  static const int premMaxHighlights = 999999;
  static const int premMaxShelves    = 999999;
  static const int premMaxSlots      = 7;
  static const int premMaxFonts      = 50;

  // ──────────────────────────────────────────────────────────────────────────
  // 3. 환불 정책 상수
  //
  // 쿨링오프 기간이나 최소 환불액을 바꾸고 싶을 때 여기서 수정하세요.
  // 법적 기준(한국 전자상거래법)을 확인한 후 변경하세요.
  // ──────────────────────────────────────────────────────────────────────────
  static const int coolingOffHours  = 72;   // 전액 환불 가능 시간 (72시간 = 3일)
  static const int annualDays       = 365;  // 연구독 일할 계산 기준일
  static const int minRefundAmount  = 100;  // 이 금액 미만이면 환불 생략 (원)

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Paywall(구독 유도 화면) 혜택 문구
  //
  // 마케팅 문구를 바꾸고 싶을 때 여기서 수정하세요.
  // icon은 텍스트 기호, title은 굵게 표시되는 짧은 제목, subtitle은 부연 설명입니다.
  // ──────────────────────────────────────────────────────────────────────────
  static const List<PaywallFeature> stdFeatures = [
    PaywallFeature('◎', 'OCR 스캔 무제한',        '하루 제한 없이 페이지를 스캔하세요'),
    PaywallFeature('⊞', '책 100권 · 문장 무제한',  '무료 5권 · 50개 한도가 사라져요'),
    PaywallFeature('≡', '책장 10개 슬롯',          '무료 1개에서 10개로 자유롭게 분류하세요'),
    PaywallFeature('◑', 'AI 기본 독서 리포트',      '한 달의 독서를 분석해 매월 리포트를 보내드려요'),
    PaywallFeature('↑', 'CSV 내보내기',            '저장한 문장을 언제든 꺼낼 수 있어요'),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Phase 3 연결 포인트 (Supabase + RevenueCat)
  //
  // 실제 서비스 연동 시 주석을 해제하고 값을 채우세요.
  // ──────────────────────────────────────────────────────────────────────────
  // static const String supabaseUrl      = 'https://YOUR_PROJECT.supabase.co';
  // static const String supabaseAnonKey  = 'YOUR_ANON_KEY';
  // static const String revenueCatApiKey = 'YOUR_REVENUECAT_KEY';
  // static const String rcStdMonthlyId   = 'revi_standard_monthly';
  // static const String rcStdAnnualId    = 'revi_standard_annual';
  // static const String rcPremAnnualId   = 'revi_premium_annual';

  // ──────────────────────────────────────────────────────────────────────────
  // 내부 헬퍼 — 수정 불필요
  // ──────────────────────────────────────────────────────────────────────────
  static String _krw(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Paywall 혜택 항목 데이터 클래스
class PaywallFeature {
  final String icon;
  final String title;
  final String subtitle;
  const PaywallFeature(this.icon, this.title, this.subtitle);
}
