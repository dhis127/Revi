import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../providers/app_state.dart';

class SlotFilterChip extends StatelessWidget {
  final String? label;
  final Color? dotColor;
  final bool active;
  final VoidCallback onTap;

  const SlotFilterChip({
    super.key,
    this.label,
    this.dotColor,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    // 다크: 활성 칩은 밝은 잉크 배경 + 어두운 글자 (라이트의 반전)
    final activeBg     = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final activeFg     = isDark ? DesignTokens.bgDark  : DesignTokens.bgIvory;
    final inactiveFg   = isDark ? DesignTokens.inkDark : DesignTokens.ink;
    final inactiveLine = isDark ? DesignTokens.ruleDarkStrong : DesignTokens.ruleStrong;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: dotColor != null
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.transparent,
          border: Border.all(color: active ? activeBg : inactiveLine),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: Colors.white.withValues(alpha: 0.4))
                      : null,
                ),
              ),
            if (label != null) ...[
              if (dotColor != null) const SizedBox(width: 5),
              Text(label!,
                  style: DesignTokens.hahmlet(11,
                      color: active ? activeFg : inactiveFg)),
            ],
          ],
        ),
      ),
    );
  }
}
