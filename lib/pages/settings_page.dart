import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../providers/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity;
        if (v != null && v > 200) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: DesignTokens.bgIvory,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('← 서재', style: DesignTokens.hahmlet(13, color: DesignTokens.inkMute)),
                      ),
                      const Spacer(),
                      Text('SETTINGS',
                          style: DesignTokens.ptSans(10, weight: FontWeight.w700, color: DesignTokens.inkMute)
                              .copyWith(letterSpacing: 1.5)),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: Text('설정',
                    style: DesignTokens.hahmlet(26, weight: FontWeight.w600).copyWith(letterSpacing: -0.2)),
              ),

              // ── 화면 표시 ──
              _Group(
                title: '화면 표시',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: DesignTokens.hahmlet(13),
                                  children: [
                                    const TextSpan(text: '주요 폰트 — '),
                                    TextSpan(
                                      text: '23 / 50 글꼴',
                                      style: DesignTokens.hahmlet(13, weight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: DesignTokens.ink),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('업데이트', style: DesignTokens.hahmlet(11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: 0.46,
                            minHeight: 6,
                            backgroundColor: DesignTokens.bgIvoryEdge,
                            valueColor: const AlwaysStoppedAnimation(DesignTokens.terracotta),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: DesignTokens.rule),
                  _Row(
                    label: '테마',
                    value: state.isDark ? '다크' : '라이트',
                    onTap: () => context.read<AppState>().toggleTheme(),
                    last: true,
                  ),
                ],
              ),

              // ── 노트 부분 ──
              _Group(
                title: '노트 부분',
                children: [
                  _SwatchRow(label: '슬롯 1 · Sage',       color: DesignTokens.sageSoft),
                  _SwatchRow(label: '슬롯 2 · Terracotta', color: DesignTokens.terracotta),
                  _SwatchRow(label: '슬롯 3 · Amber Oak',  color: DesignTokens.amber, last: true),
                ],
              ),

              // ── 계정 ──
              _Group(
                title: '계정',
                children: [
                  const _Row(label: '이메일',        value: 'dhis127@gmail.com'),
                  const _Row(label: 'OCR 언어',      value: '한국어 + English'),
                  const _Row(label: '독서 리마인더',  value: '매일 오후 9시'),
                  const _Row(label: '데이터 내보내기', value: '.csv'),
                  _Row(label: '로그아웃', showArrow: true, last: true, onTap: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }),
                ],
              ),

              // ── About ──
              Container(
                margin: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: DesignTokens.bgIvoryDeep,
                  border: Border.all(color: DesignTokens.rule),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ABOUT · 개발자 메시지',
                        style: DesignTokens.ptSans(10, weight: FontWeight.w700, color: DesignTokens.inkMute)
                            .copyWith(letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text('한 문장이 마음에 머무는 시간을 잃지 않으려고 만들었어요.',
                        style: DesignTokens.hahmlet(13, color: DesignTokens.inkSoft).copyWith(height: 1.65)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('리비 / Libre Viajera',
                            style: DesignTokens.ptSans(10, color: DesignTokens.inkFaint)
                                .copyWith(letterSpacing: 1.2)),
                        Text('REVI v0.1.0',
                            style: DesignTokens.ptSans(10, color: DesignTokens.inkFaint)
                                .copyWith(letterSpacing: 1.2)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title.toUpperCase(),
                style: DesignTokens.ptSans(10, weight: FontWeight.w700, color: DesignTokens.inkMute)
                    .copyWith(letterSpacing: 1.5)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: DesignTokens.bgIvoryDeep,
              border: Border.all(color: DesignTokens.rule),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final bool showArrow;
  final bool last;
  final VoidCallback? onTap;

  const _Row({
    required this.label,
    this.value,
    this.showArrow = false,
    this.last = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: DesignTokens.rule)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: DesignTokens.hahmlet(13))),
            if (value != null)
              Text(value!, style: DesignTokens.hahmlet(12, color: DesignTokens.inkMute)),
            if (showArrow) ...[
              const SizedBox(width: 6),
              Text('›', style: DesignTokens.ptSans(16, color: DesignTokens.inkFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final String label;
  final Color color;
  final bool last;
  const _SwatchRow({required this.label, required this.color, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: DesignTokens.rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: DesignTokens.hahmlet(13))),
          Text('변경',
              style: DesignTokens.hahmlet(11, color: DesignTokens.terracotta, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
