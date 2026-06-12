import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

/// Google 계정 선택 바텀시트를 열고, 계정 선택 후 [onSelected]를 호출.
/// [onSelected]를 생략하면 기본 동작으로 [AppState.login]을 호출.
void showGoogleAccountPicker(BuildContext context, {VoidCallback? onSelected}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _GoogleAccountSheet(
      onSelected: () {
        Navigator.pop(ctx);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!context.mounted) return;
          if (onSelected != null) {
            onSelected();
          } else {
            context.read<AppState>().login();
          }
        });
      },
    ),
  );
}

// ── 바텀시트 ──────────────────────────────────────────────────────────────────

class _GoogleAccountSheet extends StatefulWidget {
  final VoidCallback onSelected;
  const _GoogleAccountSheet({required this.onSelected});

  @override
  State<_GoogleAccountSheet> createState() => _GoogleAccountSheetState();
}

class _GoogleAccountSheetState extends State<_GoogleAccountSheet> {
  bool _loading = false;

  void _select() {
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 900), widget.onSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 0, 0, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),

          // Google 로고 + 헤더
          const SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(painter: GoogleLogoPainter()),
          ),
          const SizedBox(height: 10),
          const Text('계정 선택',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF202124))),
          const SizedBox(height: 4),
          const Text('Revi로 계속하기',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Color(0xFF5F6368))),
          const SizedBox(height: 16),

          const Divider(height: 1, color: Color(0xFFE8EAED)),

          // 계정 목록 or 로딩
          _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF4285F4))),
                  ),
                )
              : Column(
                  children: [
                    _AccountTile(
                      name: '사용자',
                      email: 'revi.reader@gmail.com',
                      onTap: _select,
                    ),
                    const Divider(
                        height: 1,
                        color: Color(0xFFE8EAED),
                        indent: 16,
                        endIndent: 16),
                    _AccountTile(
                      name: '다른 계정 사용',
                      email: '',
                      icon: Icons.person_add_alt_outlined,
                      onTap: _select,
                    ),
                  ],
                ),

          const Divider(height: 1, color: Color(0xFFE8EAED)),

          // 취소
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: Color(0xFF5F6368))),
          ),
        ],
      ),
    );
  }
}

// ── 계정 항목 ─────────────────────────────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final String name;
  final String email;
  final IconData? icon;
  final VoidCallback onTap;
  const _AccountTile({
    required this.name,
    required this.email,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: icon != null
                    ? const Color(0xFFF1F3F4)
                    : const Color(0xFF4285F4),
                shape: BoxShape.circle,
              ),
              child: icon != null
                  ? Icon(icon, size: 20, color: const Color(0xFF5F6368))
                  : const Center(
                      child: Text('사',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF202124))),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(email,
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Color(0xFF5F6368))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google 'G' 로고 페인터 ────────────────────────────────────────────────────

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(_red(size), paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(_blue(size), paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(_yellow(size), paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(_green(size), paint);
  }

  Path _red(Size s) => Path()
    ..moveTo(s.width * 0.5, s.height * 0.198)
    ..cubicTo(s.width * 0.566, s.height * 0.198, s.width * 0.624,
        s.height * 0.221, s.width * 0.670, s.height * 0.258)
    ..lineTo(s.width * 0.797, s.height * 0.131)
    ..cubicTo(s.width * 0.716, s.height * 0.065, s.width * 0.613,
        s.height * 0.021, s.width * 0.5, s.height * 0.021)
    ..cubicTo(s.width * 0.309, s.height * 0.021, s.width * 0.147,
        s.height * 0.135, s.width * 0.076, s.height * 0.298)
    ..lineTo(s.width * 0.224, s.height * 0.413)
    ..cubicTo(s.width * 0.261, s.height * 0.285, s.width * 0.370,
        s.height * 0.198, s.width * 0.5, s.height * 0.198);

  Path _blue(Size s) => Path()
    ..moveTo(s.width * 0.969, s.height * 0.51)
    ..cubicTo(s.width * 0.969, s.height * 0.476, s.width * 0.966,
        s.height * 0.443, s.width * 0.960, s.height * 0.411)
    ..lineTo(s.width * 0.5, s.height * 0.411)
    ..lineTo(s.width * 0.5, s.height * 0.598)
    ..lineTo(s.width * 0.765, s.height * 0.598)
    ..cubicTo(s.width * 0.753, s.height * 0.659, s.width * 0.718,
        s.height * 0.712, s.width * 0.669, s.height * 0.749)
    ..lineTo(s.width * 0.819, s.height * 0.865)
    ..cubicTo(s.width * 0.900, s.height * 0.776, s.width * 0.969,
        s.height * 0.653, s.width * 0.969, s.height * 0.51);

  Path _yellow(Size s) => Path()
    ..moveTo(s.width * 0.224, s.height * 0.587)
    ..cubicTo(s.width * 0.214, s.height * 0.562, s.width * 0.198,
        s.height * 0.537, s.width * 0.198, s.height * 0.5)
    ..cubicTo(s.width * 0.198, s.height * 0.470, s.width * 0.203,
        s.height * 0.440, s.width * 0.214, s.height * 0.413)
    ..lineTo(s.width * 0.076, s.height * 0.298)
    ..cubicTo(s.width * 0.053, s.height * 0.363, s.width * 0.0,
        s.height * 0.430, s.width * 0.0, s.height * 0.5)
    ..cubicTo(s.width * 0.0, s.height * 0.581, s.width * 0.019,
        s.height * 0.657, s.width * 0.053, s.height * 0.725)
    ..lineTo(s.width * 0.224, s.height * 0.587);

  Path _green(Size s) => Path()
    ..moveTo(s.width * 0.5, s.height * 0.979)
    ..cubicTo(s.width * 0.614, s.height * 0.979, s.width * 0.710,
        s.height * 0.941, s.width * 0.780, s.height * 0.876)
    ..lineTo(s.width * 0.630, s.height * 0.760)
    ..cubicTo(s.width * 0.592, s.height * 0.785, s.width * 0.548,
        s.height * 0.802, s.width * 0.5, s.height * 0.802)
    ..cubicTo(s.width * 0.370, s.height * 0.802, s.width * 0.261,
        s.height * 0.715, s.width * 0.224, s.height * 0.587)
    ..lineTo(s.width * 0.053, s.height * 0.725)
    ..cubicTo(s.width * 0.147, s.height * 0.865, s.width * 0.309,
        s.height * 0.979, s.width * 0.5, s.height * 0.979);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
