import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/design_tokens.dart';
import 'providers/app_state.dart';
import 'pages/login_page.dart';

// Export AppThemeMode for use in other files
export 'providers/app_state.dart' show AppThemeMode;

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

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
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
          home: const LoginPage(),
        );
      },
    );
  }
}
