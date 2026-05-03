import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import 'home_page.dart';

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

  @override
  void initState() {
    super.initState();
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

  void _goHome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bgIvory,
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
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 85, left: 24, right: 28, bottom: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // ── 로고 섹션 (Expanded로 여백 유지) ──
                    Expanded(
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
                        ),
                        const SizedBox(height: 20),

                        // 비밀번호 입력창 (12 × 1.05 = 12.6)
                        TextField(
                          obscureText: _obscurePassword,
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

                        // Google 로그인 버튼 (12 × 1.05 = 12.6, 높이 살짝 증가)
                        OutlinedButton(
                          onPressed: _goHome,
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
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CustomPaint(
                                  painter: _GoogleLogoPainter(),
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
                        RichText(
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Positioned.fill closes here
            ),

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

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.198)
      ..cubicTo(size.width * 0.566, size.height * 0.198, size.width * 0.624,
          size.height * 0.221, size.width * 0.670, size.height * 0.258)
      ..lineTo(size.width * 0.797, size.height * 0.131)
      ..cubicTo(size.width * 0.716, size.height * 0.065, size.width * 0.613,
          size.height * 0.021, size.width * 0.5, size.height * 0.021)
      ..cubicTo(size.width * 0.309, size.height * 0.021, size.width * 0.147,
          size.height * 0.135, size.width * 0.076, size.height * 0.298)
      ..lineTo(size.width * 0.224, size.height * 0.413)
      ..cubicTo(size.width * 0.261, size.height * 0.285, size.width * 0.370,
          size.height * 0.198, size.width * 0.5, size.height * 0.198);
    canvas.drawPath(redPath, paint);

    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(size.width * 0.969, size.height * 0.51)
      ..cubicTo(size.width * 0.969, size.height * 0.476, size.width * 0.966,
          size.height * 0.443, size.width * 0.960, size.height * 0.411)
      ..lineTo(size.width * 0.5, size.height * 0.411)
      ..lineTo(size.width * 0.5, size.height * 0.598)
      ..lineTo(size.width * 0.765, size.height * 0.598)
      ..cubicTo(size.width * 0.753, size.height * 0.659, size.width * 0.718,
          size.height * 0.712, size.width * 0.669, size.height * 0.749)
      ..lineTo(size.width * 0.819, size.height * 0.865)
      ..cubicTo(size.width * 0.900, size.height * 0.776, size.width * 0.969,
          size.height * 0.653, size.width * 0.969, size.height * 0.51);
    canvas.drawPath(bluePath, paint);

    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(size.width * 0.224, size.height * 0.587)
      ..cubicTo(size.width * 0.214, size.height * 0.562, size.width * 0.198,
          size.height * 0.537, size.width * 0.198, size.height * 0.5)
      ..cubicTo(size.width * 0.198, size.height * 0.470, size.width * 0.203,
          size.height * 0.440, size.width * 0.214, size.height * 0.413)
      ..lineTo(size.width * 0.076, size.height * 0.298)
      ..cubicTo(size.width * 0.053, size.height * 0.363, size.width * 0.0,
          size.height * 0.430, size.width * 0.0, size.height * 0.5)
      ..cubicTo(size.width * 0.0, size.height * 0.581, size.width * 0.019,
          size.height * 0.657, size.width * 0.053, size.height * 0.725)
      ..lineTo(size.width * 0.224, size.height * 0.587);
    canvas.drawPath(yellowPath, paint);

    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.979)
      ..cubicTo(size.width * 0.614, size.height * 0.979, size.width * 0.710,
          size.height * 0.941, size.width * 0.780, size.height * 0.876)
      ..lineTo(size.width * 0.630, size.height * 0.760)
      ..cubicTo(size.width * 0.592, size.height * 0.785, size.width * 0.548,
          size.height * 0.802, size.width * 0.5, size.height * 0.802)
      ..cubicTo(size.width * 0.370, size.height * 0.802, size.width * 0.261,
          size.height * 0.715, size.width * 0.224, size.height * 0.587)
      ..lineTo(size.width * 0.053, size.height * 0.725)
      ..cubicTo(size.width * 0.147, size.height * 0.865, size.width * 0.309,
          size.height * 0.979, size.width * 0.5, size.height * 0.979);
    canvas.drawPath(greenPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
