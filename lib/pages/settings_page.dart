import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../providers/app_state.dart';
import 'login_page.dart';
import '../models/subscription_model.dart';
import 'subscription_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity;
        if (v != null && v > 200) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
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
                    style: DesignTokens.hahmlet(26, weight: FontWeight.w600, color: isDark ? DesignTokens.inkDark : DesignTokens.ink).copyWith(letterSpacing: -0.2)),
              ),

              // ── 화면 표시 ──
              _Group(
                title: '화면 표시',
                children: [
                  _UsageLimitSection(state: state, isDark: isDark),
                  Divider(height: 1, color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                  _Row(
                    label: '테마',
                    value: _getThemeModeName(state.themeMode),
                    onTap: () => _showThemeModeDialog(context),
                    last: true,
                  ),
                ],
              ),

              // ── 노트 부분 ──
              _Group(
                title: '노트 부분',
                children: [
                  ...state.highlightSlotOrder.asMap().entries.map((e) {
                    final slot = e.value;
                    final idx  = e.key;
                    final isLast = idx == state.highlightSlotOrder.length - 1 && !state.isPremium;
                    return _SwatchRow(
                      label: _slotName(slot, idx),
                      slot: slot,
                      color: state.slotColor(slot),
                      canDelete: !['sage', 'terra', 'amber'].contains(slot),
                      last: isLast,
                    );
                  }),
                  _SlotAddRow(state: state),
                  _FontPickerRow(currentFont: state.memoFont, last: true),
                ],
              ),

              // ── 구독 ──
              _SubscriptionBanner(isDark: isDark, state: state),

              // ── 알림 ──
              _Group(
                title: '알림',
                children: [
                  _ReminderRow(state: state, isDark: isDark),
                ],
              ),

              // ── 계정 ──
              _Group(
                title: '계정',
                children: [
                  _NicknameRow(state: state, isDark: isDark),
                  Divider(height: 1, color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                  const _Row(label: '이메일', value: 'dhis127@gmail.com'),
                  _OcrLanguageRow(state: state),
                  _ExportRow(state: state),
                  _Row(label: '로그아웃', showArrow: true, last: true, onTap: () {
                    _showLogoutDialog(context);
                  }),
                ],
              ),

              // ── About ──
              Container(
                margin: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
                  border: Border.all(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ABOUT · 개발자 메시지',
                        style: DesignTokens.ptSans(10, weight: FontWeight.w700, color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                            .copyWith(letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text('한 문장이 마음에 머무는 시간을 잃지 않으려고 만들었어요.',
                        style: DesignTokens.hahmlet(13, color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft).copyWith(height: 1.65)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('리비 / Libre Viajera',
                            style: DesignTokens.ptSans(10, color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
                                .copyWith(letterSpacing: 1.2)),
                        Text('REVI v0.1.0',
                            style: DesignTokens.ptSans(10, color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
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

  String _getThemeModeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light: return '라이트';
      case AppThemeMode.rest:  return '레스트';
      case AppThemeMode.dark:  return '다크';
      case AppThemeMode.sepia: return '세피아';
    }
  }

  void _showThemeModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ThemePickerDialog(parentContext: context),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final AppThemeMode mode;
  final String label;
  final String description;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeModeOption({
    required this.mode,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.locked,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ink  = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge)
                : null,
            border: Border(
              bottom: BorderSide(
                color: isDark ? DesignTokens.ruleDark : DesignTokens.rule,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: DesignTokens.hahmlet(13, weight: FontWeight.w600, color: ink)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: DesignTokens.ptSans(10, color: mute)),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline, size: 14, color: faint)
              else if (isSelected)
                Icon(Icons.check_circle,
                    size: 20,
                    color: isDark ? DesignTokens.sageDark : DesignTokens.sage),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Theme Picker Dialog (테마 + 강도 조절) ────────────────────────────────────
class _ThemePickerDialog extends StatefulWidget {
  final BuildContext parentContext;
  const _ThemePickerDialog({required this.parentContext});

  @override
  State<_ThemePickerDialog> createState() => _ThemePickerDialogState();
}

class _ThemePickerDialogState extends State<_ThemePickerDialog> {
  late double _intensity;

  @override
  void initState() {
    super.initState();
    _intensity = context.read<AppState>().themeIntensity;
  }

  String _modeLabel(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.light: return '라이트';
      case AppThemeMode.rest:  return '레스트';
      case AppThemeMode.dark:  return '다크';
      case AppThemeMode.sepia: return '세피아';
    }
  }

  String _modeDesc(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.light: return '밝은 배경 (기본)';
      case AppThemeMode.rest:  return '따뜻한 톤 · 블루라이트 필터 (스탠다드+)';
      case AppThemeMode.dark:  return '어두운 배경 · 블루라이트 필터 (스탠다드+)';
      case AppThemeMode.sepia: return '세피아 톤 · 클래식 독서 감성 (프리미엄)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final isDark = state.isDark;
    final ink    = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute   = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;

    return AlertDialog(
      backgroundColor: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
      title: Text('테마 선택',
          style: DesignTokens.hahmlet(16, weight: FontWeight.w600, color: ink)),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...AppThemeMode.values.map((mode) {
            final canUse = state.canUseThemeMode(mode);
            return _ThemeModeOption(
              mode: mode,
              label: _modeLabel(mode),
              description: _modeDesc(mode),
              isSelected: state.themeMode == mode,
              locked: !canUse,
              isDark: isDark,
              onTap: () {
                if (!canUse) {
                  final plan = (mode == AppThemeMode.sepia) ? '프리미엄' : '스탠다드';
                  Navigator.pop(context); // theme dialog 닫기
                  showDialog(
                    context: widget.parentContext,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: Text('$plan 전용 테마',
                          style: DesignTokens.hahmlet(16, weight: FontWeight.w600,
                              color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                      content: Text('이 테마는 $plan 구독 후 이용할 수 있어요.',
                          style: DesignTokens.hahmlet(13,
                              color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: Text('닫기',
                              style: DesignTokens.hahmlet(13,
                                  color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            Navigator.push(
                              widget.parentContext,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const SubscriptionPage(),
                                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                                  position: Tween<Offset>(
                                      begin: const Offset(0, 1), end: Offset.zero)
                                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                                  child: child,
                                ),
                                transitionDuration: const Duration(milliseconds: 350),
                              ),
                            );
                          },
                          child: Text('구독하기',
                              style: DesignTokens.hahmlet(13,
                                  weight: FontWeight.w600, color: DesignTokens.sage)),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                state.setThemeMode(mode);
                Navigator.pop(context);
              },
            );
          }),
          // 스탠다드+: 필터 강도 슬라이더 (프리미엄만 조작 가능, 스탠다드는 잠금 표시)
          if (state.isSubscribed) ...[
            Divider(height: 1, color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('필터 강도',
                              style: DesignTokens.hahmlet(12, weight: FontWeight.w600, color: ink)),
                          if (!state.isPremium) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock_outline, size: 12,
                                color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
                          ],
                        ],
                      ),
                      Text(state.isPremium ? '${(_intensity * 100).round()}%' : 'PREMIUM',
                          style: state.isPremium
                              ? DesignTokens.ptSans(11, color: mute)
                              : DesignTokens.ptSans(9,
                                      weight: FontWeight.w700, color: DesignTokens.amber)
                                  .copyWith(letterSpacing: 0.6)),
                    ],
                  ),
                  Opacity(
                    opacity: state.isPremium ? 1.0 : 0.35,
                    child: Slider(
                      value: state.isPremium ? _intensity : 1.0,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      activeColor: DesignTokens.amber,
                      inactiveColor: isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge,
                      onChanged: state.isPremium
                          ? (v) {
                              setState(() => _intensity = v);
                              state.setThemeIntensity(v);
                            }
                          : null,
                    ),
                  ),
                  Text(
                    state.isPremium
                        ? 'light 모드에서는 필터가 적용되지 않아요.'
                        : '프리미엄 구독 시 필터 강도를 자유롭게 조절할 수 있어요.',
                    style: DesignTokens.ptSans(10, color: mute).copyWith(letterSpacing: 0.1),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('닫기',
              style: DesignTokens.hahmlet(12, color: ink)),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title.toUpperCase(),
                style: DesignTokens.ptSans(10, weight: FontWeight.w700,
                    color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
                    .copyWith(letterSpacing: 1.5)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvoryDeep,
              border: Border.all(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule),
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
    final isDark = context.watch<AppState>().isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(
            color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label,
                style: DesignTokens.hahmlet(13, color: isDark ? DesignTokens.inkDark : DesignTokens.ink))),
            if (value != null)
              Text(value!, style: DesignTokens.hahmlet(12,
                  color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
            if (showArrow) ...[
              const SizedBox(width: 6),
              Text('›', style: DesignTokens.ptSans(16,
                  color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final String label;
  final String slot;
  final Color color;
  final bool last;
  final bool canDelete;
  const _SwatchRow({
    required this.label,
    required this.slot,
    required this.color,
    this.last = false,
    this.canDelete = false,
  });

  void _showPicker(BuildContext context) {
    final state = context.read<AppState>();
    showDialog(
      context: context,
      builder: (_) => _ColorPickerDialog(
        slot: slot,
        current: color,
        isPremium: state.isPremium,
      ),
    );
  }

  String _slotNumber(String label) {
    // "슬롯 1 · Sage" → "슬롯 1"
    final parts = label.split(' · ');
    return parts.isNotEmpty ? parts[0] : label;
  }

  String _slotHintName(String label) {
    // "슬롯 1 · Sage" → "Sage"
    final parts = label.split(' · ');
    return parts.length > 1 ? parts[1] : '';
  }

  Widget _buildHintText(BuildContext context, bool isDark) {
    final state = context.read<AppState>();
    final isDefault = state.isDefaultSlotColor(slot);
    final faint = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    final hintName = _slotHintName(label);

    return GestureDetector(
      onTap: isDefault ? null : () => state.resetSlotColor(slot),
      child: Text(
        isDefault ? hintName : '↺ $hintName (기본으로)',
        style: DesignTokens.ptSans(9, color: faint)
            .copyWith(letterSpacing: 0.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(
          color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showPicker(context),
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _showPicker(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 슬롯 번호 (예: 슬롯 1)
                  Text(_slotNumber(label),
                      style: DesignTokens.hahmlet(13,
                          color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                  // 원래 색상명 힌트 (예: Sage) — 색이 바뀌면 리셋 가능 표시
                  if (_slotHintName(label).isNotEmpty)
                    _buildHintText(context, isDark),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showPicker(context),
            child: Text('변경',
                style: DesignTokens.hahmlet(11,
                    color: DesignTokens.terracotta, weight: FontWeight.w700)),
          ),
          if (canDelete) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => context.read<AppState>().removeHighlightSlot(slot),
              child: Icon(Icons.remove_circle_outline, size: 16,
                  color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Slot Add Row ─────────────────────────────────────────────────────────────
class _SlotAddRow extends StatelessWidget {
  final AppState state;
  const _SlotAddRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark    = context.watch<AppState>().isDark;
    final isPremium = state.isPremium;
    final canAdd    = state.canAddHighlightSlot; // false when slots >= 7
    final slotCount = state.highlightSlotOrder.length;
    final ink       = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final faint     = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    final rule      = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    // 상태: ① 비프리미엄 → 잠금  ② 프리미엄 한도 도달 → 비활성  ③ 프리미엄 추가 가능 → 활성
    final bool isLocked    = !isPremium;
    final bool isAtLimit   = isPremium && !canAdd;
    final bool isAvailable = isPremium && canAdd;

    return GestureDetector(
      onTap: isLocked
          ? () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage()))
          : isAvailable
              ? () => context.read<AppState>().addHighlightSlot()
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: rule)),
        ),
        child: Row(
          children: [
            Icon(
              isLocked
                  ? Icons.lock_outline
                  : isAtLimit
                      ? Icons.check_circle_outline
                      : Icons.add_circle_outline,
              size: 15,
              color: isAvailable ? DesignTokens.sage : faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLocked
                    ? '색상 슬롯 추가 — 프리미엄 전용 (최대 7개)'
                    : isAtLimit
                        ? '최대 슬롯 도달 ($slotCount / 7)'
                        : '색상 슬롯 추가 ($slotCount / 7)',
                style: DesignTokens.hahmlet(13, color: isAvailable ? ink : faint),
              ),
            ),
            if (isLocked)
              Text('PREMIUM',
                  style: DesignTokens.ptSans(9,
                          weight: FontWeight.w700, color: DesignTokens.amber)
                      .copyWith(letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ─── Export Format Row ────────────────────────────────────────────────────────
class _ExportRow extends StatelessWidget {
  final AppState state;
  const _ExportRow({required this.state});

  static const _formatLabels = {
    'csv': 'CSV',
    'pdf': 'PDF',
    'md':  'Markdown',
  };

  void _showFormatPicker(BuildContext context, AppState live) {
    final isDark = live.isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('내보내기 포맷',
                style: DesignTokens.hahmlet(16, weight: FontWeight.w600,
                    color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
            const SizedBox(height: 4),
            Text('저장된 문장을 어떤 형식으로 내보낼지 선택하세요.',
                style: DesignTokens.ptSans(11,
                    color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
                    .copyWith(letterSpacing: 0.2)),
            const SizedBox(height: 16),
            ...live.availableExportFormats.map((fmt) {
              final isSelected = live.exportFormat == fmt;
              return GestureDetector(
                onTap: () {
                  sheetCtx.read<AppState>().setExportFormat(fmt);
                  Navigator.pop(sheetCtx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)
                          : (isDark ? DesignTokens.ruleDark : DesignTokens.rule),
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatLabels[fmt] ?? fmt.toUpperCase(),
                                style: DesignTokens.hahmlet(14, weight: FontWeight.w600,
                                    color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                            const SizedBox(height: 2),
                            Text(_formatDesc(fmt),
                                style: DesignTokens.ptSans(11,
                                    color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check, size: 16,
                            color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDesc(String fmt) {
    switch (fmt) {
      case 'csv': return '스프레드시트 호환 · 엑셀, Notion 등';
      case 'pdf': return '인쇄 가능한 문서 형식';
      case 'md':  return 'Obsidian, Notion, GitHub 등';
      default:    return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch 로 직접 읽어야 구독 변경 즉시 반영
    final live   = context.watch<AppState>();
    final isDark = live.isDark;
    final isFree = live.availableExportFormats.isEmpty;
    final isPrem = live.isPremium;
    final ink    = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute   = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint  = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    final rule   = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    return GestureDetector(
      onTap: isFree
          ? () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage()))
          : (isPrem ? () => _showFormatPicker(context, live) : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: rule)),
        ),
        child: Row(
          children: [
            Expanded(child: Text('데이터 내보내기',
                style: DesignTokens.hahmlet(13, color: ink))),
            if (isFree)
              Row(children: [
                Icon(Icons.lock_outline, size: 13, color: faint),
                const SizedBox(width: 4),
                Text('구독 필요', style: DesignTokens.hahmlet(12, color: faint)),
              ])
            else
              Text((_ExportRow._formatLabels[live.exportFormat] ?? live.exportFormat.toUpperCase()),
                  style: DesignTokens.hahmlet(12, color: mute)),
            if (isPrem && !isFree) ...[
              const SizedBox(width: 6),
              Text('›', style: DesignTokens.ptSans(16, color: faint)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Reminder Row ─────────────────────────────────────────────────────────────
class _ReminderRow extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _ReminderRow({required this.state, required this.isDark});

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? '오전' : '오후';
    return '$p $h:$m';
  }

  String _daysSummary(Set<int> days) {
    if (days.length == 7) return '매일';
    if (days.isEmpty) return '—';
    return _dayLabels.asMap().entries
        .where((e) => days.contains(e.key))
        .map((e) => e.value)
        .join(' ');
  }

  Future<void> _pickTime(BuildContext context, bool isStart, TimeOfDay initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      if (isStart) {
        context.read<AppState>().setReminderStartTime(picked);
      } else {
        context.read<AppState>().setReminderEndTime(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final live         = context.watch<AppState>();
    final isSubscribed = live.isSubscribed;
    final ink          = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute         = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint        = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    final rule         = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    return Column(
      children: [
        // ── 토글 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: rule)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('문장 리마인더',
                        style: DesignTokens.hahmlet(13,
                            color: isSubscribed ? ink : faint)),
                    const SizedBox(height: 2),
                    Text(
                      isSubscribed
                          ? '저장한 문장을 랜덤 시각에 알려드려요'
                          : '스탠다드 구독 후 이용 가능',
                      style: DesignTokens.ptSans(10,
                              color: isSubscribed ? mute : faint)
                          .copyWith(letterSpacing: 0.1),
                    ),
                  ],
                ),
              ),
              if (isSubscribed)
                Switch(
                  value: live.reminderEnabled,
                  onChanged: (v) =>
                      context.read<AppState>().setReminderEnabled(v),
                  activeColor: DesignTokens.sage,
                )
              else
                Row(children: [
                  Icon(Icons.lock_outline, size: 13, color: faint),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SubscriptionPage())),
                    child: Text('구독하기',
                        style: DesignTokens.hahmlet(11,
                            color: DesignTokens.terracotta,
                            weight: FontWeight.w700)),
                  ),
                ]),
            ],
          ),
        ),

        // ── 알림 요일 선택 ──
        if (isSubscribed && live.reminderEnabled) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: rule)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('알림 요일',
                          style: DesignTokens.hahmlet(13, color: ink)),
                    ),
                    Text(
                      _daysSummary(live.reminderDays),
                      style: DesignTokens.hahmlet(12,
                          weight: FontWeight.w600, color: DesignTokens.sage),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final selected = live.reminderDays.contains(i);
                    return GestureDetector(
                      onTap: () =>
                          context.read<AppState>().toggleReminderDay(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? DesignTokens.sage
                              : (isDark
                                  ? DesignTokens.bgDarkEdge
                                  : DesignTokens.bgIvoryEdge),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? DesignTokens.sage
                                : rule,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _dayLabels[i],
                            style: DesignTokens.hahmlet(12,
                                weight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : (isDark
                                        ? DesignTokens.inkDarkSoft
                                        : DesignTokens.inkSoft)),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── 알림 시간대 (시작 ~ 종료) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('알림 시간대',
                    style: DesignTokens.hahmlet(13, color: ink)),
                const SizedBox(height: 2),
                Text('지정한 시간대 중 랜덤 시각에 알림이 와요',
                    style: DesignTokens.ptSans(10, color: mute)
                        .copyWith(letterSpacing: 0.1)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // 시작 시간
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(
                            context, true, live.reminderStartTime),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DesignTokens.bgDarkEdge
                                : DesignTokens.bgIvoryEdge,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: rule),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('시작',
                                  style: DesignTokens.ptSans(9, color: faint)
                                      .copyWith(letterSpacing: 0.3)),
                              const SizedBox(height: 3),
                              Text(_fmtTime(live.reminderStartTime),
                                  style: DesignTokens.hahmlet(14,
                                      weight: FontWeight.w600, color: ink)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('~',
                          style: DesignTokens.hahmlet(16, color: mute)),
                    ),
                    // 종료 시간
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(
                            context, false, live.reminderEndTime),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DesignTokens.bgDarkEdge
                                : DesignTokens.bgIvoryEdge,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: rule),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('종료',
                                  style: DesignTokens.ptSans(9, color: faint)
                                      .copyWith(letterSpacing: 0.3)),
                              const SizedBox(height: 3),
                              Text(_fmtTime(live.reminderEndTime),
                                  style: DesignTokens.hahmlet(14,
                                      weight: FontWeight.w600, color: ink)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── OCR Language Row ────────────────────────────────────────────────────────
class _OcrLanguageRow extends StatelessWidget {
  final AppState state;
  const _OcrLanguageRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark       = context.watch<AppState>().isDark;
    final isSubscribed = state.isSubscribed;
    final ink          = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute         = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint        = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;
    final rule         = isDark ? DesignTokens.ruleDark : DesignTokens.rule;

    return GestureDetector(
      onTap: isSubscribed
          ? null
          : () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: rule)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('OCR 언어',
                  style: DesignTokens.hahmlet(13, color: ink)),
            ),
            if (isSubscribed)
              Text('언어 제한 없음',
                  style: DesignTokens.hahmlet(12, color: mute))
            else
              Row(children: [
                Icon(Icons.lock_outline, size: 13, color: faint),
                const SizedBox(width: 4),
                Text('구독 필요', style: DesignTokens.hahmlet(12, color: faint)),
              ]),
          ],
        ),
      ),
    );
  }
}

// ─── Font Picker Row ──────────────────────────────────────────────────────────
class _FontPickerRow extends StatelessWidget {
  final String currentFont;
  final bool last;
  const _FontPickerRow({required this.currentFont, this.last = false});

  String get _currentLabel {
    return DesignTokens.memoFontOptions
        .firstWhere((f) => f['key'] == currentFont,
            orElse: () => DesignTokens.memoFontOptions.first)['label']!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return GestureDetector(
      onTap: () => _showFontPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(
            color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
        ),
        child: Row(
          children: [
            Icon(Icons.text_fields_outlined, size: 16,
                color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute),
            const SizedBox(width: 10),
            Expanded(child: Text('메모 폰트',
                style: DesignTokens.hahmlet(13, color: isDark ? DesignTokens.inkDark : DesignTokens.ink))),
            Text(_currentLabel,
                style: DesignTokens.hahmlet(12,
                    color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
            const SizedBox(width: 6),
            Text('›', style: DesignTokens.ptSans(16,
                color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)),
          ],
        ),
      ),
    );
  }

  void _showFontPicker(BuildContext context) {
    final isDark = context.read<AppState>().isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _FontPickerSheet(currentFont: currentFont),
    );
  }
}

class _FontPickerSheet extends StatelessWidget {
  final String currentFont;
  const _FontPickerSheet({required this.currentFont});

  // 폰트 옵션 빌더 (중복 제거용)
  Widget _fontTile(BuildContext context, Map<String, String> f, bool canUse) {
    return _FontOption(
      fontMap: f,
      isSelected: currentFont == f['key'],
      locked: !canUse,
      onTap: () {
        if (!canUse) {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage()));
          return;
        }
        context.read<AppState>().updateMemoFont(f['key']!);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final isDark = state.isDark;

    // ── Standard 접근 가능 (고딕 5종 + 필기체 5종) ──
    final stdGothic = DesignTokens.memoFontOptions
        .where((f) => f['category'] == '고딕' &&
            DesignTokens.standardFontKeys.contains(f['key']))
        .toList();
    final stdHandwriting = DesignTokens.memoFontOptions
        .where((f) => f['category'] == '필기체' &&
            DesignTokens.standardFontKeys.contains(f['key']))
        .toList();

    // ── Premium 전용 (category 기준 분류) ──
    final premGothic = DesignTokens.memoFontOptions
        .where((f) => f['category'] == '고딕' &&
            !DesignTokens.standardFontKeys.contains(f['key']))
        .toList();
    final premMyeongjo = DesignTokens.memoFontOptions
        .where((f) => f['category'] == '명조')
        .toList();
    final premHandwriting = DesignTokens.memoFontOptions
        .where((f) => f['category'] == '필기체' &&
            !DesignTokens.standardFontKeys.contains(f['key']))
        .toList();
    final premSerif = DesignTokens.memoFontOptions
        .where((f) => f['category'] == 'Serif')
        .toList();

    final ink   = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final faint = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.bgDark : DesignTokens.bgIvory,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('메모 폰트 선택',
                style: DesignTokens.hahmlet(16, weight: FontWeight.w600, color: ink)),
            const SizedBox(height: 4),
            Text('스탠다드 이상부터 고딕·필기체 10종, 프리미엄은 25종을 이용할 수 있어요.',
                style: DesignTokens.ptSans(10, color: faint)
                    .copyWith(letterSpacing: 0.2, height: 1.5)),
            const SizedBox(height: 18),

            // ── 고딕체 (Standard 5종) ──
            _FontCategoryLabel(label: '고딕체'),
            const SizedBox(height: 8),
            ...stdGothic.map((f) {
              final canUse = state.canUseFont(f['key']!);
              return _fontTile(context, f, canUse);
            }),
            const SizedBox(height: 12),

            // ── 필기체 (Standard 5종) ──
            _FontCategoryLabel(label: '필기체'),
            const SizedBox(height: 8),
            ...stdHandwriting.map((f) {
              final canUse = state.canUseFont(f['key']!);
              return _fontTile(context, f, canUse);
            }),
            const SizedBox(height: 20),

            // ── PREMIUM 구분선 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DesignTokens.amber.withValues(alpha: 0.08),
                border: Border.all(color: DesignTokens.amber.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      size: 14, color: DesignTokens.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PREMIUM 전용 · 총 ${premGothic.length + premMyeongjo.length + premHandwriting.length + premSerif.length}종 추가 폰트',
                      style: DesignTokens.ptSans(10,
                              weight: FontWeight.w700, color: DesignTokens.amber)
                          .copyWith(letterSpacing: 0.4),
                    ),
                  ),
                  if (!state.isPremium)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SubscriptionPage()));
                      },
                      child: Text('업그레이드 →',
                          style: DesignTokens.ptSans(9,
                                  weight: FontWeight.w700, color: DesignTokens.amber)
                              .copyWith(letterSpacing: 0.3)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 고딕체+ (Premium 5종) ──
            _FontCategoryLabel(label: '고딕체+'),
            const SizedBox(height: 8),
            ...premGothic.map((f) => _fontTile(context, f, state.isPremium)),
            const SizedBox(height: 12),

            // ── 명조체 (Premium 3종) ──
            _FontCategoryLabel(label: '명조체'),
            const SizedBox(height: 8),
            ...premMyeongjo.map((f) => _fontTile(context, f, state.isPremium)),
            const SizedBox(height: 12),

            // ── 필기체+ (Premium 4종) ──
            _FontCategoryLabel(label: '필기체+'),
            const SizedBox(height: 8),
            ...premHandwriting.map((f) => _fontTile(context, f, state.isPremium)),
            const SizedBox(height: 12),

            // ── Serif 영문 (Premium 4종) ──
            _FontCategoryLabel(label: 'Serif (영문)'),
            const SizedBox(height: 8),
            ...premSerif.map((f) => _fontTile(context, f, state.isPremium)),
          ],
        ),
      ),
    );
  }
}

class _FontCategoryLabel extends StatelessWidget {
  final String label;
  const _FontCategoryLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return Text(label.toUpperCase(),
        style: DesignTokens.ptSans(9, weight: FontWeight.w700,
            color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)
            .copyWith(letterSpacing: 1.5));
  }
}

class _FontOption extends StatelessWidget {
  final Map<String, String> fontMap;
  final bool isSelected;
  final bool locked; // NEW
  final VoidCallback onTap;
  const _FontOption({required this.fontMap, required this.isSelected, required this.onTap, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryDeep)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? (isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)
                  : (isDark ? DesignTokens.ruleDark : DesignTokens.rule),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fontMap['label']!,
                        style: DesignTokens.hahmlet(12, weight: FontWeight.w600,
                            color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                    const SizedBox(height: 3),
                    Text(fontMap['preview']!,
                        style: DesignTokens.memoStyle(fontMap['key']!, 14,
                            color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft)),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline, size: 14,
                    color: isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint)
              else if (isSelected)
                Icon(Icons.check, size: 16,
                    color: isDark ? DesignTokens.inkDarkSoft : DesignTokens.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

String _slotName(String slot, int index) {
  switch (slot) {
    case 'sage':  return '슬롯 1 · Sage';
    case 'terra': return '슬롯 2 · Terracotta';
    case 'amber': return '슬롯 3 · Amber Oak';
    default:      return '슬롯 ${index + 1}';
  }
}

// ─── Logout ───────────────────────────────────────────────────────────────────
void _showLogoutDialog(BuildContext context) {
  final isDark = context.read<AppState>().isDark;
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: isDark ? DesignTokens.bgDarkDeep : DesignTokens.bgIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('로그아웃 하시겠습니까?',
                style: DesignTokens.hahmlet(16, weight: FontWeight.w600,
                    color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
            const SizedBox(height: 8),
            Text('로그인 화면으로 이동합니다.',
                style: DesignTokens.ptSans(12,
                    color: isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute)),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('아니오', style: DesignTokens.hahmlet(13,
                        color: isDark ? DesignTokens.inkDark : DesignTokens.ink)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.terracotta,
                      foregroundColor: DesignTokens.bgIvory,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    child: Text('예',
                        style: DesignTokens.hahmlet(14,
                            weight: FontWeight.w600,
                            color: DesignTokens.bgIvory)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── 닉네임 수정 Row ──────────────────────────────────────────────────────────
class _NicknameRow extends StatefulWidget {
  final AppState state;
  final bool isDark;
  const _NicknameRow({required this.state, required this.isDark});

  @override
  State<_NicknameRow> createState() => _NicknameRowState();
}

class _NicknameRowState extends State<_NicknameRow> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.nickname);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AppState>().setNickname(_ctrl.text);
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final ink    = isDark ? DesignTokens.inkDark     : DesignTokens.ink;
    final mute   = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;
    final faint  = isDark ? DesignTokens.inkDarkFaint : DesignTokens.inkFaint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('닉네임',
                    style: DesignTokens.hahmlet(14, color: ink)),
                const SizedBox(height: 4),
                _editing
                    ? TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: DesignTokens.hahmlet(13, color: ink),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        onTapOutside: (_) => _save(),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '닉네임을 입력하세요',
                          hintStyle: DesignTokens.hahmlet(13, color: faint),
                          border: InputBorder.none,
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: isDark ? DesignTokens.ruleDark : DesignTokens.rule)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: DesignTokens.sage)),
                        ),
                      )
                    : Text(
                        widget.state.nickname.isEmpty ? '설정되지 않음' : widget.state.nickname,
                        style: DesignTokens.hahmlet(13,
                            color: widget.state.nickname.isEmpty ? faint : mute),
                      ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_editing) {
                _save();
              } else {
                setState(() => _editing = true);
              }
            },
            child: Text(
              _editing ? '저장' : '수정',
              style: DesignTokens.hahmlet(13,
                  color: _editing ? DesignTokens.sage : mute),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Usage Limit Section ──────────────────────────────────────────────────────
class _UsageLimitSection extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _UsageLimitSection({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bookMax      = SubscriptionLimits.maxBooks[state.subscriptionTier]!;
    final bookUnlim    = bookMax >= 999999;
    final bookUsed     = state.effectiveBookCount;
    final bookProgress = bookUnlim ? 1.0 : (bookUsed / bookMax).clamp(0.0, 1.0);

    final hlMax      = SubscriptionLimits.maxHighlights[state.subscriptionTier]!;
    final hlUnlim    = hlMax >= 999999;
    final hlUsed     = state.effectiveHighlightCount;
    final hlProgress = hlUnlim ? 1.0 : (hlUsed / hlMax).clamp(0.0, 1.0);

    final barColor = state.isPremium
        ? DesignTokens.amber
        : (state.isStandard ? DesignTokens.terracotta : DesignTokens.inkFaint);
    final barBg  = isDark ? DesignTokens.bgDarkEdge : DesignTokens.bgIvoryEdge;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GaugeRow(
            label: '저장된 책',
            unit: '권',
            used: bookUsed,
            max: bookMax,
            unlimited: bookUnlim,
            progress: bookProgress,
            isNear: state.isNearBookLimit,
            barColor: barColor,
            barBg: barBg,
            isDark: isDark,
            isSubscribed: state.isSubscribed,
            onUpgradeTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionPage())),
          ),
          const SizedBox(height: 14),
          _GaugeRow(
            label: '저장된 문장',
            unit: '개',
            used: hlUsed,
            max: hlMax,
            unlimited: hlUnlim,
            progress: hlProgress,
            isNear: state.isNearHighlightLimit,
            barColor: barColor,
            barBg: barBg,
            isDark: isDark,
            isSubscribed: state.isSubscribed,
            onUpgradeTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionPage())),
          ),
        ],
      ),
    );
  }
}

class _GaugeRow extends StatelessWidget {
  final String label;
  final String unit;
  final int used;
  final int max;
  final bool unlimited;
  final double progress;
  final bool isNear;
  final bool isSubscribed;
  final Color barColor;
  final Color barBg;
  final bool isDark;
  final VoidCallback onUpgradeTap;

  const _GaugeRow({
    required this.label,
    required this.unit,
    required this.used,
    required this.max,
    required this.unlimited,
    required this.progress,
    required this.isNear,
    required this.isSubscribed,
    required this.barColor,
    required this.barBg,
    required this.isDark,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink   = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final mute  = isDark ? DesignTokens.inkDarkMute : DesignTokens.inkMute;

    final valueText = unlimited
        ? '$used$unit · 무제한'
        : '$used / $max$unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: DesignTokens.hahmlet(13, color: ink),
                  children: [
                    TextSpan(text: '$label  '),
                    TextSpan(
                      text: valueText,
                      style: DesignTokens.hahmlet(13,
                          weight: FontWeight.w600, color: ink),
                    ),
                  ],
                ),
              ),
            ),
            if (!isSubscribed)
              GestureDetector(
                onTap: onUpgradeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: mute),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('구독하기',
                      style: DesignTokens.hahmlet(11, color: ink)),
                ),
              )
            else if (unlimited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('무제한',
                    style: DesignTokens.ptSans(10,
                            weight: FontWeight.w700, color: barColor)
                        .copyWith(letterSpacing: 0.4)),
              )
            else if (isNear)
              GestureDetector(
                onTap: onUpgradeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DesignTokens.terracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('한도 임박 →',
                      style: DesignTokens.ptSans(10,
                              weight: FontWeight.w700, color: DesignTokens.terracotta)
                          .copyWith(letterSpacing: 0.3)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: unlimited ? 1.0 : progress,
            minHeight: 4,
            backgroundColor: barBg,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }
}

// ─── Subscription Banner ─────────────────────────────────────────────────────
class _SubscriptionBanner extends StatelessWidget {
  final bool isDark;
  final AppState state;
  const _SubscriptionBanner({required this.isDark, required this.state});

  @override
  Widget build(BuildContext context) {
    final plan = state.subscriptionTier;

    final (gradColors, badgeLabel, title, subtitle) = switch (plan) {
      SubscriptionTier.standardMonthly => (
          [DesignTokens.terracotta.withValues(alpha: 0.9), const Color(0xFF8A3F20)],
          'MONTHLY',
          'STANDARD MONTHLY',
          '연간으로 전환하면 4개월이 공짜예요 →',
        ),
      SubscriptionTier.standardAnnual => (
          [const Color(0xFF7A5030), const Color(0xFF4A3020)],
          'ANNUAL',
          'STANDARD ANNUAL',
          '프리미엄 업그레이드로 무제한 기능 이용 →',
        ),
      SubscriptionTier.premiumAnnual => (
          [const Color(0xFF5C3A18), const Color(0xFF3A2410)],
          'PREMIUM',
          'REVI PREMIUM',
          'AI 심층 리포트 · 카드형 아카이빙 · 무제한 이용 중',
        ),
      SubscriptionTier.free => (
          [DesignTokens.terracotta.withValues(alpha: 0.85), const Color(0xFF8A3F20)],
          null as String?,
          '구독 플랜 보기',
          '책 5권 · 문장 50개 이후 구독이 필요해요',
        ),
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: DesignTokens.ptSans(9,
                                weight: FontWeight.w700,
                                color: const Color(0xFFFFF0DC))
                            .copyWith(letterSpacing: 1.4),
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: plan == SubscriptionTier.premiumAnnual
                                ? DesignTokens.amber
                                : DesignTokens.sage,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badgeLabel,
                              style: DesignTokens.ptSans(7,
                                      weight: FontWeight.w700,
                                      color: DesignTokens.bgIvory)
                                  .copyWith(letterSpacing: 0.7)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: DesignTokens.hahmlet(12,
                            color: const Color(0xFFE8D4B8))
                        .copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('›',
                style: DesignTokens.ptSans(20,
                    color: const Color(0xFFD4B896))),
          ],
        ),
      ),
    );
  }
}

// ─── Color Picker Dialog ──────────────────────────────────────────────────────
class _ColorPickerDialog extends StatefulWidget {
  final String slot;
  final Color current;
  final bool isPremium;
  const _ColorPickerDialog({required this.slot, required this.current, this.isPremium = false});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  // ── 팔레트 (무료·스탠다드용 24색) ───────────────────────────────────────────
  static const _palette = [
    Color(0xFF8FB89E), Color(0xFF4A7B5E), Color(0xFF6DAA85), Color(0xFFA8CBB5),
    Color(0xFFB85C38), Color(0xFFD4784F), Color(0xFF9C3D20), Color(0xFFE8A080),
    Color(0xFF8A6523), Color(0xFFB8882E), Color(0xFF6E4F18), Color(0xFFC9A55C),
    Color(0xFF4A6FA5), Color(0xFF7DA0C4), Color(0xFF2E5082), Color(0xFF9BB8D4),
    Color(0xFF7B5EA7), Color(0xFFA484C8), Color(0xFF5C3D8A), Color(0xFFBDA0D8),
    Color(0xFFC4627A), Color(0xFFD98A9E), Color(0xFF9C3A54), Color(0xFFE8B0BF),
  ];

  late Color _selected;
  late HSVColor _hsv; // 프리미엄 HSV 피커용

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _hsv = HSVColor.fromColor(widget.current);
  }

  void _setFromColor(Color c) => setState(() {
    _selected = c;
    _hsv = HSVColor.fromColor(c);
  });

  void _setFromHsv(HSVColor hsv) => setState(() {
    _hsv = hsv;
    _selected = hsv.toColor();
  });

  String get _hexLabel =>
      '#${_selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  // ── 공통 버튼 ────────────────────────────────────────────────────────────────
  Widget _actionButtons(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: DesignTokens.ruleStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text('취소', style: DesignTokens.hahmlet(13)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          onPressed: () {
            context.read<AppState>().updateSlotColor(widget.slot, _selected);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: DesignTokens.ink,
            foregroundColor: DesignTokens.bgIvory,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
          ),
          child: Text('적용',
              style: DesignTokens.hahmlet(13,
                  weight: FontWeight.w600, color: DesignTokens.bgIvory)),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return widget.isPremium
        ? _buildHsvDialog(context)
        : _buildPaletteDialog(context);
  }

  // ── 무료·스탠다드: 24색 팔레트 다이얼로그 ──────────────────────────────────
  Widget _buildPaletteDialog(BuildContext context) {
    return Dialog(
      backgroundColor: DesignTokens.bgIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: _selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 10),
                Text('색상 변경',
                    style: DesignTokens.hahmlet(16, weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _palette.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, i) {
                final c = _palette[i];
                final isSel = c.toARGB32() == _selected.toARGB32();
                return GestureDetector(
                  onTap: () => _setFromColor(c),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSel
                          ? Border.all(color: DesignTokens.ink, width: 2.5)
                          : Border.all(color: Colors.black12),
                      boxShadow: isSel
                          ? [BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _actionButtons(context),
          ],
        ),
      ),
    );
  }

  // ── 프리미엄: HSV 컬러피커 다이얼로그 ────────────────────────────────────────
  Widget _buildHsvDialog(BuildContext context) {
    return Dialog(
      backgroundColor: DesignTokens.bgIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더: 미리보기 + 제목 + HEX 코드 ──
            Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('색상 변경',
                      style: DesignTokens.hahmlet(16, weight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DesignTokens.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(_hexLabel,
                      style: DesignTokens.ptSans(10,
                              weight: FontWeight.w700, color: DesignTokens.amber)
                          .copyWith(letterSpacing: 0.4)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 2D SB 피커 (채도×명도) ──
            LayoutBuilder(
              builder: (_, constraints) {
                const h = 168.0;
                final w = constraints.maxWidth;
                return GestureDetector(
                  onPanStart:  (d) => _onSbDrag(d.localPosition, w, h),
                  onPanUpdate: (d) => _onSbDrag(d.localPosition, w, h),
                  onTapDown:   (d) => _onSbDrag(d.localPosition, w, h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: _SbPickerPainter(
                        hue: _hsv.hue,
                        saturation: _hsv.saturation,
                        value: _hsv.value,
                      ),
                      size: Size(w, h),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── 색조(Hue) 슬라이더 ──
            LayoutBuilder(
              builder: (_, constraints) {
                const h = 24.0;
                final w = constraints.maxWidth;
                return GestureDetector(
                  onHorizontalDragStart:  (d) => _onHueDrag(d.localPosition.dx, w),
                  onHorizontalDragUpdate: (d) => _onHueDrag(d.localPosition.dx, w),
                  onTapDown: (d) => _onHueDrag(d.localPosition.dx, w),
                  child: CustomPaint(
                    painter: _HueSliderPainter(hue: _hsv.hue),
                    size: Size(w, h),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _actionButtons(context),
          ],
        ),
      ),
    );
  }

  void _onSbDrag(Offset pos, double w, double h) {
    final s = (pos.dx / w).clamp(0.0, 1.0);
    final v = (1.0 - pos.dy / h).clamp(0.0, 1.0);
    _setFromHsv(_hsv.withSaturation(s).withValue(v));
  }

  void _onHueDrag(double dx, double w) {
    final hue = ((dx / w) * 360).clamp(0.0, 360.0);
    _setFromHsv(_hsv.withHue(hue));
  }
}

// ─── SB Picker Painter (채도×명도 2D 피커) ────────────────────────────────────
class _SbPickerPainter extends CustomPainter {
  final double hue, saturation, value;
  const _SbPickerPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    // 가로: 흰색 → 순색 (채도)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );

    // 세로: 투명 → 검정 오버레이 (명도)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    // 선택 원 (흰 테두리 + 현재 색 내부)
    final cx = saturation * size.width;
    final cy = (1 - value) * size.height;
    final selColor = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
    canvas.drawCircle(Offset(cx, cy), 10,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx, cy), 8, Paint()..color = selColor);
  }

  @override
  bool shouldRepaint(covariant _SbPickerPainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}

// ─── Hue Slider Painter (무지개 바) ──────────────────────────────────────────
class _HueSliderPainter extends CustomPainter {
  final double hue;
  const _HueSliderPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    // 무지개 그라디언트
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ]).createShader(rect),
    );

    // 선택 핸들 (흰 테두리 사각형)
    final tx = (hue / 360) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(tx - 4, -1, 8, size.height + 2),
          const Radius.circular(4)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _HueSliderPainter old) => old.hue != hue;
}
