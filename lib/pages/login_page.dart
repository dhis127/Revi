import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/google_auth.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  late AnimationController _swipeController;
  late Animation<double> _swipeAnim;
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;
  bool _isKeyboardActive = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode()..addListener(_onFocusChange);
    _passwordFocus = FocusNode()..addListener(_onFocusChange);
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3170),
    )..repeat();

    _swipeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 12), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 12, end: 5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 5, end: 12), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 12, end: 5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 5, end: 12), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 12, end: 0), weight: 15),
    ]).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));
  }

  void _goHome() => context.read<AppState>().login();

  Future<void> _handleGoogleSignIn() async {
    try {
      // 먼저 이전 로그인 세션 시도 (자동 로그인)
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      // 자동 로그인 실패 시 수동 로그인
      account ??= await _googleSignIn.signIn();
      if (account != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  void _onFocusChange() {
    final active = _emailFocus.hasFocus || _passwordFocus.hasFocus;
    if (active != _isKeyboardActive) setState(() => _isKeyboardActive = active);
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;

    return Scaffold(
      backgroundColor: DesignTokens.bgColor(isDark),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity;
          if (v != null && v < -200) {
            _goHome();
          }
        },
        child: Stack(
          children: [
            // ── 메인 영역 ──
            Positioned.fill(
              right: 40,
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                  padding: const EdgeInsets.only(
                      top: 85, left: 24, right: 28, bottom: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // ── 로고 섹션 ──
                    SizedBox(
                      height: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '독서 아카이브',
                            style: DesignTokens.hahmletRegular(
                                    11.55, DesignTokens.highlightSlot3)
                                .copyWith(letterSpacing: 2),
                          ),
                          const SizedBox(height: 15),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text(
                                'Revi',
                                style: DesignTokens.solwayBold700(80),
                              ),
                              Positioned(
                                bottom: -13,
                                left: 4,
                                child: Container(
                                  width: 90,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: DesignTokens.terracotta,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      height: _isKeyboardActive ? 0.0 : 30.0,
                    ),

                    // ── 로그인 섹션 ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Swipe 문구 (10.3 × 1.15 = 11.8)
                        Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedBuilder(
                            animation: _swipeAnim,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_swipeAnim.value, 0),
                                child: child,
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: DesignTokens.ptSansRegular(
                                    11.8, const Color(0xFF3B2015)),
                                children: const [
                                  TextSpan(text: 'Swipe to my '),
                                  TextSpan(
                                    text: 'Revi',
                                    style: TextStyle(
                                      color: DesignTokens.sage,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: 'ew shelf →'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 이메일 입력창 (12 × 1.05 = 12.6)
                        TextField(
                          style: DesignTokens.ptSansRegular(12.6),
                          decoration: InputDecoration(
                            hintText: '이메일',
                            hintStyle: DesignTokens.ptSansRegular(
                                12.6, const Color(0xFFAAAAAA)),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFFBBBBBB)),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: DesignTokens.sage),
                            ),
                            contentPadding:
                                const EdgeInsets.only(top: 9, bottom: 7),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          focusNode: _emailFocus,
                        ),
                        const SizedBox(height: 20),

                        // 비밀번호 입력창 (12 × 1.05 = 12.6)
                        TextField(
                          obscureText: _obscurePassword,
                          focusNode: _passwordFocus,
                          style: DesignTokens.ptSansRegular(12.6),
                          decoration: InputDecoration(
                            hintText: '비밀번호',
                            hintStyle: DesignTokens.ptSansRegular(
                                12.6, const Color(0xFFAAAAAA)),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFFBBBBBB)),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: DesignTokens.sage),
                            ),
                            contentPadding:
                                const EdgeInsets.only(top: 9, bottom: 7),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFFBBBBBB),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // 비밀번호 찾기 (9.4 × 1.05 = 9.9)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '비밀번호를 잊으셨나요?',
                              style: DesignTokens.ptSansRegular(
                                  9.9, const Color(0xFF999999)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 로그인 버튼
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _goHome,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B2015),
                              foregroundColor: DesignTokens.bgIvory,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              elevation: 0,
                            ),
                            child: Text('로그인',
                                style: DesignTokens.ptSansBold(
                                    13.0, DesignTokens.bgIvory)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 구분선 (또는) (9.4 × 1.05 = 9.9)
                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Color(0xFFCCCCCC))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '또는',
                                style: DesignTokens.ptSansRegular(
                                    9.9, const Color(0xFFAAAAAA)),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: Color(0xFFCCCCCC))),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Google 로그인 버튼 (12 × 1.05 = 12.6)
                        OutlinedButton(
                          onPressed: _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                                color: Color(0xFFDDDDDD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CustomPaint(
                                  painter: GoogleLogoPainter(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Google로 계속하기',
                                style: DesignTokens.ptSansRegular(
                                    12.6, const Color(0xFF3B2015)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 회원가입 (10.3 × 1.05 = 10.8)
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupPage()),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: DesignTokens.ptSansRegular(
                                  10.8, const Color(0xFF888888)),
                              children: [
                                const TextSpan(text: '아직 계정이 없으신가요? '),
                                TextSpan(
                                  text: '회원가입',
                                  style: DesignTokens.ptSansBold(
                                      10.8, DesignTokens.sage),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ), // SingleChildScrollView
          ), // Positioned.fill closes here


            // ── 우측 사이드바 ──
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 40,
              child: GestureDetector(
                onTap: _goHome,
                child: Container(
                  color: const Color(0xFF3B2015),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: RichText(
                        text: TextSpan(
                          style: DesignTokens.ptSansRegular(
                                  10.0, Colors.white.withValues(alpha: 0.55))
                              .copyWith(letterSpacing: 1.7325, height: 1.6),
                          children: const [
                            TextSpan(text: 'My Only one Book — '),
                            TextSpan(
                              text: 'Revi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: 'ew shelf'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

