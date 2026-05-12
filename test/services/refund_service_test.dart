import 'package:flutter_test/flutter_test.dart';
import 'package:revi/models/refund_result.dart';
import 'package:revi/services/refund_service.dart';

void main() {
  final svc = RefundService.instance;

  // ── 기준 날짜 ────────────────────────────────────────────────────────────
  // purchaseDate: 2026-01-01 00:00:00
  // expiresAt(연구독): 2026-12-31 00:00:00
  final purchaseDate = DateTime(2026, 1, 1);
  final expiresAtAnnual = DateTime(2026, 12, 31);

  group('isCoolingOff()', () {
    // ── 케이스 1: 쿨링오프 — 결제 후 71시간 → 전액 환불 ────────────────────
    test('1. 결제 후 71시간 → 쿨링오프 true', () {
      final request = purchaseDate.add(const Duration(hours: 71));
      expect(svc.isCoolingOff(purchaseDate, request), isTrue);
    });

    // ── 케이스 2: 쿨링오프 경계 — 정확히 72시간 → 쿨링오프 미적용 ────────
    test('2. 결제 후 정확히 72시간 → 쿨링오프 false', () {
      final request = purchaseDate.add(const Duration(hours: 72));
      expect(svc.isCoolingOff(purchaseDate, request), isFalse);
    });
  });

  group('calculateRefund() — 쿨링오프', () {
    // ── 케이스 1 전체: 71시간 후 해지 → 프리미엄 연구독 전액 환불 ────────
    test('1. 쿨링오프 71h → 전액 환불 (프리미엄 연구독 ₩69,900)', () {
      final request = purchaseDate.add(const Duration(hours: 71));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate,
        expiresAt: expiresAtAnnual,
        requestDate: request,
        isCancellation: true,
      );
      expect(result.refundType, RefundType.coolingOff);
      expect(result.refundAmount, 69900);
    });

    // ── 쿨링오프: 스탠다드 월구독 전액 환불 ──────────────────────────────
    test('쿨링오프 → 스탠다드 월구독 전액 환불 (₩4,900)', () {
      final request = purchaseDate.add(const Duration(hours: 1));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.standard,
        currentBillingType: SubscriptionBillingType.monthly,
        purchaseDate: purchaseDate,
        expiresAt: purchaseDate.add(const Duration(days: 30)),
        requestDate: request,
        isCancellation: true,
      );
      expect(result.refundType, RefundType.coolingOff);
      expect(result.refundAmount, 4900);
    });
  });

  group('calculateRefund() — 케이스 A (연→연 다운그레이드)', () {
    // ── 케이스 3: 프리미엄(연) → 스탠다드(연), 남은 200일 → ₩16,438 ─────
    // daily diff = (69900 - 39900) / 365 = 30000 / 365 ≈ 82.1917...
    // raw = floor(82.1917 * 200) = floor(16438.35...) = 16438
    test('3. 프리미엄(연) → 스탠다드(연), 200일 → ₩16,438', () {
      // requestDate = expiresAt - 200 days
      final requestDate = expiresAtAnnual.subtract(const Duration(days: 200));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate.subtract(const Duration(days: 200)),
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        targetPlan: SubscriptionPlan.standard,
        targetBillingType: SubscriptionBillingType.annual,
        isCancellation: false,
      );
      expect(result.refundType, RefundType.proratedDiff);
      expect(result.refundAmount, 16438);
      expect(result.expiresAt, expiresAtAnnual); // 만료일 유지
    });

    // ── 케이스 4: 프리미엄(연) → 스탠다드(연), 남은 1일 ─────────────────
    // daily diff ≈ 82.19, raw = floor(82.19 * 1) = 82 → 100원 미만 → 0
    test('4. 프리미엄(연) → 스탠다드(연), 1일 → ₩0 (100원 미만 threshold)', () {
      final requestDate = expiresAtAnnual.subtract(const Duration(days: 1));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate.subtract(const Duration(days: 300)),
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        targetPlan: SubscriptionPlan.standard,
        targetBillingType: SubscriptionBillingType.annual,
        isCancellation: false,
      );
      expect(result.refundAmount, 0);
      expect(result.refundType, RefundType.noRefund);
    });
  });

  group('calculateRefund() — 케이스 B·C (연→월 다운그레이드)', () {
    // ── 케이스 5: 프리미엄(연) → 스탠다드(월), 200일 → ₩38,301 ──────────
    // daily rate = 69900 / 365 ≈ 191.506...
    // raw = floor(191.506 * 200) = floor(38301.36...) = 38301
    test('5. 프리미엄(연) → 스탠다드(월), 200일 → ₩38,301', () {
      final requestDate = expiresAtAnnual.subtract(const Duration(days: 200));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate.subtract(const Duration(days: 200)),
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        targetPlan: SubscriptionPlan.standard,
        targetBillingType: SubscriptionBillingType.monthly,
        isCancellation: false,
      );
      expect(result.refundType, RefundType.proratedFull);
      expect(result.refundAmount, 38301);
      // 신규 만료일 = 요청일 + 30일
      expect(result.expiresAt, requestDate.add(const Duration(days: 30)));
    });

    // ── 케이스 6: 스탠다드(연) → 스탠다드(월), 100일 ────────────────────
    // daily rate = 39900 / 365 ≈ 109.315...
    // raw = floor(109.315 * 100) = floor(10931.5...) = 10931
    test('6. 스탠다드(연) → 스탠다드(월), 100일 → ₩10,931', () {
      final requestDate = expiresAtAnnual.subtract(const Duration(days: 100));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.standard,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate.subtract(const Duration(days: 265)),
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        targetPlan: SubscriptionPlan.standard,
        targetBillingType: SubscriptionBillingType.monthly,
        isCancellation: false,
      );
      expect(result.refundType, RefundType.proratedFull);
      expect(result.refundAmount, 10931);
    });
  });

  group('calculateRefund() — 쿨링오프 이후 해지 (환불 없음)', () {
    // ── 케이스 7: 프리미엄(연) 해지 → 환불 0, expiresAt 유지 ─────────────
    test('7. 프리미엄(연) 쿨링오프 이후 해지 → refundAmount 0, expiresAt 유지', () {
      final requestDate = purchaseDate.add(const Duration(days: 30));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate,
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        isCancellation: true,
      );
      expect(result.refundType, RefundType.noRefund);
      expect(result.refundAmount, 0);
      expect(result.expiresAt, expiresAtAnnual);
    });

    // ── 케이스 8: 스탠다드(연) 해지 → 환불 0, expiresAt 유지 ─────────────
    test('8. 스탠다드(연) 쿨링오프 이후 해지 → refundAmount 0, expiresAt 유지', () {
      final requestDate = purchaseDate.add(const Duration(days: 10));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.standard,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate,
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        isCancellation: true,
      );
      expect(result.refundType, RefundType.noRefund);
      expect(result.refundAmount, 0);
      expect(result.expiresAt, expiresAtAnnual);
    });

    // ── 케이스 9: 스탠다드(월) 해지 → 환불 0, expiresAt 유지 ─────────────
    test('9. 스탠다드(월) 쿨링오프 이후 해지 → refundAmount 0, expiresAt 유지', () {
      final monthlyExpiry = purchaseDate.add(const Duration(days: 30));
      final requestDate = purchaseDate.add(const Duration(days: 10));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.standard,
        currentBillingType: SubscriptionBillingType.monthly,
        purchaseDate: purchaseDate,
        expiresAt: monthlyExpiry,
        requestDate: requestDate,
        isCancellation: true,
      );
      expect(result.refundType, RefundType.noRefund);
      expect(result.refundAmount, 0);
      expect(result.expiresAt, monthlyExpiry);
    });
  });

  group('calculateRefund() — 최소 환불 threshold (₩100)', () {
    // ── 케이스 10: 일할 환불액이 100원 미만 → refundAmount == 0 ──────────
    // Standard(연) → Standard(월), 남은 0일
    test('10. 잔여 0일 → 환불액 0 (threshold 미달)', () {
      final requestDate = expiresAtAnnual; // 만료 당일 = 잔여 0일
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.standard,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate.subtract(const Duration(days: 1)),
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        targetPlan: SubscriptionPlan.standard,
        targetBillingType: SubscriptionBillingType.monthly,
        isCancellation: false,
      );
      expect(result.refundAmount, 0);
    });

    // 연→연, 잔여 1일 (82원 < 100원)
    test('10b. 케이스 A, 잔여 1일 → 82원 → threshold 미달 → ₩0', () {
      final requestDate = expiresAtAnnual.subtract(const Duration(days: 1));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate.subtract(const Duration(days: 1)),
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        targetPlan: SubscriptionPlan.standard,
        targetBillingType: SubscriptionBillingType.annual,
        isCancellation: false,
      );
      // daily diff = (69900-39900)/365 ≈ 82.19 → floor = 82 < 100
      expect(result.refundAmount, 0);
      expect(result.refundType, RefundType.noRefund);
    });
  });

  group('processRefund()', () {
    test('refundAmount > 0 → status pending', () async {
      final request = purchaseDate.add(const Duration(hours: 1));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate,
        expiresAt: expiresAtAnnual,
        requestDate: request,
        isCancellation: true,
      );
      final record = await svc.processRefund('user_test', result, 'pay_abc');
      expect(record.status.name, 'pending');
      expect(record.refundAmount, 69900);
    });

    test('refundAmount == 0 → status completed', () async {
      final requestDate = purchaseDate.add(const Duration(days: 10));
      final result = svc.calculateRefund(
        currentPlan: SubscriptionPlan.premium,
        currentBillingType: SubscriptionBillingType.annual,
        purchaseDate: purchaseDate,
        expiresAt: expiresAtAnnual,
        requestDate: requestDate,
        isCancellation: true,
      );
      final record = await svc.processRefund('user_test2', result, 'pay_xyz');
      expect(record.status.name, 'completed');
      expect(record.refundAmount, 0);
    });
  });

  group('시나리오별 계산 결과 출력 (검증용)', () {
    test('샘플 출력', () {
      final now = DateTime(2026, 5, 10);
      final scenarios = [
        ('프리미엄(연) → 스탠다드(연), 200일', () {
          final expiresAt = now.add(const Duration(days: 200));
          return svc.calculateRefund(
            currentPlan: SubscriptionPlan.premium,
            currentBillingType: SubscriptionBillingType.annual,
            purchaseDate: now.subtract(const Duration(days: 165)),
            expiresAt: expiresAt,
            requestDate: now,
            targetPlan: SubscriptionPlan.standard,
            targetBillingType: SubscriptionBillingType.annual,
            isCancellation: false,
          );
        }),
        ('프리미엄(연) → 스탠다드(월), 200일', () {
          final expiresAt = now.add(const Duration(days: 200));
          return svc.calculateRefund(
            currentPlan: SubscriptionPlan.premium,
            currentBillingType: SubscriptionBillingType.annual,
            purchaseDate: now.subtract(const Duration(days: 165)),
            expiresAt: expiresAt,
            requestDate: now,
            targetPlan: SubscriptionPlan.standard,
            targetBillingType: SubscriptionBillingType.monthly,
            isCancellation: false,
          );
        }),
        ('스탠다드(연) 해지 (쿨링오프 이후)', () {
          final expiresAt = now.add(const Duration(days: 100));
          return svc.calculateRefund(
            currentPlan: SubscriptionPlan.standard,
            currentBillingType: SubscriptionBillingType.annual,
            purchaseDate: now.subtract(const Duration(days: 265)),
            expiresAt: expiresAt,
            requestDate: now,
            isCancellation: true,
          );
        }),
        ('쿨링오프 71h → 스탠다드(연) 전액 환불', () {
          final purchase = now.subtract(const Duration(hours: 71));
          return svc.calculateRefund(
            currentPlan: SubscriptionPlan.standard,
            currentBillingType: SubscriptionBillingType.annual,
            purchaseDate: purchase,
            expiresAt: purchase.add(const Duration(days: 365)),
            requestDate: now,
            isCancellation: true,
          );
        }),
      ];

      for (final (label, fn) in scenarios) {
        final r = fn();
        // ignore: avoid_print
        print('[$label]\n'
            '  refundType   : ${r.refundType.name}\n'
            '  refundAmount : ${r.refundAmount}원\n'
            '  remainingDays: ${r.remainingDays}일\n'
            '  expiresAt    : ${r.expiresAt.toIso8601String().substring(0, 10)}\n'
            '  userMessage  : ${r.userMessage}\n');
      }
    });
  });
}
