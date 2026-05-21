import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/design_tokens.dart';
import 'providers/app_state.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

// Export AppThemeMode for use in other files
export 'providers/app_state.dart' show AppThemeMode;

// ── 인증 게이트 ────────────────────────────────────────────────────────────────
// isLoggedIn 변경 시 AnimatedSwitcher가 LoginPage ↔ _MainNavigator를 슬라이드 전환.
// 로그아웃은 appState.logout() 한 줄이면 충분 — popUntil 불필요.

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AppState>().isLoggedIn;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, animation) {
        // 로그인 화면은 서재의 왼쪽에 위치
        // 로그인 → 서재: 서재가 오른쪽에서 진입, 로그인이 왼쪽으로 퇴장
        // 서재 → 로그인: 로그인이 왼쪽에서 진입, 서재가 오른쪽으로 퇴장
        final isLoginChild = child.key == const ValueKey('login');
        final begin = isLoginChild ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
        return SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      child: isLoggedIn
          ? const _MainNavigator(key: ValueKey('home'))
          : const LoginPage(key: ValueKey('login')),
    );
  }
}

// ── 메인 내부 네비게이터 ────────────────────────────────────────────────────────
// HomePage + SettingsPage 등 로그인 후 화면을 독립된 Navigator로 관리.
// 로그아웃 시 이 Navigator 전체가 unmount → popUntil 없이 깔끔하게 전환됨.
class _MainNavigator extends StatelessWidget {
  const _MainNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
    );
  }
}

/// 색상 필터 매트릭스를 단위 행렬(identity)과 intensity 비율로 보간
List<double> _scaleMatrix(List<double> m, double intensity) {
  const id = [
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];
  return List.generate(20, (i) => id[i] + (m[i] - id[i]) * intensity);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.loadState();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const ReviApp(),
    ),
  );
}

class ReviApp extends StatelessWidget {
  const ReviApp({super.key});

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: DesignTokens.bgIvory,
      appBarTheme: AppBarTheme(
        backgroundColor: DesignTokens.bgIvory,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: DesignTokens.solwayBold700(20),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: DesignTokens.bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: DesignTokens.bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: DesignTokens.solwayBold700(20, DesignTokens.inkDark),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, appState, __) {
        // 테마 모드에 따라 색상 필터 결정
        List<double>? colorMatrix;
        switch (appState.themeMode) {
          case AppThemeMode.light:
            colorMatrix = null;
          case AppThemeMode.rest:
            colorMatrix = _scaleMatrix(DesignTokens.restModeMatrix, appState.themeIntensity);
          case AppThemeMode.dark:
            colorMatrix = _scaleMatrix(DesignTokens.darkModeMatrix, appState.themeIntensity);
          case AppThemeMode.sepia:
            colorMatrix = _scaleMatrix(DesignTokens.sepiaModeMatrix, appState.themeIntensity);
        }

        return MaterialApp(
          title: 'Revi',
          debugShowCheckedModeBanner: false,
          theme: appState.isDark ? _buildDarkTheme() : _buildLightTheme(),
          // Rest/Dark 모드: 블루라이트 필터 적용
          builder: (ctx, child) {
            if (colorMatrix == null) return child!;
            return ColorFiltered(
              colorFilter: ColorFilter.matrix(colorMatrix),
              child: child,
            );
          },
          home: const _AppGate(),
        );
      },
    );
  }
}
