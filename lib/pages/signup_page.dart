import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/google_auth.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailCtrl    = TextEditingController();
  final _pwCtrl       = TextEditingController();
  final _pw2Ctrl      = TextEditingController();
  bool   _obscurePw   = true;
  bool   _obscurePw2  = true;
  bool   _loading     = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    final pw    = _pwCtrl.text;
    final pw2   = _pw2Ctrl.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '올바른 이메일 주소를 입력해주세요.');
      return;
    }
    if (pw.length < 8) {
      setState(() => _error = '비밀번호는 8자 이상이어야 합니다.');
      return;
    }
    if (pw != pw2) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      // pop → login 순서: context가 유효할 때 AppState를 먼저 캡처
      final appState = context.read<AppState>();
      appState.setUserEmail(email);
      Navigator.popUntil(context, (route) => route.isFirst);
      appState.login();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    final bg     = DesignTokens.bgColor(isDark);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 뒤로 ──
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('← 로그인으로',
                    style: DesignTokens.ptSansRegular(
                        12.0, isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
              ),
              const SizedBox(height: 36),

              // ── 타이틀 ──
              Text('계정 만들기',
                  style: DesignTokens.solwayBold700(28,
                      isDark ? DesignTokens.inkDark : DesignTokens.ink)),
              const SizedBox(height: 6),
              Text('Revi와 함께 책의 순간을 기록하세요.',
                  style: DesignTokens.ptSansRegular(
                      12.0, isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
              const SizedBox(height: 36),

              // ── 이메일 ──
              _FieldLabel('이메일', isDark: isDark),
              const SizedBox(height: 6),
              _InputField(
                controller: _emailCtrl,
                hintText: 'hello@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // ── 비밀번호 ──
              _FieldLabel('비밀번호', isDark: isDark),
              const SizedBox(height: 6),
              _InputField(
                controller: _pwCtrl,
                hintText: '8자 이상',
                obscureText: _obscurePw,
                textInputAction: TextInputAction.next,
                isDark: isDark,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePw = !_obscurePw),
                  child: Icon(_obscurePw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 18,
                      color: isDark ? DesignTokens.inkDarkFaint : const Color(0xFFBBBBBB)),
                ),
              ),
              const SizedBox(height: 20),

              // ── 비밀번호 확인 ──
              _FieldLabel('비밀번호 확인', isDark: isDark),
              const SizedBox(height: 6),
              _InputField(
                controller: _pw2Ctrl,
                hintText: '비밀번호를 다시 입력하세요',
                obscureText: _obscurePw2,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                isDark: isDark,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePw2 = !_obscurePw2),
                  child: Icon(_obscurePw2
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 18,
                      color: isDark ? DesignTokens.inkDarkFaint : const Color(0xFFBBBBBB)),
                ),
              ),
              const SizedBox(height: 10),

              // ── 에러 메시지 ──
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(_error!,
                            style: DesignTokens.ptSansRegular(
                                11.0, DesignTokens.terracotta)),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // ── 가입하기 버튼 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.ink,
                    foregroundColor: DesignTokens.bgIvory,
                    disabledBackgroundColor: DesignTokens.ink.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('가입하기',
                          style: DesignTokens.ptSansBold(
                              13.0, DesignTokens.bgIvory)),
                ),
              ),
              const SizedBox(height: 20),

              // ── 구분선 ──
              Row(children: [
                Expanded(child: Divider(
                    color: isDark ? DesignTokens.ruleDark : const Color(0xFFCCCCCC))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('또는',
                      style: DesignTokens.ptSansRegular(
                          10.0, isDark ? DesignTokens.inkDarkFaint : const Color(0xFFAAAAAA))),
                ),
                Expanded(child: Divider(
                    color: isDark ? DesignTokens.ruleDark : const Color(0xFFCCCCCC))),
              ]),
              const SizedBox(height: 16),

              // ── Google로 가입 ──
              OutlinedButton(
                onPressed: () => showGoogleAccountPicker(
                  context,
                  onSelected: () {
                    if (!context.mounted) return;
                    final appState = context.read<AppState>();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    appState.login();
                  },
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 13, height: 13,
                      child: CustomPaint(painter: GoogleLogoPainter()),
                    ),
                    const SizedBox(width: 8),
                    Text('Google로 가입하기',
                        style: DesignTokens.ptSansRegular(
                            12.6, const Color(0xFF3B2015))),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── 이미 계정이 있나요 ──
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      style: DesignTokens.ptSansRegular(
                          10.8, isDark ? DesignTokens.inkDarkMute : const Color(0xFF888888)),
                      children: [
                        const TextSpan(text: '이미 계정이 있으신가요?  '),
                        TextSpan(
                          text: '로그인',
                          style: DesignTokens.ptSansBold(10.8, DesignTokens.sage),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 약관 안내 ──
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '가입하면 서비스 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주됩니다.',
                  textAlign: TextAlign.center,
                  style: DesignTokens.ptSansRegular(
                      9.5, isDark ? DesignTokens.inkDarkFaint : const Color(0xFFBBBBBB)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 내부 헬퍼 위젯 ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _FieldLabel(this.label, {required this.isDark});

  @override
  Widget build(BuildContext context) => Text(label,
      style: DesignTokens.ptSansBold(
          10.5, isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final bool isDark;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.isDark,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: DesignTokens.ptSansRegular(12.6,
          isDark ? DesignTokens.inkDark : DesignTokens.ink),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: DesignTokens.ptSansRegular(
            12.6, isDark ? DesignTokens.inkDarkFaint : const Color(0xFFAAAAAA)),
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
                color: isDark ? DesignTokens.ruleDark : const Color(0xFFBBBBBB))),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: DesignTokens.sage)),
        contentPadding: const EdgeInsets.only(top: 9, bottom: 7),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

