import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:revi/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('로그아웃 시 로그인 화면으로 전환 테스트', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 1. 로그인 화면 확인
    expect(find.text('Revi'), findsOneWidget);
    debugPrint('[TEST] ✓ 로그인 화면 확인');

    // 2. 우측 사이드바 탭 → 로그인
    // 화면 우측 끝 탭
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width - 10, size.height / 2));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    debugPrint('[TEST] ✓ 우측 사이드바 탭 → 로그인');

    // 3. 홈 화면 확인 (내 책장 텍스트)
    expect(find.text('내 책장'), findsWidgets);
    debugPrint('[TEST] ✓ 홈 화면 진입 확인');

    // 4. 설정 아이콘 탭
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    debugPrint('[TEST] ✓ 설정 화면 진입');

    // 5. 로그아웃 버튼 탭
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    debugPrint('[TEST] ✓ 로그아웃 다이얼로그 열림');

    // 6. 다이얼로그 확인
    expect(find.text('로그아웃 하시겠습니까?'), findsOneWidget);
    debugPrint('[TEST] ✓ 다이얼로그 내용 확인');

    // 7. "예" 버튼 탭
    await tester.tap(find.text('예'));
    await tester.pumpAndSettle(const Duration(seconds: 2)); // 애니메이션 대기

    debugPrint('[TEST] ✓ 예 버튼 탭');

    // 8. 로그인 화면으로 복귀 확인
    expect(find.text('Revi'), findsOneWidget);
    expect(find.text('내 책장'), findsNothing);
    debugPrint('[TEST] ✓✓✓ 로그아웃 후 로그인 화면 복귀 확인 완료!');
  });
}
