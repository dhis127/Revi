import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/design_tokens.dart';
import 'providers/app_state.dart';
import 'pages/login_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      ),
      home: const LoginPage(),
    );
  }
}
