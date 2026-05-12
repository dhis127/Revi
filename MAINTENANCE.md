# Revi 유지보수 가이드
> 비개발자용 · 최종 수정: 2026-05

---

## 핵심 원칙

**모든 숫자와 문구 변경은 딱 한 파일에서 합니다.**

```
lib/config/app_config.dart
```

이 파일만 열면 가격, 한도, Paywall 문구를 전부 바꿀 수 있습니다.  
변경 후에는 **반드시 개발자에게 빌드/배포를 요청**하세요.  
코드만 바꿔도 App Store에 올라가지 않으면 유저에게는 반영되지 않습니다.

---

## 상황별 대응 가이드

### 가격을 바꾸고 싶을 때

1. `lib/config/app_config.dart` 를 텍스트 에디터로 열기
2. 아래 줄의 숫자만 수정

```dart
static const int stdMonthlyKrw = 4900;   // ← 월구독 가격
static const int stdAnnualKrw  = 39900;  // ← 연구독 가격
static const int premAnnualKrw = 69900;  // ← 프리미엄 가격
```

3. 저장 후 개발자에게 빌드 요청  
4. ⚠️ **App Store Connect**에서도 실제 결제 가격을 같은 금액으로 변경

> 화면에 표시되는 "월 ₩3,325 · 4개월 공짜" 같은 문구는 자동으로 재계산됩니다.

---

### 무료/유료 한도를 바꾸고 싶을 때

`lib/config/app_config.dart` 에서 해당 숫자 변경:

```dart
static const int freeMaxBooks      = 5;    // 무료 책 저장 한도
static const int freeMaxHighlights = 50;   // 무료 문장 저장 한도
static const int stdMaxBooks       = 100;  // 스탠다드 책 저장 한도
```

---

### Paywall(구독 유도 화면) 혜택 문구를 바꾸고 싶을 때

`lib/config/app_config.dart` 의 `stdFeatures` 목록 수정:

```dart
static const List<PaywallFeature> stdFeatures = [
  PaywallFeature('◎', 'OCR 스캔 무제한', '하루 제한 없이 페이지를 스캔하세요'),
  //             아이콘  굵은 제목          회색 부연 설명
  ...
];
```

항목 순서를 바꾸거나, 텍스트를 수정하면 Paywall 화면에 바로 반영됩니다.

---

### CQ(책계일주) 멤버 할인 금액을 바꾸고 싶을 때

```dart
static const int cqTravelerDiscount    = 10000; // Traveler 멤버 할인액
static const int cqBookdrunkerDiscount = 20000; // Bookdrunker 멤버 할인액
```

할인 후 최종 가격("→ ₩29,900/년")은 자동으로 계산됩니다.

---

### 환불 정책을 바꾸고 싶을 때

```dart
static const int coolingOffHours = 72;  // 전액 환불 가능 시간 (시간 단위)
static const int minRefundAmount = 100; // 이 금액 미만이면 환불 생략
```

> ⚠️ 쿨링오프 기간은 한국 전자상거래법 기준을 확인한 후 변경하세요.

---

## 직접 건드리면 안 되는 것들

| 하면 안 되는 것 | 이유 |
|---|---|
| `lib/config/app_config.dart` 외 파일의 숫자 직접 수정 | 한 곳만 바꾸면 다른 곳이 불일치 |
| `pubspec.yaml` 수정 | 패키지 버전 충돌 위험 |
| `ios/` 폴더 내 파일 수정 | Xcode 설정 손상 위험 |
| `lib/models/` 파일 수정 | 데이터 구조 변경 → 앱 전체 오류 |
| Git commit 없이 파일 교체 | 이전 버전으로 복구 불가 |

---

## 버그 발생 시 체크리스트

버그 신고 전에 아래를 먼저 확인하세요. 개발자에게 이 정보를 전달하면 수정이 빨라집니다.

- [ ] 어떤 화면에서 발생했나요?
- [ ] 어떤 동작을 했을 때 발생했나요? (예: "스캔 → 저장 버튼 탭")
- [ ] 어떤 기기/iOS 버전인가요?
- [ ] 무료 유저인가요, 구독 유저인가요?
- [ ] 재현 가능한가요? (같은 동작을 반복하면 항상 발생하나요?)
- [ ] 스크린샷 또는 화면 녹화

---

## 향후 개발 예정 (Phase 3)

아래 기능은 아직 연결되지 않은 상태입니다. 개발자와 함께 진행해야 합니다.

| 기능 | 설명 |
|---|---|
| 실제 결제 | RevenueCat + App Store 인앱결제 연동 |
| OCR (문자 인식) | 카메라로 찍은 페이지에서 텍스트 자동 추출 |
| 계정·데이터 동기화 | Supabase 서버 연결 (지금은 기기 내 저장) |
| 푸시 알림 | 문장 리마인더 실제 작동 |
| AI 독서 리포트 | 실제 데이터 기반 월간 리포트 생성 |
| 데이터 내보내기 | CSV/PDF/MD 실제 파일 생성 및 공유 |

Phase 3 연결 시 `lib/config/app_config.dart` 하단의 주석 처리된 상수들을 채우면 됩니다.

---

## 배포 절차 요약

코드 변경 → 개발자에게 전달 → 빌드 (flutter build ipa) → App Store Connect 업로드 → 심사 제출 → 승인 후 배포

App Store 심사는 보통 1~3일 소요됩니다. 긴급 수정이 필요하면 Apple Expedited Review를 요청할 수 있습니다.
